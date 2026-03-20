import fs from "node:fs";
import path from "node:path";
import { createConfig, connect } from "@wagmi/core";
import { mock } from "@wagmi/connectors";
import { foundry } from "@wagmi/core/chains";
import { createTestClient, http, walletActions, publicActions } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { RulesEngine, setPolicies } from "@fortefoundation/forte-rules-engine-sdk";

async function main() {
  const rpcUrl = process.env.RPC_URL ?? "http://127.0.0.1:8545";
  const privateKey = (process.env.PRIV_KEY ??
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80") as `0x${string}`;
  const diamondAddress = (process.env.RULES_ENGINE_ADDRESS ??
    "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318") as `0x${string}`;
  const nftAddress = process.env.NFT_ADDRESS as `0x${string}` | undefined;

  if (!nftAddress) {
    throw new Error("NFT_ADDRESS is required");
  }

  const account = privateKeyToAccount(privateKey);

  const config = createConfig({
    chains: [foundry],
    connectors: [mock({ accounts: [account.address] })],
    client({ chain }) {
      return createTestClient({
        chain,
        transport: http(rpcUrl),
        mode: "anvil",
        account,
      })
        .extend(walletActions)
        .extend(publicActions);
    },
  });

  await connect(config, { connector: config.connectors[0] });
  const client = config.getClient({ chainId: foundry.id });
  const engine = await RulesEngine.create(diamondAddress, config, client, 1);

  if (!engine) {
    throw new Error(`RulesEngine.create failed for ${diamondAddress}`);
  }

  const policyPath = path.resolve("policy/nft-transfer-guard.policy.json");
  const policySyntax = fs.readFileSync(policyPath, "utf8");

  const createResult = await engine.createPolicy(policySyntax);
  const policyId = createResult.policyId;

  if (policyId < 0) {
    throw new Error(`createPolicy failed: ${JSON.stringify(createResult)}`);
  }

  const skipApply = process.env.SKIP_APPLY === "1";
  if (!skipApply) {
    await setPolicies(config, engine.getRulesEnginePolicyContract(), [policyId] as [number], nftAddress, 1);
  }

  const appliedPolicyIds = await engine.getAppliedPolicyIds(nftAddress);
  const output = { rpcUrl, diamondAddress, nftAddress, policyId, appliedPolicyIds, createResult };
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
