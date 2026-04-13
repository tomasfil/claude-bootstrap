# Module 07 — Code Specialists

> Research-driven creation of per-language code-writer + test-writer + project reviewer.
> Phases 1–2 dispatch `proj-researcher` (project-specific analysis — cannot be tracked templates).
> Phases 3–4 render per-language agents from tracked templates via `sed` substitution — NO LLM dispatch.
> Phase 5 dispatches `proj-code-writer-markdown` to generate the project-aware `proj-code-reviewer` (project-specific — requires reading analysis + research refs).
> Phase 6 wires the agent index + skill refs on the main thread.

---

## Idempotency

Per-language analysis + research refs: `proj-researcher` merges new findings with any existing content (never discard prior research). Per-language code-writer + test-writer agents: render from the tracked template via `sed` (overwrites placeholders; project-specific customizations belong in the template, not the rendered output). Agent index: regenerated from current agent frontmatter on every run.

## What This Produces

| Output | Path | Source |
|--------|------|--------|
| Per-lang analysis refs | `.claude/skills/code-write/references/{lang}-analysis.md` | Phase 1 — `proj-researcher` (project-specific) |
| Per-lang research refs | `.claude/skills/code-write/references/{lang}-research.md` | Phase 2 — `proj-researcher` (project-specific) |
| Code writer agents | `.claude/agents/proj-code-writer-{lang}.md` | Phase 3 — `templates/agents/code-writer.template.md` via `sed` |
| Test writer agents | `.claude/agents/proj-test-writer-{lang}.md` | Phase 4 — `templates/agents/test-writer.template.md` via `sed` |
| Code reviewer | `.claude/agents/proj-code-reviewer.md` | Phase 5 — `proj-code-writer-markdown` dispatch (project-specific) |
| Agent index | `.claude/agents/agent-index.yaml` | Phase 6 — main thread |
| Capability index | `.claude/skills/code-write/references/capability-index.md` | Phase 6 — main thread |

---

## Phase 0 (main) — Capability Scan

Scan the project for languages w/ 3+ owned source files. Exclude directories: `node_modules/`, `vendor/`, `wwwroot/lib/`, `bin/`, `obj/`, `.nuget/`, `packages/`, `dist/`, `build/`, `__pycache__/`, `.venv/`, `venv/`, `target/`, `.gradle/`, `out/`.

**Exclude languages: `bash`, `markdown`** — these are installed as universal code writers by Module 05 (`proj-code-writer-bash`, `proj-code-writer-markdown`) and must NOT appear in `DETECTED_LANGS`. Rendering them here would clobber the Module 05 static templates. Module 07 only handles project-specific primary languages (C#, Python, TypeScript, Go, Rust, Java, etc.) that need deep per-language analysis + research refs.

Per detected language, record: language + version, framework(s) + version(s), test framework + mock library, file count, and the build/test/lint commands (from project manifests — `package.json`, `*.csproj`, `pyproject.toml`, `Cargo.toml`, etc.).

Delete any legacy unprefixed specialists:

```bash
ls .claude/agents/code-writer.md .claude/agents/test-writer.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md 2>/dev/null && echo "LEGACY FOUND — will delete"
rm -f .claude/agents/code-writer.md .claude/agents/test-writer.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md
```

Create the directories consumed by later phases:

```bash
mkdir -p .claude/skills/code-write/references .claude/agents/references
```

**Phase 0 output contract — main thread MUST re-emit these four bash declarations as a prefix to EVERY bash block in Phases 1, 2, 3, and 4.** Each fenced `bash` block runs in a fresh shell (separate Bash-tool invocation), and every Phase 1-4 block runs under `set -euo pipefail`. Variables declared in one block do NOT persist to the next — referencing `${DETECTED_LANGS[@]}` in a fresh shell under `set -u` where the array was never declared is a hard error. Treat the block below as the prelude that must be pasted at the top of each Phase 1-4 bash invocation, immediately after `set -euo pipefail`. Substitute real languages + commands from the scan:

```bash
declare -a DETECTED_LANGS=(python typescript)
declare -A BUILD_CMD=( [python]="pytest && mypy" [typescript]="npm run build" )
declare -A TEST_CMD=( [python]="pytest" [typescript]="npm test" )
declare -A LINT_CMD=( [python]="ruff check" [typescript]="npm run lint" )
```

Every detected language MUST have an entry in all four structures. Empty string is acceptable (e.g., `[go]=""` if a language has no lint command) but the key must be present — Phase 3/4 reads `${BUILD_CMD[$lang]}` unconditionally. Missing key under `set -u` = hard error. `bash` + `markdown` are excluded from `DETECTED_LANGS` entirely per the exclusion rule above — they never appear as either keys or array entries.

**Checkpoint:** `Phase 0 complete — {N} languages detected: {summaries}`

---

## Phase 1 (dispatch proj-researcher) — Local Analysis — ALL languages simultaneously

Dispatch ONE `proj-researcher` per detected language via `subagent_type="proj-researcher"`, ALL in a single message (parallel Agent calls). Each researcher deep-reads project source, extracts component types, naming conventions, architecture layers, DI patterns, test patterns, mocking conventions, error-handling approach, and the build/test/lint/coverage commands. Findings written to `.claude/skills/code-write/references/{lang}-analysis.md`. Returns path + 1-line summary per pass-by-reference contract.

Wait for all Phase 1 dispatches to complete. Verify:

```bash
set -euo pipefail

# Re-emit the Phase 0 contract (DETECTED_LANGS + BUILD_CMD/TEST_CMD/LINT_CMD)
# as the prelude here — each Phase 1-4 bash block runs in a fresh shell.
# <paste contract declarations from Phase 0 output contract above>

for lang in "${DETECTED_LANGS[@]}"; do
  [[ -s ".claude/skills/code-write/references/${lang}-analysis.md" ]] || { printf 'MISSING: %s-analysis.md\n' "$lang" >&2; exit 1; }
done
```

**Checkpoint:** `Phase 1 complete — {N} languages analyzed`

---

## Phase 2 (dispatch proj-researcher) — Web Research — ALL languages simultaneously

Dispatch ONE `proj-researcher` per detected language (parallel). Each researcher reads the matching `{lang}-analysis.md` for framework + version info, then runs ~15–20 web searches covering code-writing best practices, framework patterns, DI, error handling, security, and testing (`{test_framework}` + `{mocking_library}` gotchas, coverage tools, async patterns). Findings written to `.claude/skills/code-write/references/{lang}-research.md`. MUST print total search count, 5–7 key findings, and any topic gaps where search failed after 2 attempts.

Verify:

```bash
set -euo pipefail

# Re-emit the Phase 0 contract (DETECTED_LANGS + BUILD_CMD/TEST_CMD/LINT_CMD)
# as the prelude here — each Phase 1-4 bash block runs in a fresh shell.
# <paste contract declarations from Phase 0 output contract above>

for lang in "${DETECTED_LANGS[@]}"; do
  [[ -s ".claude/skills/code-write/references/${lang}-research.md" ]] || { printf 'MISSING: %s-research.md\n' "$lang" >&2; exit 1; }
done
```

**Checkpoint:** `Phase 2 complete — {N} languages researched`

---

## Phase 3 (template render) — Generate Code Writers — `sed` substitution per language

Fetch `templates/agents/code-writer.template.md` (placeholders `{lang}`, `{build_cmd}`, `{test_cmd}`, `{lint_cmd}`) once, then render one file per detected language. Main thread only — NO LLM dispatch. Project-specific patterns live in the `{lang}-analysis.md` / `{lang}-research.md` reference files the rendered agent reads at runtime.

```bash
set -euo pipefail

# Re-emit the Phase 0 contract (DETECTED_LANGS + BUILD_CMD/TEST_CMD/LINT_CMD)
# as the prelude here — each Phase 1-4 bash block runs in a fresh shell.
# <paste contract declarations from Phase 0 output contract above>

OWNER="${BOOTSTRAP_OWNER:-$(jq -r '.github_username // "tomasfil"' .claude/bootstrap-state.json 2>/dev/null || echo tomasfil)}"
REPO="claude-bootstrap"
BRANCH="main"
TEMPLATE_PATH="templates/agents/code-writer.template.md"

if [[ -f "$TEMPLATE_PATH" ]]; then
  CODE_WRITER_TEMPLATE="$(cat "$TEMPLATE_PATH")"
else
  CODE_WRITER_TEMPLATE="$(gh api "repos/${OWNER}/${REPO}/contents/${TEMPLATE_PATH}?ref=${BRANCH}" --jq '.content' | base64 -d)"
fi

# Escape sed-replacement metacharacters: \, |, & (| is our s delimiter).
# Without this, commands like `npm test | grep PASSED` break sed.
sed_escape() {
  local raw="$1"
  raw="${raw//\\/\\\\}"
  raw="${raw//|/\\|}"
  raw="${raw//&/\\&}"
  printf '%s' "$raw"
}

# DETECTED_LANGS + per-lang build/test/lint commands come from Phase 0 output contract.
for lang in "${DETECTED_LANGS[@]}"; do
  build_cmd="$(sed_escape "${BUILD_CMD[$lang]}")"
  test_cmd="$(sed_escape "${TEST_CMD[$lang]}")"
  lint_cmd="$(sed_escape "${LINT_CMD[$lang]}")"
  lang_esc="$(sed_escape "$lang")"
  target=".claude/agents/proj-code-writer-${lang}.md"

  printf '%s\n' "$CODE_WRITER_TEMPLATE" \
    | sed -e "s|{lang}|${lang_esc}|g" \
          -e "s|{build_cmd}|${build_cmd}|g" \
          -e "s|{test_cmd}|${test_cmd}|g" \
          -e "s|{lint_cmd}|${lint_cmd}|g" \
    > "$target"

  if grep -qE '\{(lang|build_cmd|test_cmd|lint_cmd)\}' "$target"; then
    printf 'ERROR: unresolved placeholder in %s\n' "$target" >&2
    exit 1
  fi
  printf '  RENDERED %s\n' "$target"
done
```

**Checkpoint:** `Phase 3 complete — {N} code writers rendered`

---

## Phase 4 (template render) — Generate Test Writers — `sed` substitution per language

Same mechanic as Phase 3 against `templates/agents/test-writer.template.md`. Same placeholders. NO LLM dispatch.

```bash
set -euo pipefail

# Re-emit the Phase 0 contract (DETECTED_LANGS + BUILD_CMD/TEST_CMD/LINT_CMD)
# as the prelude here — each Phase 1-4 bash block runs in a fresh shell.
# <paste contract declarations from Phase 0 output contract above>

TEMPLATE_PATH="templates/agents/test-writer.template.md"

if [[ -f "$TEMPLATE_PATH" ]]; then
  TEST_WRITER_TEMPLATE="$(cat "$TEMPLATE_PATH")"
else
  TEST_WRITER_TEMPLATE="$(gh api "repos/${OWNER}/${REPO}/contents/${TEMPLATE_PATH}?ref=${BRANCH}" --jq '.content' | base64 -d)"
fi

# sed_escape defined in Phase 3; if Phase 4 runs in a separate shell, redefine here.
sed_escape() {
  local raw="$1"
  raw="${raw//\\/\\\\}"
  raw="${raw//|/\\|}"
  raw="${raw//&/\\&}"
  printf '%s' "$raw"
}

for lang in "${DETECTED_LANGS[@]}"; do
  build_cmd="$(sed_escape "${BUILD_CMD[$lang]}")"
  test_cmd="$(sed_escape "${TEST_CMD[$lang]}")"
  lint_cmd="$(sed_escape "${LINT_CMD[$lang]}")"
  lang_esc="$(sed_escape "$lang")"
  target=".claude/agents/proj-test-writer-${lang}.md"

  printf '%s\n' "$TEST_WRITER_TEMPLATE" \
    | sed -e "s|{lang}|${lang_esc}|g" \
          -e "s|{build_cmd}|${build_cmd}|g" \
          -e "s|{test_cmd}|${test_cmd}|g" \
          -e "s|{lint_cmd}|${lint_cmd}|g" \
    > "$target"

  if grep -qE '\{(lang|build_cmd|test_cmd|lint_cmd)\}' "$target"; then
    printf 'ERROR: unresolved placeholder in %s\n' "$target" >&2
    exit 1
  fi
  printf '  RENDERED %s\n' "$target"
done
```

**Checkpoint:** `Phase 4 complete — {N} test writers rendered`

---

## Phase 5 (dispatch proj-code-writer-markdown) — Generate Project Code Reviewer

Single dispatch — reviewer must read ALL `{lang}-analysis.md` + `{lang}-research.md` refs, `.claude/rules/*.md`, `.learnings/log.md` (if present), and `CLAUDE.md` for project-specific gotchas. Output: `.claude/agents/proj-code-reviewer.md` with the 9 required sections (Role, Pre-Review Read, Review Checklist, Architecture Awareness, Security, Completeness Check, Anti-Hallucination, Parallel Tool Calls, Pass-by-Reference). Project-specific content means this cannot be a tracked template — dispatch via `Agent(subagent_type="proj-code-writer-markdown", ...)` using the BOOTSTRAP_DISPATCH_PROMPT from Module 01.

After dispatch returns, verify:

```bash
[[ -f .claude/agents/proj-code-reviewer.md ]] || { echo "MISSING: proj-code-reviewer.md"; exit 1; }
grep -q '^name: proj-code-reviewer$' .claude/agents/proj-code-reviewer.md || { echo "proj-code-reviewer.md missing frontmatter name"; exit 1; }
```

**Checkpoint:** `Phase 5 complete — proj-code-reviewer generated`

---

## Phase 6 (main) — Agent Index + References + Skill Wiring

Main thread reads every agent's frontmatter and writes `.claude/agents/agent-index.yaml` — dispatch routing index for orchestrators. Entries include `name`, `scope`, `model`, `parent`, `type` (`code-writer` / `test-writer` / `review` / `utility`), `last-updated`. Agent type inferred from filename: `proj-code-writer-*` → code-writer, `proj-test-writer-*` → test-writer, `proj-code-reviewer` → review, all others → utility.

Update `.claude/skills/code-write/references/capability-index.md` with the full inventory (name, scope, parent, type, file path, per-language coverage, remaining gaps). Update `.claude/skills/code-write/references/pipeline-traces.md` with the feature-type → file-order mapping extracted during Phase 1 analysis. Ensure `.claude/skills/code-write/SKILL.md`, `.claude/skills/coverage/SKILL.md`, `.claude/skills/coverage-gaps/SKILL.md`, and `.claude/skills/review/SKILL.md` are present (installed by Module 06) — if missing, STOP and instruct the user to re-run Module 06.

---

## Checkpoint

```
✅ Module 07 complete — code specialists installed
  Languages: {list}
  Code writers: proj-code-writer-{lang} × N
  Test writers: proj-test-writer-{lang} × N
  Code reviewer: proj-code-reviewer.md
  Agent index: agent-index.yaml
```
