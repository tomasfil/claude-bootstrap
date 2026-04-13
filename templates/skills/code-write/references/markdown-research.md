# Markdown Research — claude-bootstrap

> No external web research. Documentation/prompt-engineering meta-project.
> Patterns already codified in `techniques/*.md`. Local refs are authoritative.
> Last updated: 2026-04-10.

---

## Summary

This is a documentation project — the "best practices" for its content type (LLM instructions, prompt engineering, subagent design, markdown conventions) are already curated in the `techniques/` directory. Web research would duplicate existing reference material without adding signal.

The `techniques/*.md` files are explicitly marked `status: curated-starting-point` and reflect researched best practices synthesized from Claude Code docs, Anthropic guidance, and production multi-agent systems (AutoGen, CrewAI, LangGraph, OpenAI Agents SDK, A2A protocol).

---

## Authoritative Local References

- `techniques/prompt-engineering.md` — RCCF framework, structured outputs, token optimization, scope locks, verify-and-fix containment
- `techniques/anti-hallucination.md` — verification patterns, read-before-write mandate, false-claims mitigation, negative instructions
- `techniques/agent-design.md` — subagent constraints, MCP tool propagation, orchestrator-as-skill pattern, role-to-tools table, maxTurns table, pass-by-reference protocol, skill dispatch reliability
- `techniques/token-efficiency.md` — telegraphic compression rules, symbol vocabulary, claude-facing vs human-facing scope
- `.claude/rules/code-standards-markdown.md` — naming, structure, content, verification conventions

---

## Rationale for Skipping Web Research

1. **Stable domain** — markdown syntax + YAML frontmatter are stable specs; no 2024/2025 churn to capture
2. **Claude Code spec is first-party** — hooks, skills, sub-agents docs at code.claude.com are authoritative; local `techniques/agent-design.md` already encodes the findings
3. **Project is the research** — this repo's modules + techniques ARE curated research, synthesized from ~40 sources (see techniques bibliographies)
4. **Risk of drift** — web findings could contradict internal conventions; local refs are the source of truth
5. **Meta-bootstrap loop** — searching the web about "how to write LLM instructions" would find content that this project itself informs

---

## When Web Research WOULD Be Warranted

Re-enable research only if:
- Claude Code releases a new frontmatter field not covered in `techniques/agent-design.md`
- Anthropic publishes a new prompt-engineering pattern not in `techniques/prompt-engineering.md`
- A subagent constraint changes (e.g., fork behavior, tool restrictions)
- GitHub issue resolution changes documented gotchas (check referenced issues #17283, #18721, #6497, #22050, #29202)

Until then: local refs authoritative; no searches.
