# Bash Research — claude-bootstrap

> No external web research. POSIX/bash patterns are stable.
> Claude Code hooks spec is authoritative — already documented locally.
> Last updated: 2026-04-10.

---

## Summary

Bash/POSIX shell is a stable, decades-old specification. The project's bash surface area (hook scripts, utility scripts, JSON config writers) follows well-established conventions already codified in `.claude/rules/shell-standards.md`.

The only project-specific spec is the Claude Code hook lifecycle + stdin JSON input contract — this is documented in `modules/03-hooks.md` and enforced by `.claude/agents/proj-code-writer-bash.md`.

---

## Authoritative Local References

- `.claude/rules/shell-standards.md` — shebang, `set -euo pipefail`, quoting, `[[ ]]`, `local`, `printf`, stdin contract
- `modules/03-hooks.md` — hook lifecycle events, settings.json nested format, stdin JSON input, exit code conventions
- `.claude/agents/proj-code-writer-bash.md` — canonical bash writer agent
- `.claude/scripts/json-val.sh` — portable JSON extraction (fallback when jq absent)
- Claude Code hooks docs: https://code.claude.com/docs/en/hooks (first-party spec)

---

## Hook JSON Stdin Contract

Hooks receive a JSON payload on **stdin** (never via environment variables). Minimum fields:

```json
{
  "tool_name": "Bash",
  "tool_input": { "command": "...", "file_path": "..." },
  "tool_response": { "exit_code": 0, "output": "..." },
  "stop_reason": "end_turn"
}
```

Extract via `jq` when available; fall back to `.claude/scripts/json-val.sh` for portability. Hook scripts in this repo demonstrate both patterns (`log-failures.sh` uses jq-with-fallback; `observe.sh` uses json-val.sh directly).

---

## Rationale for Skipping Web Research

1. **POSIX shell stable** — no meaningful 2024/2025 changes to bash builtins, flags, or core semantics
2. **Claude Code hooks docs first-party** — the spec is at code.claude.com; local references already encode the findings
3. **Project patterns authoritative** — existing scripts in `.claude/hooks/` demonstrate every pattern the writer needs (observe.sh for JSONL rotation, log-failures.sh for jq+fallback, guard-git.sh for PreToolUse blocking, detect-env.sh for session maintenance)
4. **Cross-platform gotchas stable** — MINGW64 path handling, `stat` flag variance, BSD vs GNU `find`/`date` differences are well-known and encoded in existing hooks

---

## When Web Research WOULD Be Warranted

Re-enable research only if:
- Claude Code publishes a new hook lifecycle event not covered in `modules/03-hooks.md`
- The hooks JSON schema changes (new input fields, new exit-code semantics)
- A cross-platform portability issue arises that isn't solved by the existing fallback chains
- jq or another tool is deprecated in supported environments

Until then: POSIX spec + local hooks authoritative; no searches.
