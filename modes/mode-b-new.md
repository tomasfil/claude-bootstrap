# Mode B — Building From Scratch

Select this mode when the working directory is empty or contains only
scaffolding (e.g., a bare git init). There is no existing code to discover.

## Decision Logic Per Step

### Step 1 — Discovery
Minimal detection (empty directory). Ask the user what they are building:
primary language, framework, architecture style, package manager preference,
and target platform. All subsequent steps depend on these answers.

### Step 2 — CLAUDE.md Generation
Generate CLAUDE.md with the user's stated preferences. Since there is no
existing code to discover, sections like Architecture, Key Files, and
Commands are populated from the user's intent rather than observation.

### Step 3 — Code Standards
Create starter rules based on the chosen language and framework. Use
well-established community conventions as defaults (e.g., PEP 8 for Python,
Airbnb for JS/TS). These will be refined through /reflect as code is written.

### Step 4 — Hooks
Install the full set of hooks. A fresh project has no existing CI or
pre-commit setup to conflict with, so every recommended hook applies.

### Step 5 — Skills
Skills are generic — create as specified in the step definition.

### Step 6 — CLAUDE.local.md
Generate CLAUDE.local.md with the user's workflow preferences gathered
during setup (editor, terminal, OS, personal conventions).

### Step 7 — Agents
Create generic agents. Without existing code patterns to match against,
agents start with sensible defaults and will be refined through /reflect
as the codebase takes shape.

### Step 8 — Learnings
Create .learnings/ directory with example entries showing the expected
format. Gives the user a template for how learnings are captured.

### Step 9 — Plugins
Recommend plugins based on the stated languages and frameworks. Since
nothing is installed yet, all relevant plugins are candidates.

### Step 10 — Verification
Full verification pass. Some commands may be N/A until actual code exists
(e.g., test runners, build commands). Note these as "pending first code"
rather than failing them.
