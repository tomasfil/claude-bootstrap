#!/usr/bin/env bash
set -euo pipefail

# verify-templates-seeded.sh — verify templates/ matches manifest.json checksums
#
# Reads templates/manifest.json; for every skill and agent entry checks:
#   1. File exists at the declared source path
#   2. sha256 matches the stored hash
# Prints PASS: N files verified  OR  FAIL: {list of mismatches}
# Exit 0 on PASS, exit 1 on FAIL.
#
# Run from repo root: bash scripts/verify-templates-seeded.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MANIFEST="templates/manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
    printf 'FAIL: %s not found\n' "$MANIFEST" >&2
    exit 1
fi

command -v python3 >/dev/null 2>&1 || {
    printf 'FAIL: python3 required for JSON parsing and sha256\n' >&2
    exit 1
}

# Delegate all verification to python3 — avoids CRLF issues from mapfile + process substitution
# on Windows MINGW64 bash.
python3 - "$MANIFEST" <<'PYEOF'
import json, sys, hashlib, os, pathlib

manifest_path = sys.argv[1]
repo_root = pathlib.Path(manifest_path).parent.parent

with open(manifest_path) as f:
    manifest = json.load(f)

failures = []
pass_count = 0

def sha256_of(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def check(label, src, expected_hash):
    global pass_count
    full = repo_root / src
    if not full.exists():
        failures.append(f"MISSING: {src}")
        return
    actual = sha256_of(full)
    if actual != expected_hash:
        failures.append(f"SHA256 MISMATCH: {src} — expected={expected_hash} actual={actual}")
    else:
        pass_count += 1

for s in manifest.get('skills', []):
    check(f"skill:{s['name']}", s['source'], s['sha256'])
    # Also verify each reference file listed under the skill
    for ref in s.get('references', []) or []:
        check(f"skill-ref:{s['name']}:{ref['source']}", ref['source'], ref['sha256'])

for a in manifest.get('agents', []):
    check(f"agent:{a['name']}", a['source'], a['sha256'])

for t in manifest.get('agent-templates', []):
    check(f"agent-template:{t['name']}", t['source'], t['sha256'])

total = pass_count + len(failures)

if not failures:
    print(f"PASS: {pass_count} files verified")
    sys.exit(0)
else:
    print(f"FAIL: {len(failures)}/{total} files failed verification")
    for f in failures:
        print(f"  {f}")
    sys.exit(1)
PYEOF
