# Technique References — Index

> Research-synthesized best practices. Starting point for design + implementation, NOT definitive truths.
> Validate against current project state before applying.

## Files

| File | Covers | Use when |
|------|--------|----------|
| `prompt-engineering.md` | RCCF framework, structured outputs, classification trees, few-shot patterns, context caching, token optimization, scope locks, verify-and-fix | Writing skills, agents, prompts; optimizing token usage |
| `anti-hallucination.md` | Read-before-write, CoVe, negative instructions, LSP verification, build verification, package detection, claim-evidence ledger | Building any code-writing agent; research-to-output skills |
| `agent-design.md` | Subagent constraints, orchestrator-as-skill, YAML templates, tool restrictions, invocation quality, turn efficiency, tool call batching, search batching | Designing agents, dispatching subagents, pipeline architecture |

## Canonical Ownership (deduplication)

Shared concepts live in ONE file; the other cross-references it:

| Concept | Canonical file |
|---------|---------------|
| Scope locks | prompt-engineering.md |
| Verify-and-fix containment | prompt-engineering.md |
| Tool call batching | agent-design.md |
| Search batching | agent-design.md |
| Pre-computed context | agent-design.md |
