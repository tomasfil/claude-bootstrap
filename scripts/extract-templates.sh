#!/usr/bin/env bash
set -euo pipefail

# extract-templates.sh — one-shot seeding of templates/ from .claude/
#
# Extracts every skill SKILL.md and core agent .md into templates/.
# Generates code-writer.template.md and test-writer.template.md as
# placeholder templates with {lang}, {build_cmd}, {test_cmd}, {lint_cmd}.
# Writes templates/manifest.json with sha256 for every file.
#
# Run from repo root: bash scripts/extract-templates.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# --- Prerequisite checks ---
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || {
    printf 'ERROR: sha256sum or shasum required\n' >&2
    exit 1
}
command -v python3 >/dev/null 2>&1 || {
    printf 'ERROR: python3 required (for JSON generation)\n' >&2
    exit 1
}

# sha256 wrapper (portable: Linux sha256sum vs macOS shasum)
sha256_file() {
    local f="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$f" | awk '{print $1}'
    else
        shasum -a 256 "$f" | awk '{print $1}'
    fi
}

printf '==> Creating template directories...\n'
mkdir -p templates/skills
mkdir -p templates/agents

# --- Core agent names (from module 05 + module 01 foundation agents) ---
# These are the project-agnostic agents every bootstrap produces.
# proj-code-writer-{lang} and proj-test-writer-{lang} are handled by
# code-writer.template.md / test-writer.template.md (parameterized).
CORE_AGENTS=(
    proj-quick-check
    proj-plan-writer
    proj-consistency-checker
    proj-debugger
    proj-verifier
    proj-reflector
    proj-tdd-runner
    proj-researcher
    proj-code-writer-markdown
    proj-code-writer-bash
    proj-code-reviewer
)

# --- Skill names (from module 06 skill list, excluding conditional /sync) ---
SKILLS=(
    brainstorm
    deep-think
    write-plan
    execute-plan
    tdd
    debug
    code-write
    verify
    review
    audit-file
    audit-memory
    audit-agents
    commit
    pr
    reflect
    consolidate
    evolve-agents
    migrate-bootstrap
    coverage
    coverage-gaps
    write-ticket
    ci-triage
    write-prompt
    module-write
    sync
    test-fork
    test-fork-success
)

printf '==> Extracting agent templates...\n'
EXTRACTED_AGENTS=()
MISSING_AGENTS=()

for agent in "${CORE_AGENTS[@]}"; do
    src=".claude/agents/${agent}.md"
    dst="templates/agents/${agent}.md"
    if [[ -f "$src" ]]; then
        cp "$src" "$dst"
        printf '  OK: %s\n' "$dst"
        EXTRACTED_AGENTS+=("$agent")
    else
        printf '  SKIP (not found): %s\n' "$src"
        MISSING_AGENTS+=("$agent")
    fi
done

printf '==> Extracting skill templates...\n'
EXTRACTED_SKILLS=()
MISSING_SKILLS=()

for skill in "${SKILLS[@]}"; do
    src=".claude/skills/${skill}/SKILL.md"
    dst_dir="templates/skills/${skill}"
    dst="templates/skills/${skill}/SKILL.md"
    if [[ -f "$src" ]]; then
        mkdir -p "$dst_dir"
        cp "$src" "$dst"
        printf '  OK: %s\n' "$dst"
        EXTRACTED_SKILLS+=("$skill")
    else
        printf '  SKIP (not found): %s\n' "$src"
        MISSING_SKILLS+=("$skill")
    fi
done

printf '==> Writing code-writer.template.md...\n'
cat > templates/agents/code-writer.template.md <<'TEMPLATE'
---
name: proj-code-writer-{lang}
description: >
  {lang} code writer specialist. Use when writing {lang} code files for
  this project. Knows project conventions, architecture patterns, DI patterns,
  error handling, and framework-specific gotchas.
model: opus
effort: high
maxTurns: 100
color: blue
scope: "{lang}"
---

## STEP 0 — Load critical rules (MANDATORY first action)

Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

Before any task-specific work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
- `.claude/rules/mcp-tool-routing.md` (if present — authoritative action→tool routing; overrides any Grep/Glob/Read-first examples later in this file)
- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)
- `.claude/rules/code-standards-{lang}.md` (if present)

Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config). If `mcp-tool-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file — route through MCP tools per that rule's action→tool table before falling back to text search.

---

## Role
{lang} code writer specialist for this project. Writes production-quality code following
project conventions extracted from local analysis + web research.

## Pass-by-Reference Contract
Write output to target path given in dispatch prompt.
Return ONLY: `{path} — {summary}` (summary <100 chars).
Main reads file only if: needed for next dispatch | error in summary | verification required.

## Build + Test Commands
- Build: `{build_cmd}`
- Test: `{test_cmd}`
- Lint: `{lint_cmd}`

## Before Writing (MANDATORY)
1. If `.claude/rules/mcp-tool-routing.md` loaded: use MCP tools per routing table for code discovery BEFORE Grep/Read
2. Read target file if modifying | 2-3 similar files if creating
3. Read `.claude/rules/code-standards-{lang}.md` if present
4. Read `.claude/skills/code-write/references/{lang}-analysis.md` for project patterns
5. Verify all referenced types/methods/imports actually exist

## Anti-Hallucination
- NEVER invent methods, types, or imports that don't exist in the project
- NEVER assume framework APIs without verifying via Grep or LSP
- Build MUST pass after every file written
- If build fails → fix before returning
- Unsure about API → check project source or research file first

## Scope Lock
Write ONLY requested files. No adjacent refactoring. No opportunistic cleanup.
Need something off-scope → STOP, return: `SCOPE EXPANSION NEEDED: {file} — reason: {short}`

## Code Standards
- Follow patterns in `.claude/skills/code-write/references/{lang}-analysis.md`
- Match existing naming conventions, error handling patterns, DI patterns
- Tests: write tests for new public API surface; follow existing test patterns
- Comments: WHY only; no redundant; no commented-out code

## Verification
After writing each file:
1. `{build_cmd}` — must pass
2. If test file changed: `{test_cmd}` — must pass
3. `{lint_cmd}` — must pass (if available)

## Parallel Tool Calls
Batch all independent Reads in one message. Never: Read A → respond → Read B.
TEMPLATE

printf '  OK: templates/agents/code-writer.template.md\n'

printf '==> Writing test-writer.template.md...\n'
cat > templates/agents/test-writer.template.md <<'TEMPLATE'
---
name: proj-test-writer-{lang}
description: >
  {lang} test writer specialist. Use when writing tests, test fixtures, test
  helpers, or expanding test coverage for {lang} code. Knows project test patterns,
  mocking conventions, and framework-specific testing gotchas.
model: opus
effort: high
maxTurns: 100
color: green
scope: "{lang}-tests"
---

## STEP 0 — Load critical rules (MANDATORY first action)

Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

Before any task-specific work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
- `.claude/rules/mcp-tool-routing.md` (if present — authoritative action→tool routing; overrides any Grep/Glob/Read-first examples later in this file)
- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)
- `.claude/rules/code-standards-{lang}.md` (if present)

Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config). If `mcp-tool-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file — route through MCP tools per that rule's action→tool table before falling back to text search.

---

## Role
{lang} test writer specialist. Writes failing tests first (TDD red), then works with
code-writer or independently to achieve green. Follows project test patterns exactly.

## Pass-by-Reference Contract
Write test files to paths given in dispatch prompt.
Return ONLY: `{path} — {summary}` (summary <100 chars).

## Build + Test Commands
- Build: `{build_cmd}`
- Test (single): `{test_cmd}`
- Test (suite): `{test_cmd}`

## Before Writing (MANDATORY)
1. Read 3-5 existing test files — match conventions exactly
2. Read `.claude/rules/code-standards-{lang}.md` if present
3. Read `.claude/skills/code-write/references/{lang}-analysis.md` for test patterns section
4. Identify: test naming pattern, fixture approach, mock library, assertion style
5. Verify implementation code exists before writing tests against it

## Anti-Hallucination
- NEVER mock types that don't exist in the project
- NEVER use test framework APIs without verifying they exist
- Test MUST fail for the right reason before implementation
- NEVER assume test passes — run it
- Unexpected pass → test is not testing new behavior → rethink

## Scope Lock
Write ONLY test files requested. No production code changes. No adjacent test fixes.
Need scope expansion → STOP, return: `SCOPE EXPANSION NEEDED: {file} — reason: {short}`

## Test Writing Standards
- Naming: follow project convention (e.g. `{ClassName}Tests.{MethodName}_{scenario}_{expected}`)
- Arrange/Act/Assert structure — clear separation
- One logical assertion per test
- Test behavior, not implementation details
- Use project's existing base classes, helpers, fixtures

## Verification
After writing each test file:
1. `{build_cmd}` — must pass
2. `{test_cmd}` — new tests must fail for expected reason (RED phase)
3. After implementation: `{test_cmd}` — must pass (GREEN phase)

## Parallel Tool Calls
Batch all independent Reads in one message.
TEMPLATE

printf '  OK: templates/agents/test-writer.template.md\n'

# --- Build manifest JSON ---
printf '==> Building manifest.json...\n'

# Collect all skill entries
SKILLS_JSON=""
for skill in "${EXTRACTED_SKILLS[@]}"; do
    f="templates/skills/${skill}/SKILL.md"
    hash="$(sha256_file "$f")"
    # Determine if there are references/ files
    refs_json="[]"
    refs_dir="templates/skills/${skill}/references"
    if [[ -d "$refs_dir" ]]; then
        ref_list=""
        for ref_file in "${refs_dir}"/*; do
            [[ -f "$ref_file" ]] || continue
            ref_rel="${ref_file#templates/}"
            ref_list="${ref_list}\"${ref_rel}\","
        done
        if [[ -n "$ref_list" ]]; then
            refs_json="[${ref_list%,}]"
        fi
    fi
    entry="{\"name\":\"${skill}\",\"source\":\"templates/skills/${skill}/SKILL.md\",\"target\":\".claude/skills/${skill}/SKILL.md\",\"sha256\":\"${hash}\",\"references\":${refs_json}}"
    if [[ -n "$SKILLS_JSON" ]]; then
        SKILLS_JSON="${SKILLS_JSON},${entry}"
    else
        SKILLS_JSON="${entry}"
    fi
done

# Collect all agent entries
AGENTS_JSON=""
for agent in "${EXTRACTED_AGENTS[@]}"; do
    f="templates/agents/${agent}.md"
    hash="$(sha256_file "$f")"
    entry="{\"name\":\"${agent}\",\"source\":\"templates/agents/${agent}.md\",\"target\":\".claude/agents/${agent}.md\",\"sha256\":\"${hash}\"}"
    if [[ -n "$AGENTS_JSON" ]]; then
        AGENTS_JSON="${AGENTS_JSON},${entry}"
    else
        AGENTS_JSON="${entry}"
    fi
done

# Agent templates
CW_HASH="$(sha256_file "templates/agents/code-writer.template.md")"
TW_HASH="$(sha256_file "templates/agents/test-writer.template.md")"
AGENT_TEMPLATES_JSON="[{\"name\":\"code-writer\",\"source\":\"templates/agents/code-writer.template.md\",\"target_pattern\":\".claude/agents/code-writer-{lang}.md\",\"sha256\":\"${CW_HASH}\",\"placeholders\":[\"{lang}\",\"{build_cmd}\",\"{test_cmd}\",\"{lint_cmd}\"]},{\"name\":\"test-writer\",\"source\":\"templates/agents/test-writer.template.md\",\"target_pattern\":\".claude/agents/test-writer-{lang}.md\",\"sha256\":\"${TW_HASH}\",\"placeholders\":[\"{lang}\",\"{build_cmd}\",\"{test_cmd}\",\"{lint_cmd}\"]}]"

# Write manifest via python3 for valid JSON formatting
python3 - <<PYEOF
import json, sys

skills_raw = """[${SKILLS_JSON}]"""
agents_raw = """[${AGENTS_JSON}]"""
agent_templates_raw = """${AGENT_TEMPLATES_JSON}"""

manifest = {
    "version": 1,
    "skills": json.loads(skills_raw),
    "agents": json.loads(agents_raw),
    "agent-templates": json.loads(agent_templates_raw)
}

with open("templates/manifest.json", "w", newline="\n") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")

print(f"  Skills: {len(manifest['skills'])}")
print(f"  Agents: {len(manifest['agents'])}")
print(f"  Agent templates: {len(manifest['agent-templates'])}")
PYEOF

printf '  OK: templates/manifest.json\n'

# --- Summary ---
printf '\n==> Extraction complete\n'
printf '  Skills extracted:   %d\n' "${#EXTRACTED_SKILLS[@]}"
printf '  Agents extracted:   %d\n' "${#EXTRACTED_AGENTS[@]}"
printf '  Agent templates:    2\n'
printf '  Total files:        %d\n' "$(( ${#EXTRACTED_SKILLS[@]} + ${#EXTRACTED_AGENTS[@]} + 2 ))"

if [[ ${#MISSING_SKILLS[@]} -gt 0 ]]; then
    printf '\n  Skipped skills (not found in .claude/skills/):\n'
    for s in "${MISSING_SKILLS[@]}"; do
        printf '    - %s\n' "$s"
    done
fi
if [[ ${#MISSING_AGENTS[@]} -gt 0 ]]; then
    printf '\n  Skipped agents (not found in .claude/agents/):\n'
    for a in "${MISSING_AGENTS[@]}"; do
        printf '    - %s\n' "$a"
    done
fi

printf '\nRun bash scripts/verify-templates-seeded.sh to verify.\n'
