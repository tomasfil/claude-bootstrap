# Agent Design Techniques Reference

---
type: research-knowledge
status: curated-starting-point
warning: >
  Patterns are researched best practices — NOT project-verified truths.
  Architectural constraints (subagent limits, tool removal) reflect Claude Code
  as of 2026 — verify against current docs.
see-also:
  - techniques/prompt-engineering.md — RCCF framework, structured outputs, token optimization
  - techniques/anti-hallucination.md — verification patterns for every agent
---

> **Cross-references:**
> - Scope locks, verify-and-fix containment → canonical in `techniques/prompt-engineering.md`
> - RCCF framework → `techniques/prompt-engineering.md`
> - Verification patterns → `techniques/anti-hallucination.md`

## Subagent Constraints (Hard Rules)

1. CANNOT spawn subagents — Agent tool removed
2. CANNOT ask user questions — AskUserQuestion removed
3. CANNOT enter plan mode — EnterPlanMode removed
4. Isolated context window per subagent (size = model-dependent)
5. System prompt = `.md` body (NOT full Claude Code system prompt)
6. Windows: long `.md` may fail via `--agents` CLI (8191 char limit)

**Exception** — `claude --agent`: agents ARE main thread, CAN spawn subagents + restrict types

## Orchestrator-as-Skill Pattern

Skills run in main conversation where Agent tool IS available → orchestrate specialists w/o nested-subagent constraint.

```
.claude/skills/code-write/
├── SKILL.md                    # Orchestrator logic (~100-200 lines)
└── references/
    ├── pipeline-traces.md      # Feature-type → file mapping
    └── layer-dependencies.md   # Which layers depend on which
```

```yaml
---
name: code-write
description: >
  Use when implementing features, writing code, adding functionality,
  building components, or creating new files. Orchestrates language-specific
  code writers for cross-layer features. MUST be invoked for any code
  generation task.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob, Skill
model: opus
effort: high
paths: "src/**"
---
```

```markdown
## Orchestrator Protocol

1. **Analyze the request** — what kind of feature? What layers affected?
2. **Load pipeline trace** — read references/pipeline-traces.md
3. **Map file changes** — which files need to be created/modified?
4. **Determine specialists** — which language agents needed?
5. **Check file ownership** — no two agents should edit the same file
6. **Dispatch specialists** — in dependency order (data layer first, UI last)
7. **Verify integration** — build all, run tests, check cross-layer wiring
```

## Agent YAML Frontmatter

```yaml
---
name: code-writer-dotnet
description: >
  .NET/C# code writer specialist. Use when writing C# code for FastEndpoints
  APIs, EF Core entities/configurations, services, DTOs, mappers, or any
  .cs file. Knows project conventions, DI patterns, error handling.
tools: Read, Write, Edit, Bash, Grep, Glob, LSP, WebSearch
model: sonnet
effort: medium
---
```

| Field | Req | Notes |
|-------|-----|-------|
| `name` | Y | Lowercase hyphens, <64 chars |
| `description` | Y | Pushy — trigger words for when to use |
| `tools` / `disallowedTools` | N | Allow/denylist; default: inherit |
| `model` | N | `haiku` `sonnet` `opus`; default: inherit |
| `effort` | N | `low` `medium` `high` `max`; default: inherit |
| `maxTurns` | N | Limit iterations |
| `color` | N | CLI output color |
| `memory` | N | `user` `project` `local` |
| `skills` | N | Preloaded (full SKILL.md injected) |
| `isolation` | N | `worktree` for git isolation |
| `permissionMode` | N | `default` `acceptEdits` `dontAsk` `plan` |
| `background` | N | **Do not use** — see Foreground-Only |
| `hooks` / `mcpServers` | N | Lifecycle hooks; MCP servers |
| `scope` | N | Comma-separated framework/concern list; used by orchestrators for sub-specialist routing |
| `parent` | N | Name of parent agent this sub-specialist was split from; prevents re-splitting |

**Skill authoring** (Anthropic docs): description third-person max 1024 chars; body <500 lines (split to `references/`); refs one level deep; TOC for >100-line files; project-specific only ("would Claude get this wrong?"); match freedom to fragility; validate→fix→repeat loops; test 3+ scenarios before writing docs

**Model selection:** GENERATES code | SUBTLE errors → `opus`; ANALYZES → `sonnet`; CHECKS → `haiku`

| Agent | Model | Agent | Model |
|-------|-------|-------|-------|
| code-writer-{lang} | opus | plan-writer | sonnet |
| code-writer-{lang}-{fw} | opus | | |
| test-writer | opus | researcher | sonnet |
| project-code-reviewer | opus | consistency-checker | sonnet |
| debugger | opus | verifier | sonnet |
| tdd-runner / reflector | opus | quick-check | haiku |

## Foreground-Only Dispatch

**Always foreground. Never `run_in_background: true`.** Permission-gated tools silently block background agents. Parallel foreground (multiple Agent calls in one message) = same concurrency.
- Permission-gated: `Write` `Edit` `Bash` `NotebookEdit` `Agent` `WebSearch` `WebFetch`
- Auto-allowed: `Read` `Grep` `Glob` `LSP`

| Restriction | Tools | Use for |
|-------------|-------|---------|
| Minimal | `Read, Grep, Glob` | reviewers, researchers |
| Standard | `Read, Write, Edit, Bash, Grep, Glob, LSP` | implementation |
| Extended | Standard + `WebSearch, WebFetch` | current docs/APIs |
| Orchestrator | `Agent(...), Read, Grep, Glob, Bash` | main-thread only |

## Communication + Errors + Teams

**Communication:** file-based (most reliable) | task-based (teams only) | sequential (A→B→synthesize) | parallel (no deps → single message)

**Errors:** check output → retry ONCE w/ context → surface to user; never swallow. Prevention: verification steps; maxTurns; "if unsure, say so"

**Teams** = independent full sessions (unlike subagents). Own context + tools.

| Criteria | Subagents | Teams |
|----------|-----------|-------|
| Scope | Focused | Complex |
| Context | <50% window | Full window |
| Coordination | Dispatch | Shared tasks |
| Cost | 4-7x | ~15x |
| Isolation | Shared repo | Worktree |

Avoid teams for: simple tasks; cost-sensitive; tight sequential coordination

## Invocation Quality (Critical)

Most failures = poor invocations. Bad:
```
"Fix the Division service"
```

Good:
```
"In MyProject.Services/Data/Divisions/DivisionService.cs,
add a new method `GetActiveDivisionsForBrandAsync(Guid brandId)` that:
1. Queries divisions where BrandId == brandId AND IsActive == true
2. Uses AsNoTracking() (read-only query)
3. Returns Task<List<Division>>
4. Follows the existing pattern in GetDivisionsByBrandAsync (line 45)
5. Uses IDataService<AppDbContext>.Entity<Division, Guid>().WhereAsQueryable()

Reference files:
- Current service: Services/Data/Divisions/DivisionService.cs
- Interface: Services/Data/Divisions/IDivisionService.cs (add to interface too)
- Pattern example: Services/Data/Brands/BrandService.cs:GetActiveBrandsAsync

After implementation, run: dotnet build MyProject.Services"
```

Checklist: file paths; success criteria; reference files; build/test command; unexpected-case instructions

## Turn-Efficient Agent Design

Turn count = second cost axis. Each turn re-reads conversation → turn reduction × token compression = multiplicative.

### Pre-Computed Context
Front-load context orchestrator already has — don't make agent discover it.

**Bad — forces discovery turns:**
```
"Write an article about the trend in the database"
```

**Good — eliminates discovery turns:**
```
"Write an article about {trend_title}.

Research data (pre-computed by researcher job):
{yaml block with key_facts, sources, angles}

Brand voice rules are pre-loaded in context (cron/shared/brand-voice-rules.md).
Do NOT re-read them. Do NOT search for additional brand guidance.

Target: 800-1200 words, Czech, publish-ready.
Output: JSON with title, body, meta_description, slug."
```

Pipeline: `pre_commands` compute+inject; `include_files` for static refs; stage outputs = YAML injected directly

### Scope Locks
→ See canonical: `techniques/prompt-engineering.md` § Scope Locks

### Verify-and-Fix Containment
→ See canonical: `techniques/prompt-engineering.md` § Verify-and-Fix Containment

### Search Batching for Research Agents

```markdown
## Research Protocol
1. Identify ALL information needs before searching
2. Execute all WebSearch calls in ONE message (parallel)
3. After receiving results, identify specific gaps
4. At most ONE follow-up batch
5. Maximum 2 search rounds total
```

### Tool Call Batching Instruction
Include in every multi-tool prompt — agents, orchestrator skills, CI prompts, cron prompts (Anthropic-recommended XML pattern):

```markdown
<use_parallel_tool_calls>
For maximum efficiency, invoke all independent tool calls simultaneously
rather than sequentially. Err on the side of maximizing parallel calls.
- Multiple Reads → batch in one message
- Multiple Greps → batch in one message
- Multiple WebSearches → batch in one message
- Read-only commands (ls, Glob, Grep) → ALWAYS parallel
NEVER: Read A → respond → Read B → respond. INSTEAD: Read A + B → respond.
</use_parallel_tool_calls>
```

Compact form (short prompts, CI/cron):
```markdown
<use_parallel_tool_calls>true</use_parallel_tool_calls>
Batch all independent tool calls into one message.
```

Full block: multi-step workflow, nuanced batching rules needed.
Compact: prompt is brief; single instruction sufficient.

XML tag = behavioral anchor — stronger than markdown headers.

### Agent SDK: Tool Result Formatting
Parallel batch results MUST go in **single** user message. Splitting trains model away from parallelism.

```json
[
  {"role": "assistant", "content": ["tool_use_1", "tool_use_2"]},
  {"role": "user", "content": ["tool_result_1"]},
  {"role": "user", "content": ["tool_result_2"]}
]
```

```json
[
  {"role": "assistant", "content": ["tool_use_1", "tool_use_2"]},
  {"role": "user", "content": ["tool_result_1", "tool_result_2"]}
]
```

No text before tool_results; every `tool_use` needs matching `tool_result`; collect all before next message.

### Batch Operations (Script Threshold)

>5 homogeneous ops (rename 10 files, patch 8 agents, update 12 configs) → write script, execute in one Bash call. <=5 ops OR heterogeneous → parallel tool calls.

BAD: 10× individual Read calls for 10 config files
GOOD: one Bash `for f in configs/*.yaml; do cat "$f"; done`

Threshold = IDENTICAL operations. Mixed read+write+grep = parallel tool calls, not script.

### Tool Use Examples (Reduce Misuse)

Include wrong/right examples in agent templates for tool-misuse-prone patterns. Inline examples reduce correction loops more than rule statements alone.

BAD: Read file-a.md → respond → Read file-b.md → respond (2 turns)
GOOD: Read file-a.md + Read file-b.md → respond once (1 turn)

BAD: Bash `grep -r foo .` (shell grep instead of Grep tool)
GOOD: Grep tool w/ pattern="foo" (optimized permissions + access)

### Meta-Tools / Pre-Commands

| Pattern | Solution |
|---------|----------|
| Agent greps for compliance rules → reads them → applies | pre_command runs compliance check, injects result |
| Agent reads DB → filters → processes | pre_command runs SQL query, injects filtered data |
| Agent reads 3 files to learn pattern | Inline pattern example in prompt |
| Agent searches web for same reference each run | Cache result, inject as include_file |

Sequence in >50% runs → extract to pre_command | include_file.

### Turn Budget Guidelines

```markdown
## Efficiency Expectations
- Research phase: batch all searches (aim for 2 search rounds max)
- Writing phase: produce complete draft in 1-2 turns
- Verification phase: self-fix up to 3 attempts before reporting
- Total: minimize turns. Every tool call should have clear purpose.
```

Mechanical jobs: hard `maxTurns` (5-10) — deterministic.

## File Size + Token Efficiency

| Lines | Action |
|-------|--------|
| <100 | Too sparse — may lack context |
| 100-300 | Ideal |
| 300-500 | Acceptable for complex projects |
| 500+ | Split into agent + `references/` |

```
.claude/agents/code-writer-dotnet.md          # Core logic (200 lines)
.claude/agents/references/dotnet-patterns.md   # Detailed examples (300 lines)
```

Agent `.md` = system prompts — Claude only reader. Compress w/ telegraphic notation (`techniques/prompt-engineering.md` → Token Optimization). Code examples → full fidelity. 30-50% smaller × invocation count.

## Inter-Agent Handoff Formats (LLM-general, verified via 2025-2026 docs)

Multi-agent systems in production (AutoGen, CrewAI, LangGraph, OpenAI Agents SDK, A2A protocol) converge on similar handoff schemas. Summary + essential fields below.

### Production System Patterns
| System | Format | Key Idea |
|--------|--------|----------|
| AutoGen HandoffMessage | id, source, target, content, context[prior], metadata, models_usage | explicit routing + inline usage metrics |
| OpenAI Agents SDK | `handoff(agent, on_handoff, input_filter)` — handoff-as-tool | input_filter trims prior history per target |
| LangGraph State | TypedDict/Pydantic w/ reducer fns per key | typed end-to-end, merge semantics |
| CrewAI Task | description, expected_output, context[task_refs], output_json | typed output contract + task-ref chaining |
| A2A Protocol v0.3 | Message{parts[TextPart|FilePart|DataPart], taskId, contextId, referenceTaskIds} | typed parts discriminator, multi-link refs |
| Claude Agent SDK subagents | prompt string in → single message out, fresh context | strict isolation forces explicit injection |

### Essential Handoff Fields (synthesis)
```yaml
handoff:
  id: <ulid>                       # stable chain identifier
  parent_id: <ulid>?               # chain link (A2A referenceTaskIds)
  context_id: <ulid>               # groups multi-agent conversation
  source: {agent, step?}           # routing + audit
  target: {agent, role}            # scope-lock + compression profile lookup
  task: <telegraphic intent>
  scope:
    include: [paths|modules]
    exclude: [negatives]           # hard negative injections (under-used, biggest quality win)
    constraints: [rules]
  context:
    files: [paths]                 # Conductor-injected, not agent-fetched
    prior_refs: [<handoff_id>]     # A2A-style, not inline re-embed
    instincts: [ids]               # Cortex refs
    injected: {k: v}               # pre-computed data
  output:
    findings: <role-shaped payload>
    evidence:                      # pattern 9, REQUIRED for research roles
      - {claim, source_url, confidence: h|m|l, corroborated: bool}
    unresolved: [trail-lost items] # explicit gaps prevent fabrication
    confidence: h|m|l
  budget: {tokens, tools: {web: int}}
  meta: {profile: code|research|review|route, tokens_in_out, created}
```

### Key Design Rules (from research synthesis)
1. **Typed parts discriminator** (A2A pattern): payload carries region type (text/file/data/evidence) → enables structured evidence tracking + per-region compression
2. **Chain by reference, not embed**: `prior_refs: [ids]` — Conductor dereferences at dispatch; prevents context bloat across long chains
3. **Mandate evidence[] for research roles**: scout/survey/researcher handoffs w/ empty evidence → auto-reject (Pattern 9 enforcement)
4. **Forbid evidence[] for code-writer roles**: dilutes token budget, not their job
5. **Scope.exclude hard-injects into target system prompt**: biggest under-used quality lever
6. **Tag compression_profile in meta**: prevents silent lossy chains (research 70% → code-writer expects 80%)
7. **Budget inline** (AutoGen models_usage pattern): enforced pre-dispatch via Ledger
8. **Handoff → Manifest promotion**: approval-gated handoffs wrap in Manifest sections; single source-of-truth record per chain step

### Novel Patterns Worth Adopting
| Pattern | Source | What It Adds |
|---------|--------|--------------|
| AgentCard discovery | A2A /.well-known/agent-card.json | capability cards for Conductor routing |
| referenceTaskIds multi-link | A2A | fan-in from multiple parallel agents |
| on_handoff callbacks | OpenAI | pre-dispatch side effects (prefetch, warmup) |
| input_filter | OpenAI | automatic prior-context trimming per target |
| Typed streaming deltas | LangGraph stream_version v2 | emit handoff deltas during long runs, not just completion |
| Hash-chain audit log | arXiv 2512.20985 | tamper-evident append-only event log |

---

## Sources
- Claude Code Docs: sub-agents, agent-teams, tools-reference
- claudefa.st: sub-agent best practices
- OpenDev Paper (arxiv 2603.05344)
- Anthropic: Building Effective AI Agents
- lst97/claude-code-sub-agents; wshobson/agents
- AutoGen: microsoft.github.io/autogen/stable/
- CrewAI: docs.crewai.com/en/concepts/tasks
- LangGraph: docs.langchain.com/oss/python/langgraph
- OpenAI Agents SDK: openai.github.io/openai-agents-python/handoffs/
- A2A Protocol v0.3: a2a-protocol.org/latest/specification/
- Google ADK: google.github.io/adk-docs/a2a/intro/
