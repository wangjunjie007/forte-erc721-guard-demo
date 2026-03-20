import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

interface CallingFunction {
  Name: string;
  FunctionSignature: string;
  EncodedValues: string;
}

interface Rule {
  Name: string;
  Description: string;
  Condition: string;
  PositiveEffects: string[];
  NegativeEffects: string[];
  CallingFunction: string;
}

interface PolicyDocument {
  Policy: string;
  Description: string;
  PolicyType: string;
  CallingFunctions: CallingFunction[];
  ForeignCalls?: unknown[];
  Trackers?: unknown[];
  MappedTrackers?: unknown[];
  Rules: Rule[];
}

function assertNonEmptyString(value: unknown, label: string): asserts value is string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${label} must be a non-empty string`);
  }
}

function assertStringArray(value: unknown, label: string): asserts value is string[] {
  if (!Array.isArray(value) || value.length === 0 || value.some((entry) => typeof entry !== "string" || entry.trim().length === 0)) {
    throw new Error(`${label} must be a non-empty string array`);
  }
}

function validatePolicyDocument(doc: unknown, filePath: string): PolicyDocument {
  if (typeof doc !== "object" || doc === null) {
    throw new Error(`${filePath}: policy file must be a JSON object`);
  }

  const policy = doc as Partial<PolicyDocument>;
  assertNonEmptyString(policy.Policy, `${filePath}: Policy`);
  assertNonEmptyString(policy.Description, `${filePath}: Description`);
  assertNonEmptyString(policy.PolicyType, `${filePath}: PolicyType`);

  if (!["open", "closed"].includes(policy.PolicyType)) {
    throw new Error(`${filePath}: PolicyType must be \"open\" or \"closed\"`);
  }

  if (!Array.isArray(policy.CallingFunctions) || policy.CallingFunctions.length === 0) {
    throw new Error(`${filePath}: CallingFunctions must be a non-empty array`);
  }

  const callingFunctionNames = new Set<string>();
  for (const [index, callingFunction] of policy.CallingFunctions.entries()) {
    if (typeof callingFunction !== "object" || callingFunction === null) {
      throw new Error(`${filePath}: CallingFunctions[${index}] must be an object`);
    }

    assertNonEmptyString(callingFunction.Name, `${filePath}: CallingFunctions[${index}].Name`);
    assertNonEmptyString(callingFunction.FunctionSignature, `${filePath}: CallingFunctions[${index}].FunctionSignature`);
    assertNonEmptyString(callingFunction.EncodedValues, `${filePath}: CallingFunctions[${index}].EncodedValues`);

    if (callingFunctionNames.has(callingFunction.Name)) {
      throw new Error(`${filePath}: duplicate calling function name \"${callingFunction.Name}\"`);
    }
    callingFunctionNames.add(callingFunction.Name);
  }

  if (!Array.isArray(policy.Rules) || policy.Rules.length === 0) {
    throw new Error(`${filePath}: Rules must be a non-empty array`);
  }

  for (const [index, rule] of policy.Rules.entries()) {
    if (typeof rule !== "object" || rule === null) {
      throw new Error(`${filePath}: Rules[${index}] must be an object`);
    }

    assertNonEmptyString(rule.Name, `${filePath}: Rules[${index}].Name`);
    assertNonEmptyString(rule.Description, `${filePath}: Rules[${index}].Description`);
    assertNonEmptyString(rule.Condition, `${filePath}: Rules[${index}].Condition`);
    assertStringArray(rule.PositiveEffects, `${filePath}: Rules[${index}].PositiveEffects`);
    assertStringArray(rule.NegativeEffects, `${filePath}: Rules[${index}].NegativeEffects`);
    assertNonEmptyString(rule.CallingFunction, `${filePath}: Rules[${index}].CallingFunction`);

    if (!callingFunctionNames.has(rule.CallingFunction)) {
      throw new Error(`${filePath}: Rules[${index}].CallingFunction references unknown function \"${rule.CallingFunction}\"`);
    }
  }

  return policy as PolicyDocument;
}

async function main() {
  const rootPolicyPath = path.resolve("policy/nft-transfer-guard.policy.json");
  const examplesDir = path.resolve("examples/policies");

  const files = [rootPolicyPath];
  for (const name of (await readdir(examplesDir)).sort()) {
    if (name.endsWith(".json")) {
      files.push(path.join(examplesDir, name));
    }
  }

  if (files.length < 2) {
    throw new Error("Expected at least one policy example in examples/policies");
  }

  const summaries: string[] = [];
  for (const filePath of files) {
    const raw = await readFile(filePath, "utf8");
    const parsed = JSON.parse(raw) as unknown;
    const doc = validatePolicyDocument(parsed, path.relative(process.cwd(), filePath));
    summaries.push(`- ${path.relative(process.cwd(), filePath)} :: ${doc.Policy} (${doc.CallingFunctions.length} calling functions, ${doc.Rules.length} rules)`);
  }

  console.log(`Validated ${files.length} Forte NFT policy file(s):`);
  for (const summary of summaries) {
    console.log(summary);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
