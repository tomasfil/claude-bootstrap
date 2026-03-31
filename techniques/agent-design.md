# Agent Design Techniques Reference

> Referenced by bootstrap modules when generating agents and skills. Covers constraints, patterns, and templates.

---

## Subagent Constraints (Hard Rules)

These are architectural constraints in Claude Code — not suggestions:

1. **Subagents CANNOT spawn other subagents** — Agent tool is removed at spawn time
2. **Subagents CANNOT ask the user questions** — AskUserQuestion tool removed
3. **Subagents CANNOT enter plan mode** — EnterPlanMode tool removed
4. **Each subagent gets its own isolated context window** (size depends on model)
5. **Subagent system prompt = the .md file body** (NOT the full Claude Code system prompt)
6. **On Windows, very long agent .md files may fail** via `--agents` CLI flag (8191 char limit) — use file-based agents instead

### Exception: Main-Thread Agents
When run via `claude --agent agent-name`, agents ARE the main thread and CAN:
- Spawn subagents using the Agent tool
- Restrict spawnable types: `tools: Agent(worker, researcher), Read, Bash`
- This is useful for orchestrator agents, but changes the UX

---

## Orchestrator-as-Skill Pattern (Recommended)

**Why:** Skills run in the main conversation where the Agent tool IS available. This lets the skill orchestrate specialist agents without hitting the "no nested subagents" constraint.

**Structure:**

```
.claude/skills/code-write/
├── SKILL.md                    # Orchestrator logic (~100-200 lines)
└── references/
    ├── pipeline-traces.md      # Feature-type → file mapping
    └── layer-dependencies.md   # Which layers depend on which
```

**SKILL.md Template:**

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

---

## Agent YAML Frontmatter Template

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

### Field Reference

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Lowercase, hyphens, <64 chars |
| `description` | Yes | "Pushy" — include trigger words for when to use (see Skill Authoring Rules below) |
| `tools` | No | Allowlist. Default: inherit all from main conversation |
| `disallowedTools` | No | Denylist. Alternative to `tools` |
| `model` | No | `haiku`, `sonnet`, `opus`. Default: inherit from parent |
| `effort` | No | `low`, `medium`, `high`, `max`. Default: inherit |
| `maxTurns` | No | Limit agent iterations |
| `color` | No | CLI output color for visual distinction (e.g., `green`, `red`, `cyan`) |
| `memory` | No | Persistent memory scope: `user`, `project`, `local` |
| `skills` | No | Skills preloaded into agent context at startup (full SKILL.md injected) |
| `isolation` | No | `worktree` for isolated git worktree |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `plan` |
| `background` | No | **Do not use.** Always dispatch foreground. See "Foreground-Only Dispatch" section |
| `hooks` | No | Lifecycle hooks scoped to this subagent |
| `mcpServers` | No | MCP servers available to this subagent |

### Skill Authoring Rules

Rules for writing effective SKILL.md files. Source: Anthropic platform docs.

1. **Description** — third person voice; state what the skill does + when to trigger it; max 1024 chars. Example: "Use when implementing features, writing code, or creating new files. Orchestrates language-specific writers."
2. **Body size** — SKILL.md under 500 lines. Approaching limit → split to `references/` subdirectory. Claude loads full SKILL.md into context on every invocation.
3. **Reference depth** — all references one level deep from SKILL.md. No A→B→C chains. SKILL.md → `references/foo.md` is fine; `references/foo.md` → `references/bar.md` is not.
4. **TOC** — reference files >100 lines need table of contents at top for navigation.
5. **Conciseness** — Claude already knows standard patterns, frameworks, idioms. Only add project-specific conventions, unusual constraints, non-obvious decisions. Test: "would Claude get this wrong without being told?"
6. **Degrees of freedom** — match flexibility to task fragility:
   - High (prose instructions): flexible tasks where Claude's judgment adds value
   - Low (exact scripts/commands): fragile ops where deviation breaks things (deploys, migrations, CI)
7. **Feedback loops** — quality-critical operations need validate → fix → repeat cycles. Include verification command + expected output in skill body.
8. **Evaluation** — test with 3+ real scenarios before writing extensive docs. Observe what Claude gets wrong → add only those corrections. Premature docs waste tokens on things Claude already handles.

### Automatic Model Selection

Model is assigned based on task complexity — no user preference needed.

**Decision rule:** If the agent GENERATES code or catches SUBTLE errors → `opus`. If it ANALYZES → `sonnet`. If it CHECKS or LOOKS UP → `haiku`.

| Agent | Model | Reasoning |
|-------|-------|-----------|
| code-writer-{lang} | opus | Generates code — needs maximum quality |
| test-writer | opus | Generates code + catches subtle bugs |
| project-code-reviewer | opus | Catches subtle issues, judgment-heavy |
| debugger | opus | Traces complex bugs, generates fixes |
| tdd-runner | opus | Generates tests + implementation code |
| reflector | opus | Judgment: promote/demote instincts |
| plan-writer | sonnet | Analyzes codebase, structures plans |
| researcher | sonnet | Analyzes patterns, explores code |
| consistency-checker | sonnet | Analyzes cross-references |
| verifier | sonnet | Runs checks, analyzes results |
| quick-check | haiku | Fast lookups, existence checks |

Override in `CLAUDE.local.md` if cost is a concern. Comment: `## Model Override — set model: sonnet in agent frontmatter`

---

## Foreground-Only Dispatch (Critical)

**Always dispatch agents in foreground. Never use `run_in_background: true`.**

Background agents cannot prompt the user for permission. Any tool that requires permission approval (Write, Edit, Bash, WebSearch, WebFetch) will **silently block** a background agent forever. Even read-only tools like WebSearch require permission, making background dispatch unreliable for most agents.

Foreground agents can run in parallel — launch multiple Agent tool calls in a single message for concurrency. This gives the same performance benefit as background dispatch without the permission problem.

### Why Not Background?
1. **Permission prompts silently block** — the agent hangs, wastes tokens, returns nothing
2. **No progress visibility** — you cannot see what a background agent is doing
3. **Foreground parallel works** — multiple foreground Agent calls in one message run concurrently
4. **No real benefit** — background only helps if you need to do other work while waiting, but in practice the orchestrator should wait for agent results before proceeding

### Permission-Gated Tools (any of these block background agents)
`Write`, `Edit`, `Bash`, `NotebookEdit`, `Agent`, `WebSearch`, `WebFetch`

### Auto-Allowed Tools (never prompt)
`Read`, `Grep`, `Glob`, `LSP`

---

## Tool Restriction Patterns

### Minimal (Research Only)
```yaml
tools: Read, Grep, Glob
```
Use for: code reviewers, researchers, quick-check agents

### Standard (Code Writer)
```yaml
tools: Read, Write, Edit, Bash, Grep, Glob, LSP
```
Use for: implementation agents, test writers

### Extended (With Web Access)
```yaml
tools: Read, Write, Edit, Bash, Grep, Glob, LSP, WebSearch, WebFetch
```
Use for: agents that need to research current docs/APIs

### Orchestrator (Can Dispatch — main thread only)
```yaml
tools: Agent(code-writer-dotnet, code-writer-frontend), Read, Grep, Glob, Bash
```
Use for: main-thread orchestrator agents (via `claude --agent`)

---

## Communication Patterns

### File-Based (Most Reliable)
Agents read/write shared files. No direct messaging needed.
- Agent A writes `output-a.md`
- Agent B reads `output-a.md` as input
- Works across subagents, teams, and sessions

### Task-Based (Agent Teams Only)
Shared task list with status tracking.
- Lead creates tasks
- Workers self-assign
- Status visible to all teammates
- NOT available for regular subagents

### Sequential Chaining (Subagents)
Main conversation chains subagents:
1. Dispatch Agent A → wait for result
2. Use result to inform Agent B dispatch → wait for result
3. Synthesize both results

### Parallel Dispatch (Independent Work)
```markdown
When tasks have NO dependencies and NO shared files:
- Dispatch all specialists in a single message
- Each gets clear, complete instructions
- Each owns distinct files
- Main thread synthesizes results after all complete
```

---

## Agent Error Handling

### Common Failure Modes
- Context overflow: agent runs out of context mid-task
- Tool errors: file not found, build failures, permission denied
- Hallucination: agent invents files or patterns that don't exist
- Silent failure: agent claims success without verifying

### Orchestrator Recovery
1. Check agent output for error indicators ("not found", "failed", empty result)
2. If agent failed: provide more context and retry ONCE
3. If retry fails: surface error to user with agent's output
4. Never silently swallow agent failures

### Prevention
- Include verification steps in every agent prompt
- Set maxTurns to prevent runaway agents
- Include "if unsure, say so" in agent instructions

---

## Agent Teams (Multi-Session Coordination)

Agent Teams allow multiple independent Claude sessions to coordinate on parallel work.
Unlike subagents (which run within the main conversation), team members are full sessions
with their own context, tool access, and user interaction.

### When to Use Teams vs Subagents
| Criteria | Subagents | Agent Teams |
|----------|-----------|-------------|
| Task scope | Focused, single-purpose | Complex, multi-faceted |
| Context needs | <50% of window | Full window per member |
| Coordination | Sequential/parallel dispatch | Shared task list, messaging |
| Token cost | 4-7x standard | ~15x standard |
| Isolation | Shared repo (or worktree) | Each member can use worktree |

### When NOT to Use Teams
- Simple tasks that a single subagent can handle
- Cost-sensitive workflows (15x token multiplier)
- Tasks requiring tight sequential coordination

---

## Invocation Quality (Critical)

Most subagent failures come from poor invocations, not execution failures.

### Bad Invocation
```
"Fix the Division service"
```

### Good Invocation
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

### Invocation Checklist
Every subagent dispatch should include:
- [ ] Specific file paths
- [ ] Expected behavior / success criteria
- [ ] Reference files for pattern matching
- [ ] Build/test command to verify
- [ ] What to do if something unexpected is found

---

## Turn-Efficient Agent Design

Turn count is the second cost axis after token size. Each turn re-reads the
entire conversation prefix, so turn reduction and token compression are
multiplicative. These patterns apply to both Claude Code subagents and
Agent SDK orchestrator jobs (e.g., Tof Orchestrator cron pipelines).

### Pre-Computed Context in Invocations

Every tool call an agent makes to "discover" context the orchestrator already
has is a wasted turn. Front-load it in the dispatch:

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

For **orchestrator pipelines** (Agent SDK / Tof Orchestrator):
- Use `pre_commands` to compute data before agent starts → inject via context
- Use `include_files` for static references → agent never needs to Read them
- Pipeline stage outputs should be structured (YAML) and injected directly
- Rule: if the orchestrator can compute it, don't make the agent discover it

### Scope Locks in Agent Prompts

Models overbuild, triggering generate → simplify loops. Include scope locks
in every code-writing agent:

```markdown
## Scope Lock
- Implement ONLY what's specified — no extras
- Do NOT refactor adjacent code
- Do NOT add abstractions for one-time operations
- MINIMAL change that satisfies the spec
```

### Verify-and-Fix Containment

Agents should self-fix rather than report errors back to orchestrator:

```markdown
## Self-Fix Protocol
After changes, run build/test. If failure:
1. Read error → fix in same turn → rebuild
2. Up to 3 fix attempts
3. Only report if still failing after 3 attempts
```

This prevents the costly: agent fails → orchestrator retries → agent fixes →
orchestrator validates cycle (4+ turns → 1 turn).

### Search Batching for Research Agents

Research-heavy agents (trend scouts, article researchers, QC with web checks)
should plan all searches upfront:

```markdown
## Research Protocol
1. Identify ALL information needs before searching
2. Execute all WebSearch calls in ONE message (parallel)
3. After receiving results, identify specific gaps
4. At most ONE follow-up batch
5. Maximum 2 search rounds total
```

For **pipeline jobs**: cap web searches per job in the instruction file.
Example: "Maximum 5 WebSearch calls for competitive sweep. If key_facts >= 5
from prior research, skip competitive sweep entirely."

### Tool Call Batching Instruction

Include in every agent that uses multiple tools. Use the XML-tagged variant
for stronger compliance (Anthropic-recommended pattern):

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

The `<use_parallel_tool_calls>` XML tag is a behavioral anchor — Claude
treats content inside named XML blocks as stronger instructions than plain
markdown headers. This is the official Anthropic recommendation for
maximizing parallel tool use.

### Agent SDK: Tool Result Formatting (Critical for Parallelism)

When building API-based agents (Agent SDK, custom orchestrators), how you
format tool results in conversation history **directly affects** whether
Claude continues to use parallel tool calls.

**Rule:** All tool results from a parallel batch MUST go in a **single**
user message. Splitting them into separate messages actively trains the
model away from parallelism.

❌ **WRONG** — separate messages teach Claude to avoid parallel calls:
```json
[
  {"role": "assistant", "content": ["tool_use_1", "tool_use_2"]},
  {"role": "user", "content": ["tool_result_1"]},
  {"role": "user", "content": ["tool_result_2"]}
]
```

✅ **CORRECT** — single message maintains parallel behavior:
```json
[
  {"role": "assistant", "content": ["tool_use_1", "tool_use_2"]},
  {"role": "user", "content": ["tool_result_1", "tool_result_2"]}
]
```

Additional formatting rules:
- Do NOT insert text blocks before tool_result blocks in the content array
- Every `tool_use` must have a matching `tool_result` with the same `tool_use_id`
- For pipeline jobs: your tool execution layer must collect all results
  before sending the next message — never stream partial results back

### Meta-Tools / Pre-Commands for Predictable Sequences

When agents consistently perform the same tool sequence, extract it:

| Pattern | Solution |
|---------|----------|
| Agent greps for compliance rules → reads them → applies | pre_command runs compliance check, injects result |
| Agent reads DB → filters → processes | pre_command runs SQL query, injects filtered data |
| Agent reads 3 files to learn pattern | Inline pattern example in prompt |
| Agent searches web for same reference each run | Cache result, inject as include_file |

Rule: if a sequence appears in >50% of runs, make it a pre_command or
include_file instead.

### Turn Budget Guidelines (Pipeline Jobs)

For Agent SDK orchestrator jobs, set expectations in the instruction file.
Not a hard `maxTurns` (article writing isn't deterministic), but explicit
guidance on efficiency:

```markdown
## Efficiency Expectations
- Research phase: batch all searches (aim for 2 search rounds max)
- Writing phase: produce complete draft in 1-2 turns
- Verification phase: self-fix up to 3 attempts before reporting
- Total: minimize turns. Every tool call should have clear purpose.
```

For **mechanical jobs** (metadata, uploads, routing): these CAN use hard
`maxTurns` (5-10) since their behavior IS deterministic.

---

## Agent File Size Guidelines

| Lines | Assessment | Action |
|-------|-----------|--------|
| <100 | Too sparse | May lack context for reliable generation |
| 100-300 | Ideal | Focused, sufficient context |
| 300-500 | Acceptable | For complex projects with many component types |
| 500+ | Consider splitting | Break into agent + reference files |

For agents >300 lines, use the reference file pattern:
```
.claude/agents/code-writer-dotnet.md          # Core logic (200 lines)
.claude/agents/references/dotnet-patterns.md   # Detailed examples (300 lines)
```
Agent reads references on demand rather than having everything in the system prompt.

### Token Efficiency in Agent Files

Agent .md files are system prompts — Claude is the only reader.
Write in compressed telegraphic notation (see `techniques/prompt-engineering.md` → Token Optimization):
- Strip articles/filler; use symbols (→ | + ~); key:value over sentences
- Exception: code examples + few-shot patterns → keep full fidelity
- Impact: 30-50% smaller agent prompts = faster subagent startup + lower token cost
- Each subagent loads its full .md file into its own context window — savings multiply by invocation count

---

## See Also
- `techniques/prompt-engineering.md` — RCCF framework (required for all agents)
- `techniques/anti-hallucination.md` — verification patterns (required in all agents)

## Sources
- Claude Code Docs: sub-agents, agent-teams, tools-reference
- claudefa.st: sub-agent best practices
- OpenDev Paper (arxiv 2603.05344)
- Anthropic: Building Effective AI Agents
- lst97/claude-code-sub-agents (resource metrics)
- wshobson/agents (large-scale agent architecture)
