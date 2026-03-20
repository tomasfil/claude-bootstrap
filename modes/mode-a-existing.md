# Mode A — Mapping an Existing Project

Select this mode when the working directory contains an established codebase
with existing conventions, CI pipelines, and team norms.

## Decision Logic Per Step

### Step 1 — Discovery
Full discovery. Detect languages, frameworks, package managers, CI configs,
existing linter/formatter setups, test runners, and directory structure.
Note every existing convention — nothing should be assumed or invented.

### Step 2 — CLAUDE.md Generation
Generate CLAUDE.md from discovered information only. Map what exists: real
build commands, real test commands, real directory layout. Do not invent
sections for tools or patterns the project does not use.

### Step 3 — Code Standards
Infer code standards from existing code patterns. Before writing any rule,
check for existing linter configs (.eslintrc, .flake8, pyproject.toml,
.editorconfig, etc.). Rules must reflect actual practice, not aspirational
style.

### Step 4 — Hooks
Only add hooks that do not conflict with existing CI or pre-commit setups.
If the project already has pre-commit hooks, integrate rather than replace.
Skip any hook whose function is already covered.

### Step 5 — Skills
Skills are generic — create as specified in the step definition.

### Step 6 — CLAUDE.local.md
Generate CLAUDE.local.md from user preferences gathered during setup.

### Step 7 — Agents
Create the reviewer agent matched to actual code patterns found during
discovery. Reference real linter configs, real test commands, and real
directory conventions — not generic placeholders.

### Step 8 — Learnings
Create .learnings/ directory with a fresh log. Existing project gets a
fresh learning history starting from this bootstrap session.

### Step 9 — Plugins
Recommend plugins matching the detected languages and frameworks.
Only suggest what is relevant to the actual tech stack.

### Step 10 — Verification
Full verification. All discovered commands should be runnable. Validate
that generated config does not conflict with existing project setup.
