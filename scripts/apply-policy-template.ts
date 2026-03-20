import fs from "node:fs";
import path from "node:path";
import { ForteNftPolicyHelper, listPolicyTemplates } from "./policy-helper";

interface CliOptions {
  template?: string;
  nftAddress?: string;
  rulesEngineAddress?: string;
  rpcUrl?: string;
  privateKey?: string;
  outPath?: string;
  apply: boolean;
  list: boolean;
  help: boolean;
}

function loadEnvFileIfPresent(filePath: string) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const eqIndex = trimmed.indexOf("=");
    if (eqIndex < 1) {
      continue;
    }

    const key = trimmed.slice(0, eqIndex).trim();
    const value = trimmed.slice(eqIndex + 1).trim();

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = { apply: true, list: false, help: false };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    const nextValue = () => {
      const value = argv[i + 1];
      if (!value || value.startsWith("--")) {
        throw new Error(`Missing value for ${arg}`);
      }
      i += 1;
      return value;
    };

    switch (arg) {
      case "--template":
        options.template = nextValue();
        break;
      case "--nft":
        options.nftAddress = nextValue();
        break;
      case "--rules-engine":
        options.rulesEngineAddress = nextValue();
        break;
      case "--rpc":
        options.rpcUrl = nextValue();
        break;
      case "--private-key":
        options.privateKey = nextValue();
        break;
      case "--out":
        options.outPath = nextValue();
        break;
      case "--create-only":
        options.apply = false;
        break;
      case "--list":
        options.list = true;
        break;
      case "--help":
      case "-h":
        options.help = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function printHelp() {
  console.log(`Usage:
  tsx scripts/apply-policy-template.ts [options]

Options:
  --list                         List available NFT policy templates
  --template <name|path>         Template name (without suffix) or JSON path
  --nft <address>                NFT contract address
  --rules-engine <address>       Forte Rules Engine diamond address
  --rpc <url>                    RPC URL (default from RPC_URL or http://127.0.0.1:8545)
  --private-key <hex>            Deployer private key (default from PRIV_KEY)
  --create-only                  Create policy but do not apply to NFT
  --out <path>                   Write JSON result to file
  --help, -h                     Show this help

Environment fallback:
  RPC_URL, PRIV_KEY, RULES_ENGINE_ADDRESS, NFT_ADDRESS
`);
}

async function main() {
  loadEnvFileIfPresent(path.resolve(".env"));
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    printHelp();
    return;
  }

  if (options.list) {
    const templates = listPolicyTemplates();
    if (!templates.length) {
      console.log("No NFT policy templates found in examples/policies");
      return;
    }

    console.log("Available NFT policy templates:");
    for (const template of templates) {
      console.log(`- ${template}`);
    }
    return;
  }

  const template = options.template ?? "baseline-nft-transfer-guard";
  const rpcUrl = options.rpcUrl ?? process.env.RPC_URL ?? "http://127.0.0.1:8545";
  const privateKey = options.privateKey ?? process.env.PRIV_KEY;
  const rulesEngineAddress = options.rulesEngineAddress ?? process.env.RULES_ENGINE_ADDRESS;
  const nftAddress = options.nftAddress ?? process.env.NFT_ADDRESS;

  if (!privateKey) {
    throw new Error("Missing private key. Pass --private-key or set PRIV_KEY in .env");
  }
  if (!rulesEngineAddress) {
    throw new Error("Missing rules engine address. Pass --rules-engine or set RULES_ENGINE_ADDRESS in .env");
  }
  if (!nftAddress) {
    throw new Error("Missing NFT address. Pass --nft or set NFT_ADDRESS in .env");
  }

  const helper = await ForteNftPolicyHelper.create({ rpcUrl, privateKey, rulesEngineAddress, nftAddress });
  const result = await helper.createAndApplyTemplate(template, { apply: options.apply });
  const printable = JSON.stringify(result, (_key, value) => (typeof value === "bigint" ? value.toString() : value), 2);

  if (options.outPath) {
    const outPath = path.resolve(options.outPath);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, printable, "utf8");
    console.log(`Result written to ${outPath}`);
  }

  console.log(printable);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
