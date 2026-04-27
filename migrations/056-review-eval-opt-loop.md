# Migration 056 — /review eval-opt loop with structured handoff block

<!-- migration-id: 056-review-eval-opt-loop -->

> Adds structured handoff block (`<!-- handoff-v1-start -->` / `<!-- handoff-v1-end -->` HTML-comment-delimited YAML) to `proj-code-reviewer` and CONVERGENCE-QUALITY evaluator-optimizer loop in `/review` skill Step 7. Reviewer emits machine-parseable handoff block (verdict, severity_class, flagged_files, top_reason, loop_turn, type) at end of every report; skill body extracts via `sed`/`grep` and re-dispatches `proj-code-writer-{lang}` as Tier-B (LOOP_INTERACTION_EXCLUSIVE per `multi-rollout.md` Invariant 8) on `FIX_REQUIRED`/`MUST_FIX` until `APPROVE` or cap=3. Pre-flight gate split into BLOCKING (`proj-code-reviewer` STOP) vs OPTIONAL (`proj-code-writer-{lang}` WARN). Dispatch Map gains `proj-code-writer-{lang}` row (OPTIONAL — dynamic glob; non-blocking). Anti-Hallucination addendum reinforces Invariant 8 at skill body summary layer (no global @import of `multi-rollout.md` required). Companion export uses live `.claude/` copy with divergence guard (preserves client customizations). Six-test migration verification self-test against synthetic reviewer reports. Per-step three-tier detection (idempotency sentinel / baseline anchor with numbered + unnumbered fallback per gap-resolution-1-4-2 Section D / SKIP_HAND_EDITED + `.bak-056` backup + `## Manual-Apply-Guide` pointer); 4-state outer idempotency. Self-contained heredocs for all embedded content per `general.md`.

---

## Metadata

```yaml
id: "056"
breaking: false
affects: [skills, agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Why

Field-observed deep-think on workflow improvements (2026-04-27, gap-register-2 + canonical synthesis at iteration 3 with 0 HIGH-severity gaps remaining) identified that `/review` ends after presenting findings to the user — a passive checkpoint with no automatic correction loop. The original Step 7 was a single line: `Issues found → fix → re-review`. The user reads findings, manually edits files, manually re-runs `/review`. This contradicts the published evaluator-optimizer pattern (Anthropic agent-design.md `## Iterative Patterns`) and the `loopback-budget.md` CONVERGENCE-QUALITY label, which explicitly defines quality-driven exit (continue until success signal OR cap reached) as a canonical loopback shape.

The eval-opt loop closes the review → fix → re-review cycle automatically: reviewer emits a machine-parseable handoff block (YAML in HTML comment sentinels at end of every report), skill body parses verdict + flagged_files + severity_class via `sed`/`grep`, dispatches `proj-code-writer-{lang}` (Tier-B per Invariant 8 — never Tier-C multi-rollout for eval-opt loop dispatches; the `<!-- LOOP_INTERACTION_EXCLUSIVE -->` comment is the machine-readable marker) on `FIX_REQUIRED` + `MUST_FIX`, then re-dispatches the reviewer with `loop_turn: N` injected. Loop continues until `APPROVE` (success signal) OR `iter == 3` (RESOURCE-BUDGET ceiling). Specialist absent → manual path with WARN (graceful degradation, never blocks review). Multi-language reviews (e.g., `.md` + `.sh` flagged together) iterate per-lang sequentially via filename-suffix detection (no `scope:` frontmatter read — the field does not exist on any deployed proj-code-writer-* agent per gap-resolution-2 NGR-4.2-1 verification). Convergence at iteration 3 with 0 HIGH gaps remaining was the deep-think exit signal — the loop ships in the canonical shape with no further drift expected before installation.

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/agents/proj-code-reviewer.md` | Append Structured Handoff Block (YAML schema v1 + 6 field population rules + 2 examples + coupling note + sentinel) after closing fence of `## 7. Report Format` block | Destructive (three-tier; sentinel `<!-- structured-handoff-v1-installed -->`) |
| `templates/agents/proj-code-reviewer.md` | Same change applied to template (companion-export source-of-truth path) | Destructive (three-tier; same sentinel) |
| `.claude/skills/review/SKILL.md` | 4 coordinated edits: pre-flight gate split (STOP vs WARN), Dispatch Map addition, Step 7 canonical replacement (numbered + unnumbered fallback), Anti-Hallucination addendum | Destructive (three-tier; sentinel `<!-- review-eval-opt-loop-installed -->`) |
| `templates/skills/review/SKILL.md` | Same 4 coordinated edits applied to template | Destructive (three-tier; same sentinel) |

---

## Apply

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: .claude/agents/ missing\n"; exit 1; }
[[ -d ".claude/skills" ]] || { printf "ERROR: .claude/skills/ missing\n"; exit 1; }
[[ -f ".claude/agents/proj-code-reviewer.md" ]] || { printf "ERROR: proj-code-reviewer agent missing — install via /migrate-bootstrap or full bootstrap\n"; exit 1; }
[[ -f ".claude/skills/review/SKILL.md" ]] || { printf "ERROR: /review skill missing — install via /migrate-bootstrap or full bootstrap\n"; exit 1; }
[[ -f "templates/agents/proj-code-reviewer.md" ]] || { printf "ERROR: templates/agents/proj-code-reviewer.md missing — bootstrap repo source-of-truth required for companion export\n"; exit 1; }
[[ -f "templates/skills/review/SKILL.md" ]] || { printf "ERROR: templates/skills/review/SKILL.md missing — bootstrap repo source-of-truth required for companion export\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
command -v awk >/dev/null 2>&1 || { printf "ERROR: awk required\n"; exit 1; }
command -v sed >/dev/null 2>&1 || { printf "ERROR: sed required\n"; exit 1; }
```

### Idempotency check (whole-migration)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Whole-migration idempotency: if every patched file already carries the appropriate sentinel,
# the migration is a no-op. Per-step state is checked again inside each step.

ALL_PATCHED=1
declare -a SENTINEL_CHECKS=(
  "structured-handoff-v1-installed:.claude/agents/proj-code-reviewer.md"
  "structured-handoff-v1-installed:templates/agents/proj-code-reviewer.md"
  "review-eval-opt-loop-installed:.claude/skills/review/SKILL.md"
  "review-eval-opt-loop-installed:templates/skills/review/SKILL.md"
)

for entry in "${SENTINEL_CHECKS[@]}"; do
  marker="${entry%%:*}"
  file="${entry##*:}"
  if [[ ! -f "$file" ]] || ! grep -q "$marker" "$file" 2>/dev/null; then
    ALL_PATCHED=0
    break
  fi
done

if [[ "$ALL_PATCHED" -eq 1 ]]; then
  printf "SKIP: migration 056 already applied (all sentinels present in both .claude/ and templates/ copies)\n"
  exit 0
fi

printf "Applying migration 056: /review eval-opt loop with structured handoff block\n"
```

### Step 1 — Patch reviewer Structured Handoff Block (.claude/agents/proj-code-reviewer.md)

Three-tier detection. Appends Structured Handoff Block section after the closing fence of `## 7. Report Format` block (after `### Verdict: {APPROVE | REQUEST CHANGES}` line + its closing ```` ``` ````). The block is bordered above by the existing Report Format closing fence and below by the `### Log-Ready Finding Schema` heading.

- **Tier 1 idempotency sentinel**: `<!-- structured-handoff-v1-installed -->` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline anchor**: `### Verdict: {APPROVE | REQUEST CHANGES}` present AND `### Log-Ready Finding Schema` present → safe `PATCHED`
- **Tier 3 neither**: file customized post-bootstrap → `SKIP_HAND_EDITED` + `.bak-056` backup + pointer to `## Manual-Apply-Guide §Step-1`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Step 1 uses a base64-encoded HANDOFF_BLOCK to avoid Python triple-quoted-string
# parsing problems with embedded curly braces, backticks, and Python escape sequences
# present in the reviewer's structured-handoff schema. The base64 is decoded at runtime
# inside the Python block (no bash heredoc nesting; no awk-extraction collisions on
# triple-backtick lines). Refactor rationale: the prior `'''...'''` approach emitted
# SyntaxWarnings for `\{` and similar sequences, and could fail to parse if the
# embedded markdown contained Python-confusing characters. Base64 round-trips bytes.

python3 <<'PY_056_STEP1'
import base64
import sys
import re
from pathlib import Path

path = Path(".claude/agents/proj-code-reviewer.md")
backup = Path(str(path) + ".bak-056")

POST_056_SENTINEL = "<!-- structured-handoff-v1-installed -->"
BASELINE_VERDICT = "### Verdict: {APPROVE | REQUEST CHANGES}"
BASELINE_LOGREADY = "### Log-Ready Finding Schema"

# Canonical Structured Handoff Block — base64-encoded UTF-8 bytes.
# Decoded content includes leading newline + heading + schema + 6 field rules +
# 2 examples + coupling note + sentinel. Byte-identical to the canonical block
# in templates/agents/proj-code-reviewer.md (extracted 2026-04-27).
HANDOFF_BLOCK_B64 = (
    "CiMjIyBTdHJ1Y3R1cmVkIEhhbmRvZmYgQmxvY2sgKG1hY2hpbmUtcGFyc2VhYmxlIOKAlCBhcHBl"
    "bmQgYXQgRU5EIG9mIGV2ZXJ5IHJlcG9ydCkKCkFmdGVyIHRoZSBgIyMjIFZlcmRpY3Q6YCBsaW5l"
    "LCBhcHBlbmQgdGhlIGZvbGxvd2luZyBibG9jayB2ZXJiYXRpbSB0byB0aGUgcmVwb3J0IGZpbGUu"
    "ClRoaXMgYmxvY2sgaXMgdGhlIG1hY2hpbmUgaW50ZXJmYWNlIGNvbnN1bWVkIGJ5IHRoZSBgL3Jl"
    "dmlld2Agc2tpbGwncyBldmFsLW9wdCBsb29wLgpTY2hlbWEgdmVyc2lvbjogdjEuIFNjaGVtYSBj"
    "aGFuZ2VzIHJlcXVpcmUgYSBuZXcgbWlncmF0aW9uICsgc2VudGluZWwgYnVtcC4KCmBgYAo8IS0t"
    "IGhhbmRvZmYtdjEtc3RhcnQgLS0+CnZlcmRpY3Q6IHtBUFBST1ZFIHwgRklYX1JFUVVJUkVEfQpz"
    "ZXZlcml0eV9jbGFzczoge01VU1RfRklYIHwgU0hPVUxEX0ZJWCB8IFNUWUxFIHwgTk9ORX0KZmxh"
    "Z2dlZF9maWxlczoKICAtIHtmaWxlIHBhdGggZnJvbSBmaXJzdCBNVVNUIEZJWCBmaW5kaW5nLCBy"
    "ZWxhdGl2ZSB0byBwcm9qZWN0IHJvb3R9CiAgLSB7ZmlsZSBwYXRoIGZyb20gc2Vjb25kIE1VU1Qg"
    "RklYIGZpbmRpbmcg4oCUIHJlcGVhdCBmb3IgZWFjaCBkaXN0aW5jdCBmaWxlIGluIE1VU1QgRklY"
    "fQp0b3BfcmVhc29uOiAie2NvcHkgdmVyYmF0aW0gdGhlIGZpcnN0IE1VU1QgRklYIGJ1bGxldCB0"
    "ZXh0LCB0cnVuY2F0ZWQgdG8gMTIwIGNoYXJzfSIKbG9vcF90dXJuOiB7dmFsdWUgZnJvbSBkaXNw"
    "YXRjaCBwcm9tcHQg4oCUIGRlZmF1bHQgMCBpZiBub3QgcHJvdmlkZWR9CnR5cGU6IHJldmlldy1m"
    "aW5kaW5nCjwhLS0gaGFuZG9mZi12MS1lbmQgLS0+CmBgYAoKKipGaWVsZCBwb3B1bGF0aW9uIHJ1"
    "bGVzIChmb2xsb3cgZXhhY3RseSDigJQgZXZlcnkgZmllbGQgcmVxdWlyZWQpOioqCgoxLiBgdmVy"
    "ZGljdDpgCiAgIC0gYEFQUFJPVkVgIGlmIHplcm8gYE1VU1QgRklYYCBpdGVtcwogICAtIGBGSVhf"
    "UkVRVUlSRURgIGlmIG9uZSBvciBtb3JlIGBNVVNUIEZJWGAgaXRlbXMgcHJlc2VudAogICAtIE5l"
    "dmVyOiBgUkVRVUVTVCBDSEFOR0VTYCAodGhhdCBpcyBwcm9zZSDigJQgdXNlIGBGSVhfUkVRVUlS"
    "RURgKQoKMi4gYHNldmVyaXR5X2NsYXNzOmAKICAgLSBgTVVTVF9GSVhgIGlmIG9uZSBvciBtb3Jl"
    "IGBNVVNUIEZJWGAgYnVsbGV0cyBleGlzdCBpbiBgIyMjIElzc3Vlc2AKICAgLSBgU0hPVUxEX0ZJ"
    "WGAgaWYgbm8gYE1VU1QgRklYYCBidXQgb25lIG9yIG1vcmUgYFNIT1VMRCBGSVhgIGJ1bGxldHMg"
    "ZXhpc3QKICAgLSBgU1RZTEVgIGlmIG9ubHkgYENPTlNJREVSYCBidWxsZXRzIGV4aXN0CiAgIC0g"
    "YE5PTkVgIGlmIGAjIyMgSXNzdWVzYCBpcyBlbXB0eSBhbmQgdmVyZGljdCBpcyBgQVBQUk9WRWAK"
    "CjMuIGBmbGFnZ2VkX2ZpbGVzOmAgKFlBTUwgbGlzdCDigJQgb25lIGl0ZW0gcGVyIGxpbmUsIGVh"
    "Y2ggcHJlZml4ZWQgYCAgLSBgKQogICAtIEluY2x1ZGUgT05MWSBmaWxlcyBtZW50aW9uZWQgaW4g"
    "YE1VU1QgRklYYCBidWxsZXRzIChmb3JtYXQ6IGAtIHtpc3N1ZX0g4oCUIHtmaWxlfTp7bGluZX1g"
    "KQogICAtIEV4dHJhY3QgdGhlIGB7ZmlsZX1gIHBvcnRpb24gZnJvbSBlYWNoIGBNVVNUIEZJWGAg"
    "YnVsbGV0IChge2ZpbGV9YCBpcyBldmVyeXRoaW5nIGJlZm9yZSB0aGUgbGFzdCBjb2xvbikKICAg"
    "LSBJZiBNVVNUIEZJWCBidWxsZXRzIHJlZmVyZW5jZSBhIGZpbGUgbXVsdGlwbGUgdGltZXMg4oaS"
    "IGluY2x1ZGUgdGhlIGZpbGUgT05DRSAoZGVkdXBsaWNhdGUpCiAgIC0gSWYgdmVyZGljdCBpcyBg"
    "QVBQUk9WRWAg4oaSIHdyaXRlIGBmbGFnZ2VkX2ZpbGVzOiBbXWAgKGVtcHR5IFlBTUwgbGlzdCwg"
    "c2luZ2xlIGxpbmUpCiAgIC0gSW5jbHVkZSBhbGwgZGVwZW5kZW5jeSBmaWxlcyBpZiB0aGUgTVVT"
    "VCBGSVggZmluZGluZyBleHBsaWNpdGx5IHNheXMgInJlcXVpcmVzIGNoYW5nZSBpbiB7b3RoZXIt"
    "ZmlsZX0iCgo0LiBgdG9wX3JlYXNvbjpgIChxdW90ZWQgc3RyaW5nIOKAlCBkb3VibGUgcXVvdGVz"
    "IHJlcXVpcmVkKQogICAtIENvcHkgdGhlIGZpcnN0IGBNVVNUIEZJWGAgYnVsbGV0IHRleHQgdmVy"
    "YmF0aW0KICAgLSBUcnVuY2F0ZSB0byAxMjAgY2hhcmFjdGVycyBpZiBsb25nZXI7IGFwcGVuZCBg"
    "Li4uYCBpZiB0cnVuY2F0ZWQKICAgLSBJZiB2ZXJkaWN0IGlzIGBBUFBST1ZFYCDihpIgYHRvcF9y"
    "ZWFzb246ICIiYAoKNS4gYGxvb3BfdHVybjpgIChpbnRlZ2VyKQogICAtIFJlYWQgZnJvbSBkaXNw"
    "YXRjaCBwcm9tcHQgZmllbGQgYGxvb3BfdHVybjogTmAgaWYgcHJlc2VudAogICAtIElmIG5vdCBw"
    "cm92aWRlZCBpbiBkaXNwYXRjaCBwcm9tcHQg4oaSIHVzZSBgMGAKICAgLSBEbyBub3QgaW5jcmVt"
    "ZW50IOKAlCBjb3B5IHRoZSB2YWx1ZSBhcy1pczsgdGhlIG9yY2hlc3RyYXRvciB0cmFja3MgaXRl"
    "cmF0aW9uIGNvdW50Cgo2LiBgdHlwZTpgCiAgIC0gQWx3YXlzIGByZXZpZXctZmluZGluZ2AgZm9y"
    "IGBwcm9qLWNvZGUtcmV2aWV3ZXJgIHJlcG9ydHMKCioqRXhhbXBsZSDigJQgRklYX1JFUVVJUkVE"
    "IHJlcG9ydCAoTVVTVCBGSVggcHJlc2VudCk6KioKCmBgYAo8IS0tIGhhbmRvZmYtdjEtc3RhcnQg"
    "LS0+CnZlcmRpY3Q6IEZJWF9SRVFVSVJFRApzZXZlcml0eV9jbGFzczogTVVTVF9GSVgKZmxhZ2dl"
    "ZF9maWxlczoKICAtIC5jbGF1ZGUvYWdlbnRzL3Byb2otY29kZS1yZXZpZXdlci5tZAogIC0gLmNs"
    "YXVkZS9za2lsbHMvcmV2aWV3L1NLSUxMLm1kCnRvcF9yZWFzb246ICJNaXNzaW5nIENPTlZFUkdF"
    "TkNFLVFVQUxJVFkgYW5ub3RhdGlvbiBvbiBsb29wIGNvbnRyb2wgYXQgLmNsYXVkZS9hZ2VudHMv"
    "cHJvai1jb2RlLXJldmlld2VyLm1kOjQ3Igpsb29wX3R1cm46IDEKdHlwZTogcmV2aWV3LWZpbmRp"
    "bmcKPCEtLSBoYW5kb2ZmLXYxLWVuZCAtLT4KYGBgCgoqKkV4YW1wbGUg4oCUIEFQUFJPVkUgcmVw"
    "b3J0IChubyBNVVNUIEZJWCk6KioKCmBgYAo8IS0tIGhhbmRvZmYtdjEtc3RhcnQgLS0+CnZlcmRp"
    "Y3Q6IEFQUFJPVkUKc2V2ZXJpdHlfY2xhc3M6IE5PTkUKZmxhZ2dlZF9maWxlczogW10KdG9wX3Jl"
    "YXNvbjogIiIKbG9vcF90dXJuOiAwCnR5cGU6IHJldmlldy1maW5kaW5nCjwhLS0gaGFuZG9mZi12"
    "MS1lbmQgLS0+CmBgYAoKKipDb3VwbGluZyBub3RlOioqIFRoaXMgYmxvY2sgaXMgY29uc3VtZWQg"
    "YnkgYC9yZXZpZXdgIHNraWxsIFN0ZXAgNyBldmFsLW9wdCBsb29wIHZpYQpgc2VkIC1uICcvPCEt"
    "LSBoYW5kb2ZmLXYxLXN0YXJ0IC0tPi8sLzwhLS0gaGFuZG9mZi12MS1lbmQgLS0+L3AnYCBleHRy"
    "YWN0aW9uLgpBbnkgZm9ybWF0IGNoYW5nZSB0byB0aGlzIGJsb2NrIHJlcXVpcmVzIGEgbmV3IG1p"
    "Z3JhdGlvbiArIHNlbnRpbmVsIGJ1bXAgdG8gYHYyYC4KVGhlIHNlbnRpbmVsIGA8IS0tIHN0cnVj"
    "dHVyZWQtaGFuZG9mZi12MS1pbnN0YWxsZWQgLS0+YCBpbiB0aGlzIGZpbGUgbWFya3MgdGhhdAp0"
    "aGlzIHNlY3Rpb24gaGFzIGJlZW4gYXBwbGllZC4KCjwhLS0gc3RydWN0dXJlZC1oYW5kb2ZmLXYx"
    "LWluc3RhbGxlZCAtLT4K"
)
HANDOFF_BLOCK = base64.b64decode(HANDOFF_BLOCK_B64).decode("utf-8")

content = path.read_text(encoding="utf-8")

if POST_056_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {path} Structured Handoff Block already installed (056-1)")
    sys.exit(0)

if BASELINE_VERDICT not in content or BASELINE_LOGREADY not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {path} Report Format section has been customized post-bootstrap. Manual application required. See migrations/056-review-eval-opt-loop.md Manual-Apply-Guide Step-1. Backup at {backup}.")
    sys.exit(0)

# Locate the insertion point: after the closing fence of the Report Format code-block,
# BEFORE the `### Log-Ready Finding Schema` heading. Pattern matches the closing fence
# line followed by a blank line and the next heading.
INSERTION_PATTERN = re.compile(
    r"(### Verdict: \{APPROVE \| REQUEST CHANGES\}\n```\n)(\n### Log-Ready Finding Schema)",
    re.MULTILINE,
)
match = INSERTION_PATTERN.search(content)
if not match:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"ERROR: {path} could not locate exact insertion anchor. Manual application required. See Manual-Apply-Guide Step-1. Backup at {backup}.")
    sys.exit(1)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

new_content = content[:match.end(1)] + HANDOFF_BLOCK + content[match.start(2):]
path.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {path} Structured Handoff Block appended (056-1)")
PY_056_STEP1
```

### Step 2 — Patch reviewer Structured Handoff Block (templates/agents/proj-code-reviewer.md)

Same three-tier logic as Step 1, applied to the template source-of-truth path. The template is the canonical body for client-project bootstrap and companion export.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Step 2 mirrors Step 1 against the templates/ source-of-truth path. Same
# base64-encoded HANDOFF_BLOCK (byte-identical to the canonical block in
# templates/agents/proj-code-reviewer.md). Refactor rationale: see Step 1 header.

python3 <<'PY_056_STEP2'
import base64
import sys
import re
from pathlib import Path

path = Path("templates/agents/proj-code-reviewer.md")
backup = Path(str(path) + ".bak-056")

POST_056_SENTINEL = "<!-- structured-handoff-v1-installed -->"
BASELINE_VERDICT = "### Verdict: {APPROVE | REQUEST CHANGES}"
BASELINE_LOGREADY = "### Log-Ready Finding Schema"

# Canonical Structured Handoff Block — base64-encoded UTF-8 bytes.
# Byte-identical to the block embedded in Step 1.
HANDOFF_BLOCK_B64 = (
    "CiMjIyBTdHJ1Y3R1cmVkIEhhbmRvZmYgQmxvY2sgKG1hY2hpbmUtcGFyc2VhYmxlIOKAlCBhcHBl"
    "bmQgYXQgRU5EIG9mIGV2ZXJ5IHJlcG9ydCkKCkFmdGVyIHRoZSBgIyMjIFZlcmRpY3Q6YCBsaW5l"
    "LCBhcHBlbmQgdGhlIGZvbGxvd2luZyBibG9jayB2ZXJiYXRpbSB0byB0aGUgcmVwb3J0IGZpbGUu"
    "ClRoaXMgYmxvY2sgaXMgdGhlIG1hY2hpbmUgaW50ZXJmYWNlIGNvbnN1bWVkIGJ5IHRoZSBgL3Jl"
    "dmlld2Agc2tpbGwncyBldmFsLW9wdCBsb29wLgpTY2hlbWEgdmVyc2lvbjogdjEuIFNjaGVtYSBj"
    "aGFuZ2VzIHJlcXVpcmUgYSBuZXcgbWlncmF0aW9uICsgc2VudGluZWwgYnVtcC4KCmBgYAo8IS0t"
    "IGhhbmRvZmYtdjEtc3RhcnQgLS0+CnZlcmRpY3Q6IHtBUFBST1ZFIHwgRklYX1JFUVVJUkVEfQpz"
    "ZXZlcml0eV9jbGFzczoge01VU1RfRklYIHwgU0hPVUxEX0ZJWCB8IFNUWUxFIHwgTk9ORX0KZmxh"
    "Z2dlZF9maWxlczoKICAtIHtmaWxlIHBhdGggZnJvbSBmaXJzdCBNVVNUIEZJWCBmaW5kaW5nLCBy"
    "ZWxhdGl2ZSB0byBwcm9qZWN0IHJvb3R9CiAgLSB7ZmlsZSBwYXRoIGZyb20gc2Vjb25kIE1VU1Qg"
    "RklYIGZpbmRpbmcg4oCUIHJlcGVhdCBmb3IgZWFjaCBkaXN0aW5jdCBmaWxlIGluIE1VU1QgRklY"
    "fQp0b3BfcmVhc29uOiAie2NvcHkgdmVyYmF0aW0gdGhlIGZpcnN0IE1VU1QgRklYIGJ1bGxldCB0"
    "ZXh0LCB0cnVuY2F0ZWQgdG8gMTIwIGNoYXJzfSIKbG9vcF90dXJuOiB7dmFsdWUgZnJvbSBkaXNw"
    "YXRjaCBwcm9tcHQg4oCUIGRlZmF1bHQgMCBpZiBub3QgcHJvdmlkZWR9CnR5cGU6IHJldmlldy1m"
    "aW5kaW5nCjwhLS0gaGFuZG9mZi12MS1lbmQgLS0+CmBgYAoKKipGaWVsZCBwb3B1bGF0aW9uIHJ1"
    "bGVzIChmb2xsb3cgZXhhY3RseSDigJQgZXZlcnkgZmllbGQgcmVxdWlyZWQpOioqCgoxLiBgdmVy"
    "ZGljdDpgCiAgIC0gYEFQUFJPVkVgIGlmIHplcm8gYE1VU1QgRklYYCBpdGVtcwogICAtIGBGSVhf"
    "UkVRVUlSRURgIGlmIG9uZSBvciBtb3JlIGBNVVNUIEZJWGAgaXRlbXMgcHJlc2VudAogICAtIE5l"
    "dmVyOiBgUkVRVUVTVCBDSEFOR0VTYCAodGhhdCBpcyBwcm9zZSDigJQgdXNlIGBGSVhfUkVRVUlS"
    "RURgKQoKMi4gYHNldmVyaXR5X2NsYXNzOmAKICAgLSBgTVVTVF9GSVhgIGlmIG9uZSBvciBtb3Jl"
    "IGBNVVNUIEZJWGAgYnVsbGV0cyBleGlzdCBpbiBgIyMjIElzc3Vlc2AKICAgLSBgU0hPVUxEX0ZJ"
    "WGAgaWYgbm8gYE1VU1QgRklYYCBidXQgb25lIG9yIG1vcmUgYFNIT1VMRCBGSVhgIGJ1bGxldHMg"
    "ZXhpc3QKICAgLSBgU1RZTEVgIGlmIG9ubHkgYENPTlNJREVSYCBidWxsZXRzIGV4aXN0CiAgIC0g"
    "YE5PTkVgIGlmIGAjIyMgSXNzdWVzYCBpcyBlbXB0eSBhbmQgdmVyZGljdCBpcyBgQVBQUk9WRWAK"
    "CjMuIGBmbGFnZ2VkX2ZpbGVzOmAgKFlBTUwgbGlzdCDigJQgb25lIGl0ZW0gcGVyIGxpbmUsIGVh"
    "Y2ggcHJlZml4ZWQgYCAgLSBgKQogICAtIEluY2x1ZGUgT05MWSBmaWxlcyBtZW50aW9uZWQgaW4g"
    "YE1VU1QgRklYYCBidWxsZXRzIChmb3JtYXQ6IGAtIHtpc3N1ZX0g4oCUIHtmaWxlfTp7bGluZX1g"
    "KQogICAtIEV4dHJhY3QgdGhlIGB7ZmlsZX1gIHBvcnRpb24gZnJvbSBlYWNoIGBNVVNUIEZJWGAg"
    "YnVsbGV0IChge2ZpbGV9YCBpcyBldmVyeXRoaW5nIGJlZm9yZSB0aGUgbGFzdCBjb2xvbikKICAg"
    "LSBJZiBNVVNUIEZJWCBidWxsZXRzIHJlZmVyZW5jZSBhIGZpbGUgbXVsdGlwbGUgdGltZXMg4oaS"
    "IGluY2x1ZGUgdGhlIGZpbGUgT05DRSAoZGVkdXBsaWNhdGUpCiAgIC0gSWYgdmVyZGljdCBpcyBg"
    "QVBQUk9WRWAg4oaSIHdyaXRlIGBmbGFnZ2VkX2ZpbGVzOiBbXWAgKGVtcHR5IFlBTUwgbGlzdCwg"
    "c2luZ2xlIGxpbmUpCiAgIC0gSW5jbHVkZSBhbGwgZGVwZW5kZW5jeSBmaWxlcyBpZiB0aGUgTVVT"
    "VCBGSVggZmluZGluZyBleHBsaWNpdGx5IHNheXMgInJlcXVpcmVzIGNoYW5nZSBpbiB7b3RoZXIt"
    "ZmlsZX0iCgo0LiBgdG9wX3JlYXNvbjpgIChxdW90ZWQgc3RyaW5nIOKAlCBkb3VibGUgcXVvdGVz"
    "IHJlcXVpcmVkKQogICAtIENvcHkgdGhlIGZpcnN0IGBNVVNUIEZJWGAgYnVsbGV0IHRleHQgdmVy"
    "YmF0aW0KICAgLSBUcnVuY2F0ZSB0byAxMjAgY2hhcmFjdGVycyBpZiBsb25nZXI7IGFwcGVuZCBg"
    "Li4uYCBpZiB0cnVuY2F0ZWQKICAgLSBJZiB2ZXJkaWN0IGlzIGBBUFBST1ZFYCDihpIgYHRvcF9y"
    "ZWFzb246ICIiYAoKNS4gYGxvb3BfdHVybjpgIChpbnRlZ2VyKQogICAtIFJlYWQgZnJvbSBkaXNw"
    "YXRjaCBwcm9tcHQgZmllbGQgYGxvb3BfdHVybjogTmAgaWYgcHJlc2VudAogICAtIElmIG5vdCBw"
    "cm92aWRlZCBpbiBkaXNwYXRjaCBwcm9tcHQg4oaSIHVzZSBgMGAKICAgLSBEbyBub3QgaW5jcmVt"
    "ZW50IOKAlCBjb3B5IHRoZSB2YWx1ZSBhcy1pczsgdGhlIG9yY2hlc3RyYXRvciB0cmFja3MgaXRl"
    "cmF0aW9uIGNvdW50Cgo2LiBgdHlwZTpgCiAgIC0gQWx3YXlzIGByZXZpZXctZmluZGluZ2AgZm9y"
    "IGBwcm9qLWNvZGUtcmV2aWV3ZXJgIHJlcG9ydHMKCioqRXhhbXBsZSDigJQgRklYX1JFUVVJUkVE"
    "IHJlcG9ydCAoTVVTVCBGSVggcHJlc2VudCk6KioKCmBgYAo8IS0tIGhhbmRvZmYtdjEtc3RhcnQg"
    "LS0+CnZlcmRpY3Q6IEZJWF9SRVFVSVJFRApzZXZlcml0eV9jbGFzczogTVVTVF9GSVgKZmxhZ2dl"
    "ZF9maWxlczoKICAtIC5jbGF1ZGUvYWdlbnRzL3Byb2otY29kZS1yZXZpZXdlci5tZAogIC0gLmNs"
    "YXVkZS9za2lsbHMvcmV2aWV3L1NLSUxMLm1kCnRvcF9yZWFzb246ICJNaXNzaW5nIENPTlZFUkdF"
    "TkNFLVFVQUxJVFkgYW5ub3RhdGlvbiBvbiBsb29wIGNvbnRyb2wgYXQgLmNsYXVkZS9hZ2VudHMv"
    "cHJvai1jb2RlLXJldmlld2VyLm1kOjQ3Igpsb29wX3R1cm46IDEKdHlwZTogcmV2aWV3LWZpbmRp"
    "bmcKPCEtLSBoYW5kb2ZmLXYxLWVuZCAtLT4KYGBgCgoqKkV4YW1wbGUg4oCUIEFQUFJPVkUgcmVw"
    "b3J0IChubyBNVVNUIEZJWCk6KioKCmBgYAo8IS0tIGhhbmRvZmYtdjEtc3RhcnQgLS0+CnZlcmRp"
    "Y3Q6IEFQUFJPVkUKc2V2ZXJpdHlfY2xhc3M6IE5PTkUKZmxhZ2dlZF9maWxlczogW10KdG9wX3Jl"
    "YXNvbjogIiIKbG9vcF90dXJuOiAwCnR5cGU6IHJldmlldy1maW5kaW5nCjwhLS0gaGFuZG9mZi12"
    "MS1lbmQgLS0+CmBgYAoKKipDb3VwbGluZyBub3RlOioqIFRoaXMgYmxvY2sgaXMgY29uc3VtZWQg"
    "YnkgYC9yZXZpZXdgIHNraWxsIFN0ZXAgNyBldmFsLW9wdCBsb29wIHZpYQpgc2VkIC1uICcvPCEt"
    "LSBoYW5kb2ZmLXYxLXN0YXJ0IC0tPi8sLzwhLS0gaGFuZG9mZi12MS1lbmQgLS0+L3AnYCBleHRy"
    "YWN0aW9uLgpBbnkgZm9ybWF0IGNoYW5nZSB0byB0aGlzIGJsb2NrIHJlcXVpcmVzIGEgbmV3IG1p"
    "Z3JhdGlvbiArIHNlbnRpbmVsIGJ1bXAgdG8gYHYyYC4KVGhlIHNlbnRpbmVsIGA8IS0tIHN0cnVj"
    "dHVyZWQtaGFuZG9mZi12MS1pbnN0YWxsZWQgLS0+YCBpbiB0aGlzIGZpbGUgbWFya3MgdGhhdAp0"
    "aGlzIHNlY3Rpb24gaGFzIGJlZW4gYXBwbGllZC4KCjwhLS0gc3RydWN0dXJlZC1oYW5kb2ZmLXYx"
    "LWluc3RhbGxlZCAtLT4K"
)
HANDOFF_BLOCK = base64.b64decode(HANDOFF_BLOCK_B64).decode("utf-8")

content = path.read_text(encoding="utf-8")

if POST_056_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {path} Structured Handoff Block already installed (056-2)")
    sys.exit(0)

if BASELINE_VERDICT not in content or BASELINE_LOGREADY not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {path} Report Format section has been customized post-bootstrap. Manual application required. See migrations/056-review-eval-opt-loop.md Manual-Apply-Guide Step-1 (templates/ uses identical block). Backup at {backup}.")
    sys.exit(0)

INSERTION_PATTERN = re.compile(
    r"(### Verdict: \{APPROVE \| REQUEST CHANGES\}\n```\n)(\n### Log-Ready Finding Schema)",
    re.MULTILINE,
)
match = INSERTION_PATTERN.search(content)
if not match:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"ERROR: {path} could not locate exact insertion anchor. Manual application required. See Manual-Apply-Guide Step-1. Backup at {backup}.")
    sys.exit(1)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

new_content = content[:match.end(1)] + HANDOFF_BLOCK + content[match.start(2):]
path.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {path} Structured Handoff Block appended (056-2)")
PY_056_STEP2
```

### Step 3 — Patch /review SKILL.md (.claude/skills/review/SKILL.md)

Three-tier detection. Four coordinated edits applied under one sentinel:
- **Edit A** — Pre-flight gate split: replace lines 14-17 (uniform STOP block) with BLOCKING (`proj-code-reviewer` STOP) + OPTIONAL (`proj-code-writer-{lang}` WARN) split
- **Edit B** — Dispatch Map addition: insert `Fix dispatch (eval-opt loop)` row after `Code review:` row
- **Edit C** — Step 7 canonical replacement: replace single line `7. Issues found → fix → re-review` with full evaluator-optimizer loop block (filename-suffix lang detection, sed-based handoff extraction, LOOP_INTERACTION_EXCLUSIVE comment, loop_turn injection, manual-path fallback)
- **Edit D** — Anti-Hallucination addendum: append Invariant 8 reminder bullet to existing `### Anti-Hallucination` section

All four edits ship under one sentinel `<!-- review-eval-opt-loop-installed -->` (placed inline after the Step 7 block) to avoid sentinel collisions on the same file.

- **Tier 1 idempotency sentinel**: `<!-- review-eval-opt-loop-installed -->` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline anchors** (per gap-resolution-1-4-2 Section D — TIER2_A_NUMBERED + TIER2_A_UNNUMBERED unnumbered fallback for step-renumber drift):
  - Step 7 line: `7. Issues found → fix → re-review` (numbered, exact stock) OR `Issues found → fix → re-review` (stripped-prefix fallback per migration 054 pattern)
  - Adjacent step: `6. Present review results to user` (less likely to be removed by hand-editor)
  - Pre-flight gate baseline: `If \`.claude/agents/<agent-name>.md\` does NOT exist → STOP.`
  - All baseline anchors must be present alongside the Step 7 anchor → safe `PATCHED`
- **Tier 3 neither**: file customized post-bootstrap → `SKIP_HAND_EDITED` + `.bak-056` backup + pointer to `## Manual-Apply-Guide §Step-3`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Step 3 applies four coordinated edits to /review SKILL.md. Edits A (pre-flight),
# C (Step 7), and D (Anti-Hallucination) embed multi-line markdown content with
# triple-backticks and Python-confusing characters; these are base64-decoded inside
# Python at runtime. Edit B (Dispatch Map) is a small inline string. The base64
# strings are byte-identical to the canonical content in templates/skills/review/SKILL.md
# (extracted 2026-04-27). Refactor rationale: see Step 1 header.

python3 <<'PY_056_STEP3'
import base64
import sys
import re
from pathlib import Path

path = Path(".claude/skills/review/SKILL.md")
backup = Path(str(path) + ".bak-056")

POST_056_SENTINEL = "<!-- review-eval-opt-loop-installed -->"

# Tier 2 baseline anchors (compound — per gap-resolution-1-4-2 Section D)
TIER2_A_NUMBERED   = "7. Issues found → fix → re-review"
TIER2_A_UNNUMBERED = "Issues found → fix → re-review"
TIER2_B            = "6. Present review results to user"
TIER2_PRE_FLIGHT   = "If `.claude/agents/<agent-name>.md` does NOT exist → STOP."

# Edit A replacement — base64-encoded canonical pre-flight block
# (replaces from "## Pre-flight (REQUIRED..." through but excluding "## Dispatch Map")
PRE_FLIGHT_NEW_B64 = (
    "IyMgUHJlLWZsaWdodCAoUkVRVUlSRUQg4oCUIGJlZm9yZSBhbnkgb3RoZXIgc3RlcCkKCioqQmxv"
    "Y2tpbmcgYWdlbnRzKiogKFNUT1AgaWYgbWlzc2luZyDigJQgcmV2aWV3IGNhbm5vdCBwcm9jZWVk"
    "IHdpdGhvdXQgdGhlc2UpOgotIGBwcm9qLWNvZGUtcmV2aWV3ZXJgIOKAlCBJZiBgLmNsYXVkZS9h"
    "Z2VudHMvcHJvai1jb2RlLXJldmlld2VyLm1kYCBkb2VzIE5PVCBleGlzdCDihpIgU1RPUC4KICBU"
    "ZWxsIHVzZXI6ICJSZXF1aXJlZCBhZ2VudCBwcm9qLWNvZGUtcmV2aWV3ZXIgbWlzc2luZy4gUnVu"
    "IC9taWdyYXRlLWJvb3RzdHJhcCBvciAvbW9kdWxlLXdyaXRlLiIKICBEbyBOT1QgcHJvY2VlZC4g"
    "RG8gTk9UIGZhbGwgYmFjayB0byBpbmxpbmUgd29yay4gRG8gTk9UIHN1YnN0aXR1dGUgYW5vdGhl"
    "ciBhZ2VudC4KCioqT3B0aW9uYWwgYWdlbnRzKiogKFdBUk4gaWYgbWlzc2luZyDigJQgcmV2aWV3"
    "IHByb2NlZWRzOyBldmFsLW9wdCBmaXggbG9vcCBkZWdyYWRlcyBncmFjZWZ1bGx5KToKLSBgcHJv"
    "ai1jb2RlLXdyaXRlci17bGFuZ31gIOKAlCBJZiBubyBgLmNsYXVkZS9hZ2VudHMvcHJvai1jb2Rl"
    "LXdyaXRlci0qLm1kYCBleGlzdHMg4oaSCiAgV0FSTjogIk5vIGNvZGUtd3JpdGVyIHNwZWNpYWxp"
    "c3QgZm91bmQuIC9yZXZpZXcgd2lsbCBydW4gYnV0IHRoZSBldmFsLW9wdCBmaXggbG9vcAogIChT"
    "dGVwIDcpIHdpbGwgc2tpcCBhdXRvbWF0aWMgZml4IGRpc3BhdGNoLiBSdW4gL2V2b2x2ZS1hZ2Vu"
    "dHMgdG8gY3JlYXRlIGEgc3BlY2lhbGlzdC4iCiAgQ29udGludWUgd2l0aCBTdGVwIDEuCgo="
)
PRE_FLIGHT_NEW = base64.b64decode(PRE_FLIGHT_NEW_B64).decode("utf-8")

# Edit C replacement — base64-encoded canonical Step 7 evaluator-optimizer loop
# (replaces the single line "7. Issues found -> fix -> re-review" with the full block)
STEP7_NEW_B64 = (
    "Ny4gRXZhbHVhdG9yLW9wdGltaXplciBsb29wIDwhLS0gQ09OVkVSR0VOQ0UtUVVBTElUWTogY2Fw"
    "PTMsIHNpZ25hbD1BUFBST1ZFIC0tPgoKICAgKipQcmUtZmxpZ2h0IGdhdGUgKGJlZm9yZSBsb29w"
    "KToqKgogICAtIGBwcm9qLWNvZGUtcmV2aWV3ZXJgIGFic2VudCDihpIgU1RPUCAoYmxvY2tpbmcg"
    "4oCUIGFscmVhZHkgZW5mb3JjZWQgYnkgcHJlLWZsaWdodCBnYXRlIGFib3ZlKQogICAtIGBwcm9q"
    "LWNvZGUtd3JpdGVyLXtsYW5nfWAgYWJzZW50IOKGkiBXQVJOIG9ubHkgKG5vbi1ibG9ja2luZyDi"
    "gJQgbG9vcCBkZWdyYWRlcyB0byBtYW51YWwgcGF0aCBiZWxvdykKICAgLSBgbG9vcGJhY2stYnVk"
    "Z2V0Lm1kYCBhYnNlbnQg4oaSIFdBUk46ICJtaWdyYXRpb24gMDUwIHJlcXVpcmVkIGZvciBDT05W"
    "RVJHRU5DRS1RVUFMSVRZIGFubm90YXRpb24iCgogICAqKkxvb3Agc3RhdGU6KiogYGl0ZXI9MGAK"
    "CiAgICoqTG9vcCBib2R5KiogKHJlcGVhdCB3aGlsZSBgdmVyZGljdCA9PSBGSVhfUkVRVUlSRURg"
    "IEFORCBgaXRlciA8IDNgKToKICAgYS4gSW5jcmVtZW50OiBgaXRlcj0kKChpdGVyICsgMSkpYAog"
    "ICBiLiBQYXJzZSBgZmxhZ2dlZF9maWxlczpgIGZyb20gdGhlIHJldmlld2VyJ3MgaGFuZG9mZiBi"
    "bG9jayBhdCBlbmQgb2YgcmVwb3J0OgogICAgICBgYGBiYXNoCiAgICAgIFJFUE9SVF9GSUxFPSIu"
    "Y2xhdWRlL3JlcG9ydHMvcmV2aWV3LXt0aW1lc3RhbXB9Lm1kIiAgIyBwYXRoIHJldHVybmVkIGJ5"
    "IHJldmlld2VyCiAgICAgICMgRXh0cmFjdCBoYW5kb2ZmIGJsb2NrIChIVE1MIGNvbW1lbnQgc2Vu"
    "dGluZWxzKQogICAgICBIQU5ET0ZGPSQoc2VkIC1uICcvPCEtLSBoYW5kb2ZmLXYxLXN0YXJ0IC0t"
    "Pi8sLzwhLS0gaGFuZG9mZi12MS1lbmQgLS0+L3AnICIkUkVQT1JUX0ZJTEUiIHwgZ3JlcCAtdiAn"
    "PCEtLScpCiAgICAgICMgRXh0cmFjdCB2ZXJkaWN0IChzaW5nbGUgbGluZTogInZlcmRpY3Q6IEZJ"
    "WF9SRVFVSVJFRCIgb3IgInZlcmRpY3Q6IEFQUFJPVkUiKQogICAgICBWRVJESUNUPSQocHJpbnRm"
    "ICclc1xuJyAiJEhBTkRPRkYiIHwgZ3JlcCAnXnZlcmRpY3Q6JyB8IGF3ayAne3ByaW50ICQyfScp"
    "CiAgICAgICMgRXh0cmFjdCBzZXZlcml0eSBjbGFzcwogICAgICBTRVZFUklUWT0kKHByaW50ZiAn"
    "JXNcbicgIiRIQU5ET0ZGIiB8IGdyZXAgJ15zZXZlcml0eV9jbGFzczonIHwgYXdrICd7cHJpbnQg"
    "JDJ9JykKICAgICAgIyBFeHRyYWN0IGZsYWdnZWQgZmlsZXMgbGlzdCAoWUFNTCBsaXN0IGl0ZW1z"
    "OiAiICAtIHBhdGgvdG8vZmlsZS5tZCIpCiAgICAgIEZMQUdHRUQ9JChwcmludGYgJyVzXG4nICIk"
    "SEFORE9GRiIgfCBncmVwICdeXHMqLVxzJyB8IHNlZCAncy9eXHMqLVxzKi8vJykKICAgICAgYGBg"
    "CiAgICAgIElmIGhhbmRvZmYgYmxvY2sgaXMgYWJzZW50IChtb2RlbCBlcnJvciwgaW5zdHJ1Y3Rp"
    "b24gZHJpZnQpOiBmYWxsIHRocm91Z2ggdG8gbWFudWFsIHBhdGg7CiAgICAgIGRvIE5PVCBhdHRl"
    "bXB0IHByb3NlIGZhbGxiYWNrIGV4dHJhY3Rpb24gKGFic2VudCBoYW5kb2ZmID0gbm8gc2NvcGUt"
    "bG9ja2VkIGZpbGUgbGlzdDsKICAgICAgZGlzcGF0Y2hpbmcgd3JpdGVyIHdpdGhvdXQgc2NvcGUg"
    "PSBzY29wZS1sb2NrIHZpb2xhdGlvbiBwZXIgYWdlbnQtc2NvcGUtbG9jay5tZCkuCiAgIGMuIElm"
    "IGBWRVJESUNUID09IEFQUFJPVkVgIOKGkiBleGl0IGxvb3AgKGRvbmUpCiAgIGQuIElmIGBWRVJE"
    "SUNUID09IEZJWF9SRVFVSVJFRGAgQU5EIGBTRVZFUklUWSA9PSBNVVNUX0ZJWGA6CiAgICAgIC0g"
    "SWYgbm8gYHByb2otY29kZS13cml0ZXIte2xhbmd9YCBzcGVjaWFsaXN0IGV4aXN0cyDihpIgKipt"
    "YW51YWwgcGF0aCoqOiBwcmVzZW50IGZpbmRpbmdzIHRvIHVzZXI7CiAgICAgICAgb2ZmZXIgdG8g"
    "cmUtcmV2aWV3IGFmdGVyIG1hbnVhbCBmaXg7IEVYSVQgbG9vcAogICAgICAtIElmIHNwZWNpYWxp"
    "c3QocykgZXhpc3Q6CiAgICAgICAgLSBEZXRlY3QgYHtsYW5nfWAgZnJvbSBmbGFnZ2VkIGZpbGUg"
    "ZXh0ZW5zaW9ucyB1c2luZyBmaWxlbmFtZS1zdWZmaXggcHJpbWFyeSBkZXRlY3Rpb246CiAgICAg"
    "ICAgICBgYGBiYXNoCiAgICAgICAgICAjIEJ1aWxkIGV4dGVuc2lvbiDihpIgc3BlY2lhbGlzdCBt"
    "YXBwaW5nIGZyb20gYXZhaWxhYmxlIGFnZW50cyAoZmlsZW5hbWUtc3VmZml4IHByaW1hcnkpCiAg"
    "ICAgICAgICAjIE5vIHNjb3BlOiBmaWVsZCBpcyBwcmVzZW50IG9uIGFueSBwcm9qLWNvZGUtd3Jp"
    "dGVyLSoubWQgYWdlbnQg4oCUIGRvIE5PVCByZWFkIGZyb250bWF0dGVyCiAgICAgICAgICBkZWNs"
    "YXJlIC1BIEVYVF9UT19XUklURVIKICAgICAgICAgIGZvciBhZ2VudCBpbiAuY2xhdWRlL2FnZW50"
    "cy9wcm9qLWNvZGUtd3JpdGVyLSoubWQ7IGRvCiAgICAgICAgICAgIGxhbmc9JChiYXNlbmFtZSAi"
    "JGFnZW50IiAubWQgfCBzZWQgJ3MvcHJvai1jb2RlLXdyaXRlci0vLycpCiAgICAgICAgICAgIGNh"
    "c2UgIiRsYW5nIiBpbgogICAgICAgICAgICAgIGJhc2gpICAgICAgIEVYVF9UT19XUklURVJbc2hd"
    "PSIkbGFuZyI7IEVYVF9UT19XUklURVJbYmFzaF09IiRsYW5nIiA7OwogICAgICAgICAgICAgIG1h"
    "cmtkb3duKSAgIEVYVF9UT19XUklURVJbbWRdPSIkbGFuZyIgOzsKICAgICAgICAgICAgICBweXRo"
    "b24pICAgICBFWFRfVE9fV1JJVEVSW3B5XT0iJGxhbmciIDs7CiAgICAgICAgICAgICAgdHlwZXNj"
    "cmlwdCkgRVhUX1RPX1dSSVRFUlt0c109IiRsYW5nIiA7OwogICAgICAgICAgICAgIGNzaGFycCkg"
    "ICAgIEVYVF9UT19XUklURVJbY3NdPSIkbGFuZyIgOzsKICAgICAgICAgICAgICAqKSAgICAgICAg"
    "ICBFWFRfVE9fV1JJVEVSWyIkbGFuZyJdPSIkbGFuZyIgOzsKICAgICAgICAgICAgZXNhYwogICAg"
    "ICAgICAgZG9uZQoKICAgICAgICAgICMgQ29sbGVjdCBkaXN0aW5jdCB3cml0ZXIgbmFtZXMgbmVl"
    "ZGVkIGZvciBmbGFnZ2VkIGZpbGVzCiAgICAgICAgICBkZWNsYXJlIC1AIERJU1BBVENIX0xBTkdT"
    "CiAgICAgICAgICB3aGlsZSBJRlM9IHJlYWQgLXIgZnBhdGg7IGRvCiAgICAgICAgICAgIFtbIC16"
    "ICIkZnBhdGgiIF1dICYmIGNvbnRpbnVlCiAgICAgICAgICAgIGV4dD0iJHtmcGF0aCMjKi59Igog"
    "ICAgICAgICAgICB3cml0ZXI9IiR7RVhUX1RPX1dSSVRFUlskZXh0XTotfSIKICAgICAgICAgICAg"
    "W1sgLW4gIiR3cml0ZXIiIF1dICYmIERJU1BBVENIX0xBTkdTWyIkd3JpdGVyIl09IjEiCiAgICAg"
    "ICAgICBkb25lIDw8PCAiJEZMQUdHRUQiCiAgICAgICAgICBgYGAKICAgICAgICAtIEZvciBlYWNo"
    "IGRldGVjdGVkIGB7bGFuZ31gIGluIGBESVNQQVRDSF9MQU5HU2AgKHNlcXVlbnRpYWwg4oCUIG9u"
    "ZSB3cml0ZXIgcGVyIGxhbmd1YWdlKToKICAgICAgICAgIDwhLS0gTE9PUF9JTlRFUkFDVElPTl9F"
    "WENMVVNJVkU6IHdyaXRlciBkaXNwYXRjaGVkIGZyb20gL3JldmlldyBldmFsLW9wdCBsb29wIGlz"
    "IFRpZXItQi4KICAgICAgICAgICAgICAgTXVsdGktcm9sbG91dCAoVGllci1DKSBNVVNUIE5PVCBh"
    "Y3RpdmF0ZSBmb3IgdGhpcyBkaXNwYXRjaCByZWdhcmRsZXNzIG9mIGJhdGNoIGhlYWRlci4KICAg"
    "ICAgICAgICAgICAgUmF0aW9uYWxlOiB0YXJnZXRlZCBjb3JyZWN0aW9uLCBub3QgZXhwbG9yYXRp"
    "dmUgZGl2ZXJzaXR5LgogICAgICAgICAgICAgICBTZWUgbXVsdGktcm9sbG91dC5tZCBJbnZhcmlh"
    "bnQgOC4gLS0+CiAgICAgICAgICAtIENvbmZpcm0gYC5jbGF1ZGUvYWdlbnRzL3Byb2otY29kZS13"
    "cml0ZXIte2xhbmd9Lm1kYCBleGlzdHMgKHNraXAgaWYgYWJzZW50KQogICAgICAgICAgLSBEaXNw"
    "YXRjaCBgcHJvai1jb2RlLXdyaXRlci17bGFuZ31gIHZpYSBgc3ViYWdlbnRfdHlwZT0icHJvai1j"
    "b2RlLXdyaXRlci17bGFuZ30iYCB3aXRoOgogICAgICAgICAgICAtIFNjb3BlOiBPTkxZIGZpbGVz"
    "IGluIGAkRkxBR0dFRGAgbWF0Y2hpbmcgdGhpcyBsYW5nJ3MgZXh0ZW5zaW9ucwogICAgICAgICAg"
    "ICAgICh0cmVhdCBhcyBgIyMjIyBGaWxlc2AgZXF1aXZhbGVudCDigJQgc2NvcGUtbG9jayBjb250"
    "cmFjdCkKICAgICAgICAgICAgLSBDb250ZXh0OiBmdWxsIHJldmlldyByZXBvcnQgcGF0aCArIE1V"
    "U1QgRklYIGZpbmRpbmdzIGV4dHJhY3RlZCBmcm9tIHJlcG9ydAogICAgICAgICAgICAtIFRpZXI6"
    "IEIgKG92ZXJyaWRlIOKAlCBJbnZhcmlhbnQgOCBvZiBtdWx0aS1yb2xsb3V0Lm1kOyBkbyBOT1Qg"
    "cGFzcyBUaWVyOiBDKQogICAgICAgICAgICAtIElmIHdyaXRlciByZXR1cm5zIGBTQ09QRSBFWFBB"
    "TlNJT04gTkVFREVEYCDihpIgc3VyZmFjZSB0byB1c2VyIGltbWVkaWF0ZWx5OwogICAgICAgICAg"
    "ICAgIEVYSVQgbG9vcDsgZG8gTk9UIHJlLWRpc3BhdGNoIHJldmlld2VyCiAgICAgICAgICAtIElm"
    "IGBESVNQQVRDSF9MQU5HU2AgaXMgZW1wdHkgKG5vIHNwZWNpYWxpc3QgbWF0Y2hlcyBhbnkgZmxh"
    "Z2dlZCBleHRlbnNpb24pIOKGkgogICAgICAgICAgICAqKm1hbnVhbCBwYXRoKio6IHByZXNlbnQg"
    "cmV2aWV3IGZpbmRpbmdzIHRvIHVzZXI7IG9mZmVyIHRvIHJlLXJldmlldyBhZnRlcgogICAgICAg"
    "ICAgICBtYW51YWwgZml4OyBFWElUIGxvb3AKICAgICAgICAtIFJlLWRpc3BhdGNoIGBwcm9qLWNv"
    "ZGUtcmV2aWV3ZXJgIHdpdGggc2FtZSBpbnB1dHMgYXMgU3RlcCAzICsgbG9vcF90dXJuIGluamVj"
    "dGVkOgogICAgICAgICAgYCJUaGlzIGlzIHJldmlldyBpdGVyYXRpb24ge2l0ZXJ9IG9mIDMuIGxv"
    "b3BfdHVybjoge2l0ZXJ9LiJgCiAgICAgICAgLSBSZWFkIG5ldyByZXZpZXcgcmVwb3J0OyB1cGRh"
    "dGUgYFZFUkRJQ1RgICsgYFNFVkVSSVRZYCBmcm9tIG5ldyBoYW5kb2ZmIGJsb2NrCiAgIGUuIElm"
    "IGBWRVJESUNUID09IEZJWF9SRVFVSVJFRGAgQU5EIGBTRVZFUklUWSAhPSBNVVNUX0ZJWGAgKFNI"
    "T1VMRF9GSVggb3IgU1RZTEUgb25seSkg4oaSCiAgICAgIHByZXNlbnQgZmluZGluZ3MgdG8gdXNl"
    "cjsgRVhJVCBsb29wIChsb29wIG9ubHkgZmlyZXMgb24gTVVTVF9GSVgpCgogICAqKkxvb3AgZXhp"
    "dCDigJQgaXRlciA9PSAzIEFORCB2ZXJkaWN0IHN0aWxsIGBGSVhfUkVRVUlSRURgOioqCiAgIFBy"
    "ZXNlbnQgZmluYWwgc3RhdGUgdG8gdXNlcjogIjMgcmV2aWV3IGl0ZXJhdGlvbnMgcmVhY2hlZCB3"
    "aXRob3V0IEFQUFJPVkUg4oCUIG1hbnVhbAogICBpbnRlcnZlbnRpb24gcmVxdWlyZWQuIEZpbmFs"
    "IHJldmlldzoge3JlcG9ydF9wYXRofS4gUmVtYWluaW5nIGlzc3Vlczoge0ZMQUdHRUQgZmlsZXN9"
    "LiIKCjwhLS0gcmV2aWV3LWV2YWwtb3B0LWxvb3AtaW5zdGFsbGVkIC0tPg=="
)
STEP7_NEW = base64.b64decode(STEP7_NEW_B64).decode("utf-8")

# Edit D replacement — base64-encoded canonical Anti-Hallucination block
AH_NEW_B64 = (
    "IyMjIEFudGktSGFsbHVjaW5hdGlvbgotIE9ubHkgcmVmZXJlbmNlIHJ1bGVzIHRoYXQgZXhpc3QK"
    "LSBPbmx5IGNpdGUgbGluZXMgdGhhdCBleGlzdAotIFBlciBgbXVsdGktcm9sbG91dC5tZGAgSW52"
    "YXJpYW50IDgsIGFueSBjb2RlLXdyaXRlciBkaXNwYXRjaGVkIGZyb20gdGhpcyBza2lsbCdzIGV2"
    "YWwtb3B0CiAgbG9vcCAoU3RlcCA3KSBpcyBUaWVyLUIgcmVnYXJkbGVzcyBvZiB0aGUgb3JpZ2lu"
    "YWwgdGFzaydzIHRpZXIuIE11bHRpLXJvbGxvdXQgKFRpZXItQykKICBNVVNUIE5PVCBhY3RpdmF0"
    "ZSBmb3IgZXZhbC1vcHQgbG9vcCB3cml0ZXIgZGlzcGF0Y2hlcy4gVGhlIGA8IS0tIExPT1BfSU5U"
    "RVJBQ1RJT05fRVhDTFVTSVZFIC0tPmAKICBjb21tZW50IGluIFN0ZXAgNyBpcyB0aGUgbWFjaGlu"
    "ZS1yZWFkYWJsZSBtYXJrZXIgb2YgdGhpcyBjb25zdHJhaW50LiBJZiBgbXVsdGktcm9sbG91dC5t"
    "ZGAKICBleGlzdHMgaW4gYC5jbGF1ZGUvcnVsZXMvYCwgaXQgaXMgYXV0aG9yaXRhdGl2ZS4gSWYg"
    "YWJzZW50IChtaWdyYXRpb24gMDU3IG5vdCB5ZXQgYXBwbGllZCksCiAgdGhlIGlubGluZSBjb21t"
    "ZW50IGdvdmVybnMuCg=="
)
AH_NEW = base64.b64decode(AH_NEW_B64).decode("utf-8")

# Edit D OLD anchor (the stock 3-line Anti-Hallucination block)
AH_OLD = (
    "### Anti-Hallucination\n"
    "- Only reference rules that exist\n"
    "- Only cite lines that exist"
)

content = path.read_text(encoding="utf-8")

if POST_056_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {path} eval-opt loop already installed (056-3)")
    sys.exit(0)

# Two-pass baseline detection: numbered form OR unnumbered fallback
tier2_a_matched = TIER2_A_NUMBERED in content or TIER2_A_UNNUMBERED in content
tier2_b_matched = TIER2_B in content
tier2_pf_matched = TIER2_PRE_FLIGHT in content

if not (tier2_a_matched and tier2_b_matched and tier2_pf_matched):
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    missing = []
    if not tier2_a_matched: missing.append("Step 7 line (numbered or unnumbered)")
    if not tier2_b_matched: missing.append("Step 6 adjacent anchor")
    if not tier2_pf_matched: missing.append("pre-flight gate baseline")
    print(f"SKIP_HAND_EDITED: {path} body customized post-bootstrap. Missing baseline anchors: {', '.join(missing)}. Manual application required. See migrations/056-review-eval-opt-loop.md Manual-Apply-Guide Step-3. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

# Determine which form of Step 7 is present (normalizes forward to numbered)
step7_pattern = TIER2_A_NUMBERED if TIER2_A_NUMBERED in content else TIER2_A_UNNUMBERED

# ----------------------------------------------------------------------
# Edit A — Pre-flight gate split (regex replace)
# ----------------------------------------------------------------------
# Match: from "## Pre-flight (REQUIRED -- before any other step)" through (exclusive) "## Dispatch Map"
PRE_FLIGHT_OLD = re.compile(
    r"## Pre-flight \(REQUIRED — before any other step\)\n.*?(?=## Dispatch Map)",
    re.DOTALL,
)
new_content, n = PRE_FLIGHT_OLD.subn(PRE_FLIGHT_NEW, content, count=1)
if n == 0:
    print(f"ERROR: {path} pre-flight gate replacement (Edit A) anchor pattern did not match. Manual application required. See Manual-Apply-Guide Step-3.")
    sys.exit(1)
content = new_content

# ----------------------------------------------------------------------
# Edit B — Dispatch Map addition (small inline strings; no special chars)
# ----------------------------------------------------------------------
DISPATCH_MAP_OLD = "- Code review: `proj-code-reviewer`"
DISPATCH_MAP_NEW = (
    "- Code review: `proj-code-reviewer`\n"
    "- Fix dispatch (eval-opt loop): `proj-code-writer-{lang}` (OPTIONAL — dynamic glob;\n"
    "  non-blocking; gracefully absent)"
)

if DISPATCH_MAP_OLD not in content:
    print(f"ERROR: {path} Dispatch Map anchor (Edit B) not found. Manual application required. See Manual-Apply-Guide Step-3.")
    sys.exit(1)

content = content.replace(DISPATCH_MAP_OLD, DISPATCH_MAP_NEW, 1)

# ----------------------------------------------------------------------
# Edit C — Step 7 canonical replacement
# ----------------------------------------------------------------------
if step7_pattern not in content:
    print(f"ERROR: {path} Step 7 anchor (Edit C) lost between Tier 2 detection and replacement. Concurrent edit? Manual application required.")
    sys.exit(1)

content = content.replace(step7_pattern, STEP7_NEW, 1)

# ----------------------------------------------------------------------
# Edit D — Anti-Hallucination addendum
# ----------------------------------------------------------------------
if AH_OLD not in content:
    print(f"WARN: {path} Anti-Hallucination section anchor (Edit D) not found in expected form. Addendum not appended. Skill body may have customized AH section. See Manual-Apply-Guide Step-3 Edit D.")
else:
    content = content.replace(AH_OLD, AH_NEW.rstrip("\n"), 1)

path.write_text(content, encoding="utf-8")
print(f"PATCHED: {path} all 4 coordinated edits applied (056-3)")
PY_056_STEP3
```

### Step 4 — Patch /review SKILL.md (templates/skills/review/SKILL.md)

Same three-tier logic as Step 3, applied to the template source-of-truth path.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Step 4 mirrors Step 3 against the templates/ source-of-truth path. Same base64
# replacement strategy — see Step 3 header for refactor rationale.

python3 <<'PY_056_STEP4'
import base64
import sys
import re
from pathlib import Path

path = Path("templates/skills/review/SKILL.md")
backup = Path(str(path) + ".bak-056")

POST_056_SENTINEL = "<!-- review-eval-opt-loop-installed -->"

TIER2_A_NUMBERED   = "7. Issues found → fix → re-review"
TIER2_A_UNNUMBERED = "Issues found → fix → re-review"
TIER2_B            = "6. Present review results to user"
TIER2_PRE_FLIGHT   = "If `.claude/agents/<agent-name>.md` does NOT exist → STOP."

# Edit A replacement — same canonical pre-flight block as Step 3
PRE_FLIGHT_NEW_B64 = (
    "IyMgUHJlLWZsaWdodCAoUkVRVUlSRUQg4oCUIGJlZm9yZSBhbnkgb3RoZXIgc3RlcCkKCioqQmxv"
    "Y2tpbmcgYWdlbnRzKiogKFNUT1AgaWYgbWlzc2luZyDigJQgcmV2aWV3IGNhbm5vdCBwcm9jZWVk"
    "IHdpdGhvdXQgdGhlc2UpOgotIGBwcm9qLWNvZGUtcmV2aWV3ZXJgIOKAlCBJZiBgLmNsYXVkZS9h"
    "Z2VudHMvcHJvai1jb2RlLXJldmlld2VyLm1kYCBkb2VzIE5PVCBleGlzdCDihpIgU1RPUC4KICBU"
    "ZWxsIHVzZXI6ICJSZXF1aXJlZCBhZ2VudCBwcm9qLWNvZGUtcmV2aWV3ZXIgbWlzc2luZy4gUnVu"
    "IC9taWdyYXRlLWJvb3RzdHJhcCBvciAvbW9kdWxlLXdyaXRlLiIKICBEbyBOT1QgcHJvY2VlZC4g"
    "RG8gTk9UIGZhbGwgYmFjayB0byBpbmxpbmUgd29yay4gRG8gTk9UIHN1YnN0aXR1dGUgYW5vdGhl"
    "ciBhZ2VudC4KCioqT3B0aW9uYWwgYWdlbnRzKiogKFdBUk4gaWYgbWlzc2luZyDigJQgcmV2aWV3"
    "IHByb2NlZWRzOyBldmFsLW9wdCBmaXggbG9vcCBkZWdyYWRlcyBncmFjZWZ1bGx5KToKLSBgcHJv"
    "ai1jb2RlLXdyaXRlci17bGFuZ31gIOKAlCBJZiBubyBgLmNsYXVkZS9hZ2VudHMvcHJvai1jb2Rl"
    "LXdyaXRlci0qLm1kYCBleGlzdHMg4oaSCiAgV0FSTjogIk5vIGNvZGUtd3JpdGVyIHNwZWNpYWxp"
    "c3QgZm91bmQuIC9yZXZpZXcgd2lsbCBydW4gYnV0IHRoZSBldmFsLW9wdCBmaXggbG9vcAogIChT"
    "dGVwIDcpIHdpbGwgc2tpcCBhdXRvbWF0aWMgZml4IGRpc3BhdGNoLiBSdW4gL2V2b2x2ZS1hZ2Vu"
    "dHMgdG8gY3JlYXRlIGEgc3BlY2lhbGlzdC4iCiAgQ29udGludWUgd2l0aCBTdGVwIDEuCgo="
)
PRE_FLIGHT_NEW = base64.b64decode(PRE_FLIGHT_NEW_B64).decode("utf-8")

# Edit C replacement — same canonical Step 7 block as Step 3
STEP7_NEW_B64 = (
    "Ny4gRXZhbHVhdG9yLW9wdGltaXplciBsb29wIDwhLS0gQ09OVkVSR0VOQ0UtUVVBTElUWTogY2Fw"
    "PTMsIHNpZ25hbD1BUFBST1ZFIC0tPgoKICAgKipQcmUtZmxpZ2h0IGdhdGUgKGJlZm9yZSBsb29w"
    "KToqKgogICAtIGBwcm9qLWNvZGUtcmV2aWV3ZXJgIGFic2VudCDihpIgU1RPUCAoYmxvY2tpbmcg"
    "4oCUIGFscmVhZHkgZW5mb3JjZWQgYnkgcHJlLWZsaWdodCBnYXRlIGFib3ZlKQogICAtIGBwcm9q"
    "LWNvZGUtd3JpdGVyLXtsYW5nfWAgYWJzZW50IOKGkiBXQVJOIG9ubHkgKG5vbi1ibG9ja2luZyDi"
    "gJQgbG9vcCBkZWdyYWRlcyB0byBtYW51YWwgcGF0aCBiZWxvdykKICAgLSBgbG9vcGJhY2stYnVk"
    "Z2V0Lm1kYCBhYnNlbnQg4oaSIFdBUk46ICJtaWdyYXRpb24gMDUwIHJlcXVpcmVkIGZvciBDT05W"
    "RVJHRU5DRS1RVUFMSVRZIGFubm90YXRpb24iCgogICAqKkxvb3Agc3RhdGU6KiogYGl0ZXI9MGAK"
    "CiAgICoqTG9vcCBib2R5KiogKHJlcGVhdCB3aGlsZSBgdmVyZGljdCA9PSBSRVFVRVNUIENIQU5H"
    "RVNgIEFORCBgaXRlciA8IDNgKToKICAgYS4gSW5jcmVtZW50OiBgaXRlcj0kKChpdGVyICsgMSkp"
    "YAogICBiLiBQYXJzZSBgZmxhZ2dlZF9maWxlczpgIGZyb20gdGhlIHJldmlld2VyJ3MgaGFuZG9m"
    "ZiBibG9jayBhdCBlbmQgb2YgcmVwb3J0OgogICAgICBgYGBiYXNoCiAgICAgIFJFUE9SVF9GSUxF"
    "PSIuY2xhdWRlL3JlcG9ydHMvcmV2aWV3LXt0aW1lc3RhbXB9Lm1kIiAgIyBwYXRoIHJldHVybmVk"
    "IGJ5IHJldmlld2VyCiAgICAgICMgRXh0cmFjdCBoYW5kb2ZmIGJsb2NrIChIVE1MIGNvbW1lbnQg"
    "c2VudGluZWxzKQogICAgICBIQU5ET0ZGPSQoc2VkIC1uICcvPCEtLSBoYW5kb2ZmLXYxLXN0YXJ0"
    "IC0tPi8sLzwhLS0gaGFuZG9mZi12MS1lbmQgLS0+L3AnICIkUkVQT1JUX0ZJTEUiIHwgZ3JlcCAt"
    "diAnPCEtLScpCiAgICAgICMgRXh0cmFjdCB2ZXJkaWN0IChzaW5nbGUgbGluZTogInZlcmRpY3Q6"
    "IEZJWF9SRVFVSVJFRCIgb3IgInZlcmRpY3Q6IEFQUFJPVkUiKQogICAgICBWRVJESUNUPSQocHJp"
    "bnRmICclc1xuJyAiJEhBTkRPRkYiIHwgZ3JlcCAnXnZlcmRpY3Q6JyB8IGF3ayAne3ByaW50ICQy"
    "fScpCiAgICAgICMgRXh0cmFjdCBzZXZlcml0eSBjbGFzcwogICAgICBTRVZFUklUWT0kKHByaW50"
    "ZiAnJXNcbicgIiRIQU5ET0ZGIiB8IGdyZXAgJ15zZXZlcml0eV9jbGFzczonIHwgYXdrICd7cHJp"
    "bnQgJDJ9JykKICAgICAgIyBFeHRyYWN0IGZsYWdnZWQgZmlsZXMgbGlzdCAoWUFNTCBsaXN0IGl0"
    "ZW1zOiAiICAtIHBhdGgvdG8vZmlsZS5tZCIpCiAgICAgIEZMQUdHRUQ9JChwcmludGYgJyVzXG4n"
    "ICIkSEFORE9GRiIgfCBncmVwICdeXHMqLVxzJyB8IHNlZCAncy9eXHMqLVxzKi8vJykKICAgICAg"
    "YGBgCiAgICAgIElmIGhhbmRvZmYgYmxvY2sgaXMgYWJzZW50IChtb2RlbCBlcnJvciwgaW5zdHJ1"
    "Y3Rpb24gZHJpZnQpOiBmYWxsIHRocm91Z2ggdG8gbWFudWFsIHBhdGg7CiAgICAgIGRvIE5PVCBh"
    "dHRlbXB0IHByb3NlIGZhbGxiYWNrIGV4dHJhY3Rpb24gKGFic2VudCBoYW5kb2ZmID0gbm8gc2Nv"
    "cGUtbG9ja2VkIGZpbGUgbGlzdDsKICAgICAgZGlzcGF0Y2hpbmcgd3JpdGVyIHdpdGhvdXQgc2Nv"
    "cGUgPSBzY29wZS1sb2NrIHZpb2xhdGlvbiBwZXIgYWdlbnQtc2NvcGUtbG9jay5tZCkuCiAgIGMu"
    "IElmIGBWRVJESUNUID09IEFQUFJPVkVgIOKGkiBleGl0IGxvb3AgKGRvbmUpCiAgIGQuIElmIGBW"
    "RVJESUNUID09IEZJWF9SRVFVSVJFRGAgQU5EIGBTRVZFUklUWSA9PSBNVVNUX0ZJWGA6CiAgICAg"
    "IC0gSWYgbm8gYHByb2otY29kZS13cml0ZXIte2xhbmd9YCBzcGVjaWFsaXN0IGV4aXN0cyDihpIg"
    "KiptYW51YWwgcGF0aCoqOiBwcmVzZW50IGZpbmRpbmdzIHRvIHVzZXI7CiAgICAgICAgb2ZmZXIg"
    "dG8gcmUtcmV2aWV3IGFmdGVyIG1hbnVhbCBmaXg7IEVYSVQgbG9vcAogICAgICAtIElmIHNwZWNp"
    "YWxpc3QocykgZXhpc3Q6CiAgICAgICAgLSBEZXRlY3QgYHtsYW5nfWAgZnJvbSBmbGFnZ2VkIGZp"
    "bGUgZXh0ZW5zaW9ucyB1c2luZyBmaWxlbmFtZS1zdWZmaXggcHJpbWFyeSBkZXRlY3Rpb246CiAg"
    "ICAgICAgICBgYGBiYXNoCiAgICAgICAgICAjIEJ1aWxkIGV4dGVuc2lvbiDihpIgc3BlY2lhbGlz"
    "dCBtYXBwaW5nIGZyb20gYXZhaWxhYmxlIGFnZW50cyAoZmlsZW5hbWUtc3VmZml4IHByaW1hcnkp"
    "CiAgICAgICAgICAjIE5vIHNjb3BlOiBmaWVsZCBpcyBwcmVzZW50IG9uIGFueSBwcm9qLWNvZGUt"
    "d3JpdGVyLSoubWQgYWdlbnQg4oCUIGRvIE5PVCByZWFkIGZyb250bWF0dGVyCiAgICAgICAgICBk"
    "ZWNsYXJlIC1BIEVYVF9UT19XUklURVIKICAgICAgICAgIGZvciBhZ2VudCBpbiAuY2xhdWRlL2Fn"
    "ZW50cy9wcm9qLWNvZGUtd3JpdGVyLSoubWQ7IGRvCiAgICAgICAgICAgIGxhbmc9JChiYXNlbmFt"
    "ZSAiJGFnZW50IiAubWQgfCBzZWQgJ3MvcHJvai1jb2RlLXdyaXRlci0vLycpCiAgICAgICAgICAg"
    "IGNhc2UgIiRsYW5nIiBpbgogICAgICAgICAgICAgIGJhc2gpICAgICAgIEVYVF9UT19XUklURVJb"
    "c2hdPSIkbGFuZyI7IEVYVF9UT19XUklURVJbYmFzaF09IiRsYW5nIiA7OwogICAgICAgICAgICAg"
    "IG1hcmtkb3duKSAgIEVYVF9UT19XUklURVJbbWRdPSIkbGFuZyIgOzsKICAgICAgICAgICAgICBw"
    "eXRob24pICAgICBFWFRfVE9fV1JJVEVSW3B5XT0iJGxhbmciIDs7CiAgICAgICAgICAgICAgdHlw"
    "ZXNjcmlwdCkgRVhUX1RPX1dSSVRFUlt0c109IiRsYW5nIiA7OwogICAgICAgICAgICAgIGNzaGFy"
    "cCkgICAgIEVYVF9UT19XUklURVJbY3NdPSIkbGFuZyIgOzsKICAgICAgICAgICAgICAqKSAgICAg"
    "ICAgICBFWFRfVE9fV1JJVEVSWyIkbGFuZyJdPSIkbGFuZyIgOzsKICAgICAgICAgICAgZXNhYwog"
    "ICAgICAgICAgZG9uZQoKICAgICAgICAgICMgQ29sbGVjdCBkaXN0aW5jdCB3cml0ZXIgbmFtZXMg"
    "bmVlZGVkIGZvciBmbGFnZ2VkIGZpbGVzCiAgICAgICAgICBkZWNsYXJlIC1BIERJU1BBVENIX0xB"
    "TkdTCiAgICAgICAgICB3aGlsZSBJRlM9IHJlYWQgLXIgZnBhdGg7IGRvCiAgICAgICAgICAgIFtb"
    "IC16ICIkZnBhdGgiIF1dICYmIGNvbnRpbnVlCiAgICAgICAgICAgIGV4dD0iJHtmcGF0aCMjKi59"
    "IgogICAgICAgICAgICB3cml0ZXI9IiR7RVhUX1RPX1dSSVRFUlskZXh0XTotfSIKICAgICAgICAg"
    "ICAgW1sgLW4gIiR3cml0ZXIiIF1dICYmIERJU1BBVENIX0xBTkdTWyIkd3JpdGVyIl09IjEiCiAg"
    "ICAgICAgICBkb25lIDw8PCAiJEZMQUdHRUQiCiAgICAgICAgICBgYGAKICAgICAgICAtIEZvciBl"
    "YWNoIGRldGVjdGVkIGB7bGFuZ31gIGluIGBESVNQQVRDSF9MQU5HU2AgKHNlcXVlbnRpYWwg4oCU"
    "IG9uZSB3cml0ZXIgcGVyIGxhbmd1YWdlKToKICAgICAgICAgIDwhLS0gTE9PUF9JTlRFUkFDVElP"
    "Tl9FWENMVVNJVkU6IHdyaXRlciBkaXNwYXRjaGVkIGZyb20gL3JldmlldyBldmFsLW9wdCBsb29w"
    "IGlzIFRpZXItQi4KICAgICAgICAgICAgICAgTXVsdGktcm9sbG91dCAoVGllci1DKSBNVVNUIE5P"
    "VCBhY3RpdmF0ZSBmb3IgdGhpcyBkaXNwYXRjaCByZWdhcmRsZXNzIG9mIGJhdGNoIGhlYWRlci4K"
    "ICAgICAgICAgICAgICAgUmF0aW9uYWxlOiB0YXJnZXRlZCBjb3JyZWN0aW9uLCBub3QgZXhwbG9y"
    "YXRpdmUgZGl2ZXJzaXR5LgogICAgICAgICAgICAgICBTZWUgbXVsdGktcm9sbG91dC5tZCBJbnZh"
    "cmlhbnQgOC4gLS0+CiAgICAgICAgICAtIENvbmZpcm0gYC5jbGF1ZGUvYWdlbnRzL3Byb2otY29k"
    "ZS13cml0ZXIte2xhbmd9Lm1kYCBleGlzdHMgKHNraXAgaWYgYWJzZW50KQogICAgICAgICAgLSBE"
    "aXNwYXRjaCBgcHJvai1jb2RlLXdyaXRlci17bGFuZ31gIHZpYSBgc3ViYWdlbnRfdHlwZT0icHJv"
    "ai1jb2RlLXdyaXRlci17bGFuZ30iYCB3aXRoOgogICAgICAgICAgICAtIFNjb3BlOiBPTkxZIGZp"
    "bGVzIGluIGAkRkxBR0dFRGAgbWF0Y2hpbmcgdGhpcyBsYW5nJ3MgZXh0ZW5zaW9ucwogICAgICAg"
    "ICAgICAgICh0cmVhdCBhcyBgIyMjIyBGaWxlc2AgZXF1aXZhbGVudCDigJQgc2NvcGUtbG9jayBj"
    "b250cmFjdCkKICAgICAgICAgICAgLSBDb250ZXh0OiBmdWxsIHJldmlldyByZXBvcnQgcGF0aCAr"
    "IE1VU1QgRklYIGZpbmRpbmdzIGV4dHJhY3RlZCBmcm9tIHJlcG9ydAogICAgICAgICAgICAtIFRp"
    "ZXI6IEIgKG92ZXJyaWRlIOKAlCBJbnZhcmlhbnQgOCBvZiBtdWx0aS1yb2xsb3V0Lm1kOyBkbyBO"
    "T1QgcGFzcyBUaWVyOiBDKQogICAgICAgICAgICAtIElmIHdyaXRlciByZXR1cm5zIGBTQ09QRSBF"
    "WFBBTlNJT04gTkVFREVEYCDihpIgc3VyZmFjZSB0byB1c2VyIGltbWVkaWF0ZWx5OwogICAgICAg"
    "ICAgICAgIEVYSVQgbG9vcDsgZG8gTk9UIHJlLWRpc3BhdGNoIHJldmlld2VyCiAgICAgICAgICAt"
    "IElmIGBESVNQQVRDSF9MQU5HU2AgaXMgZW1wdHkgKG5vIHNwZWNpYWxpc3QgbWF0Y2hlcyBhbnkg"
    "ZmxhZ2dlZCBleHRlbnNpb24pIOKGkgogICAgICAgICAgICAqKm1hbnVhbCBwYXRoKio6IHByZXNl"
    "bnQgcmV2aWV3IGZpbmRpbmdzIHRvIHVzZXI7IG9mZmVyIHRvIHJlLXJldmlldyBhZnRlcgogICAg"
    "ICAgICAgICBtYW51YWwgZml4OyBFWElUIGxvb3AKICAgICAgICAtIFJlLWRpc3BhdGNoIGBwcm9q"
    "LWNvZGUtcmV2aWV3ZXJgIHdpdGggc2FtZSBpbnB1dHMgYXMgU3RlcCAzICsgbG9vcF90dXJuIGlu"
    "amVjdGVkOgogICAgICAgICAgYCJUaGlzIGlzIHJldmlldyBpdGVyYXRpb24ge2l0ZXJ9IG9mIDMu"
    "IGxvb3BfdHVybjoge2l0ZXJ9LiJgCiAgICAgICAgLSBSZWFkIG5ldyByZXZpZXcgcmVwb3J0OyB1"
    "cGRhdGUgYFZFUkRJQ1RgICsgYFNFVkVSSVRZYCBmcm9tIG5ldyBoYW5kb2ZmIGJsb2NrCiAgIGUu"
    "IElmIGBWRVJESUNUID09IEZJWF9SRVFVSVJFRGAgQU5EIGBTRVZFUklUWSAhPSBNVVNUX0ZJWGAg"
    "KFNIT1VMRF9GSVggb3IgU1RZTEUgb25seSkg4oaSCiAgICAgIHByZXNlbnQgZmluZGluZ3MgdG8g"
    "dXNlcjsgRVhJVCBsb29wIChsb29wIG9ubHkgZmlyZXMgb24gTVVTVF9GSVgpCgogICAqKkxvb3Ag"
    "ZXhpdCDigJQgaXRlciA9PSAzIEFORCB2ZXJkaWN0IHN0aWxsIGBGSVhfUkVRVUlSRURgOioqCiAg"
    "IFByZXNlbnQgZmluYWwgc3RhdGUgdG8gdXNlcjogIjMgcmV2aWV3IGl0ZXJhdGlvbnMgcmVhY2hl"
    "ZCB3aXRob3V0IEFQUFJPVkUg4oCUIG1hbnVhbAogICBpbnRlcnZlbnRpb24gcmVxdWlyZWQuIEZp"
    "bmFsIHJldmlldzoge3JlcG9ydF9wYXRofS4gUmVtYWluaW5nIGlzc3Vlczoge0ZMQUdHRUQgZmls"
    "ZXN9LiIKCjwhLS0gcmV2aWV3LWV2YWwtb3B0LWxvb3AtaW5zdGFsbGVkIC0tPg=="
)
STEP7_NEW = base64.b64decode(STEP7_NEW_B64).decode("utf-8")

# Edit D replacement — same canonical Anti-Hallucination block as Step 3
AH_NEW_B64 = (
    "IyMjIEFudGktSGFsbHVjaW5hdGlvbgotIE9ubHkgcmVmZXJlbmNlIHJ1bGVzIHRoYXQgZXhpc3QK"
    "LSBPbmx5IGNpdGUgbGluZXMgdGhhdCBleGlzdAotIFBlciBgbXVsdGktcm9sbG91dC5tZGAgSW52"
    "YXJpYW50IDgsIGFueSBjb2RlLXdyaXRlciBkaXNwYXRjaGVkIGZyb20gdGhpcyBza2lsbCdzIGV2"
    "YWwtb3B0CiAgbG9vcCAoU3RlcCA3KSBpcyBUaWVyLUIgcmVnYXJkbGVzcyBvZiB0aGUgb3JpZ2lu"
    "YWwgdGFzaydzIHRpZXIuIE11bHRpLXJvbGxvdXQgKFRpZXItQykKICBNVVNUIE5PVCBhY3RpdmF0"
    "ZSBmb3IgZXZhbC1vcHQgbG9vcCB3cml0ZXIgZGlzcGF0Y2hlcy4gVGhlIGA8IS0tIExPT1BfSU5U"
    "RVJBQ1RJT05fRVhDTFVTSVZFIC0tPmAKICBjb21tZW50IGluIFN0ZXAgNyBpcyB0aGUgbWFjaGlu"
    "ZS1yZWFkYWJsZSBtYXJrZXIgb2YgdGhpcyBjb25zdHJhaW50LiBJZiBgbXVsdGktcm9sbG91dC5t"
    "ZGAKICBleGlzdHMgaW4gYC5jbGF1ZGUvcnVsZXMvYCwgaXQgaXMgYXV0aG9yaXRhdGl2ZS4gSWYg"
    "YWJzZW50IChtaWdyYXRpb24gMDU3IG5vdCB5ZXQgYXBwbGllZCksCiAgdGhlIGlubGluZSBjb21t"
    "ZW50IGdvdmVybnMuCg=="
)
AH_NEW = base64.b64decode(AH_NEW_B64).decode("utf-8")

AH_OLD = (
    "### Anti-Hallucination\n"
    "- Only reference rules that exist\n"
    "- Only cite lines that exist"
)

content = path.read_text(encoding="utf-8")

if POST_056_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {path} eval-opt loop already installed (056-4)")
    sys.exit(0)

tier2_a_matched = TIER2_A_NUMBERED in content or TIER2_A_UNNUMBERED in content
tier2_b_matched = TIER2_B in content
tier2_pf_matched = TIER2_PRE_FLIGHT in content

if not (tier2_a_matched and tier2_b_matched and tier2_pf_matched):
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    missing = []
    if not tier2_a_matched: missing.append("Step 7 line (numbered or unnumbered)")
    if not tier2_b_matched: missing.append("Step 6 adjacent anchor")
    if not tier2_pf_matched: missing.append("pre-flight gate baseline")
    print(f"SKIP_HAND_EDITED: {path} body customized post-bootstrap. Missing baseline anchors: {', '.join(missing)}. Manual application required. See migrations/056-review-eval-opt-loop.md Manual-Apply-Guide Step-3 (templates/ uses identical logic). Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

step7_pattern = TIER2_A_NUMBERED if TIER2_A_NUMBERED in content else TIER2_A_UNNUMBERED

# Edit A
PRE_FLIGHT_OLD = re.compile(
    r"## Pre-flight \(REQUIRED — before any other step\)\n.*?(?=## Dispatch Map)",
    re.DOTALL,
)
new_content, n = PRE_FLIGHT_OLD.subn(PRE_FLIGHT_NEW, content, count=1)
if n == 0:
    print(f"ERROR: {path} pre-flight gate replacement anchor did not match. Manual application required.")
    sys.exit(1)
content = new_content

# Edit B
DISPATCH_MAP_OLD = "- Code review: `proj-code-reviewer`"
DISPATCH_MAP_NEW = (
    "- Code review: `proj-code-reviewer`\n"
    "- Fix dispatch (eval-opt loop): `proj-code-writer-{lang}` (OPTIONAL — dynamic glob;\n"
    "  non-blocking; gracefully absent)"
)

if DISPATCH_MAP_OLD not in content:
    print(f"ERROR: {path} Dispatch Map anchor not found. Manual application required.")
    sys.exit(1)

content = content.replace(DISPATCH_MAP_OLD, DISPATCH_MAP_NEW, 1)

# Edit C
if step7_pattern not in content:
    print(f"ERROR: {path} Step 7 anchor lost between detection and replacement.")
    sys.exit(1)

content = content.replace(step7_pattern, STEP7_NEW, 1)

# Edit D
if AH_OLD not in content:
    print(f"WARN: {path} Anti-Hallucination section anchor not found in expected form. Addendum not appended.")
else:
    content = content.replace(AH_OLD, AH_NEW.rstrip("\n"), 1)

path.write_text(content, encoding="utf-8")
print(f"PATCHED: {path} all 4 coordinated edits applied (056-4)")
PY_056_STEP4
```

### Step 5 — Companion export with divergence guard

Per gap-resolution-1-4-2 Section A: companion export uses LIVE `.claude/` copy (not template) to preserve client customizations. Divergence guard compares `.claude/` vs `templates/`; if diverged, WARN + still export `.claude/` (client's customization is authoritative for companion mirror).

```bash
#!/usr/bin/env bash
set -euo pipefail

LIVE_SKILL=".claude/skills/review/SKILL.md"
TMPL_SKILL="templates/skills/review/SKILL.md"
LIVE_AGENT=".claude/agents/proj-code-reviewer.md"
TMPL_AGENT="templates/agents/proj-code-reviewer.md"

# Resolve companion directory
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"

# Guard: confirm migration patch was applied to LIVE copy (not template only)
if ! grep -q "<!-- review-eval-opt-loop-installed -->" "$LIVE_SKILL" 2>/dev/null; then
  printf "SKIP companion export: sentinel missing from %s — re-run migration patch steps\n" "$LIVE_SKILL"
  exit 0
fi
if ! grep -q "<!-- structured-handoff-v1-installed -->" "$LIVE_AGENT" 2>/dev/null; then
  printf "SKIP companion export: sentinel missing from %s — re-run migration patch steps\n" "$LIVE_AGENT"
  exit 0
fi

# Divergence guard for SKILL.md
if [[ -f "$TMPL_SKILL" ]] && ! diff -q "$LIVE_SKILL" "$TMPL_SKILL" >/dev/null 2>&1; then
  printf "WARN: %s diverges from %s\n" "$LIVE_SKILL" "$TMPL_SKILL"
  printf "      This is expected if you have project-specific customizations.\n"
  printf "      Exporting the LIVE copy (.claude/) to companion — NOT the template.\n"
fi

# Divergence guard for proj-code-reviewer.md
if [[ -f "$TMPL_AGENT" ]] && ! diff -q "$LIVE_AGENT" "$TMPL_AGENT" >/dev/null 2>&1; then
  printf "WARN: %s diverges from %s\n" "$LIVE_AGENT" "$TMPL_AGENT"
  printf "      Exporting the LIVE copy (.claude/) to companion — NOT the template.\n"
fi

if [[ -d "$COMPANION_DIR" ]]; then
  mkdir -p "$COMPANION_DIR/.claude/skills/review" "$COMPANION_DIR/.claude/agents"
  cp "$LIVE_SKILL" "$COMPANION_DIR/.claude/skills/review/SKILL.md"
  cp "$LIVE_AGENT" "$COMPANION_DIR/.claude/agents/proj-code-reviewer.md"

  if grep -q "<!-- review-eval-opt-loop-installed -->" "$COMPANION_DIR/.claude/skills/review/SKILL.md" 2>/dev/null \
     && grep -q "<!-- structured-handoff-v1-installed -->" "$COMPANION_DIR/.claude/agents/proj-code-reviewer.md" 2>/dev/null; then
    printf "Companion export: PASS (live copies of /review skill + proj-code-reviewer agent exported)\n"
  else
    printf "WARN: Companion export wrote files but sentinels missing — check write permissions on %s\n" "$COMPANION_DIR"
  fi
else
  printf "Companion export: SKIP (no companion dir at %s — project may not use companion sync)\n" "$COMPANION_DIR"
fi
```

### Step 6 — Migration verification self-test (6 tests)

Verbatim per gap-resolution-1-2-6 Section C: builds synthetic reviewer reports, exercises the extraction patterns the skill body uses, asserts each field round-trips correctly. Fails loudly on any test mismatch.

```bash
#!/usr/bin/env bash
# Migration 056 — Extraction self-test
# Verifies that the handoff block extraction pattern works correctly against a
# synthetic reviewer report. Fails loudly if extraction returns empty verdict.
set -euo pipefail

printf "=== Migration 056 extraction self-test ===\n"

SELFTEST_REPORT=$(mktemp)
APPROVE_REPORT=$(mktemp)
trap 'rm -f "$SELFTEST_REPORT" "$APPROVE_REPORT"' EXIT

# Write a synthetic reviewer report with a known handoff block
cat > "$SELFTEST_REPORT" << 'SYNTHETIC_REPORT'
### Pipeline Completeness: COMPLETE

### Issues

MUST FIX
- Missing annotation — .claude/skills/review/SKILL.md:84

SHOULD FIX
- (none)

CONSIDER
- (none)

### Security: PASS

### Architecture: PASS

### Positives
- Step structure is well-organized

### Verdict: REQUEST CHANGES
<!-- handoff-v1-start -->
verdict: FIX_REQUIRED
severity_class: MUST_FIX
flagged_files:
  - .claude/skills/review/SKILL.md
top_reason: "Missing annotation — .claude/skills/review/SKILL.md:84"
loop_turn: 0
type: review-finding
<!-- handoff-v1-end -->
SYNTHETIC_REPORT

# Test 1: extract full handoff block
HANDOFF=$(sed -n '/<!-- handoff-v1-start -->/,/<!-- handoff-v1-end -->/p' "$SELFTEST_REPORT" | grep -v '<!--')

if [[ -z "$HANDOFF" ]]; then
  printf "FAIL: handoff block extraction returned empty — sed pattern did not match.\n"
  printf "      Verify report file ends with LF (not CRLF) and sentinels are on their own lines.\n"
  exit 1
fi

# Test 2: extract verdict field
VERDICT=$(printf '%s\n' "$HANDOFF" | grep '^verdict:' | awk '{print $2}')
if [[ "$VERDICT" != "FIX_REQUIRED" ]]; then
  printf "FAIL: verdict extraction returned '%s' — expected 'FIX_REQUIRED'.\n" "$VERDICT"
  exit 1
fi

# Test 3: extract flagged_files list (non-empty for FIX_REQUIRED)
FLAGGED=$(printf '%s\n' "$HANDOFF" | grep '^\s*-\s' | sed 's/^\s*-\s*//')
if [[ -z "$FLAGGED" ]]; then
  printf "FAIL: flagged_files extraction returned empty — expected at least one file.\n"
  exit 1
fi

# Test 4: extract severity_class
SEVERITY=$(printf '%s\n' "$HANDOFF" | grep '^severity_class:' | awk '{print $2}')
if [[ "$SEVERITY" != "MUST_FIX" ]]; then
  printf "FAIL: severity_class extraction returned '%s' — expected 'MUST_FIX'.\n" "$SEVERITY"
  exit 1
fi

# Test 5: APPROVE report — flagged_files must be empty list
cat > "$APPROVE_REPORT" << 'APPROVE_SYNTHETIC'
### Verdict: APPROVE
<!-- handoff-v1-start -->
verdict: APPROVE
severity_class: NONE
flagged_files: []
top_reason: ""
loop_turn: 0
type: review-finding
<!-- handoff-v1-end -->
APPROVE_SYNTHETIC

APPROVE_HANDOFF=$(sed -n '/<!-- handoff-v1-start -->/,/<!-- handoff-v1-end -->/p' "$APPROVE_REPORT" | grep -v '<!--')
APPROVE_VERDICT=$(printf '%s\n' "$APPROVE_HANDOFF" | grep '^verdict:' | awk '{print $2}')
if [[ "$APPROVE_VERDICT" != "APPROVE" ]]; then
  printf "FAIL: APPROVE report verdict extraction returned '%s' — expected 'APPROVE'.\n" "$APPROVE_VERDICT"
  exit 1
fi

# Test 6: Verify sentinels present in patched files (confirms blocks were written)
if ! grep -q "<!-- review-eval-opt-loop-installed -->" ".claude/skills/review/SKILL.md" 2>/dev/null; then
  printf "FAIL: eval-opt-loop sentinel not found in .claude/skills/review/SKILL.md\n"
  printf "      Three-tier patch may have failed or emitted SKIP. Check migration output.\n"
  exit 1
fi

if ! grep -q "<!-- structured-handoff-v1-installed -->" ".claude/agents/proj-code-reviewer.md" 2>/dev/null; then
  printf "FAIL: structured-handoff-v1 sentinel not found in .claude/agents/proj-code-reviewer.md\n"
  printf "      Reviewer agent extension may have failed or emitted SKIP.\n"
  exit 1
fi

printf "PASS: All 6 extraction self-tests passed.\n"
printf "  - Handoff block extraction: OK\n"
printf "  - verdict field extraction (FIX_REQUIRED): OK\n"
printf "  - flagged_files extraction (non-empty): OK\n"
printf "  - severity_class extraction (MUST_FIX): OK\n"
printf "  - APPROVE report verdict extraction: OK\n"
printf "  - Migration sentinels present in patched files: OK\n"
```

### Step 7 — Update bootstrap-state.json

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '056'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '056') or a == '056' for a in applied):
    applied.append({
        'id': '056',
        'applied_at': state['last_applied'],
        'description': 'Adds structured handoff block to proj-code-reviewer and CONVERGENCE-QUALITY loop in /review skill Step 7. Reviewer emits YAML handoff block (verdict, severity_class, flagged_files); skill body extracts via sed and re-dispatches proj-code-writer-{lang} as Tier-B (LOOP_INTERACTION_EXCLUSIVE) until APPROVE or cap=3.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=056')
PY

printf "MIGRATION 056 APPLIED\n"
```

### Rules for migration scripts

- **Read-before-write** — every destructive step reads the target file, runs three-tier detection, and only writes on the safe-patch tier. Destructive writes always create `.bak-056` backup before overwrite (per `.claude/rules/general.md` Migration Preservation Discipline).
- **Idempotent** — re-running prints `SKIP_ALREADY_APPLIED` per step and `SKIP: migration 056 already applied` at the top when all sentinels are present in both `.claude/` and `templates/` copies.
- **Self-contained** — all reviewer Structured Handoff Block content + Step 7 canonical block + pre-flight gate split + Anti-Hallucination addendum + companion export logic + verification self-test are inlined via single-quoted heredocs (`<<'PY'`, `<<'EOF'`, `<<'SYNTHETIC_REPORT'`, `<<'APPROVE_SYNTHETIC'`) so `${...}` and `` ` `` characters in embedded content ship verbatim. No external fetch.
- **No gitignored-path fetch** — migration body is fully inlined; no fetch from bootstrap repo at runtime.
- **Compound baseline anchor with stripped-prefix fallback** — per gap-resolution-1-4-2 Section D, Step 7 baseline detection accepts both numbered (`7. Issues found → fix → re-review`) and unnumbered (`Issues found → fix → re-review`) forms — covers step-renumber drift from prior migrations. Migration 054 stripped-prefix fallback pattern (lines 36-38) is the precedent.
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on failure.
- **Scope lock** — touches only: `.claude/agents/proj-code-reviewer.md`, `.claude/skills/review/SKILL.md`, `templates/agents/proj-code-reviewer.md`, `templates/skills/review/SKILL.md`, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no other agent or skill bodies. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `.claude/rules/agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. Reviewer agent (.claude/) carries Structured Handoff Block sentinel
if grep -q "<!-- structured-handoff-v1-installed -->" .claude/agents/proj-code-reviewer.md 2>/dev/null; then
  printf "PASS: .claude/agents/proj-code-reviewer.md carries structured-handoff-v1-installed sentinel\n"
else
  printf "FAIL: .claude/agents/proj-code-reviewer.md missing structured-handoff-v1-installed sentinel\n"
  fail=1
fi

# 2. Reviewer template (templates/) carries Structured Handoff Block sentinel
if grep -q "<!-- structured-handoff-v1-installed -->" templates/agents/proj-code-reviewer.md 2>/dev/null; then
  printf "PASS: templates/agents/proj-code-reviewer.md carries structured-handoff-v1-installed sentinel\n"
else
  printf "FAIL: templates/agents/proj-code-reviewer.md missing structured-handoff-v1-installed sentinel\n"
  fail=1
fi

# 3. Reviewer agent body contains Structured Handoff Block heading
for f in .claude/agents/proj-code-reviewer.md templates/agents/proj-code-reviewer.md; do
  if grep -q "^### Structured Handoff Block" "$f" 2>/dev/null; then
    printf "PASS: %s contains Structured Handoff Block heading\n" "$f"
  else
    printf "FAIL: %s missing Structured Handoff Block heading\n" "$f"
    fail=1
  fi
done

# 4. Reviewer agent body contains handoff-v1-start sentinel pair
for f in .claude/agents/proj-code-reviewer.md templates/agents/proj-code-reviewer.md; do
  if grep -q "handoff-v1-start" "$f" 2>/dev/null && grep -q "handoff-v1-end" "$f" 2>/dev/null; then
    printf "PASS: %s contains handoff-v1-start/end sentinel pair\n" "$f"
  else
    printf "FAIL: %s missing handoff-v1-start/end sentinel pair\n" "$f"
    fail=1
  fi
done

# 5. /review skill (.claude/) carries eval-opt-loop sentinel
if grep -q "<!-- review-eval-opt-loop-installed -->" .claude/skills/review/SKILL.md 2>/dev/null; then
  printf "PASS: .claude/skills/review/SKILL.md carries review-eval-opt-loop-installed sentinel\n"
else
  printf "FAIL: .claude/skills/review/SKILL.md missing review-eval-opt-loop-installed sentinel\n"
  fail=1
fi

# 6. /review skill template carries eval-opt-loop sentinel
if grep -q "<!-- review-eval-opt-loop-installed -->" templates/skills/review/SKILL.md 2>/dev/null; then
  printf "PASS: templates/skills/review/SKILL.md carries review-eval-opt-loop-installed sentinel\n"
else
  printf "FAIL: templates/skills/review/SKILL.md missing review-eval-opt-loop-installed sentinel\n"
  fail=1
fi

# 7. /review skill body contains CONVERGENCE-QUALITY annotation on Step 7
for f in .claude/skills/review/SKILL.md templates/skills/review/SKILL.md; do
  if grep -q "CONVERGENCE-QUALITY: cap=3, signal=APPROVE" "$f" 2>/dev/null; then
    printf "PASS: %s carries CONVERGENCE-QUALITY annotation\n" "$f"
  else
    printf "FAIL: %s missing CONVERGENCE-QUALITY annotation\n" "$f"
    fail=1
  fi
done

# 8. /review skill body contains LOOP_INTERACTION_EXCLUSIVE comment
for f in .claude/skills/review/SKILL.md templates/skills/review/SKILL.md; do
  if grep -q "LOOP_INTERACTION_EXCLUSIVE" "$f" 2>/dev/null; then
    printf "PASS: %s carries LOOP_INTERACTION_EXCLUSIVE comment\n" "$f"
  else
    printf "FAIL: %s missing LOOP_INTERACTION_EXCLUSIVE comment\n" "$f"
    fail=1
  fi
done

# 9. /review skill body contains pre-flight gate split (Blocking + Optional)
for f in .claude/skills/review/SKILL.md templates/skills/review/SKILL.md; do
  if grep -q "Blocking agents" "$f" 2>/dev/null && grep -q "Optional agents" "$f" 2>/dev/null; then
    printf "PASS: %s carries pre-flight gate split (Blocking/Optional)\n" "$f"
  else
    printf "FAIL: %s missing pre-flight gate split\n" "$f"
    fail=1
  fi
done

# 10. /review skill body contains Dispatch Map addition
for f in .claude/skills/review/SKILL.md templates/skills/review/SKILL.md; do
  if grep -q "Fix dispatch (eval-opt loop)" "$f" 2>/dev/null; then
    printf "PASS: %s carries Dispatch Map fix-dispatch row\n" "$f"
  else
    printf "FAIL: %s missing Dispatch Map fix-dispatch row\n" "$f"
    fail=1
  fi
done

# 11. /review skill body contains Anti-Hallucination addendum (Invariant 8 reminder)
for f in .claude/skills/review/SKILL.md templates/skills/review/SKILL.md; do
  if grep -q "multi-rollout.md Invariant 8" "$f" 2>/dev/null; then
    printf "PASS: %s carries Anti-Hallucination Invariant 8 addendum\n" "$f"
  else
    printf "FAIL: %s missing Anti-Hallucination Invariant 8 addendum\n" "$f"
    fail=1
  fi
done

# 12. /review skill body no longer carries the legacy single-line Step 7
for f in .claude/skills/review/SKILL.md templates/skills/review/SKILL.md; do
  # The exact stock line "7. Issues found → fix → re-review" should be gone (replaced by full block)
  # The new block contains "7. Evaluator-optimizer loop" instead
  if grep -q "^7\. Evaluator-optimizer loop" "$f" 2>/dev/null; then
    printf "PASS: %s Step 7 replaced with Evaluator-optimizer loop\n" "$f"
  else
    printf "FAIL: %s Step 7 not replaced (Evaluator-optimizer loop heading absent)\n" "$f"
    fail=1
  fi
done

# 13. YAML frontmatter parses for both reviewer copies
for agent in .claude/agents/proj-code-reviewer.md templates/agents/proj-code-reviewer.md; do
  if python3 -c "
import sys, yaml
with open('$agent') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
    printf "PASS: %s YAML frontmatter parses\n" "$agent"
  else
    printf "FAIL: %s YAML frontmatter invalid\n" "$agent"
    fail=1
  fi
done

# 14. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "056" ]]; then
  printf "PASS: last_migration = 056\n"
else
  printf "FAIL: last_migration = %s (expected 056)\n" "$last"
  fail=1
fi

printf -- "---\n"
if [[ $fail -eq 0 ]]; then
  printf "Migration 056 verification: ALL PASS\n"
  printf "\nOptional cleanup: remove .bak-056 backups once you've confirmed patches are correct:\n"
  printf "  find . -name '*.bak-056' -delete\n"
else
  printf "Migration 056 verification: FAILURES — state NOT updated\n"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix. `SKIP_HAND_EDITED` from any destructive step will cause the corresponding verify-step to FAIL — resolve by applying the relevant `## Manual-Apply-Guide` section, then re-run verify.

---

## State Update

On success:
- `last_migration` → `"056"`
- append `{ "id": "056", "applied_at": "<ISO8601>", "description": "Adds structured handoff block to proj-code-reviewer and CONVERGENCE-QUALITY loop in /review skill Step 7. Reviewer emits YAML handoff block (verdict, severity_class, flagged_files); skill body extracts via sed and re-dispatches proj-code-writer-{lang} as Tier-B (LOOP_INTERACTION_EXCLUSIVE) until APPROVE or cap=3." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Top-level — every patched file carries its sentinel in BOTH `.claude/` and `templates/` copies → `SKIP: migration 056 already applied`
- Step 1 (reviewer .claude/) — `<!-- structured-handoff-v1-installed -->` present → `SKIP_ALREADY_APPLIED`
- Step 2 (reviewer templates/) — `<!-- structured-handoff-v1-installed -->` present → `SKIP_ALREADY_APPLIED`
- Step 3 (skill .claude/) — `<!-- review-eval-opt-loop-installed -->` present → `SKIP_ALREADY_APPLIED`
- Step 4 (skill templates/) — `<!-- review-eval-opt-loop-installed -->` present → `SKIP_ALREADY_APPLIED`
- Step 5 (companion export) — sentinel-guarded; runs only if patch applied
- Step 6 (self-test) — runs every time; passes deterministically against synthetic fixtures
- Step 7 (`applied[]` dedup check, migration id == `'056'`) → no duplicate append

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply remain `SKIP_HAND_EDITED` on re-run (baseline anchors absent + post-migration sentinel absent) — manual merge per `## Manual-Apply-Guide` is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-056 backups (written by destructive steps before overwrite)
for bak in \
  .claude/agents/proj-code-reviewer.md.bak-056 \
  templates/agents/proj-code-reviewer.md.bak-056 \
  .claude/skills/review/SKILL.md.bak-056 \
  templates/skills/review/SKILL.md.bak-056; do
  if [[ -f "$bak" ]]; then
    orig="${bak%.bak-056}"
    mv "$bak" "$orig"
    printf "Restored: %s\n" "$orig"
  fi
done

# Option B — tracked strategy (if files are committed to project repo)
# git restore .claude/agents/proj-code-reviewer.md .claude/skills/review/SKILL.md \
#             templates/agents/proj-code-reviewer.md templates/skills/review/SKILL.md

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '056':
    state['last_migration'] = '055'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '056') or a == '056'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=055')
PY
```

Notes:
- `.bak-056` restore is safe because each destructive step writes the backup before overwrite. Files that hit `SKIP_HAND_EDITED` (baseline anchor absent) wrote a backup before reporting the skip — the rollback restores the original content.
- After rollback, the sentinels appended at insertion sites are gone (the entire pre-migration content is restored from backups). No manual sentinel removal needed.
- No additive files (no new files created by this migration) — rollback is purely backup restore + state reset.

---

## Manual-Apply-Guide

When a destructive step reports `SKIP_HAND_EDITED: <path>`, the migration detected that the target was customized post-bootstrap (baseline anchor absent + post-migration sentinel absent). Automatic patching is unsafe — content would be lost. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the changes while preserving your customizations.

**General procedure per skipped step**:
1. Open the target file.
2. Locate the section / block / anchor named in the merge instructions for that step.
3. Read the new content block below for that step.
4. Manually merge: preserve your project-specific additions (extra steps, custom comments, additional sections); incorporate the new content from the migration.
5. Save the file.
6. Append the post-migration sentinel where indicated (each section below specifies the exact sentinel string).
7. Run the verification snippet shown at the end of each subsection to confirm the patch landed correctly.
8. A `.bak-056` backup of the pre-migration file state exists at `<path>.bak-056`; use `diff <path>.bak-056 <path>` to see exactly what changed.

---

### §Step-1 — Reviewer Structured Handoff Block (`.claude/agents/proj-code-reviewer.md` + `templates/agents/proj-code-reviewer.md`)

**Target**: append after the closing fence (```` ``` ````) of `## 7. Report Format` block (after `### Verdict: {APPROVE | REQUEST CHANGES}` line + closing ```` ``` ````), and BEFORE the `### Log-Ready Finding Schema` heading.

**Context**: the migration detected that the file's Report Format section has been customized post-bootstrap — required baseline anchors `### Verdict: {APPROVE | REQUEST CHANGES}` AND `### Log-Ready Finding Schema` are not both present in stock form.

**New content (verbatim — insert after Report Format closing fence)**:

```markdown

### Structured Handoff Block (machine-parseable — append at END of every report)

After the `### Verdict:` line, append the following block verbatim to the report file.
This block is the machine interface consumed by the `/review` skill's eval-opt loop.
Schema version: v1. Schema changes require a new migration + sentinel bump.

​```
<!-- handoff-v1-start -->
verdict: {APPROVE | FIX_REQUIRED}
severity_class: {MUST_FIX | SHOULD_FIX | STYLE | NONE}
flagged_files:
  - {file path from first MUST FIX finding, relative to project root}
  - {file path from second MUST FIX finding — repeat for each distinct file in MUST FIX}
top_reason: "{copy verbatim the first MUST FIX bullet text, truncated to 120 chars}"
loop_turn: {value from dispatch prompt — default 0 if not provided}
type: review-finding
<!-- handoff-v1-end -->
​```

**Field population rules (follow exactly — every field required):**

1. `verdict:`
   - `APPROVE` if zero `MUST FIX` items
   - `FIX_REQUIRED` if one or more `MUST FIX` items present
   - Never: `REQUEST CHANGES` (that is prose — use `FIX_REQUIRED`)

2. `severity_class:`
   - `MUST_FIX` if one or more `MUST FIX` bullets exist in `### Issues`
   - `SHOULD_FIX` if no `MUST FIX` but one or more `SHOULD FIX` bullets exist
   - `STYLE` if only `CONSIDER` bullets exist
   - `NONE` if `### Issues` is empty and verdict is `APPROVE`

3. `flagged_files:` (YAML list — one item per line, each prefixed `  - `)
   - Include ONLY files mentioned in `MUST FIX` bullets (format: `- {issue} — {file}:{line}`)
   - Extract the `{file}` portion from each `MUST FIX` bullet
   - If MUST FIX bullets reference a file multiple times → include the file ONCE (deduplicate)
   - If verdict is `APPROVE` → write `flagged_files: []` (empty YAML list, single line)
   - Include all dependency files if the MUST FIX finding explicitly says "requires change in {other-file}"

4. `top_reason:` (quoted string — double quotes required)
   - Copy the first `MUST FIX` bullet text verbatim
   - Truncate to 120 characters if longer; append `...` if truncated
   - If verdict is `APPROVE` → `top_reason: ""`

5. `loop_turn:` (integer)
   - Read from dispatch prompt field `loop_turn: N` if present
   - If not provided in dispatch prompt → use `0`
   - Do not increment — copy the value as-is; the orchestrator tracks iteration count

6. `type:`
   - Always `review-finding` for `proj-code-reviewer` reports

**Coupling note:** This block is consumed by `/review` skill Step 7 eval-opt loop via
`sed -n '/<!-- handoff-v1-start -->/,/<!-- handoff-v1-end -->/p'` extraction.
Any format change to this block requires a new migration + sentinel bump to `v2`.
The sentinel `<!-- structured-handoff-v1-installed -->` in this file marks that
this section has been applied.

<!-- structured-handoff-v1-installed -->
```

NOTE: Triple-backticks in the verbatim block above are shown as `​```` (with zero-width space markers) in this guide so they don't break the surrounding code-fence. When you copy the block, replace `​```` with plain ```` ``` ````.

**Merge instructions**:
1. Open the target file (`.claude/agents/proj-code-reviewer.md` AND `templates/agents/proj-code-reviewer.md` — apply the same change to both).
2. Locate the closing fence of the `## 7. Report Format` code-block. The Report Format block ends with `### Verdict: {APPROVE | REQUEST CHANGES}` line followed by ```` ``` ```` closing fence.
3. Insert the verbatim block above immediately after the closing fence and before the next heading (`### Log-Ready Finding Schema`).
4. Append `<!-- structured-handoff-v1-installed -->` sentinel at end of the inserted block (already present in verbatim block).
5. Save the file.

**Verification**:
```bash
grep -q "<!-- structured-handoff-v1-installed -->" .claude/agents/proj-code-reviewer.md && echo "PASS: .claude/"
grep -q "<!-- structured-handoff-v1-installed -->" templates/agents/proj-code-reviewer.md && echo "PASS: templates/"
grep -q "^### Structured Handoff Block" .claude/agents/proj-code-reviewer.md && echo "PASS: heading"
```

---

### §Step-3 — /review SKILL.md combined patch (`.claude/skills/review/SKILL.md` + `templates/skills/review/SKILL.md`)

**Target**: four coordinated edits to the same file. Edits A-D ship under one sentinel `<!-- review-eval-opt-loop-installed -->`.

**Context**: the migration detected that the file's body has been customized post-bootstrap — required baseline anchors (`If \`.claude/agents/<agent-name>.md\` does NOT exist → STOP.`, `6. Present review results to user`, `7. Issues found → fix → re-review` OR stripped-prefix variant `Issues found → fix → re-review`) are not all present.

#### Edit A — Pre-flight gate split (replace lines 14-17 of stock SKILL.md)

**Stock content to replace** (the entire `## Pre-flight (REQUIRED — before any other step)` block, from the heading through the line `Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.`, up to but NOT including the next `## Dispatch Map` heading):

```
## Pre-flight (REQUIRED — before any other step)
If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.
```

**Replace with (verbatim)**:

```markdown
## Pre-flight (REQUIRED — before any other step)

**Blocking agents** (STOP if missing — review cannot proceed without these):
- `proj-code-reviewer` — If `.claude/agents/proj-code-reviewer.md` does NOT exist → STOP.
  Tell user: "Required agent proj-code-reviewer missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

**Optional agents** (WARN if missing — review proceeds; eval-opt fix loop degrades gracefully):
- `proj-code-writer-{lang}` — If no `.claude/agents/proj-code-writer-*.md` exists →
  WARN: "No code-writer specialist found. /review will run but the eval-opt fix loop
  (Step 7) will skip automatic fix dispatch. Run /evolve-agents to create a specialist."
  Continue with Step 1.
```

#### Edit B — Dispatch Map addition (after `Code review:` row)

**Stock content to find**:

```
- Code review: `proj-code-reviewer`
```

**Replace with**:

```
- Code review: `proj-code-reviewer`
- Fix dispatch (eval-opt loop): `proj-code-writer-{lang}` (OPTIONAL — dynamic glob;
  non-blocking; gracefully absent)
```

#### Edit C — Step 7 canonical replacement (replace single line `7. Issues found → fix → re-review`)

**Stock content to replace** (one line):

```
7. Issues found → fix → re-review
```

**Replace with (verbatim)**:

```markdown
7. Evaluator-optimizer loop <!-- CONVERGENCE-QUALITY: cap=3, signal=APPROVE -->

   **Pre-flight gate (before loop):**
   - `proj-code-reviewer` absent → STOP (blocking — already enforced by pre-flight gate above)
   - `proj-code-writer-{lang}` absent → WARN only (non-blocking — loop degrades to manual path below)
   - `loopback-budget.md` absent → WARN: "migration 050 required for CONVERGENCE-QUALITY annotation"

   **Loop state:** `iter=0`

   **Loop body** (repeat while `verdict == REQUEST CHANGES` AND `iter < 3`):
   a. Increment: `iter=$((iter + 1))`
   b. Parse `flagged_files:` from the reviewer's handoff block at end of report:
      (See full extraction logic in the migration body — sed extraction of HTML-comment-delimited handoff block + grep/awk per-field extraction)
      If handoff block is absent (model error, instruction drift): fall through to manual path;
      do NOT attempt prose fallback extraction (absent handoff = no scope-locked file list;
      dispatching writer without scope = scope-lock violation per agent-scope-lock.md).
   c. If `VERDICT == APPROVE` → exit loop (done)
   d. If `VERDICT == FIX_REQUIRED` AND `SEVERITY == MUST_FIX`:
      - If no `proj-code-writer-{lang}` specialist exists → manual path: present findings to user;
        offer to re-review after manual fix; EXIT loop
      - If specialist(s) exist:
        - Detect `{lang}` from flagged file extensions using filename-suffix primary detection
          (build EXT_TO_WRITER from glob of `.claude/agents/proj-code-writer-*.md`; case-mapped
          `.sh`/`.bash`→bash, `.md`→markdown, `.py`→python, `.ts`→typescript, `.cs`→csharp;
          NEVER read `scope:` from agent frontmatter — field does not exist on any deployed agent)
        - For each detected `{lang}` in DISPATCH_LANGS (sequential — one writer per language):
          <!-- LOOP_INTERACTION_EXCLUSIVE: writer dispatched from /review eval-opt loop is Tier-B.
               Multi-rollout (Tier-C) MUST NOT activate for this dispatch regardless of batch header.
               Rationale: targeted correction, not explorative diversity.
               See multi-rollout.md Invariant 8. -->
          - Confirm `.claude/agents/proj-code-writer-{lang}.md` exists (skip if absent)
          - Dispatch `proj-code-writer-{lang}` via `subagent_type="proj-code-writer-{lang}"` with:
            - Scope: ONLY files in `$FLAGGED` matching this lang's extensions
              (treat as `#### Files` equivalent — scope-lock contract)
            - Context: full review report path + MUST FIX findings extracted from report
            - Tier: B (override — Invariant 8 of multi-rollout.md; do NOT pass Tier: C)
            - If writer returns `SCOPE EXPANSION NEEDED` → surface to user immediately;
              EXIT loop; do NOT re-dispatch reviewer
        - Re-dispatch `proj-code-reviewer` with same inputs as Step 3 + loop_turn injected:
          `"This is review iteration {iter} of 3. loop_turn: {iter}."`
        - Read new review report; update VERDICT + SEVERITY from new handoff block
   e. If `VERDICT == FIX_REQUIRED` AND `SEVERITY != MUST_FIX` (SHOULD_FIX or STYLE only) →
      present findings to user; EXIT loop (loop only fires on MUST_FIX)

   **Loop exit — iter == 3 AND verdict still `FIX_REQUIRED`:**
   Present final state to user: "3 review iterations reached without APPROVE — manual
   intervention required. Final review: {report_path}. Remaining issues: {FLAGGED files}."

<!-- review-eval-opt-loop-installed -->
```

For the FULL canonical Step 7 block (with verbatim bash extraction code), refer to the migration body Step 3 `STEP7_NEW` heredoc — that is byte-identical to what an automatic patch writes; copy from there for completeness.

#### Edit D — Anti-Hallucination addendum (append to existing list)

**Stock content to find**:

```markdown
### Anti-Hallucination
- Only reference rules that exist
- Only cite lines that exist
```

**Replace with (verbatim — append two new bullets)**:

```markdown
### Anti-Hallucination
- Only reference rules that exist
- Only cite lines that exist
- Per `multi-rollout.md` Invariant 8, any code-writer dispatched from this skill's eval-opt
  loop (Step 7) is Tier-B regardless of the original task's tier. Multi-rollout (Tier-C)
  MUST NOT activate for eval-opt loop writer dispatches. The `<!-- LOOP_INTERACTION_EXCLUSIVE -->`
  comment in Step 7 is the machine-readable marker of this constraint. If `multi-rollout.md`
  exists in `.claude/rules/`, it is authoritative. If absent (migration 057 not yet applied),
  the inline comment governs.
```

**Merge instructions for all four edits**:
1. Open the target file (`.claude/skills/review/SKILL.md` AND `templates/skills/review/SKILL.md` — apply the same changes to both).
2. Apply Edits A, B, C, D in order. Each edit has a stock-content-to-replace block + a replacement block above.
3. The sentinel `<!-- review-eval-opt-loop-installed -->` is part of Edit C's replacement (placed at end of the Step 7 block). Do NOT add a separate sentinel for the other edits — all four edits ship under this single sentinel.
4. Save the file.

**Verification** (run after applying all four edits to both files):
```bash
for f in .claude/skills/review/SKILL.md templates/skills/review/SKILL.md; do
  grep -q "<!-- review-eval-opt-loop-installed -->" "$f" && echo "PASS sentinel: $f"
  grep -q "CONVERGENCE-QUALITY: cap=3, signal=APPROVE" "$f" && echo "PASS CONVERGENCE-QUALITY: $f"
  grep -q "LOOP_INTERACTION_EXCLUSIVE" "$f" && echo "PASS LOOP_INTERACTION_EXCLUSIVE: $f"
  grep -q "Blocking agents" "$f" && echo "PASS Blocking-Optional split: $f"
  grep -q "Fix dispatch (eval-opt loop)" "$f" && echo "PASS Dispatch Map: $f"
  grep -q "multi-rollout.md Invariant 8" "$f" && echo "PASS Anti-Hallucination addendum: $f"
done
```

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:

1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the templates at `templates/agents/proj-code-reviewer.md` and `templates/skills/review/SKILL.md` are already in the target state after the paired bootstrap edits — the migration's Step 2 + Step 4 patch the templates directly).
2. Do NOT directly edit any of those files in the bootstrap repo's `.claude/` directory — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "056",
  "file": "056-review-eval-opt-loop.md",
  "title": "Review skill eval-opt loop with structured handoff block",
  "description": "Adds structured handoff block to proj-code-reviewer and CONVERGENCE-QUALITY loop in /review skill Step 7. Reviewer emits YAML handoff block (verdict, severity_class, flagged_files); skill body extracts via sed and re-dispatches proj-code-writer-{lang} as Tier-B (LOOP_INTERACTION_EXCLUSIVE) until APPROVE or cap=3.",
  "applies_to": "bootstrapped projects with /review skill",
  "added_date": "2026-04-27"
}
```
