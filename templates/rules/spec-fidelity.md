# Spec Fidelity

<!-- exceeds-40-line-guideline INTENTIONAL: awk extraction snippet + behavior matrix + future-work sub-section cannot be split without loss of cross-reference integrity -->

## Rule
Every spec file that implements a deployed skill MUST declare its target via `covers-skill: <skill-name>` YAML frontmatter. Every skill with a backing spec MUST contain a `## Deviations from spec` block documenting any intentional or accepted divergences from the spec.

## Convention — covers-skill: frontmatter
- Field name: `covers-skill:` (single value, v1)
- Cardinality: single value only; multi-value list form `covers-skill: [a, b]` is NOT supported in v1 — the awk extraction returns only `[skill-a,` for list form (malformed); deferred to future-work
- Placement: inside the YAML frontmatter block at the TOP of the spec file, between two `---` markers; placement must precede any body content
- Value: single bare YAML string matching a deployed skill name (`evolve-agents`, `deep-think`, etc.)

## Extraction (awk)
Inline (1-line, for embedding in bash scripts):
```bash
skill_name=$(awk 'NR==1&&/^---/{d=1;next} NR==1{exit} d==1&&/^---/{d=2;next} d==2{exit} d==1&&/^covers-skill:/{print $2;exit}' "$spec_file")
```

Readable (5-line, for documentation):
```bash
skill_name=$(awk '
  NR==1 && /^---/ { d=1; next }
  NR==1           { exit }
  d==1 && /^---/ { d=2; next }
  d==2            { exit }
  d==1 && /^covers-skill:/ { print $2; exit }
' "$spec_file")
```

Counter-based awk (`d`: 0→1→2) terminates scanning at the second `---` unconditionally — body `---` lines cannot reactivate frontmatter scanning. See `.claude/specs/main/2026-04-27-evolve-agents-skill-eval-deep-think/gap-resolution-2-1-3-awk-robust.md` for the bug-demonstration test case + 8-case verification matrix.

## A10 Audit Behavior
- For each `.claude/specs/**/*.md`: extract `covers-skill:` value via the inline awk above
- For each extracted skill name: locate `.claude/skills/{name}/SKILL.md`; absent → INFO (spec references a skill not deployed in this project)
- SKILL.md present: grep for `^## Deviations from spec` → present = PASS; absent = WARN (or FAIL after graduation criterion below)
- Output: append A10 entry to audit-agents YAML report

## Backfill List
Specs backfilled with `covers-skill:` frontmatter on rule introduction:
- `.claude/specs/2026-04-01-evolve-agents.md` → `covers-skill: evolve-agents`
- `.claude/specs/main/2026-04-12-deep-think-skill-spec.md` → `covers-skill: deep-think`

## WARN→FAIL Graduation
WARN status until 5 migrations after the migration that installs `spec-fidelity.md` ships (installing migration: 055 → graduates to FAIL at migration 060). After the graduation point, A10 promotes WARN to FAIL. Graduation gives time for spec authors + spec-emitting skills (/brainstorm, /deep-think) to adopt the convention before failure becomes blocking.

## Future Work
- Multi-value `covers-skill: [a, b]` support — requires awk extraction rewrite to handle YAML list parsing; defer until a spec covering multiple skills arises in practice
- Commit-hash pinning — tag the spec frontmatter with a commit hash for the skill body it implements, allowing detection of skill-side drift independent of the Deviations block
- Bidirectional link — auto-generated wikilink from skill body back to its originating spec on Deviations block creation
