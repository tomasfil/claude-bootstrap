# LSP Reference

## Why LSP Plugins Need Complementary Rules

LSP plugins are **pure configuration shims** — they tell Claude Code which language server to use for which file types. Unlike other plugins (skills, agents, MCP) which are self-describing, LSP plugins add **zero behavioral guidance**. Without explicit rules in `.claude/rules/lsp-guidance.md`, Claude defaults to Grep for symbol analysis even when LSP would give precise, type-aware results.

## When to Use LSP vs Grep

| Use LSP for | Use Grep for |
|-------------|-------------|
| "What uses this symbol?" (type-aware) | String literals, config keys |
| "Where is this defined?" | Regex patterns |
| "What implements this interface?" | Cross-language search |
| "What type is this?" | Comments, log messages |
| "What symbols are in this file?" | Partial name matches |

LSP requires an exact position (file, line, character). Use Grep/Glob to locate the symbol first, then LSP to analyze it.

## LSP Operations

| Operation | Purpose | Best for |
|-----------|---------|----------|
| `goToDefinition` | Jump to where a symbol is defined | Understanding unfamiliar code |
| `findReferences` | All usages of a symbol (type-aware) | Impact analysis, refactoring |
| `goToImplementation` | Concrete implementations of interfaces | Interface-heavy languages (C#, Java) |
| `hover` | Type info and documentation | Dynamic languages (Python), complex generics (Rust) |
| `documentSymbol` | All symbols in a file | File structure overview |
| `workspaceSymbol` | Search symbols by name across project | Finding symbols without knowing their file |
| `prepareCallHierarchy` | Establish call graph entry point | Pre-step for incoming/outgoing calls |
| `incomingCalls` | Which functions call this function | Tracing callers, blast radius |
| `outgoingCalls` | Which functions this function calls | Understanding dependencies |

## Language Server Capabilities Matrix

| Operation | C# | Python | TS/JS | Go | Rust | Java | C/C++ |
|-----------|-----|--------|-------|-----|------|------|-------|
| `goToDefinition` | Excellent | Good | Excellent | Excellent | Excellent | Excellent | Good* |
| `findReferences` | Excellent | Good | Excellent | Excellent | Excellent | Excellent | Good* |
| `goToImplementation` | Excellent | Limited | Good | Limited** | Good | Excellent | Weak |
| `hover` | Good | Excellent | Good | Good | Excellent | Good | Good |
| `documentSymbol` | Good | Good | Good | Good | Good | Good | Good |
| `workspaceSymbol` | Good | Good | Good | Fast | Good | Good | Good* |
| `incomingCalls` | Good | Incomplete | Good | Partial | Unstable | Good | Good* |
| `outgoingCalls` | Good | Incomplete | Good | Partial | Unstable | Good | Good* |

\* Requires `compile_commands.json` — without it, many operations fail **silently**
\** Go has implicit interfaces — satisfying types aren't explicitly linked

## Performance Characteristics

| Server | Startup | Memory | Reliability | Notes |
|--------|---------|--------|-------------|-------|
| Go (gopls) | Fast | Low | Excellent | Fastest, most reliable overall |
| TypeScript (vtsls) | Medium | Medium | Excellent | Slower on 10k+ file projects |
| C# (csharp-ls) | Medium | Medium | Excellent | Best `goToImplementation` |
| Python (pyright) | Medium | High | Good | Call hierarchy incomplete |
| Java (jdtls) | ~8s | 1GB+ | Good | JVM warmup delay |
| Rust (rust-analyzer) | Slow | 500MB+ | Good | Compiles project on first init |
| C/C++ (clangd) | Medium | Medium | Good | Needs compile_commands.json |

## Workspace Requirements

Language servers fail **silently** without these config files:

| Language | Required file | Notes |
|----------|--------------|-------|
| C# | `.sln` or `.csproj` | Must be in or above workspace root |
| TypeScript | `tsconfig.json` | Monorepos need per-workspace configs |
| Python | `pyproject.toml` or `pyrightconfig.json` | For best type inference |
| Go | `go.mod` | Must be in workspace root |
| Rust | `Cargo.toml` | Must be in workspace root |
| Java | `pom.xml`, `build.gradle`, or `.classpath` | Maven, Gradle, or Eclipse |
| C/C++ | `compile_commands.json` | Generate via `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` or `bear make` |

## Multi-Language Projects

- Each language server operates independently — LSP operations only work within their language boundary
- For cross-language references (e.g., TypeScript calling a Python API), use Grep
- When a symbol exists in multiple languages, specify the file path to disambiguate
