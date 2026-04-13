---
name: write-ticket
description: >
  Use when asked to write a ticket, issue, user story, or task description.
  Creates INVEST+C structured tickets with acceptance criteria.
argument-hint: "[ticket-description]"
allowed-tools: Read Write Grep Glob
model: sonnet
effort: medium
# Skill Class: main-thread — inline ticket drafting, no agent dispatch
---

## /write-ticket — INVEST+C Ticket Writing

### INVEST+C Criteria
- **I**ndependent — self-contained, no hidden deps
- **N**egotiable — what, not how
- **V**aluable — clear user/business value
- **E**stimable — enough detail to size
- **S**mall — fits in one sprint/iteration
- **T**estable — clear pass/fail criteria
- **C**ontextual — relevant codebase context, affected files/components

### Process
1. Clarify scope if ambiguous
2. Read relevant code — understand the area being changed
3. Draft ticket using format below
4. Validate — verify all file paths exist, patterns referenced are real

### Output Format
```
## {Title}
**Type:** feature | bug | chore
**Priority:** P0-P3

### Description
{1-3 sentences}

### Acceptance Criteria
- [ ] Given {context} When {action} Then {result}

### Affected Components
- {file/module list}

### Test Plan
- {verification steps}
```

### Anti-Hallucination
- Verify all file references exist before including
- Don't reference code or patterns you haven't read
- Don't assume test infrastructure exists — check first
