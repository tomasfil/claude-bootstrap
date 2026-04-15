---
name: cmm-baseline
description: >
  Use when managing the CMM per-project baseline. Run /cmm-baseline init at
  bootstrap completion, /cmm-baseline refresh after large refactors, /cmm-baseline
  check for read-only drift report, /cmm-baseline verify-sentinels for correctness gate.
  Writes .claude/cmm-baseline.md — the committed source of truth for healthy cmm graph state.
model: sonnet
effort: medium
allowed-tools: Read Write Edit Bash Grep Glob
user-invocable: true
argument-hint: init | refresh | check | verify-sentinels
---

# cmm-baseline

Manage the per-project CMM baseline file `.claude/cmm-baseline.md`. The baseline is
the **committed source of truth** for a healthy `codebase-memory-mcp` graph state:
node/edge counts, per-label counts, framework blind spots, sentinels, known-broken
tools, and routing overrides.

The baseline is consumed by three layers:

1. `.claude/hooks/cmm-index-startup.sh` — SessionStart hook reads baseline, compares
   git SHA + node/edge counts, triggers full reindex on any drift (zero-drift policy).
2. `/cmm-baseline verify-sentinels` — correctness gate; asserts every sentinel symbol
   is present in the current graph.
3. Claude (main thread + sub-agents) — consults baseline for framework blind spots and
   routing overrides before running symbol queries against unreliable Node types.

This skill runs on the main thread only. It is **not forkable** — framework detection
and multi-file inspection require full main-thread tool access.

---

## STEP 0 — Force-Reads (mandatory first action)

Before any command runs, Read these rule files in parallel:

- `.claude/rules/general.md`
- `.claude/rules/max-quality.md`
- `.claude/rules/mcp-routing.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`

If a force-read file does not exist on the current project, note it and continue —
do not stop.

---

## Pre-Flight (runs for every command)

1. Check `.mcp.json` at project root. If missing OR it does not contain
   `codebase-memory-mcp` under `mcpServers`:
   ```
   STOP with error: "cmm-baseline requires codebase-memory-mcp registered in .mcp.json.
   Register the server first (see modules/08-verification.md MCP setup section) and retry."
   ```
2. Check `.claude/agents/proj-researcher.md` exists. If missing, framework detection
   falls back to direct project-file inspection (manifest parsing without dispatch).
   Continue; do not stop.
3. Confirm `mcp__codebase-memory-mcp__*` tool schemas are loaded in this session. If
   the deferred-tools contract applies, call:
   ```
   ToolSearch select:mcp__codebase-memory-mcp__index_repository,mcp__codebase-memory-mcp__index_status,mcp__codebase-memory-mcp__get_graph_schema,mcp__codebase-memory-mcp__search_graph,mcp__codebase-memory-mcp__list_projects
   ```
   BEFORE invoking any cmm tool. Missing schemas fail the command — load them.

---

## Command: `/cmm-baseline init`

First-time seed of `.claude/cmm-baseline.md`. Runs a full index, detects frameworks,
picks sentinels, writes the baseline, self-checks.

### Steps

1. **Pre-flight** (above).

2. **Run full index.** Invoke `mcp__codebase-memory-mcp__index_repository` with
   `repo_path` = absolute project root and `mode` = `"full"`. Block until the call
   returns. Timing expectations:
   - Tiny repo (<1k nodes): <1s
   - Medium repo (~50k LOC): ~6s
   - Large repo (~10k nodes, ~200k LOC C#): ~20-60s
   - Giant repo (monorepo, 75k files): ~3min
   If the call fails, report the error and stop. Do not write a partial baseline.

3. **Read the resulting graph state.**
   - Call `mcp__codebase-memory-mcp__list_projects` to resolve the cmm path-slug for
     the current working directory (slug = full absolute path with `/` and `\`
     replaced by `-`). Match by suffix against the returned list.
   - Call `mcp__codebase-memory-mcp__index_status` with `{"project": "<slug>"}` —
     extract `nodes`, `edges`, `file_count`, `status`.
   - Call `mcp__codebase-memory-mcp__get_graph_schema` with `{"project": "<slug>"}` —
     extract per-label node counts.
   - If `status != "ready"`, report the discrepancy and stop.

4. **Detect frameworks.** Inspect project manifest files:
   - `*.csproj`, `*.sln`, `Directory.Packages.props` — parse `<PackageReference Include="...">`
     entries for known framework signals.
   - `package.json` — parse `dependencies` and `devDependencies` for framework signals.
   - `pyproject.toml`, `requirements.txt`, `Pipfile`, `setup.py` — parse Python deps.
   - `Cargo.toml` — parse Rust crates.
   - `Gemfile` — parse Ruby gems.
   - `go.mod` — parse Go modules.
   - `composer.json` — parse PHP packages.
   For each detected manifest, look up matching entries in
   `references/framework-catalog.md`. Record hits as `(framework_name, blind_spot_label,
   fallback_pattern)` tuples. Unknown frameworks → no blind-spot entry; not an error.

5. **Pick sentinels.** Select 3-5 stable symbols the reindex must always find:
   - Priority 1: canonical entry-point names present in the graph — `Program`, `main`,
     `App`, `Application`, `index`, `Startup`. Call
     `mcp__codebase-memory-mcp__search_graph` with `name_pattern=<name>` for each
     candidate; include only matches that return ≥1 hit.
   - Priority 2: known framework base classes from detected frameworks (e.g. if
     FastEndpoints detected, `Endpoint` base symbol). Query the same way.
   - Priority 3: top 3 symbols by `Method` label count — query
     `mcp__codebase-memory-mcp__query_graph` with a Cypher that orders methods by
     cross-reference count descending, returning the top 3 names. Pick names that
     survive typical refactors (framework-exposed methods, public API surface).
   - Cap the final list at 5 sentinels. Fewer is fine; zero is a hard error —
     report "no stable sentinels found, graph may be near-empty" and stop.

6. **Populate routing overrides (conditional).** For each framework blind-spot,
   emit a line of the form:
   ```
   # {Node_label} queries unreliable under {framework} -> prefer {fallback_pattern}
   ```
   Do NOT hardcode specific MCP server names in overrides — use generic descriptions
   ("LSP-based parsers", "graph-indexed tools") when referring to tool classes.

7. **Write `.claude/cmm-baseline.md`.** Use the template below (YAML frontmatter
   + markdown body). All fields are mandatory except `Routing overrides` which may
   be empty when no framework blind-spots were detected.

   ```markdown
   ---
   project_slug: {cmm_path_slug}
   last_indexed_ref: {git_sha_or_empty_if_not_git}
   last_index_mode: full
   last_indexed_at: {ISO8601_UTC}
   nodes: {N}
   edges: {E}
   file_count: {F}
   nodes_per_file: {N/F_two_decimals}
   ---

   # CMM Baseline
   Generated: {ISO8601_UTC} | Managed by: /cmm-baseline + .claude/hooks/cmm-index-startup.sh

   ## Per-label counts
   {label_1}: {count_1}
   {label_2}: {count_2}
   ...

   ## Sentinels
   - {sentinel_1}  # {why stable — e.g., "entry point", "framework base class", "stable public API"}
   - {sentinel_2}  # {reason}
   ...

   ## Framework blind spots
   - {Node_label}: {X/Y coverage}  # {framework} — use {fallback}
   ...

   ## Known-broken tools
   - cmm.{tool}: {reason}  # fallback: {alternative}
   ...

   ## Routing overrides
   # {pattern_description} -> prefer {tool} over {default}
   ...
   ```

8. **Self-check.** Run `/cmm-baseline verify-sentinels` as the final step. Any
   missing sentinel → revert the baseline write (or leave the broken baseline in
   place with a warning), report the failure, and stop. All present → report success
   with summary `baseline seeded: nodes=N edges=E sentinels=K frameworks=M`.

---

## Command: `/cmm-baseline refresh`

Force full reindex + rebaseline. Preserves user-managed sections by default.

### Steps

1. **Pre-flight.**

2. **Parse existing baseline** at `.claude/cmm-baseline.md`. Read the YAML frontmatter
   fields and the four body sections (`Sentinels`, `Framework blind spots`,
   `Known-broken tools`, `Routing overrides`). If the file is missing, report
   "no baseline found — run /cmm-baseline init first" and stop.

3. **Run full index** via `mcp__codebase-memory-mcp__index_repository(mode="full")`.
   Block until complete. Same timing expectations as `init`.

4. **Re-read graph state** — `index_status` + `get_graph_schema` — extract fresh
   counts and per-label counts.

5. **Update YAML frontmatter fields.** Replace `nodes`, `edges`, `file_count`,
   `nodes_per_file`, `last_indexed_ref` (fresh `git rev-parse HEAD` if this is a
   git repo), `last_indexed_at` (current ISO8601 UTC). Leave `project_slug` and
   `last_index_mode: full` unchanged.

6. **Update `## Per-label counts` body section** with fresh counts.

7. **Preserve user-managed sections** — `Sentinels`, `Framework blind spots`,
   `Known-broken tools`, `Routing overrides` — UNLESS the user passed `--full-regen`
   as an argument. With `--full-regen`:
   - Clear all four user-managed sections.
   - Re-run framework detection (step 4 of `init`).
   - Re-pick sentinels (step 5 of `init`).
   - Re-populate routing overrides (step 6 of `init`).

8. **Write the updated baseline file.**

9. **Self-check** via `/cmm-baseline verify-sentinels`. Report success with summary
   `baseline refreshed: nodes=N (was M) edges=E (was F) ref=<sha>`.

---

## Command: `/cmm-baseline check`

Read-only drift report. Never writes.

### Steps

1. **Pre-flight.**

2. **Parse existing baseline.** Missing → report "no baseline" and stop.

3. **Read current graph state** — `index_status` + `get_graph_schema`. Do NOT run
   `index_repository`.

4. **Compare** against baseline:
   - `last_indexed_ref` vs current `git rev-parse HEAD` (if git repo)
   - `nodes` vs current `index_status.nodes`
   - `edges` vs current `index_status.edges`
   - Per-label counts — any label in baseline missing from current, or any current
     label missing from baseline, or any count delta ≥ 10% of baseline value

5. **Report drift to the user** as a structured summary:
   ```
   CMM drift report for {project_slug}
     baseline:  nodes={N}  edges={E}  ref={SHA}  labels={K}
     current:   nodes={M}  edges={F}  ref={SHA}  labels={L}
     deltas:    nodes={+/-dN}  edges={+/-dE}  sha={changed|same}
     label deltas (if any): {label}: {baseline_count}->{current_count}
     recommendation: {fresh | drift — run /cmm-baseline refresh | stale — reindex required}
   ```
   Do NOT write any file. Do NOT run any mutation. Exit with the report.

---

## Command: `/cmm-baseline verify-sentinels`

Correctness gate. Asserts every sentinel from the baseline is currently present in
the cmm graph. Runs after any reindex (self-check) or on demand.

### Steps

1. **Pre-flight.**

2. **Parse baseline** `## Sentinels` section. Empty or missing → report "no sentinels
   defined in baseline" and exit success (nothing to verify).

3. **For each sentinel**, call `mcp__codebase-memory-mcp__search_graph` with
   `name_pattern=<sentinel_name>` and whatever label constraint is recorded in the
   baseline comment (fallback: no label constraint).
   - ≥1 hit → mark PASS
   - 0 hits → mark FAIL, record the sentinel name + line reference

4. **If ANY sentinel failed**:
   - Append a line to `.learnings/log.md` in the format:
     ```
     ### {YYYY-MM-DD} — correction: cmm sentinel missing after reindex: {sentinel_name}
     - Project: {project_slug}
     - Expected label: {label_from_baseline}
     - Reindex ref: {current_git_sha}
     - Baseline ref: {baseline_last_indexed_ref}
     - Recommended action: /cmm-baseline refresh (or investigate structural drift)
     ```
   - Report the failure to the user: which sentinels are missing, the recommended
     action (`/cmm-baseline refresh --full-regen` is appropriate when the project
     underwent a large refactor; a plain refresh when only counts drifted).
   - Exit with a non-zero status indication (report the failure; do not silently pass).

5. **All present** → report `verify-sentinels PASS: {K} sentinels verified
   (nodes={N} edges={E} ref={SHA})`. Exit success.

---

## Reference material

`references/framework-catalog.md` — generic catalog of framework blind spots
keyed by detection signal (package name, manifest path). Content hygiene:
**zero third-party MCP server names**. Use generic tool-class descriptions only.

---

## Failure modes + recovery

| Symptom | Cause | Recovery |
|---|---|---|
| Pre-flight STOP: cmm not registered | `.mcp.json` missing codebase-memory-mcp | Register the server, retry |
| `index_repository` hangs >10min | Pathological repo, tooling bug | Cancel, check index_status, file upstream bug report |
| Sentinel self-check FAIL after init | Picked unstable symbols | Re-run with more conservative picks (entry points only) |
| `verify-sentinels` FAIL on existing baseline | Refactor removed the symbol | Run `/cmm-baseline refresh --full-regen` to re-pick sentinels |
| `check` reports drift but `refresh` produces identical counts | cmm graph already fresh | Harmless; baseline already matches current state |
| `list_projects` returns no matching slug | Project never indexed or slug mismatch | Run `/cmm-baseline init` first |

---

## Rationale

- **Why committed to git**: team members share the healthy-state definition, reducing
  "works for me" drift in distributed teams.
- **Why sentinels**: exact node/edge counts fluctuate on every commit; sentinels are
  semantic guarantees that survive normal refactors.
- **Why main-thread only**: framework detection + file inspection need full tool
  access; sub-agent forks add latency for no quality gain on this workload.
- **Why zero-drift policy**: partial indexes are silent correctness bugs
  (tree-sitter 75-89% accuracy tier on some languages); fresh full index is cheap
  enough to demand on every session start via the SessionStart hook.
