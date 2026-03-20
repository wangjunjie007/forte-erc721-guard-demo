import fs from "node:fs";
import path from "node:path";
import { createConfig, connect } from "@wagmi/core";
import { mock } from "@wagmi/connectors";
import { foundry } from "@wagmi/core/chains";
import { createTestClient, http, publicActions, walletActions } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { RulesEngine, setPolicies } from "@fortefoundation/forte-rules-engine-sdk";

export interface PolicyHelperConfig {
  rpcUrl: string;
  privateKey: `0x${string}`;
  rulesEngineAddress: `0x${string}`;
  nftAddress: `0x${string}`;
}

export interface CreateApplyResult {
  template: string;
  templatePath: string;
  policyId: number;
  appliedPolicyIds: number[];
  createResult: unknown;
  skippedApply: boolean;
  rulesEngineAddress: string;
  nftAddress: string;
  rpcUrl: string;
}

const TEMPLATE_DIR = path.resolve("examples/policies");

function ensureHexAddress(value: string, label: string): `0x${string}` {
  if (!/^0x[a-fA-F0-9]{40}$/.test(value)) {
    throw new Error(`${label} must be a 20-byte hex address, got: ${value}`);
  }
  return value as `0x${string}`;
}

function ensureHexPrivateKey(value: string, label: string): `0x${string}` {
  if (!/^0x[a-fA-F0-9]{64}$/.test(value)) {
    throw new Error(`${label} must be a 32-byte hex private key`);
  }
  return value as `0x${string}`;
}

export function listPolicyTemplates(): string[] {
  if (!fs.existsSync(TEMPLATE_DIR)) {
    return [];
  }

  return fs.readdirSync(TEMPLATE_DIR).filter((name) => name.endsWith(".policy.json")).sort();
}

export function resolveTemplatePath(template: string): string {
  const direct = path.resolve(template);
  if (fs.existsSync(direct) && direct.endsWith(".json")) {
    return direct;
  }

  const normalized = template.endsWith(".policy.json") ? template : `${template}.policy.json`;
  const inTemplateDir = path.resolve(TEMPLATE_DIR, normalized);
  if (fs.existsSync(inTemplateDir)) {
    return inTemplateDir;
  }

  const available = listPolicyTemplates();
  throw new Error(`Template not found: ${template}. Available templates: ${available.length ? available.join(", ") : "<none>"}`);
}

export function readPolicyTemplate(template: string): { templatePath: string; policySyntax: string } {
  const templatePath = resolveTemplatePath(template);
  return {
    templatePath,
    policySyntax: fs.readFileSync(templatePath, "utf8"),
  };
}

export class ForteNftPolicyHelper {
  private readonly config: PolicyHelperConfig;
  private readonly rulesEngine: Awaited<ReturnType<typeof RulesEngine.create>>;
  private readonly wagmiConfig: ReturnType<typeof createConfig>;

  private constructor(
    config: PolicyHelperConfig,
    rulesEngine: Awaited<ReturnType<typeof RulesEngine.create>>,
    wagmiConfig: ReturnType<typeof createConfig>,
  ) {
    this.config = config;
    this.rulesEngine = rulesEngine;
    this.wagmiConfig = wagmiConfig;
  }

  static async create(rawConfig: {
    rpcUrl: string;
    privateKey: string;
    rulesEngineAddress: string;
    nftAddress: string;
  }): Promise<ForteNftPolicyHelper> {
    const config: PolicyHelperConfig = {
      rpcUrl: rawConfig.rpcUrl,
      privateKey: ensureHexPrivateKey(rawConfig.privateKey, "privateKey"),
      rulesEngineAddress: ensureHexAddress(rawConfig.rulesEngineAddress, "rulesEngineAddress"),
      nftAddress: ensureHexAddress(rawConfig.nftAddress, "nftAddress"),
    };

    const account = privateKeyToAccount(config.privateKey);

    const wagmiConfig = createConfig({
      chains: [foundry],
      connectors: [mock({ accounts: [account.address] })],
      client({ chain }) {
        return createTestClient({
          chain,
          transport: http(config.rpcUrl),
          mode: "anvil",
          account,
        })
          .extend(walletActions)
          .extend(publicActions);
      },
    });

    await connect(wagmiConfig, { connector: wagmiConfig.connectors[0] });
    const client = wagmiConfig.getClient({ chainId: foundry.id });
    const rulesEngine = await RulesEngine.create(config.rulesEngineAddress, wagmiConfig, client, 1);

    if (!rulesEngine) {
      throw new Error(`RulesEngine.create failed for ${config.rulesEngineAddress}`);
    }

    return new ForteNftPolicyHelper(config, rulesEngine, wagmiConfig);
  }

  async createAndApplyTemplate(template: string, options?: { apply?: boolean }): Promise<CreateApplyResult> {
    const { templatePath, policySyntax } = readPolicyTemplate(template);
    const apply = options?.apply ?? true;

    const createResult = await this.rulesEngine.createPolicy(policySyntax);
    const policyId = Number(createResult.policyId);

    if (!Number.isFinite(policyId) || policyId < 0) {
      throw new Error(`createPolicy failed: ${JSON.stringify(createResult)}`);
    }

    if (apply) {
      await setPolicies(
        this.wagmiConfig,
        this.rulesEngine.getRulesEnginePolicyContract(),
        [policyId] as [number],
        this.config.nftAddress,
        1,
      );
    }

    const appliedPolicyIdsRaw = await this.rulesEngine.getAppliedPolicyIds(this.config.nftAddress);
    const appliedPolicyIds = Array.isArray(appliedPolicyIdsRaw)
      ? appliedPolicyIdsRaw.map((value) => Number(value))
      : [];

    return {
      template,
      templatePath,
      policyId,
      appliedPolicyIds,
      createResult,
      skippedApply: !apply,
      rulesEngineAddress: this.config.rulesEngineAddress,
      nftAddress: this.config.nftAddress,
      rpcUrl: this.config.rpcUrl,
    };
  }
}
