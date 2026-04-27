# /evolve-agents Phase 3 Gate

<!-- exceeds-40-line-guideline INTENTIONAL: 16-line gate snippet + behavior matrix cannot be split without loss of canonical-reference integrity -->

## Rule
/evolve-agents Phase 3 (specialist creation) MUST run a pre-flight bash gate that verifies a fresh audit artifact exists. The gate BLOCKs on absent or malformed artifacts. The gate emits a non-blocking WARN if any specialist agent file is newer than the audit artifact.

## Artifact Contract
- Path: `.claude/reports/evolve-agents-audit-latest.md` (stable filename — no timestamp; `ls -t` glob NOT used)
- Producer: Phase 1 dispatched `proj-researcher` writes via Bash heredoc
- Required token: trailing `^## Gate Complete` heading at end of artifact body
- Lifetime: stable filename overwritten on each Phase 1 run; `find -newer` compares specialist agent mtimes against artifact mtime

## Gate Snippet (canonical)
Verbatim from `.claude/specs/main/2026-04-27-evolve-agents-skill-eval-deep-think/gap-resolution-2-1-1-final-gate-snippet.md` lines 65-81:

```bash
## Phase 3 Pre-Flight Gate
ARTIFACT=".claude/reports/evolve-agents-audit-latest.md"
if [[ ! -f "$ARTIFACT" ]]; then
  echo "BLOCK: No audit artifact found. Run /evolve-agents Phase 1 first (or pass --skip-audit-gate)."
  exit 1
fi
if ! grep -q "^## Gate Complete" "$ARTIFACT"; then
  echo "BLOCK: Audit artifact missing Gate Token (truncated write?). Re-run Phase 1."
  exit 1
fi
STALE_AGENTS=$(find .claude/agents/ -type f \( -name 'proj-code-writer-*.md' -o -name 'proj-test-writer-*.md' \) -newer "$ARTIFACT" 2>/dev/null)
if [[ -n "$STALE_AGENTS" ]]; then
  echo "WARN: Agent files modified after audit artifact — consider re-running Phase 1:"
  echo "$STALE_AGENTS"
fi
```

## Behavior Matrix
| Condition | Outcome |
|---|---|
| Artifact missing | BLOCK (`exit 1` with diagnostic) |
| Artifact present, no `## Gate Complete` heading | BLOCK (truncated write) |
| Artifact present + complete + no specialist newer | PASS |
| Artifact present + complete + ≥1 specialist newer | WARN (non-blocking; lists stale agents) |

## A9 Audit Behavior
- Scope: only `.claude/skills/evolve-agents/SKILL.md` (not all skills)
- Check 1: grep for `<!-- evolve-agents-gate-installed -->` sentinel → presence = PASS
- Check 2: grep for the canonical gate text patterns (`evolve-agents-audit-latest.md`, `## Gate Complete`, `find .claude/agents/`) → all present = PASS
- Check 3: confirm Phase 1 contains a Write call producing the artifact path → presence of `evolve-agents-audit-latest.md` in Phase 1 body = PASS
- Failure: any check fails → A9 = FAIL with file:line evidence

## Bypass
Documented but DISCOURAGED: pass `--skip-audit-gate` arg to /evolve-agents; gate emits warning instead of BLOCK; useful only for repair scenarios (audit infrastructure broken; user manually verified state).
