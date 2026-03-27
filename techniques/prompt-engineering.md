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

## Sources
- RCCF Framework: Internal framework — Role, Context, Constraints, Format
- Structured outputs: General pattern — multiple sources
- Context caching: Anthropic Prompt Caching docs
- Taxonomy-guided: General pattern — multiple sources
- Few-shot patterns: General pattern — multiple sources
- Front-loading: General pattern — multiple sources
