## Pipeline Traces — Bootstrap Content

### new-module
Files (in order):
1. `modules/NN-{name}.md` — create module content with Actions, idempotency, checkpoint
2. `claude-bootstrap.md` — add to Master Checklist and Module Execution sections
3. `techniques/*.md` — update technique references if module introduces new patterns
4. `.claude/settings.json` — update routing hook if module creates new skills/agents

### new-skill
Files (in order):
1. `.claude/skills/{name}/SKILL.md` — create skill with YAML frontmatter
2. `.claude/settings.json` — add to UserPromptSubmit routing hook echo text
3. `modules/08-verification.md` — add to skill existence check list

### new-agent
Files (in order):
1. `.claude/agents/{name}.md` — create agent with YAML frontmatter
2. `.claude/settings.json` — add to UserPromptSubmit routing hook echo text
3. `modules/08-verification.md` — add to agent existence check list

### edit-technique
Files:
1. `techniques/{name}.md` — modify content
2. Check all modules that reference this technique — verify references still valid

### edit-module
Files:
1. `modules/NN-{name}.md` — modify content
2. `claude-bootstrap.md` — verify checklist description still accurate
3. Check downstream modules that depend on this module's output
