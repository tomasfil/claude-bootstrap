# Technique References — Index

> Research-synthesized best practices. Starting point for design + implementation, NOT definitive truths.
> Validate against current project state before applying.

## Files

| File | Covers | Use when |
|------|--------|----------|
| `prompt-engineering.md` | RCCF framework, structured outputs, classification trees, few-shot patterns, context caching, token optimization, scope locks, verify-and-fix | Writing skills, agents, prompts; optimizing token usage |
| `anti-hallucination.md` | Read-before-write, CoVe, negative instructions, LSP verification, build verification, package detection, claim-evidence ledger | Building any code-writing agent; research-to-output skills |
| `agent-design.md` | Subagent constraints, orchestrator-as-skill, YAML templates, tool restrictions, invocation quality, turn efficiency, tool call batching, search batching, pass-by-reference protocol, maxTurns config, self-bootstrapping, agent index, build integrity | Designing agents, dispatching subagents, pipeline architecture |
| `token-efficiency.md` | Compression tiers, retention floors per agent role, protected regions, algorithmic tools, turn reduction rules, format selection, @import pattern, cache economics | Canonical compression source; optimizing token usage; designing inter-agent handoffs; writing always-loaded config |

## Canonical Ownership (deduplication)

Shared concepts live in ONE file; the other cross-references it:

| Concept | Canonical file |
|---------|---------------|
| Scope locks | prompt-engineering.md |
| Verify-and-fix containment | prompt-engineering.md |
| Tool call batching | agent-design.md |
| Search batching | agent-design.md |
| Pre-computed context | agent-design.md |
| Compression tiers | token-efficiency.md |
| Glyph symbol legend | token-efficiency.md |
| Handoff schema | agent-design.md |
| Pass-by-reference protocol | agent-design.md |
| maxTurns configuration | agent-design.md |
| Self-bootstrapping pattern | agent-design.md |
| Agent index schema | agent-design.md |
| Build integrity rule | agent-design.md |
| Agent loading constraint | agent-design.md |
| Format selection (YAML/JSON/TSV) | token-efficiency.md |
| Cache economics | token-efficiency.md |
| Agent output verification | anti-hallucination.md |
| Build state invariant | anti-hallucination.md |
| Skill description optimization | prompt-engineering.md |
| Split-plan pattern | prompt-engineering.md |
