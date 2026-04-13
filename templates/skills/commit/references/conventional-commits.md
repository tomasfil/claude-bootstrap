# Conventional Commits Reference

## Format
```
type(scope): description

[optional body]

[optional footer(s)]
```

## Types
| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behavior change |
| `test` | Adding or fixing tests |
| `docs` | Documentation only |
| `chore` | Build, CI, tooling changes |
| `style` | Formatting, whitespace (no logic change) |
| `perf` | Performance improvement |

## Rules
- Subject line < 72 chars
- Imperative mood: "Add X" not "Added X"
- Body explains WHY not WHAT
- One logical change per commit
- No secrets, no large binaries
- Stage specific files, not `git add .`
