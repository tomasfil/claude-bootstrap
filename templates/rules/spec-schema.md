# Spec Schema

## Rule
Every spec file consumed by `/write-plan` MUST carry all 5 required `##` section headers. Word-boundary prefix match within the first 40 chars of each `##` line. Missing section → plan-writer refuses dispatch unless `--skip-schema-gate` passed.

## Required Section Headers (prefix match)
- `## Problem` — maps to "Problem / Goal", "Problem Statement", etc.
- `## Constraints` — hard rules / budget / compatibility
- `## Approach` — chosen mechanism (may be "Approach (approved)")
- `## Components` — files / interfaces / data flow (may be "Components (files, interfaces, data flow)")
- `## Open Questions` — triaged per `open-questions-discipline.md`

## Prefix Match Definition
A `##` line matches a required prefix iff:
- Line starts with `## ` (two hashes + single space)
- Heading text after `## ` starts with the required phrase verbatim, character-for-character, case-sensitive
- Multi-word prefixes (e.g. `Open Questions`) require BOTH words to appear in order at the start — `## Opening Remarks` does NOT match because `Open Questions` ≠ `Opening Remarks`
- Match window: first 40 chars of the line

Shell check: `grep -m1 "^## <prefix>" <spec-file>` per required prefix — non-zero exit = missing section. The leading-anchor + literal-substring form naturally enforces the word-boundary semantics for multi-word prefixes (grep looks for the exact substring `"^## Open Questions"`, so `## Opening Remarks` does NOT match). This is the canonical check used by `/write-plan` Step 1.5.

## Examples
PASS:
- `## Problem / Goal` — first word `Problem` matches
- `## Problem Statement` — first word `Problem` matches
- `## Approach (approved)` — first word `Approach` matches
- `## Components (files, interfaces, data flow)` — first word `Components` matches
- `## Open Questions` — first word `Open` matches full prefix `Open Questions`

FAIL:
- `## problems` — lowercase, case-sensitive mismatch
- `## The Problem` — first word `The`, not `Problem`
- `##Problem` — missing space after `##`
- `##  Problem` — double space after `##`
- `### Problem` — wrong heading level

## Enforcement
- `/write-plan` Step 1.5 Spec Schema Gate runs the 5 prefix checks before dispatching `proj-plan-writer`. Any missing → BLOCK with list of missing sections.
- Escape hatch: `--skip-schema-gate` flag passed as SEPARATE arg bypasses the check (use when spec intentionally partial, e.g., exploratory scratch).
- `/brainstorm` + `/deep-think` spec output templates already conform; re-running the schema gate on their output = no-op PASS.

---

# Canonical Spec Skeleton (reference — these are the exact `##` headings a valid spec MUST carry)

The remaining `##`-level headings in this file (below) are NOT rule sections; they are the literal headings every spec must include (or a prefix-compatible variant of each). Do not edit.

## Problem

Placeholder. In a real spec, this section states the problem or goal. Variant forms accepted by the gate: `## Problem / Goal`, `## Problem Statement`.

## Constraints

Placeholder. In a real spec, this section enumerates hard constraints: budget, compatibility, non-goals, rule conformance requirements.

## Approach

Placeholder. In a real spec, this section describes the chosen mechanism. Variant forms accepted by the gate: `## Approach (approved)`.

## Components

Placeholder. In a real spec, this section lists files, interfaces, data flow. Variant forms accepted by the gate: `## Components (files, interfaces, data flow)`.

## Open Questions

Placeholder. In a real spec, this section carries triaged open questions per `open-questions-discipline.md` (USER_DECIDES / AGENT_RECOMMENDS / AGENT_DECIDED).
