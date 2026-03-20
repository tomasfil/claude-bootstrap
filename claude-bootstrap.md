# Claude Code — Project Bootstrap v4.0

> Point Claude at this repo: `claude -p "Read /path/to/claude-bootstrap/claude-bootstrap.md and execute it"`
>
> Or from within a session: "Read claude-bootstrap.md from {repo-path} and execute all steps"

**Is this for you?** Best for projects you'll actively develop over multiple Claude Code sessions. Overkill for one-off scripts or quick experiments.

---

<role>
You are a senior engineering lead setting up a Claude Code environment. You are meticulous, systematic, and never skip steps. Every component must be created AND wired to the components it depends on.
</role>

<task>
Analyze this project and execute ALL steps below. For each step, read the referenced module file and execute its instructions. Detect the appropriate mode (A/B/C) and adapt accordingly.
</task>

<rules>
MANDATORY RULES — VIOLATIONS CAUSE SETUP FAILURE:

1. Execute steps in order. Do not skip or combine steps.
2. After each step, print: `✅ Step N complete — {what was created}`
3. If a step requires asking the user, STOP and wait for their answer.
4. Every file that references another file MUST use its exact path. Verify paths exist after creation.
5. At the end (Step 10), run the WIRING VERIFICATION checklist. Every item must pass.
6. Do not invent extra files or structures not specified in the modules.
7. Hooks receive JSON input on **stdin** — there is no `$CLAUDE_TOOL_INPUT` environment variable. Always read stdin.
8. All skill files must use YAML frontmatter with `name` and `description` fields between `---` markers.
9. All agent files must use YAML frontmatter with `name` and `description` fields between `---` markers.
10. When troubleshooting fails after 2 attempts, **search the web** before trying more local fixes.

**Hook exit codes** (critical for security hooks):
- `exit 0` — success, proceed (stdout JSON parsed as output)
- `exit 1` — non-blocking error, action STILL PROCEEDS (stderr shown in verbose mode only)
- `exit 2` — block the action (stderr shown to user as error message)
- ⚠️ Security hooks MUST use exit 2 to block — exit 1 only logs but does not prevent the action.
</rules>

---

## Mode Detection

Before starting, detect which mode to run in:

**Mode A — Map Existing Project**: Source files, package manager, build system, or git history exist. Discover and generate configs matching what exists.

**Mode B — Build From Scratch**: Empty directory or only README. Ask the user what they're building.

**Mode C — Incremental Enhancement**: A `.claude/` setup already exists. Audit, preserve customizations, fill in missing/outdated pieces.

Read the appropriate mode file for mode-specific guidance:
- Mode A: Read `modes/mode-a-existing.md` from the bootstrap repo
- Mode B: Read `modes/mode-b-new.md` from the bootstrap repo
- Mode C: Read `modes/mode-c-upgrade.md` from the bootstrap repo

Announce the detected mode before proceeding. If unsure, ask.

---

## Master Checklist

- [ ] Step 1: Project analyzed, environment detected
- [ ] Step 2: `CLAUDE.md` created (<120 lines)
- [ ] Step 3: `.claude/rules/` created
- [ ] Step 4: `.claude/settings.json` with hooks
- [ ] Step 5: Skills created (reflect, audit-file, audit-memory, write-prompt)
- [ ] Step 6: `CLAUDE.local.md` created + scoped files if needed
- [ ] Step 7: `.claude/agents/` created
- [ ] Step 8: `.learnings/` initialized
- [ ] Step 9: MCP + plugins configured
- [ ] Step 10: Wiring verification passes

---

## Step Execution

For each step below, read the referenced module file from the bootstrap repo and execute its instructions.

### Step 1 — Discover the Project
Read `modules/01-discovery.md` and execute it.

### Step 2 — Create CLAUDE.md
Read `modules/02-claude-md.md` and execute it.

### Step 3 — Create Rules
Read `modules/03-rules.md` and execute it.

### Step 4 — Create Hooks
Read `modules/04-hooks.md` and execute it.

### Step 5 — Create Skills
Read `modules/05-skills.md` and execute it.

### Step 6 — Create Personal & Scoped Files
Read `modules/06-personal.md` and execute it.

### Step 7 — Create Subagents
Read `modules/07-agents.md` and execute it.

### Step 8 — Initialize Learnings
Read `modules/08-learnings.md` and execute it.

### Step 9 — MCP & Plugins
Read `modules/09-mcp-plugins.md` and execute it.

### Step 10 — Wiring Verification
Read `modules/10-verification.md` and execute it.

---

## Context Engineering Principles

Instruction-following accuracy degrades as instruction count increases. Anthropic's guidance: "Good context engineering means finding the smallest possible set of high-signal tokens that maximize the likelihood of the desired outcome." Every line in CLAUDE.md must earn its place.

**Key levers:**
- CLAUDE.md: 120 lines max, loads every session — audit ruthlessly
- `.claude/rules/`: Scoped rules, loaded per glob match
- Skills: Domain knowledge loaded on demand (~100 token metadata cost)
- `@import` pointers: Load detailed docs on demand, not inline
- Compaction: Compact proactively at ~70% (`/compact`). Auto-compact fires at high usage (~80-95% depending on platform). Set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` to compact earlier (values above ~83 may be clamped).
- Structured > narrative: Compaction preserves lists at ~92% vs ~71% for paragraphs

For detailed reference on hook events, agent frontmatter, skill authoring, plugins, and LSP: read files in `reference/` from the bootstrap repo as needed.

---

## Appendix — Reference Files

These are available in the `reference/` directory of the bootstrap repo. Read on demand when needed during setup:

- `reference/hook-reference.md` — Complete hook events, exit codes, stdin schemas, all hook types
- `reference/agent-reference.md` — Full agent frontmatter fields, design principles
- `reference/skill-reference.md` — Skill authoring, directory structure, `context: fork`, progressive disclosure
- `reference/plugin-reference.md` — Plugin ecosystem, marketplace, LSP prerequisites, known issues
- `reference/lsp-reference.md` — LSP operations matrix, language server capabilities, platform notes
