# LSP Reference

## Why LSP Plugins Need Complementary Rules

LSP plugins are pure configuration shims — they tell Claude Code how to
start and communicate with a language server, but they provide zero
behavioral guidance. Without rules, Claude Code will have access to LSP
operations but no instruction on when to use them, how to interpret results,
or when to prefer other approaches (like Grep). Complementary rules bridge
this gap.

## LSP Operations

| Operation | Purpose | Best For |
|-----------|---------|----------|
| `goToDefinition` | Jump to where a symbol is defined | Understanding implementation, navigating to source |
| `findReferences` | Find all usages of a symbol | Impact analysis, refactoring safety checks |
| `goToImplementation` | Jump to concrete implementations of an interface/abstract | Understanding polymorphism, finding actual behavior |
| `hover` | Get type information and documentation for a symbol | Quick type checks, reading inline docs |
| `documentSymbol` | List all symbols in a file | File structure overview, finding functions/classes |
| `workspaceSymbol` | Search symbols across the entire workspace | Finding symbols by name project-wide |
| `prepareCallHierarchy` | Initialize call hierarchy analysis for a symbol | Setting up incoming/outgoing call analysis |
| `incomingCalls` | Find all callers of a function | Understanding who depends on a function |
| `outgoingCalls` | Find all functions called by a function | Understanding a function's dependencies |

## Language Server Capabilities Matrix

| Operation | C# | Python | TS/JS | Go | Rust | Java | C/C++ |
|-----------|-----|--------|-------|-----|------|------|-------|
| goToDefinition | Excellent | Good | Excellent | Excellent | Excellent | Good | Good* |
| findReferences | Excellent | Good | Excellent | Excellent | Excellent | Good | Good* |
| goToImplementation | Excellent | Limited^1 | Good | Excellent | Good | Good | Limited^2 |
| hover | Excellent | Good | Excellent | Excellent | Excellent | Good | Good |
| documentSymbol | Excellent | Good | Excellent | Excellent | Excellent | Good | Good |
| workspaceSymbol | Good | Good | Good | Excellent | Good | Good | Limited^3 |
| prepareCallHierarchy | Good | Limited^4 | Good | Excellent | Good | Good | Limited |
| incomingCalls | Good | Limited^4 | Good | Excellent | Good | Good | Limited |
| outgoingCalls | Good | Limited^4 | Good | Excellent | Good | Good | Limited |

**Footnotes:**
1. Python: Dynamic typing limits implementation resolution. Duck typing
   means Pyright cannot always resolve concrete implementations.
2. C/C++: Requires compile_commands.json for accurate cross-TU resolution.
   Without it, results are incomplete.
3. C/C++: Workspace symbol search depends heavily on index quality and
   compile_commands.json completeness.
4. Python: Call hierarchy support is limited in Pyright. Results may be
   incomplete for dynamically dispatched calls.

\* C/C++ operations marked with asterisk require compile_commands.json —
without it, many operations fail silently.

## Performance Characteristics

| Metric | Fastest | Slowest |
|--------|---------|---------|
| Startup time | Go (gopls) — near instant | Java (jdtls) — ~8 seconds |
| Memory usage | Go (~100MB) | Java (~1GB+), Rust (~500MB+) |
| Query response | Go, TypeScript | Java (initial queries) |
| Most reliable | Go, TypeScript, C# | C/C++ (depends on build config) |

## Workspace Requirements

Language servers fail silently without proper workspace configuration.
Ensure these files exist before expecting LSP to function:

| Language | Required Files | Notes |
|----------|---------------|-------|
| TypeScript/JS | `tsconfig.json` or `jsconfig.json` | Without this, TS server uses default config |
| Python | `pyrightconfig.json` or `pyproject.toml` with [tool.pyright] | Virtual env must be detectable |
| Go | `go.mod` | Must be at workspace root or parent |
| C# | `.sln` or `.csproj` | OmniSharp needs a project entry point |
| Rust | `Cargo.toml` | Must be at workspace root |
| Java | `pom.xml`, `build.gradle`, or `.project` | jdtls needs a build system |
| C/C++ | `compile_commands.json` | Generate with CMake, Bear, or compiledb |
| Ruby | `Gemfile` | ruby-lsp needs Bundler context |
| Swift | `Package.swift` or `.xcodeproj` | sourcekit-lsp needs project structure |
| Lua | `.luarc.json` | Server uses defaults without it |
| Kotlin | `build.gradle.kts` or `pom.xml` | JVM build system required |
| PHP | `composer.json` | Intelephense works without it but with reduced accuracy |

## When to Use LSP vs Grep

### Use LSP When
- You need **type-aware symbol analysis** — findReferences returns semantic
  references, not string matches
- You need **goToDefinition** — follows imports, resolves aliases, handles
  re-exports
- You need **call hierarchy** — who calls this function, what does this
  function call
- You need **hover information** — type signatures, documentation, parameter
  info
- You are working within a **single language** with a running server

### Use Grep When
- Searching for **string literals**, config keys, or environment variables
- Searching with **regex patterns** that are not symbol-based
- Searching **cross-language** (e.g., a constant used in both Python and JS)
- Searching **comments**, log messages, or documentation
- The language server is **not running** or not installed
- You need results **fast** without waiting for server initialization

### Combined Approach
LSP requires exact file positions — it cannot search. The standard workflow
is:

1. **Grep/Glob** to locate the symbol or file
2. **LSP** to analyze it (find references, check types, trace calls)

This two-step pattern gives you both breadth (Grep finds candidates across
the codebase) and depth (LSP provides semantic understanding of each match).
