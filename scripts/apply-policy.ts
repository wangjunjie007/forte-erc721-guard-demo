import fs from "node:fs";
import path from "node:path";
import { createConfig, connect } from "@wagmi/core";
import { mock } from "@wagmi/connectors";
import {
  arbitrumSepolia,
  base,
  baseSepolia,
  foundry,
  mainnet,
  optimismSepolia,
  sepolia,
} from "@wagmi/core/chains";
import { createWalletClient, http, publicActions, type Chain } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { RulesEngine, setPolicies } from "@fortefoundation/forte-rules-engine-sdk";

const KNOWN_CHAINS: Chain[] = [foundry, mainnet, sepolia, base, baseSepolia, arbitrumSepolia, optimismSepolia];
const CHAIN_NAME_ALIASES = new Map<string, Chain>([
  ["anvil", foundry],
  ["foundry", foundry],
  ["ethereum", mainnet],
  ["mainnet", mainnet],
  ["sepolia", sepolia],
  ["base", base],
  ["base-sepolia", baseSepolia],
  ["basesepolia", baseSepolia],
  ["base_sepolia", baseSepolia],
  ["arbitrum-sepolia", arbitrumSepolia],
  ["arbitrumsepolia", arbitrumSepolia],
  ["optimism-sepolia", optimismSepolia],
  ["opsepolia", optimismSepolia],
  ["op-sepolia", optimismSepolia],
]);

function normalizeName(value?: string): string | undefined {
  if (!value) return undefined;
  return value.trim().toLowerCase();
}

function resolveChain(requestedName?: string, requestedChainId?: number): Chain {
  const byId = typeof requestedChainId === "number" && Number.isFinite(requestedChainId)
    ? KNOWN_CHAINS.find((chain) => chain.id === requestedChainId)
    : undefined;
  const byName = requestedName ? CHAIN_NAME_ALIASES.get(normalizeName(requestedName) ?? "") : undefined;

  if (byId && byName && byId.id !== byName.id) {
    throw new Error(
      `CHAIN_NAME (${requestedName}) does not match CHAIN_ID (${requestedChainId}). Resolved to ${byName.id} vs ${byId.id}.`,
    );
  }

  if (byId) return byId;
  if (byName) return byName;
  return foundry;
}

async function main() {
  const rpcUrl = process.env.RPC_URL ?? process.env.TESTNET_RPC_URL ?? "http://127.0.0.1:8545";
  const privateKey = (process.env.PRIV_KEY ??
    process.env.TESTNET_PRIVATE_KEY ??
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80") as `0x${string}`;
  const diamondAddress = (process.env.RULES_ENGINE_ADDRESS ??
    "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318") as `0x${string}`;
  const targetContractAddress = (process.env.TARGET_CONTRACT_ADDRESS ??
    process.env.MARKETPLACE_NFT_ADDRESS ??
    process.env.NFT_ADDRESS) as `0x${string}` | undefined;
  const policyPath = path.resolve(process.env.POLICY_PATH ?? "policy/nft-transfer-guard.policy.json");

  if (!targetContractAddress) {
    throw new Error("TARGET_CONTRACT_ADDRESS (or MARKETPLACE_NFT_ADDRESS / NFT_ADDRESS) is required");
  }

  const requestedChainIdRaw = process.env.CHAIN_ID ?? process.env.TESTNET_CHAIN_ID;
  const requestedChainId = requestedChainIdRaw ? Number(requestedChainIdRaw) : undefined;
  if (requestedChainIdRaw && !Number.isFinite(requestedChainId)) {
    throw new Error(`Invalid CHAIN_ID: ${requestedChainIdRaw}`);
  }

  const selectedChain = resolveChain(process.env.CHAIN_NAME ?? process.env.TESTNET_CHAIN_NAME, requestedChainId);
  const localConfirmationCount = Number(
    process.env.LOCAL_CONFIRMATION_COUNT ?? process.env.TESTNET_CONFIRMATIONS ?? (selectedChain.id === foundry.id ? 1 : 2),
  );

  const account = privateKeyToAccount(privateKey);

  const config = createConfig({
    chains: [selectedChain],
    connectors: [mock({ accounts: [account.address] })],
    client({ chain }) {
      return createWalletClient({
        account,
        chain,
        transport: http(rpcUrl),
      }).extend(publicActions);
    },
  });

  await connect(config, { connector: config.connectors[0], chainId: selectedChain.id });
  const client = config.getClient({ chainId: selectedChain.id });
  const engine = await RulesEngine.create(diamondAddress, config, client, localConfirmationCount);

  if (!engine) {
    throw new Error(`RulesEngine.create failed for ${diamondAddress}`);
  }

  const policySyntax = fs.readFileSync(policyPath, "utf8");
  const createResult = await engine.createPolicy(policySyntax);
  const policyId = createResult.policyId;

  if (policyId < 0) {
    throw new Error(`createPolicy failed: ${JSON.stringify(createResult)}`);
  }

  const skipApply = process.env.SKIP_APPLY === "1";
  if (!skipApply) {
    await setPolicies(config, engine.getRulesEnginePolicyContract(), [policyId] as [number], targetContractAddress, 1);
  }

  const appliedPolicyIds = await engine.getAppliedPolicyIds(targetContractAddress);
  const output = {
    rpcUrl,
    chain: {
      id: selectedChain.id,
      name: selectedChain.name,
    },
    diamondAddress,
    targetContractAddress,
    policyPath,
    policyId,
    appliedPolicyIds,
    createResult,
  };

  const stringify = (obj: unknown) =>
    JSON.stringify(obj, (_key, value) => (typeof value === "bigint" ? value.toString() : value), 2);

  const outPath = path.resolve("cache/apply-policy-result.json");
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, stringify(output), "utf8");
  console.log(stringify(output));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
