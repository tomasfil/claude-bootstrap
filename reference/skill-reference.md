# Skill Reference

## Directory Structure

```
skill-name/
  SKILL.md          # Required — skill definition with frontmatter + body
  references/       # Optional — additional docs loaded on demand
  scripts/          # Optional — executable scripts (output only, not loaded into context)
  assets/           # Optional — static files, templates, examples
```

## Progressive Disclosure (3-Level Loading)

1. **Metadata** (~100 tokens) — Name, description, and triggers. Always
   loaded. This is how the model decides whether to activate the skill.
2. **Body** (on trigger) — The full SKILL.md body. Loaded when the skill
   is triggered by a matching user prompt or explicit invocation.
3. **Resources** (on demand) — Files in references/, scripts/, assets/.
   Loaded only when the skill body references them. Keeps context lean.

## YAML Frontmatter Fields

| Field | Description |
|-------|-------------|
| `name` | Lowercase, hyphens only, max 64 chars. Must not contain "anthropic" or "claude" |
| `description` | Pushy description with trigger phrases. This is how the model finds the skill — be explicit about when it should activate |
| `allowed-tools` | Tools the skill can use when running |
| `model` | Model override for skill execution |
| `disable-model-invocation` | Set to `true` for skills with side effects that should run scripts without LLM reasoning |
| `user-invocable` | Whether users can trigger this skill directly (default true) |
| `effort` | Execution effort: `low`, `medium`, or `high` |
| `hooks` | Lifecycle hooks scoped to this skill |
| `context` | Set to `fork` to run in an isolated subagent. Main context sees only the final result |

## Skill Budget

Skills share a budget that scales with the context window, roughly ~2% of
total context. This means all loaded skill bodies combined should stay
within this budget. Exceeding it causes skills to be dropped silently.

## Body Guidelines

- **Ideal length**: Under 500 lines. If longer, split supplementary content
  into reference files.
- **Be pushy in the description**: The description is the skill's
  advertisement. Use trigger words that match how users phrase requests.
  Example: "Use when the user says /reflect, asks to review session,
  wants to capture learnings, or says 'what did we learn'"
- **Keep the body focused**: The body should contain instructions, not
  reference material. Put lookup tables, examples, and templates in
  references/.
- **Handle the empty case**: Skills should degrade gracefully when invoked
  in a context where they have nothing to work with (e.g., /reflect in a
  brand new session with no history).

## Scripts

Scripts in the scripts/ directory execute without loading their source into
context. Only their stdout/stderr output consumes tokens. This makes them
ideal for:

- Data collection (gathering file lists, running analyses)
- Validation checks (linting, test runs)
- Environment inspection (checking installed tools, versions)

Scripts should be executable (`chmod +x`) and include a shebang line.

## Key Authoring Rules

1. **Be pushy in description** — Multiple trigger phrases, active voice,
   explicit about when to activate
2. **Keep body focused** — Instructions only, reference material in files
3. **Handle empty case** — Graceful behavior when there is nothing to do
4. **Respect the budget** — Stay under 500 lines, split if needed
5. **Use scripts for side effects** — Keep the LLM out of data collection
6. **Name carefully** — Lowercase, hyphens, no reserved words, max 64 chars
