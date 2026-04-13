# Debug Checklist

## Before Investigating
- [ ] Get exact error message (copy-paste, not paraphrase)
- [ ] Identify when it started (last known working state)
- [ ] Check if it's a regression (`git log`, `git bisect`)

## During Investigation
- [ ] Read the actual code at the error location
- [ ] Trace the call stack from error → entry point
- [ ] Check recent changes: `git diff HEAD~5`
- [ ] Check `.learnings/log.md` for prior similar issues
- [ ] Verify assumptions: types, null checks, env vars

## Common Root Causes
| Symptom | Likely Cause | Check |
|---------|-------------|-------|
| "undefined" / null | Missing initialization | Grep for the variable assignment |
| Type error | Wrong import or version mismatch | Check package.json, tsconfig |
| Timeout | Async without await, infinite loop | Grep for async calls without await |
| 404 / route not found | Route registration order | Read route config file |
| "permission denied" | File/API access | Check chmod, API keys, tokens |

## After Fixing
- [ ] Write a test that reproduces the original bug
- [ ] Run surrounding tests to check for regressions
- [ ] Log the fix to `.learnings/log.md` if it's a pattern
- [ ] After 2 failed attempts: search the web
