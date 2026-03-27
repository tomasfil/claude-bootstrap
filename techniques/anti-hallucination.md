# Anti-Hallucination Techniques Reference

> Referenced by bootstrap modules and generated agents/skills. Apply these patterns to every agent that generates or modifies code.

---

## Core Principle

Code hallucinations are the LEAST dangerous form (they produce immediate compile/runtime errors), but they waste time. The goal is to catch them BEFORE the user sees them, not after.

---

## 1. Read-Before-Write (Mandatory in Every Agent)

**Template to include in every code-writing agent:**

```markdown
## Pre-Writing Checklist (MANDATORY)

BEFORE writing or modifying ANY code:

1. **Read the target file** — if modifying, read the entire file first. If creating new,
   read 2-3 similar files to understand the pattern.
2. **Read related files** — trace imports, base classes, interfaces. Use LSP goToDefinition
   if available, otherwise Grep.
3. **Check project rules** — read `.claude/rules/code-standards.md` and any scoped CLAUDE.md
   in the target directory.
4. **Verify types exist** — for every type you plan to use, verify it exists via LSP hover
   or Grep. Do NOT assume a class/method exists because it "should."
5. **Check naming patterns** — read existing files in the same directory to match naming
   conventions exactly.

NEVER skip this checklist. "I already know the pattern" is not valid — patterns change.
```

---

## 2. Chain-of-Verification (CoVe) for Complex Generation

Use when generating code that spans 3+ files or involves unfamiliar patterns.

**Template:**

```markdown
## Verification Protocol (for multi-file changes)

### Step 1: Draft the Plan
List every file that needs to change and what the change is:
- File: path/to/file.cs → Change: add PropertyX of type Y
- File: path/to/other.cs → Change: map PropertyX in DTO

### Step 2: Verify References (INDEPENDENTLY)
For EACH reference in the plan, verify it exists NOW (not from memory):
- [ ] Class `X` exists at expected path → Glob/Read to confirm
- [ ] Method `Y` has expected signature → LSP hover or Read
- [ ] Type `Z` is importable → Grep for namespace
- [ ] Base class `W` has expected interface → Read to confirm

### Step 3: Flag Discrepancies
If ANY reference doesn't match reality:
- STOP implementation
- Report what was expected vs what was found
- Ask for clarification or investigate further

### Step 4: Implement Only After Verification
Proceed with implementation ONLY after all references verified.
```

---

## 3. Negative Instructions (Include in Every Agent)

**Template — adapt to specific language/framework:**

```markdown
## Anti-Hallucination Rules

DO NOT:
- Invent API methods, classes, or parameters that don't exist in this project
- Fabricate package names or import paths — verify they exist first
- Assume method signatures — check the actual source code
- Generate code for component types you haven't seen examples of in this project
- Use deprecated APIs from your training data — search for current docs
- Copy patterns from other frameworks — use THIS project's patterns

IF UNSURE whether something exists:
1. Search for it (Grep/Glob/LSP)
2. If not found, say "I couldn't verify that X exists — let me check"
3. Never proceed with unverified assumptions

WHEN YOU MAKE A MISTAKE:
- Don't silently fix it — acknowledge what went wrong
- Log it to .learnings/log.md if it's a pattern worth remembering
```

---

## 4. LSP Verification Checklist

**Template for agents with LSP access:**

```markdown
## LSP Verification (use after writing code)

After generating or modifying code, run these LSP checks:

1. **hover** on every new type reference → confirms type exists and is correct
2. **goToDefinition** on base classes → confirms inheritance chain
3. **findReferences** on modified interfaces → confirms all implementations updated
4. **documentSymbol** on modified file → confirms structure is valid
5. **workspaceSymbol** for new types → confirms no naming conflicts

If LSP reports errors:
- Fix immediately — don't present code with LSP errors
- If error is in a {framework-specific files with known LSP false positives}, verify with build command (LSP false positives common)
```

**Template for agents WITHOUT LSP access (fallback):**

```markdown
## Grep-Based Verification (fallback when LSP unavailable)

After generating code:

1. **Grep for every import/using** → confirm the namespace exists in the project
2. **Grep for every base class** → confirm it exists and matches expected signature
3. **Grep for every method called** → confirm it exists on the target type
4. **Grep for every type used** → confirm it's defined somewhere reachable
5. **Run `dotnet build`** (or language equivalent) → catch anything Grep missed
```

---

## 5. Build Verification (Mandatory)

**Template:**

```markdown
## Build Verification (MANDATORY after code changes)

After ALL code changes are complete:

1. Run build command: `dotnet build` / `npm run build` / equivalent
2. If build fails:
   a. Read the error message carefully
   b. Fix the root cause (don't suppress warnings or add casts)
   c. Rebuild and verify
   d. If same error persists after 2 attempts, search the web
3. If build succeeds:
   a. Run affected tests: `dotnet test --filter "FullyQualifiedName~{TestClass}"`
   b. Fix any test failures
4. Report: "Build succeeded, {N} tests passed, {M} tests failed"

NEVER claim code is complete without a successful build.
```

---

## 6. Fabricated Package Detection

Code-specific hallucination where LLMs invent plausible package names.

**Template:**

```markdown
## Package Verification

Before adding ANY new package/dependency:

1. Verify it exists: search NuGet/npm/PyPI (or use {package registry search tool or MCP})
2. Verify the exact version is compatible with the project's framework version
3. Check if the project already has a similar package (avoid duplicates)
4. If you're unsure whether a package exists, say so — don't guess

Common hallucination patterns to watch for:
- Packages with "Extended", "Extra", "Plus" suffixes that don't exist
- Outdated package names that were renamed
- Packages from your training data that have since been deprecated
```

---

## 7. Confidence-Based Routing

**Template for complex decisions:**

```markdown
## When Unsure

Rate your confidence on a scale:

- **HIGH (>90%)**: I've verified the pattern exists in this project → proceed
- **MEDIUM (60-90%)**: I've seen similar patterns but haven't verified → verify first
- **LOW (<60%)**: I'm inferring from general knowledge → STOP and research

For LOW confidence:
1. Search project codebase for similar patterns
2. Check project documentation (.claude/rules/, CLAUDE.md)
3. Search the web for framework-specific guidance
4. If still uncertain, ask the user rather than guessing
```

---

## 8. Spec-Driven Truth (for Complex Features)

**Template for multi-step implementations:**

```markdown
## Feature Implementation Protocol

For features requiring 3+ file changes:

1. WRITE a brief spec FIRST (in conversation, not a file):
   - What files will change
   - What each change does
   - What the expected behavior is

2. VERIFY the spec against reality:
   - Do all referenced files exist?
   - Are the types/methods I plan to use real?
   - Does the pipeline trace match how this project works?

3. GET confirmation before implementing:
   - Present the spec to the user
   - Wait for approval or corrections

4. IMPLEMENT against the spec:
   - Follow the spec exactly — don't add extras
   - Check off each step as completed

5. VERIFY against the spec:
   - Does the implementation match what was planned?
   - Did anything change during implementation that invalidates the spec?
```

---

## 9. Claim-Evidence Ledger (for Research-to-Output Skills)

Use when a skill researches external data and synthesizes it into output (reports,
recommendations, competitive analysis, audits that cite external sources). This is
the most dangerous hallucination surface — fabricated statistics and false citations
look authoritative and are hard to catch after the fact.

**Template:**

```markdown
## Claim-Evidence Ledger

Every external claim discovered during research gets a tracked entry:

| Field | Required | Purpose |
|-------|----------|---------|
| claim | yes | The specific factual assertion |
| source_url | yes | Where it was found |
| source_name | yes | Human-readable source name |
| source_date | yes | When the source was published |
| confidence | yes | high / medium / low |
| corroborated | yes | true if independently confirmed by a second source |
| corroboration_source | if corroborated | Name of the second source |

### Rules
1. **No ledger entry = claim banned from output.** No exceptions.
2. **Statistics require corroboration.** Any %, number, or date needs a second
   independent source. Uncorroborated stats: prefix with "~" and name the single source.
3. **Low-confidence + uncorroborated = DROPPED.** Move to GAPS section in output.
4. **Absence ≠ fact.** Never assert "X doesn't exist." Instead: document exact
   search queries and state "searches returned no results."
5. **Previous outputs are not verified facts.** Re-verify anything material.
6. **No gap-filling from training data.** If search returns nothing, write
   "no current data found" — do not invent from memory.

### Mandatory Audit Phase (insert BEFORE synthesis)
Before writing the final output:
1. Categorize all claims: ✓ (high + corroborated), ⚡ (high + single-source),
   DROPPED (medium/low + uncorroborated)
2. Remove any output text that references DROPPED claims
3. State: "Claim audit complete: {N} total, {X} corroborated, {Y} single-source, {Z} dropped"

### Output Format
- Inline attribution: `[Claim] — [Source, Date] [✓ / ⚡ single source]`
- GAPS section: `[Topic — queries tried — why it matters]`

### Hallucination Ban-List (include project-specific BAD/GOOD examples)
- Never fabricate a statistic — cite exact source or omit
- Never combine two sources into one stat — report each separately with own source
- Never assert "not found" as "doesn't exist" — document search queries
- Never present single case study as universal — label scope explicitly
- Never fill gaps from training data — "no current data found" instead
- Never confuse dates (release vs deprecation, announced vs deployed) — verify against primary sources
```

**When to include:** Any skill whose output contains external claims — market reports,
technology recommendations, audit findings that cite docs, competitive analysis. NOT
needed for code-writing agents (those use read-before-write + build verification instead).

---

## Integration Into Generated Agents

When the bootstrap generates an agent, include these sections based on the agent's role:

| Agent Type | Must Include |
|-----------|-------------|
| Code writer | Patterns 1-8 |
| Code reviewer | Patterns 1, 3, 4, 7 |
| Test writer | Patterns 1, 2, 3, 5, 6 |
| Quick-check / researcher | Patterns 3, 7 |
| Orchestrator skill | Patterns 2, 7, 8 |
| Research-to-output skill | Pattern 9 (Claim-Evidence Ledger) + Patterns 3, 7 |

---

## See Also
- `techniques/prompt-engineering.md` — RCCF framework for structuring agent prompts
- `techniques/agent-design.md` — agent constraints and tool restrictions

## Sources
- Chain-of-Verification: Meta Research / arXiv 2309.11495
- Anthropic Claude Documentation — reducing hallucinations
- Read-before-write: Medium / Design Bootcamp
- Spec-driven workflow: DEV Community (samhath03)
- Package hallucination: USENIX
- LSP grounding: Amir Teymoori, The Experts Tech Talk
- Layered guardrails: AWS DEV Community, Neubird
