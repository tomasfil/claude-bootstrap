# Prompt Engineering Techniques Reference

---
type: research-knowledge
status: curated-starting-point
warning: >
  Patterns are researched best practices — NOT project-verified truths.
  Validate against current project state before applying.
see-also:
  - techniques/anti-hallucination.md — verification patterns for every agent
  - techniques/agent-design.md — agent constraints, orchestrator patterns, YAML templates
---

> **Cross-references:**
> - Tool call batching, search planning, pre-computed context → canonical in `techniques/agent-design.md`
> - Scope locks, verify-and-fix containment → canonical HERE (Turn Optimization)
> - Verification patterns → `techniques/anti-hallucination.md`

---

## RCCF Framework

Structure every agent/skill w/ four components:

**Role** — WHO: expertise, seniority, mindset.
```markdown
<role>
You are a senior {language} engineer specializing in {framework}
with deep knowledge of {key_patterns}.
</role>
```
**Context** — WHAT: ground in real project state.
```markdown
<context>
This project uses:
- {framework} {version} with {architecture_pattern}
- {data_layer} with {database}, {configuration_approach}
- {error_handling_pattern} for business logic errors
- {service_abstraction} for all data access
</context>
```
**Constraints** — BOUNDARIES: what NOT to do matters equally.
```markdown
<constraints>
- NEVER {common_anti_pattern} — always use {correct_pattern}
- NEVER {unsafe_operation} — managed by {automation_layer}
- Max function length: {max_lines} lines. Split if longer.
- Prefer {preferred_style} over {discouraged_style}
</constraints>
```
**Format** — OUTPUT: constrains generation, reduces hallucination.
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

**Classification Trees** — decision trees for component-type routing:
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

**Enum-Based Routing** — finite decision sets:
```markdown
Determine the {decision_category}:
- `{option_a}` → Use for {scenario_a} ({action_a})
- `{option_b}` → Use for {scenario_b} ({action_b})
- `{option_c}` → Use for {scenario_c} ({action_c})
```

---

## Chain-of-Thought Prompting

Instruct step-by-step for complex reasoning: "list affected files + why", "think through edge cases", "explain approach before starting"
- Use: multi-file changes, architecture decisions, debugging
- Skip: simple lookups, single-file edits, formatting

---

## Positive vs Negative Rules

Negative rules weaker at high context depth — model may ignore when far from focus.

| Use Case | Framing | Example |
|----------|---------|---------|
| Critical safety constraint | Negative (top of prompt) | "NEVER inject DbContext directly" |
| Style preference | Positive | "Prefer guard clauses over nested if-else" |
| Convention guidance | Positive | "Use collection expressions instead of .ToList()" |
| Security boundary | Negative (top of prompt) | "DO NOT commit secrets or credentials" |

Reserve NEVER/DO NOT for safety-critical at prompt top; "Prefer X over Y" for rest.

---

## Few-Shot Examples

Use for: repeatedly-generated components, project-specific non-obvious patterns, conventions differing from defaults. Provide 1-2 per frequently-generated type.
```markdown
### Example: {task_description}
**Input:** "{natural_language_request}"
**Output:**
- File: `{output_file_path}`
- Pattern followed: {pattern_name} from {reference_file}
- Key decisions: {why_this_approach}
{code block in project language showing the generated output}
```

---

## Context Caching Layout

1. **Static first** (cached across calls): system instructions, tool defs, few-shot, code standards
2. **Semi-static** (cached per session): architecture, classification tree, pipeline trace
3. **Variable last** (never cached): current task, user request, conversation history

---

## Front-Loading + Recency

**Primacy** (first): safety constraints, anti-hallucination, read-before-write
**Middle**: detailed patterns, examples, edge cases, optional conventions
**Recency** (last): verification checklist, "verify imports?", "run build?"

---

## Taxonomy-Guided Prompting

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

Three levers: compress sent content, cache repeats, architect pipelines minimizing redundancy.

### Claude-Facing vs Human-Facing

Claude-consumed content (CLAUDE.md, rules, skills, agents, memory, refs) → compressed telegraphic. Only conversation output, commits, PRs, user-facing docs stay prose.

Techniques: strip articles/filler → 15-30% savings; symbols (→ | + ~ × w/); key:value + bullets over prose; merge short rules w/ `;`; abbreviate repeated terms w/ legend; restructure prose → structured → up to 70% savings.
```markdown
# Before (38 tokens)
You should always make sure to verify that the sources you are
citing actually exist and are accessible before including them.

# After (14 tokens)
Verify cited sources exist + accessible before including.
```
**Conciseness**: Claude knows standard patterns. Only add: project-specific conventions, unusual constraints, non-obvious architecture. Test: "would Claude get this wrong unprompted?" If no → remove.

**Quality thresholds**: code examples + few-shot → full fidelity (cliff <65%); classification/routing → 5-10× safe; chain-of-thought → >80%; reference docs → 2-3× safe.

### Format Selection

| Format | Savings vs JSON | Best For |
|--------|----------------|----------|
| Markdown | 16-38% fewer | Prose instructions, mixed content |
| YAML | 11-20% fewer | Hierarchical config, structured data |
| TOON | 30-60% fewer | Flat/tabular arrays, uniform records |
| TSV/CSV | Highest | Pure tabular, no nesting |

Default YAML | Markdown unless consumer needs JSON. JSON replacement: Claude-only config → YAML; uniform arrays → TSV | TOON; tooling-mandated → keep JSON; code-consumed w/ YAML runtime → migrate via TDD (largest files first). Rule: Claude-only consumer → never JSON.

### Manual Compression

**Strip filler** (15-30%):
```markdown
# Before (38 tokens)
You should always make sure to verify that the sources you are
citing actually exist and are accessible before including them.

# After (14 tokens)
Verify all cited sources exist & accessible before including.
```
**Abbreviate repeated keys** — legend once:
```markdown
## Legend: S=source R=reliability(1-5) T=type(pri|sec|opinion)
- S:reuters.com R:5 T:pri
- S:blog.example R:2 T:opinion
```
**Restructure prose → structured** (up to 70%):
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

1. **Compress once** — 15K doc at 30% = 4,500 tokens saved/job; 20 jobs/day = 90K/day
2. **Tier includes** — slim (~3K) for triage; full (~10K) for writer/QC
3. **Deduplicate** — preamble + include_files loading same file = sent twice
4. **Merge small files** — 5 × 500 tokens w/ wrapping overhead → one 2,500-token file cheaper

### Compression Quality Thresholds

| Task Type | Safe Compression | Behavior Under Compression |
|-----------|-----------------|---------------------------|
| RAG / document QA | Up to 4-6x | Often *improves* (noise removal) |
| Article writing | Keep >80% | Gradual quality decline |
| Code generation | Keep >65% | Sharp cliff below threshold |
| Chain-of-thought | Keep >80% | Linear decline, no cliff |
| Classification / routing | Up to 5-10x | Very tolerant |

Start 2-3×, measure, increase if holds. Code generation: hard cliff 55-65%.

> For detailed compression rules and Claude-facing file optimization, see `techniques/token-efficiency.md`.

### Skill Description Optimization

Every skill `description:` field serves as API documentation for the LLM routing layer.
Claude Code natively loads descriptions via the Skill tool definition.

Rules:
- Start with "Use when..." trigger phrases
- Include key distinguishing keywords
- Keep under 2 lines
- Example: "Use when implementing features, writing code, or creating files. Routes to language-specific code-writer agents."

### Algorithmic Compression

For large variable contexts (RAG, research, inter-stage):

| Method | Compression | Quality | Requirements |
|--------|------------|---------|--------------|
| LLMLingua-2 | 4-6x | 95-98% retained | Python, XLM-RoBERTa |
| LongLLMLingua | 4-6x | Often improves QA | Best for 10k+ contexts |
| CompactPrompt | ~60% reduction | <5% loss | Production pipeline |

Variable per-request content → algorithmic. Static refs → manual (one-time, no deps).

---

## Prompt Caching Economics

### Pricing

| Model | Input | Cache Write (5m TTL) | Cache Write (1h TTL) | Cache Read |
|-------|-------|---------------------|---------------------|------------|
| Sonnet 4.6 | $3.00/M | $3.75/M (1.25x) | $6.00/M (2x) | $0.30/M (0.1x) |
| Opus 4.6 | $5.00/M | $6.25/M (1.25x) | $10.00/M (2x) | $0.50/M (0.1x) |
| Haiku 4.5 | $0.80/M | $1.00/M (1.25x) | $1.60/M (2x) | $0.08/M (0.1x) |

Cache read = **10x cheaper**. Write = 1.25×. Break-even: 2+ reads/write.

### TTL Behavior
- **5-min default** — refreshes on hit
- **1-hour extended** — 2× write cost, refreshes on hit
- Keyed on **exact byte-identical prefix**, not session ID
- Cross-session: Job B within TTL of Job A w/ identical prefix → cache hits
- **Cache-busting**: MCP tools, timestamps in system prompt, model switch → invalidates all

### Cross-Session Cache Math

6 sequential jobs, 20K shared context, Sonnet 4.6:
```
Cache hits (within 5-min TTL):
  Job 1: 20K × $3.75/M = $0.075  (write)
  Jobs 2-6: 5 × 20K × $0.30/M = $0.030  (read)
  Total: $0.105

Cache misses (TTL expired):
  6 × 20K × $3.00/M = $0.360  (3.4× more expensive)
```
Keep inter-job gaps <5 min | use 1-hour TTL if gaps unpredictable.

### Cache + Compress Stack

| Strategy | Target | Savings | Quality Impact |
|----------|--------|---------|---------------|
| Prompt caching | Static prefix (preamble, includes) | 90% off reads | Zero |
| Manual compression | Reference docs, guidelines | 15-40% fewer tokens | Minimal |
| Format optimization | Structured data payloads | 20-60% fewer tokens | Zero to positive |
| Algorithmic compression | Variable contexts (research, data) | 50-80% fewer tokens | 2-5% typical loss |

Combined: **50-70% total cost reduction**. Optimal ordering:
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

| Factor | Separate Sessions | Single Orchestrator + Subagents |
|--------|---------------------------|-------------------------------|
| **Reliability** | Isolated failures, clean starts | Cascade risk; silent subagent failures |
| **QC effectiveness** | Fresh context = independent verification | Shared context = confirmation bias |
| **Cache cost** | Write per session (mitigated by TTL) | Write once, reads throughout |
| **Context window** | Full window per phase | Shared, filling risk on long pipelines |
| **Token overhead** | Redundant include loading | ~15× multi-agent coordination |
| **Parallelism** | Fully independent | Subagents parallelize within session |

**Separate sessions win**: quality-critical sequential pipelines (QC independence), reliability-sensitive public content, phase-output-feeds-next-phase (clean data contracts).

**Single session wins**: parallel independent tasks, short pipelines (2-3 phases), exploratory/research, cost-dominated scenarios.

**Content pipeline recommendation**: keep separate sessions for core pipeline — QC independence > cache savings. Optimize within: compress shared refs, gaps <5 min for TTL, tier includes, format-optimize inter-stage → YAML. Single-session only for parallelizable sub-tasks (image sourcing + social draft, SEO + schema markup).

### Subagent Constraints (Claude Agent SDK)
- Fresh context (no parent history); only bridge = task description string
- One level deep — no sub-subagents; each specifies own model
- Dominant failure: **silent wrong output** (plausible but incorrect), not crashes

### Sources — Token Optimization & Pipeline Architecture
- LLMLingua / LLMLingua-2: Microsoft Research (EMNLP 2023, ACL 2024)
- LongLLMLingua: ACL 2024; CompactPrompt: arXiv 2025
- TOON format: toonformat.dev; Compression thresholds: NAACL 2025 (Li et al.)
- Prompt caching: Anthropic docs; Cache pricing: Anthropic (2026)
- Multi-agent: Anthropic engineering blog; Agent SDK: Anthropic docs
- GSD Framework: MindStudio / The New Stack; Failure modes: arXiv 2503.13657

---

## Turn Optimization

Second cost axis after tokens. Each turn re-reads entire conversation prefix → fewer turns = multiplicative savings w/ compression. 30% compression + 40% turn reduction ~ 58% total reduction.

→ See canonical: `techniques/agent-design.md` § Tool Call Batching Instruction

→ See canonical: `techniques/agent-design.md` § Search Batching for Research Agents

→ See canonical: `techniques/agent-design.md` § Pre-Computed Context

### Scope Locks (Anti-Overengineering)

Models overbuild → generate → simplify loops. Constrain:
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

Fix loops inside agent turn, not bouncing to orchestrator:
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

### Plan-Then-Act Separation

Explicit mode separation prevents false starts:
```markdown
## Protocol
Phase 1 (PLAN): List every file to read/create/modify. List every command
to run. Do NOT execute anything yet.
Phase 2 (ACT): Execute the plan. Do not deviate unless blocking error.
```

Plans should be split into separate task files — one per task/batch — so executing agents
receive focused context. Master plan = index + execution order. Task files are self-contained.

### Runtime Behavioral Steering (system-reminder)

Inject behavioral instructions into user messages at runtime — not system prompt.
Claude Code uses this internally for mid-session steering (conditional reminders).

Use when: behavior varies per invocation; system prompt fixed (CI harnesses, API pipelines).

```markdown
<system-reminder>
{conditional rule or constraint active for this invocation}
IMPORTANT: These instructions OVERRIDE any default behavior.
</system-reminder>
```

Injected in user message turn. Claude treats as high-priority.
Complements static system prompt (cacheable); does not replace it.

### Meta-Tools for Predictable Sequences

Same tool sequence in >50% of runs → composite tool | pre_command. Examples: `check-brand-compliance` as pre_command, `find-and-update` script, research pre-fetched via pre_commands.

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
- Anthropic: Writing effective tools (2025); Context engineering (2025); Multi-agent research (2025)
- AWO Meta-tools: arXiv 2601.22037; PASTE: arXiv 2603.18897
- AgentDiet: arXiv 2509.23586; Efficient Agents: arXiv 2508.02694

---

## Modern LLM Guidance (2025-2026) — applies to all major models

Modern instruction-tuned LLMs (Claude 4.x (and modern LLMs), GPT-4/5, Gemini 2.x, Llama 3.x+) trend toward **precise literal instruction following** vs older models. Less "helpful guessing", more explicit-scope requirement.

### LLM-General Rules (Claude, GPT, Gemini, open models)
1. **Be explicit** — modern models don't infer "helpful" additions; state requirements
2. **Structural delimiters** for sections — improves attention to boundaries on all models
3. **Positive framing** for style ("prefer X"); reserve NEVER/DO NOT for safety-critical + front-load
4. **Literal interpretation** — models take instructions at face value; pair negative rules w/ positive equivalent
5. **Request behaviors explicitly** vs trusting defaults
6. **Context-budget awareness** — hint long-running agents about remaining headroom
7. **Scope locks** for strong models — reduce overengineering tendency on high-capability tiers

### Compression Ranges per File Type (LLM-general, verified across Claude + GPT research)
| File Type | Safe Range | Source |
|-----------|-----------|--------|
| agent definition | 30-50% compression | telegraphic bullets, tokenizer-neutral |
| skill (procedural) | 40-60% | classification/routing tolerates 5-10× (NAACL 2025) |
| system prompt | 20-35% max | code-gen cliff <65% retention (arXiv 2503.19114) |
| always-loaded (CLAUDE.md) | T2_AGGRESSIVE (~50%) | amortizes infinitely |

### Claude-Specific (adjust per target LLM when generating configs)
| Concern | Claude | Other LLMs |
|---------|--------|-----------|
| Section delimiters | XML tags (`<instructions>`, `<context>`) preferred | GPT: markdown headers equivalent; Gemini: either |
| Instruction placement | user turn > system prompt (Anthropic guidance) | GPT/Gemini: less dependent, system prompt fine |
| `effort` parameter | Claude 4.5+ Opus only | N/A |
| Per-model quirks | Haiku=literal, Sonnet=parallel-tools, Opus=overengineers | each family has own quirks — verify per target |

### RCCF Caveat
RCCF (Role/Context/Constraints/Format) is a **3rd-party synthesis**, not vendor-canonical. It aligns w/ the "be explicit" principle held by all modern LLM vendors. Keep as internal convention. Extension: RCCF-V adds Verification (build/test commands, false-claims prevention).

### Compression Eval Harness (recommended, LLM-agnostic)
Before shipping a compressed prompt:
1. Golden prompt set: 10-20 representative tasks
2. Run both versions (full + compressed) on target LLM
3. Compare outputs: pass/fail + token count
4. Ship compressed only if ≥95% pass rate match

Per-target harness — a prompt safe at 40% on Claude may fail on Llama 3.1 7B.

---

## Max Quality Doctrine

Doctrine enforcing output completeness over output-token minimization in subagent contexts. Canonical rationale + directive patterns for completeness floors, calibrated effort framing, and the research basis.

### Root Cause — Subagent Incentive Tension

Subagent system prompts (Claude Agent SDK + Claude Code) instruct subagents to `minimize output tokens` while `completing the task fully` — two objectives that collide under load. Cross-reference: `techniques/agent-design.md:84` (fresh-context gap + silent-wrong-output failure mode). A fresh-context subagent receives only the dispatch string; it cannot see prior conversation establishing scope. When the subagent hits uncertainty about scope, `minimize output tokens` wins the tiebreak → silent elision (`# ... similar pattern follows`, `for brevity`), effort padding (`this is substantial effort`), or truncated implementations that look complete. Main thread never notices because subagent return is plausible. Doctrine purpose: make completeness the dominant objective, make elision observable at verification time.

### Seven-Point Doctrine (canonical)

Mirrors `.claude/rules/max-quality.md` with rationale. All seven are enforced together; partial application defeats the doctrine.

1. **Output completeness > token efficiency.** Instruction compression (agent bodies, rule files, specs) is orthogonal to output compression (generated code, spec bodies, review findings). Compress instructions; never compress output. See `techniques/token-efficiency.md` § Output Carve-Out.
2. **No elision in implementation output.** Banned literals: `for brevity`, `... (omitted)`, `pseudocode`, `abbreviated for`, `truncated for`, `similar pattern follows`, `etc. (more ...)`. Full content every time. If output is genuinely too long, split into multiple dispatches — never elide.
3. **Calibrated effort framing.** Frame effort in observable units: N files, N steps, N minutes in session. Never `days`, `weeks`, `months` — these are temporal units for human-driven work; LLM-executable work completes in the current session. The research basis: arXiv 2604.00010 (temporal miscalibration) shows LLMs trained on human-authored project estimates import human time units into task framing, inflating perceived difficulty and triggering premature stopping.
4. **Completeness floor over abbreviation floor.** Directive: "Provide complete implementation. If omitting any section, explain why in the output — never silently truncate." Forces violations into visible reasoning instead of invisible elision.
5. **Binary verification checklists.** Adopt CheckEval-style (EMNLP 2025) binary pass/fail checklists for every completion criterion. Each criterion = yes/no, no middle state. Prevents self-grading drift where a model rates itself "mostly complete" and stops.
6. **No premature stopping.** Banned phrases: "good stopping point", "natural checkpoint", "should I continue?", "want me to keep going?". If solvable, solve it. Stopping is failure unless the blocker is external (missing API key, user decision required).
7. **No ownership-dodging.** Banned patterns: "pre-existing issue", "not my changes", "known limitation", "out of scope" used as an excuse to leave adjacent bugs unfixed when fixing them is trivial. Own the outcome; fix what you touch.

### Directive Prompting Patterns (completeness floors)

Positive framing dominates negative at high context depth (see § Positive vs Negative Rules). Max-quality directives:

```markdown
## Output Completeness Floor
Output completeness > token efficiency. Full scope every time.
Provide complete implementation. If omitting any section, explain why in the output — never silently truncate.
If the output is too long for a single response, split into multiple responses and continue — do NOT elide.
```

```markdown
## Effort Calibration
Frame effort in observable units: N files, N steps, N minutes in session.
Never use "days", "weeks", "months" for LLM-executable work — these are human temporal units and do not apply.
If a task genuinely cannot complete in one session, state the exact blocker and the exact next step.
```

```markdown
## Verification Checklist (CheckEval binary)
Before returning, answer each as yes/no:
- [ ] Every file listed in scope is created or modified?
- [ ] Every function/section specified is fully implemented (no elision)?
- [ ] Build/test command run and passing?
- [ ] No `TODO` without linked issue?
- [ ] No banned elision literals in output?
Return verification table with results. "Partial yes" is not an allowed answer.
```

### Research Sources

- **GPT-4 "shortcut" incident, Nov 2023** — dbreunig 2026 analysis: GPT-4 introduced elision literals (`# ... (rest of implementation)`) after a model update optimized output tokens. Regressed on code-gen benchmarks. Anthropic + OpenAI subsequently added explicit anti-elision training, but incentive tension remains under subagent load.
- **arXiv 2604.00010** — temporal miscalibration in LLM task estimation. Models trained on human project plans inherit human time units; framing LLM-executable work in `weeks`/`days` triggers inflated difficulty estimates and premature stopping. Fix: constrain effort framing to session-observable units.
- **EMNLP 2025 CheckEval** — binary checklist evaluation outperforms Likert-scale self-grading by 18-34% on completeness detection. Binary forces a decision; scaled grades enable drift.
- **Claude Agent SDK subagent docs** — explicit `minimize output tokens` + `complete the task fully` dual directive. Doctrine exists to resolve the tension in favor of completeness.

### Cross-References

- `techniques/agent-design.md` § Subagent Constraints — fresh-context gap, silent-wrong-output failure mode, why dispatch string is the only bridge
- `techniques/token-efficiency.md` § Output Carve-Out — compression applies to instructions, never to output
- `.claude/rules/max-quality.md` — rule-file enforcement (telegraphic, always-loaded)
- `.claude/hooks/check-quality.sh` — Layer 3 literal-scan enforcement at SubagentStop
- `.claude/agents/proj-code-reviewer.md` — Layer 6 context-sensitive completeness checks (catches what hook regex cannot)

---

## See Also
- `techniques/anti-hallucination.md` — verification patterns
- `techniques/agent-design.md` — agent YAML templates + dispatch patterns + inter-agent handoff formats
- `techniques/token-efficiency.md` — compression tiers, per-role retention floors, protected content passthrough

## Sources
- RCCF Framework: 3rd-party synthesis (promptbestie.com, sterlingchin) — NOT Anthropic canon
- Claude 4.x best practices: docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices
- XML tags: docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/use-xml-tags
- Compression cliffs: arXiv 2503.19114 (Information Preservation), NAACL 2025 (Li et al.)
- LLMLingua-2: arXiv 2403.12968; CompactPrompt: arXiv 2510.18043
- Structured outputs, context caching, taxonomy, few-shot, front-loading: General patterns
