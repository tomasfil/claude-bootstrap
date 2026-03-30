# Prompt Engineering Techniques Reference

> Referenced by bootstrap modules and generated agents/skills. Apply these patterns when creating any LLM instruction file.

---

## RCCF Framework

Every agent/skill file should be structured with these four components:

### Role
Define WHO the agent is. Be specific — expertise area, seniority, mindset.
```markdown
<role>
You are a senior {language} engineer specializing in {framework}
with deep knowledge of {key_patterns}.
</role>
```

### Context
Ground the agent in WHAT it's working with. Reference real project state.
```markdown
<context>
This project uses:
- {framework} {version} with {architecture_pattern}
- {data_layer} with {database}, {configuration_approach}
- {error_handling_pattern} for business logic errors
- {service_abstraction} for all data access
</context>
```

### Constraints
Define boundaries — what NOT to do is as important as what to do.
```markdown
<constraints>
- NEVER {common_anti_pattern} — always use {correct_pattern}
- NEVER {unsafe_operation} — managed by {automation_layer}
- Max function length: {max_lines} lines. Split if longer.
- Prefer {preferred_style} over {discouraged_style}
</constraints>
```

### Format
Specify expected output structure — reduces hallucination by constraining generation.
```markdown
<format>
For each new {component_type}, generate:
1. {file_type_1} in {directory_1}: `{naming_convention_1}`
2. {file_type_2} in {directory_2}: `{naming_convention_2}`
3. {file_type_3} in {directory_3}: `{naming_convention_3}`
Each file must follow {file_convention}.
</format>
```

---

## Structured Output Patterns

### Classification Trees
Use decision trees for component-type routing. Structure as nested conditions:

```markdown
## Component Classification

Determine component type BEFORE writing code:

1. **Is it a {data_component}?** → {Data Pattern}
   - New → Create {data_artifact_1} + {data_artifact_2} + {data_artifact_3}
   - Modify → Update {data_artifact_1} + {data_artifact_3}

2. **Is it a {handler_component}?** → {Handler Pattern}
   - Standard operation → Use {base_class} + {standard_template}
   - Custom operation → Use {custom_approach}

3. **Is it a {service_component}?** → {Service Pattern}
   - Simple (single dependency) → Type A: {simple_strategy}
   - Complex (multiple deps) → Type B: {complex_strategy}
   - Extends base → Type C: {inherited_strategy}
```

### Enum-Based Routing
When a decision maps to a finite set of options, enumerate them:

```markdown
Determine the {decision_category}:
- `{option_a}` → Use for {scenario_a} ({action_a})
- `{option_b}` → Use for {scenario_b} ({action_b})
- `{option_c}` → Use for {scenario_c} ({action_c})
```

---

## Chain-of-Thought Prompting

For complex reasoning tasks, instruct the agent to think step-by-step:
- "Before implementing, list the files that will be affected and why"
- "Think through edge cases before writing the code"
- "Explain your approach before starting"

When to use: multi-file changes, architectural decisions, debugging
When NOT to use: simple lookups, single-file edits, formatting

---

## Positive vs Negative Rules

Negative rules ("DO NOT...") are weaker at high context depth — the model
may ignore them when they're far from the active focus area.

| Use Case | Framing | Example |
|----------|---------|---------|
| Critical safety constraint | Negative (top of prompt) | "NEVER inject DbContext directly" |
| Style preference | Positive | "Prefer guard clauses over nested if-else" |
| Convention guidance | Positive | "Use collection expressions instead of .ToList()" |
| Security boundary | Negative (top of prompt) | "DO NOT commit secrets or credentials" |

Rule of thumb: Reserve "NEVER/DO NOT" for safety-critical constraints placed at the top
of the instruction. Use "Prefer X over Y" for everything else.

---

## Few-Shot Examples

### When to Use
- Component types the agent will generate repeatedly
- Patterns that are project-specific and non-obvious
- Conventions that differ from framework defaults

### Template
```markdown
### Example: {task_description}

**Input:** "{natural_language_request}"

**Output:**
- File: `{output_file_path}`
- Pattern followed: {pattern_name} from {reference_file}
- Key decisions: {why_this_approach}

{code block in project language showing the generated output}
```

Provide 1-2 examples per component type the agent generates frequently.

---

## Context Caching Layout

Order content for optimal prompt caching:

1. **Static content first** (cached across calls):
   - System instructions / role definition
   - Tool definitions
   - Few-shot examples
   - Code standards / rules

2. **Semi-static content** (cached per session):
   - Project architecture description
   - Component classification tree
   - Pipeline trace map

3. **Variable content last** (never cached):
   - Current task description
   - User's specific request
   - Session state / conversation history

---

## Front-Loading and Recency

### Primacy Effect
Place the most critical rules in the FIRST section of any prompt:
- Safety constraints
- Anti-hallucination instructions
- "Read before write" mandate

### Recency Effect
Repeat critical rules at the END:
- Verification checklist
- "Did you verify all imports exist?"
- "Did you run the build?"

### The Middle
Less critical but still important content:
- Detailed patterns and examples
- Edge case handling
- Optional conventions

---

## Taxonomy-Guided Prompting

For complex decisions, provide a hierarchical taxonomy:

```markdown
## Decision Taxonomy

### Level 1: What layer?
├── {Layer A} → go to Level 2A
├── {Layer B} → go to Level 2B
├── {Layer C} → go to Level 2C
└── {Layer D} → go to Level 2D

### Level 2A: {Layer A} — What operation?
├── New {component} → {artifact_1} + {artifact_2} + {artifact_3}
├── Modify {component} → {artifact_3} + update {artifact_2} if needed
├── New {relationship} → Both {configurations} + {artifact_3}
└── {Optimization} → Add {optimization_artifact}

### Level 2B: {Layer B} — What type?
├── CRUD → Extend {base_class}
├── Business logic → Standalone with {service_abstraction}
├── External integration → Wrapper with {http_client}
└── Event handler → {event_handler_interface}
```

---

## Token Optimization

Techniques for reducing token cost. Three levers: compress what you send,
cache what repeats, architect pipelines to minimize redundancy.

### Writing Style: Claude-Facing vs Human-Facing

All content consumed by Claude (CLAUDE.md, rules, skills, agents, memory files,
cron job prompts, shared reference docs) should use compressed telegraphic notation.
Only conversation output, commits, PRs, and user-facing docs stay in natural prose.

**Compression techniques (apply to all Claude-facing files):**
- Strip articles (a, an, the), filler words, unnecessary prepositions → 15-30% savings
- Use symbols: → (then/results in) | (or) + (and) ~ (approx) × (times) w/ (with)
- Key:value + bullet lists over prose paragraphs
- Merge short related rules onto single lines w/ `;` separators
- Abbreviate repeated terms; define legend at file top
- Restructure prose → structured format → up to 70% savings

**Example:**
```markdown
# Before (38 tokens)
You should always make sure to verify that the sources you are
citing actually exist and are accessible before including them.

# After (14 tokens)
Verify cited sources exist + accessible before including.
```

**Quality thresholds for compression:**
- Code examples + few-shot patterns: keep full fidelity (quality cliff below 65%)
- Classification/routing instructions: very tolerant (5-10× compression safe)
- Chain-of-thought prompts: keep >80% tokens
- Reference docs (brand guidelines, style rules): 2-3× compression safe

### Format Selection

Data shape determines optimal format — not habit:

| Format | Savings vs JSON | Best For |
|--------|----------------|----------|
| Markdown | 16-38% fewer | Prose instructions, mixed content |
| YAML | 11-20% fewer | Hierarchical config, structured data |
| TOON | 30-60% fewer | Flat/tabular arrays, uniform records |
| TSV/CSV | Highest | Pure tabular, no nesting |

No universal winner. JSON is always the most verbose for structured data.
Default to YAML or Markdown unless the consumer explicitly needs JSON.

**JSON replacement guidance:**
- Config consumed only by Claude → YAML (11-20% savings, identical semantics)
- Inter-stage pipeline data → YAML (Claude reads both equally well)
- Data with arrays of uniform objects → TSV or TOON (30-60% savings)
- Tooling-mandated JSON (settings.json, package.json, tsconfig.json) → keep JSON
- Code-consumed JSON where runtime supports YAML → migrate gradually via TDD:
  1. Check if runtime has YAML support (js-yaml for TS/Node, PyYAML for Python, etc.)
  2. Write failing test expecting YAML input → make it pass → convert data file
  3. Migrate one file at a time; keep JSON schema as validation reference during transition
  4. Priority: largest files first (most token savings per migration)

Rule: if the only consumer is Claude, JSON is never the right format.
If the consumer is code that *can* handle YAML, plan a gradual TDD-driven migration.

### Manual Compression

When prompts are agent-consumed (include files, reference docs, system
instructions), human readability is optional. Compress aggressively:

**Strip filler** (15-30% savings):
```markdown
# Before (38 tokens)
You should always make sure to verify that the sources you are
citing actually exist and are accessible before including them.

# After (14 tokens)
Verify all cited sources exist & accessible before including.
```

**Abbreviate repeated keys** — define legend once, use codes:
```markdown
## Legend: S=source R=reliability(1-5) T=type(pri|sec|opinion)
- S:reuters.com R:5 T:pri
- S:blog.example R:2 T:opinion
```

**Symbol substitution**: `->` results in, `|` separator, `&` and,
`~` approximately, `=>` therefore, `!` negation/never.

**Restructure prose -> structured** (up to 70% savings):
```markdown
# Before
When you encounter a topic that has legal implications, you need to
be very careful about making definitive claims. Instead, you should
use hedging language and cite specific legal sources.

# After
Legal topics:
- Hedge all claims, cite legal sources
- Ongoing cases -> require source, no unsourced claims
```

### Shared Reference Compression

For pipelines loading shared files across multiple jobs:

1. **Compress shared docs once** — rewrite reference files in telegram-style.
   15K doc compressed 30% = 4,500 tokens saved per job.
   At 20 jobs/day = 90K tokens/day from one file.

2. **Tier includes by job type** — not every job needs every file.
   Create slim/full variants:
   - `brand-guidelines-slim.md` (~3K) for triage/routing jobs
   - `brand-guidelines-full.md` (~10K) for writer/QC jobs

3. **Deduplicate includes** — if preamble AND include_files load the
   same file, it's sent twice. Deduplicate at orchestrator level.

4. **Merge small files** — 5 files x 500 tokens each have wrapping
   overhead (headers, fences). One 2,500-token merged file is cheaper.

### Compression Quality Thresholds

| Task Type | Safe Compression | Behavior Under Compression |
|-----------|-----------------|---------------------------|
| RAG / document QA | Up to 4-6x | Often *improves* (noise removal) |
| Article writing | Keep >80% | Gradual quality decline |
| Code generation | Keep >65% | Sharp cliff below threshold |
| Chain-of-thought | Keep >80% | Linear decline, no cliff |
| Classification / routing | Up to 5-10x | Very tolerant |

Rule of thumb: start at 2-3x, measure quality, increase only if it holds.
Code generation has a hard cliff at 55-65% retention — below this, output
collapses abruptly.

### Algorithmic Compression

For programmatic compression of large variable contexts (RAG chunks,
research outputs, inter-stage data):

| Method | Compression | Quality | Requirements |
|--------|------------|---------|--------------|
| LLMLingua-2 | 4-6x | 95-98% retained | Python, XLM-RoBERTa |
| LongLLMLingua | 4-6x | Often improves QA | Best for 10k+ contexts |
| CompactPrompt | ~60% reduction | <5% loss | Production pipeline |

Best fit: compress variable per-request content (research results, trend
data) before injection. Static reference files -> manual compression
(one-time effort, no tooling dependency).

---

## Prompt Caching Economics

### Pricing

| Model | Input | Cache Write (5m TTL) | Cache Write (1h TTL) | Cache Read |
|-------|-------|---------------------|---------------------|------------|
| Sonnet 4.6 | $3.00/M | $3.75/M (1.25x) | $6.00/M (2x) | $0.30/M (0.1x) |
| Opus 4.6 | $5.00/M | $6.25/M (1.25x) | $10.00/M (2x) | $0.50/M (0.1x) |
| Haiku 4.5 | $0.80/M | $1.00/M (1.25x) | $1.60/M (2x) | $0.08/M (0.1x) |

Cache read is **10x cheaper** than uncached input. Cache write is 1.25x.
Break-even: 2+ reads per write = net savings.

### TTL Behavior

- **5-minute default TTL** — refreshes on every cache hit
- **1-hour extended TTL** — 2x write cost, refreshes on hit
- Cache is keyed on **exact byte-identical prefix**, not session ID
- Cross-session: if Job B starts within TTL of Job A with identical
  prefix, Job B gets cache hits
- **Cache-busting**: adding MCP tools, timestamps in system prompt,
  or switching models mid-session invalidates entire cache

### Cross-Session Cache Math

Example: 6 sequential jobs, 20K shared context, Sonnet 4.6:

**Cache hits (all jobs within 5-min TTL)**:
```
Job 1: 20K × $3.75/M = $0.075  (cache write)
Jobs 2-6: 5 × 20K × $0.30/M = $0.030  (cache read)
Total: $0.105
```

**Cache misses (TTL expired between jobs)**:
```
6 × 20K × $3.00/M = $0.360  (uncached)
Total: $0.360  (3.4x more expensive)
```

**Implication for sequential pipelines**: keep inter-job gaps under 5 min
to maintain cache. If orchestrator has scheduling gaps, use 1-hour TTL
for shared prefixes.

### Cache + Compress Stack

Use both — they target different content:

| Strategy | Target | Savings | Quality Impact |
|----------|--------|---------|---------------|
| Prompt caching | Static prefix (preamble, includes) | 90% off reads | Zero |
| Manual compression | Reference docs, guidelines | 15-40% fewer tokens | Minimal |
| Format optimization | Structured data payloads | 20-60% fewer tokens | Zero to positive |
| Algorithmic compression | Variable contexts (research, data) | 50-80% fewer tokens | 2-5% typical loss |

Combined: **50-70% total cost reduction** reported by production teams.

Optimal prompt ordering for cache + compress:
```
[CACHED — identical across all jobs]
  System prompt (compressed)
  Shared reference files (compressed, merged)
[CACHED — identical per job type]
  Job-type-specific includes
[NOT CACHED — variable per run]
  Pre-command outputs (format-optimized)
  Prior stage results (algorithmically compressed if large)
  Task-specific instructions
```

---

## Pipeline Architecture: Multi-Session vs Single-Session

### The Trade-Off

For multi-phase content pipelines (research -> write -> QC -> style ->
images -> publish), two architecture options exist:

| Factor | Separate Sessions (current) | Single Orchestrator + Subagents |
|--------|---------------------------|-------------------------------|
| **Reliability** | Isolated failures, each phase starts clean | One failure can cascade; subagent silent failures |
| **QC effectiveness** | Fresh context = independent verification | Shared context = confirmation bias risk |
| **Cache cost** | Cache write per session (mitigated by TTL) | Cache write once, reads throughout |
| **Context window** | Full window per phase | Shared window, risk of filling on long pipelines |
| **Token overhead** | Redundant include loading | ~15x overhead for multi-agent coordination |
| **Parallelism** | Fully independent | Subagents can parallelize within session |

### When Separate Sessions Win

- **Quality-critical sequential pipelines** — QC must independently verify
  writer output. Fresh context prevents confirmation bias where the model
  "remembers" its own reasoning and fails to catch its own errors.
- **Reliability-sensitive content** — web articles, public-facing content
  where errors are costly. Isolated failures don't cascade.
- **Phase outputs feed next phase** — each phase writes structured output
  (JSON/files), next phase reads it fresh. Clean data contract.

### When Single Session Wins

- **Parallel independent tasks** — image sourcing + style lint can run
  simultaneously as subagents within one session
- **Short pipelines** (2-3 phases) where context window isn't a concern
- **Exploratory/research tasks** where shared context improves quality
- **Cost-dominated scenarios** where cache savings outweigh reliability risk

### Recommendation for Content Pipelines

**Keep separate sessions for the core pipeline.** The QC independence is
worth more than the cache savings. A style lint that catches issues because
it evaluates the article fresh (without the writer's reasoning polluting
context) is the whole point of multi-layer QC.

**Optimize within the separate-session architecture:**
1. Compress shared reference files (one-time effort, permanent savings)
2. Keep inter-job scheduling gaps <5 min for cache TTL reuse
3. Tier includes — triage/routing jobs get slim files, writer/QC get full
4. Format-optimize inter-stage data (research output -> YAML not verbose JSON)
5. Use 1-hour cache TTL if scheduling gaps are unpredictable

**Consider single-session only for parallelizable sub-tasks:**
- Image sourcing + social media draft can run as parallel subagents
- SEO metadata + schema markup generation in parallel
- These are independent tasks where shared context doesn't hurt quality

### Subagent Constraints (Claude Agent SDK)

- Subagents get **fresh context** — no parent conversation history
- Only data bridge: the task description string passed to Agent tool
- **One level deep** — subagents cannot spawn sub-subagents
- Each subagent can specify its own model (cost optimization)
- Dominant failure mode: **silent wrong output** (plausible but incorrect),
  not crashes. Harder to detect than clean errors.

### Sources — Token Optimization & Pipeline Architecture
- LLMLingua / LLMLingua-2: Microsoft Research (EMNLP 2023, ACL 2024)
- LongLLMLingua: ACL 2024
- CompactPrompt: arXiv 2025
- TOON format: toonformat.dev
- Compression quality thresholds: NAACL 2025 survey (Li et al.)
- Prompt caching: Anthropic docs, Claude Code Camp analysis
- Cache pricing: Anthropic pricing page (2026)
- Multi-agent trade-offs: Anthropic engineering blog
- Agent SDK subagents: Anthropic Agent SDK docs
- GSD Framework: MindStudio / The New Stack
- Multi-agent failure modes: arXiv 2503.13657

---

## Turn Optimization

Turns are the second cost axis after tokens. Each turn re-reads the entire
conversation prefix — so fewer turns = fewer re-sent tokens = multiplicative
savings with compression. A 30% token compression + 40% turn reduction ≈ 58%
total cost reduction.

### Tool Call Batching

When multiple tool calls have NO data dependencies, issue ALL in a single
response. Infrastructure executes concurrently; latency = slowest call, not sum.

**Prompt instruction template (include in agents that use tools):**

```markdown
## Parallel Execution Rule
When multiple tool calls have no data dependencies, issue ALL in one response.

Parallelizable:
- Reading multiple files → one message, multiple Read calls
- Searching different patterns → one message, multiple Grep/WebSearch calls
- Dispatching independent subagents → one message, multiple Agent calls

NOT parallelizable (must be sequential):
- Read file → edit it (edit depends on read content)
- Search → read found file (read depends on search result)

NEVER do: Read file A → respond → Read file B → respond → Read file C
INSTEAD: Read file A + Read file B + Read file C → respond once
```

### Search Planning Protocol

**The anti-pattern:** search → read result → realize you need another search →
search again → read → repeat. Each cycle = 2 wasted turns.

**The fix — plan all queries upfront:**

```markdown
## Search Planning
Before executing ANY web search:
1. Identify ALL information needs from the task
2. Formulate ALL search queries at once
3. Execute all searches in parallel (single message, multiple WebSearch calls)
4. Synthesize all results together
5. Follow-up searches ONLY for specific identified gaps
6. Maximum 2 search rounds total

NEVER do iterative search-read-search loops. Plan first, execute in batch.
```

Best fit: research agents, trend scouts, competitive analysis jobs. Anthropic's
own multi-agent research system uses this pattern — lead agent plans research,
spawns parallel searchers, condenses results.

### Pre-Computed Context Injection

Every tool call an agent makes to "discover" something the orchestrator already
knows is a wasted turn. Front-load known context into the prompt.

**Patterns:**

**a) File maps — eliminate directory exploration:**
```markdown
## Project Map (pre-loaded — do NOT search for these)
- Endpoints: src/Api/Endpoints/{Entity}/
- Services: src/Services/Data/{Entity}/
- Configs: src/Data/Configurations/
- Tests: tests/Unit/{Layer}.Tests/
```

**b) Pattern examples inline — eliminate "read similar files" turns:**
```markdown
## Pattern: New Endpoint (follow exactly, do NOT read other endpoints)
public class Get{Entity}Endpoint : Endpoint<Get{Entity}Request, Get{Entity}Response> { ... }
```

**c) Pre-made decisions — eliminate deliberation turns:**
```markdown
## Decisions (pre-made — do not deliberate)
- ORM: EF Core, AsNoTracking for reads
- Validation: FluentValidation, one validator per endpoint
- Error handling: ProblemDetails, never throw from services
```

**d) Pipeline stage outputs — inject what prior stages produced:**
```markdown
## Input from Prior Stage (already computed)
{structured data from previous pipeline job — YAML/JSON}
Do NOT re-derive this data. Use as-is.
```

**Anti-pattern:** Never instruct an agent to "explore the codebase" or
"familiarize yourself." Every exploration step is a wasted turn.
Give it the map instead.

### Scope Locks (Anti-Overengineering)

Models tend to overbuild, triggering generate → realize it's too much → simplify
loops. Constrain scope to prevent this:

```markdown
## Scope Lock
- Do NOT add abstractions not explicitly requested
- Do NOT refactor adjacent code
- Do NOT add error handling beyond what's specified
- Do NOT add comments, docstrings, or type annotations to unchanged code
- Make the MINIMAL change that satisfies the spec
- Three similar lines > premature abstraction
```

### Verify-and-Fix Containment

Keep fix loops inside the agent turn rather than bouncing back to orchestrator:

```markdown
## Self-Fix Protocol
After implementation, run build/test command.
If it fails:
1. Read error output carefully
2. Fix ALL errors in the SAME turn
3. Re-run build/test
4. Repeat up to 3 attempts
5. If still failing after 3 → report errors with diagnosis

Do NOT report build failures and wait. Fix them yourself first.
```

This eliminates the common pattern of: agent reports error → orchestrator
re-dispatches → agent fixes → reports → orchestrator validates. Instead: agent
fixes internally, returns clean result.

### Plan-Then-Act Separation

For multi-step tasks, explicit mode separation prevents false starts:

```markdown
## Protocol
Phase 1 (PLAN): List every file to read/create/modify. List every command
to run. Do NOT execute anything yet.
Phase 2 (ACT): Execute the plan. Do not deviate unless blocking error.
```

Prevents: read file → realize wrong approach → start over → read different
files. The planning phase catches these before any tool calls.

### Meta-Tools for Predictable Sequences

When agents consistently perform the same tool sequence (e.g., grep → read →
edit), consider creating a composite tool or pre_command that handles the entire
sequence. This eliminates intermediate LLM reasoning steps.

**Pipeline examples:**
- `check-brand-compliance` as a pre_command instead of in-agent tool calls
- `find-and-update` script instead of grep → read → edit cycles
- Research data pre-fetched via pre_commands, injected into context

Rule: if a tool sequence appears in >50% of runs, it's a candidate for a
composite tool or pre_command.

### Turn Reduction Checklist

| Technique | Turn Savings | Where to Apply |
|-----------|-------------|----------------|
| Parallel tool calls | 2-5× per batch | All tool-using agents |
| Search query planning | 50-70% fewer search turns | Research agents, scouts |
| Pre-computed context injection | Eliminates discovery turns | All agent invocations |
| Inline few-shot examples | Fewer correction loops | Code writers, content writers |
| Exhaustive task specs | 1-3 fewer rounds | Orchestrator → agent dispatch |
| Scope locks | Prevents generate-then-simplify | Code writers |
| Verify-and-fix containment | Keeps fixes internal | All agents with build/test |
| Plan-then-act separation | Prevents false starts | Multi-file changes |
| Meta-tools / pre_commands | Eliminates intermediate reasoning | Predictable sequences |

### Sources — Turn Optimization
- Anthropic: Writing effective tools for AI agents (2025)
- Anthropic: Effective context engineering for AI agents (2025)
- Anthropic: Multi-agent research system (2025)
- AWO Meta-tools: arXiv 2601.22037
- PASTE speculative execution: arXiv 2603.18897
- AgentDiet trajectory reduction: arXiv 2509.23586
- Efficient Agents: arXiv 2508.02694

---

## See Also
- `techniques/anti-hallucination.md` — verification patterns for every agent
- `techniques/agent-design.md` — agent YAML templates and dispatch patterns

## Sources
- RCCF Framework: Internal framework — Role, Context, Constraints, Format
- Structured outputs: General pattern — multiple sources
- Context caching: Anthropic Prompt Caching docs
- Taxonomy-guided: General pattern — multiple sources
- Few-shot patterns: General pattern — multiple sources
- Front-loading: General pattern — multiple sources
