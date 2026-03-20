const TEMPLATE_FILES = [
  "baseline-nft-transfer-guard.policy.json",
  "strict-no-bypass-nft.policy.json",
  "lockup-and-sanctions-only-nft.policy.json",
  "emergency-freeze-nft.policy.json",
];

const state = {
  policies: new Map(),
  currentTemplate: TEMPLATE_FILES[0],
};

const templateSelect = document.getElementById("templateSelect");
const policyDescription = document.getElementById("policyDescription");
const resultsBody = document.getElementById("resultsBody");
const outcome = document.getElementById("outcome");

function boolToFlag(inputId) {
  return document.getElementById(inputId).checked ? 1 : 0;
}

function num(inputId) {
  const value = Number(document.getElementById(inputId).value);
  return Number.isFinite(value) ? value : 0;
}

function buildContext() {
  return {
    tokenId: num("tokenId"),
    blockTime: num("blockTime"),
    tokenUnlockTime: num("tokenUnlockTime"),
    fromBlacklistFlag: boolToFlag("fromBlacklistFlag"),
    toBlacklistFlag: boolToFlag("toBlacklistFlag"),
    treasuryBypass: boolToFlag("treasuryBypass"),
    transfersPausedFlag: boolToFlag("transfersPausedFlag"),
  };
}

function evaluateCondition(condition, context) {
  const expression = condition.replace(/\bAND\b/g, "&&").replace(/\bOR\b/g, "||");
  const fn = new Function("context", `with (context) { return Boolean(${expression}); }`);
  return fn(context);
}

function render(policy, callingFunction, context) {
  const rules = policy.Rules.filter((rule) => rule.CallingFunction === callingFunction);
  resultsBody.innerHTML = "";

  let firstFailure = null;
  for (const rule of rules) {
    let passed = false;
    let effect = "";

    try {
      passed = evaluateCondition(rule.Condition, context);
    } catch (error) {
      passed = false;
      effect = `Condition parser error: ${error instanceof Error ? error.message : String(error)}`;
    }

    if (!effect) {
      effect = passed
        ? (rule.PositiveEffects || []).join("; ") || "allow"
        : (rule.NegativeEffects || []).join("; ") || "revert";
    }

    if (!passed && !firstFailure) {
      firstFailure = { rule: rule.Name, effect };
    }

    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${rule.Name}</td>
      <td><code>${rule.Condition}</code></td>
      <td class="${passed ? "ok" : "bad"}">${passed ? "PASS" : "FAIL"}</td>
      <td>${effect}</td>
    `;
    resultsBody.appendChild(tr);
  }

  if (firstFailure) {
    outcome.className = "outcome bad";
    outcome.textContent = `REVERT — ${firstFailure.rule}: ${firstFailure.effect}`;
  } else {
    outcome.className = "outcome ok";
    outcome.textContent = "ALLOW — all rules passed for this calling function";
  }
}

async function loadPolicies() {
  for (const file of TEMPLATE_FILES) {
    const response = await fetch(`../examples/policies/${file}`);
    if (!response.ok) {
      throw new Error(`Failed to load policy template: ${file}`);
    }
    const policy = await response.json();
    state.policies.set(file, policy);
  }
}

function mountTemplateSelect() {
  templateSelect.innerHTML = "";
  for (const file of TEMPLATE_FILES) {
    const option = document.createElement("option");
    option.value = file;
    option.textContent = file.replace(".policy.json", "");
    templateSelect.appendChild(option);
  }

  templateSelect.value = state.currentTemplate;
  templateSelect.addEventListener("change", () => {
    state.currentTemplate = templateSelect.value;
    const policy = state.policies.get(state.currentTemplate);
    policyDescription.textContent = policy?.Description || "";
    simulate();
  });
}

function simulate() {
  const policy = state.policies.get(state.currentTemplate);
  const callingFunction = document.getElementById("callingFunction").value;
  const context = buildContext();
  render(policy, callingFunction, context);
}

async function main() {
  await loadPolicies();
  mountTemplateSelect();

  const initialPolicy = state.policies.get(state.currentTemplate);
  policyDescription.textContent = initialPolicy?.Description || "";

  document.getElementById("simulateBtn").addEventListener("click", simulate);
  for (const id of [
    "callingFunction",
    "tokenId",
    "blockTime",
    "tokenUnlockTime",
    "fromBlacklistFlag",
    "toBlacklistFlag",
    "treasuryBypass",
    "transfersPausedFlag",
  ]) {
    document.getElementById(id).addEventListener("change", simulate);
    document.getElementById(id).addEventListener("input", simulate);
  }

  simulate();
}

main().catch((error) => {
  outcome.className = "outcome bad";
  outcome.textContent = error instanceof Error ? error.message : String(error);
});
