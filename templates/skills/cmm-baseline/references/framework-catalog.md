# Framework Catalog — CMM Blind Spots

Generic catalog of framework-specific blind spots in graph-indexed / LSP-based
code memory tools. Used by `/cmm-baseline init` to populate the per-project
`.claude/cmm-baseline.md` `## Framework blind spots` and `## Routing overrides`
sections.

**Content hygiene**: this file contains ZERO third-party MCP server / product names.
When a blind spot exists because "LSP-based parsers don't handle X", the catalog
says exactly that — generic tool-class descriptions only. Fallback entries reference
tool classes ("graph-indexed tools", "text search with glob scope"), never specific
products.

Detection signal → blind spot mapping. Per-signal entries include:
- Package / file signal
- Blind-spot label (which cmm `Node` type becomes unreliable)
- Reason (why the blind spot exists)
- Fallback pattern (what to do instead)
- Evidence tier (empirical = observed in the field, documented = upstream-confirmed)

---

## C# / .NET

Detection files: `*.csproj`, `*.sln`, `Directory.Packages.props`, `global.json`.

### FastEndpoints
- Package signal: `FastEndpoints` in `<PackageReference>`
- Blind spot: `Route` node type — coverage empirically 2/37 on real projects
- Reason: attribute-based route registration hidden behind compile-time source
  generators; LSP-based parsers skip generated partial declarations
- Fallback: traverse `INHERITS` edges from the project's `EndpointBase`-style
  class (each endpoint type subclasses the base); enumerate subclasses via
  graph-indexed `INHERITS` query, then read each endpoint's `Configure` /
  `HandleAsync` method
- Evidence tier: empirical

### ASP.NET Minimal API
- File signal: `Program.cs` containing `MapGet` / `MapPost` / `MapPut` / `MapDelete` calls
- Blind spot: `Route` node type — route definitions live in top-level statements,
  not as discoverable methods
- Reason: minimal API route registration is imperative top-level code; no named
  symbol to index as a route
- Fallback: text search with file glob scoped to `Program.cs` and startup modules
- Evidence tier: empirical

### ASP.NET MVC / WebAPI (classic)
- Package signal: `Microsoft.AspNetCore.Mvc` in `<PackageReference>`
- Blind spot: attribute-routed controllers — `[Route]` / `[HttpGet]` / `[HttpPost]`
  bindings may not be indexed as `Route` nodes
- Reason: attributes are metadata on `Controller` methods; parsers vary on whether
  they promote attribute-routed methods into a dedicated Route label
- Fallback: find subclasses of `ControllerBase` / `Controller` via graph `INHERITS`
  query, inspect each action method for the attribute pattern
- Evidence tier: empirical

### Blazor
- Package signal: `Microsoft.AspNetCore.Components` in `<PackageReference>`
- File signal: `*.razor` files
- Blind spot: `.razor` markup files — NOT parseable by LSP-based parsers at all
- Reason: Razor is a hybrid markup + C# syntax requiring a dedicated compiler pass;
  general-purpose LSP-based tools skip these files
- Fallback: text search scoped via `paths_include_glob="**/*.razor"`; for
  code-behind `.razor.cs` partial classes, normal symbol lookup works
- Evidence tier: empirical

### Source generators
- File signal: `*.g.cs` files in `obj/` directories
- Blind spot: generated code is excluded by default in most index configurations
- Reason: source-generated files are build artifacts, not source of truth
- Fallback: never reference generated code directly; query the generator's input
  attributes / source classes instead
- Evidence tier: documented

### gRPC / protobuf (C#)
- Package signal: `Grpc.Tools` in `<PackageReference>`
- Blind spot: `*.proto`-generated classes may not be in the graph
- Reason: `.proto` compilation is a build-time generator; the generated
  `*.g.cs` files are typically excluded
- Fallback: read the `*.proto` file directly; match service / message names
  against call sites in text search
- Evidence tier: documented

---

## TypeScript / JavaScript

Detection files: `package.json`, `tsconfig.json`, `yarn.lock`, `pnpm-lock.yaml`.

### Next.js (app router)
- Package signal: `next` in `package.json` dependencies; presence of `app/`
  directory containing `page.tsx` / `layout.tsx` files
- Blind spot: route tree — filesystem-based, not symbol-based
- Reason: Next.js app router infers routes from directory structure at build time;
  no named symbol represents a route
- Fallback: file-tree traversal under `app/**/page.tsx`; text search for specific
  route paths
- Evidence tier: documented

### Next.js (pages router)
- Package signal: `next` in dependencies; presence of `pages/` directory
- Blind spot: same as app router — filesystem-based routes
- Fallback: file-tree traversal under `pages/**/*.{ts,tsx,js,jsx}`
- Evidence tier: documented

### Express
- Package signal: `express` in `package.json` dependencies
- Blind spot: `Route` node type for `app.get` / `app.post` / `router.use` chains
- Reason: Express routes are registered via imperative method calls, not declarative
  definitions; some parsers track call sites but do not promote them into a Route label
- Fallback: call-site detection via graph `CALLS` edges from `Router` / `app`
  symbols; text search on `.get|.post|.put|.delete|.patch` methods
- Evidence tier: empirical

### React component libraries
- Package signal: `react`, `react-dom` in dependencies
- Blind spot: JSX usage sites — components rendered via JSX syntax are NOT tracked
  as `CALLS` edges in typical call graphs
- Reason: JSX is desugared to `React.createElement` calls at compile time; pre-sugar
  AST-based parsers miss the usage relationship
- Fallback: text search for `<ComponentName` patterns with glob scoped to `.tsx` / `.jsx`
- Evidence tier: empirical

### Vue single-file components
- File signal: `*.vue` files
- Blind spot: `.vue` markup templates — mixed script / template / style syntax not
  parseable by LSP-based tools without a dedicated Vue language server
- Fallback: text search scoped via `paths_include_glob="**/*.vue"`
- Evidence tier: documented

### Svelte components
- File signal: `*.svelte` files
- Blind spot: `.svelte` files — same hybrid-syntax problem as Vue / Razor
- Fallback: text search scoped via `paths_include_glob="**/*.svelte"`
- Evidence tier: documented

### NestJS
- Package signal: `@nestjs/core` in dependencies
- Blind spot: decorator-based controllers — `@Controller`, `@Get`, `@Post` decorators
  may not be promoted into a Route label
- Fallback: find classes decorated with `@Controller` via text search or graph
  `INHERITS` from base classes; map methods by decorator name
- Evidence tier: empirical

---

## Python

Detection files: `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile`, `Pipfile.lock`.

### Django
- Package signal: `Django` / `django` in deps
- Blind spot: URL patterns in `urls.py` — list comprehensions of `path(...)` calls
  are imperative, no Route symbols
- Reason: Django's `urlpatterns` is a runtime list; AST parsers may track call sites
  but cannot build a Route table without executing the module
- Fallback: text search on `urlpatterns` variable; AST-level parse of
  `path('...', view)` calls within `urls.py` files
- Evidence tier: documented

### Flask
- Package signal: `Flask` / `flask` in deps
- Blind spot: `@app.route` decorator-bound routes may not be promoted into Route nodes
- Reason: decorator detection varies by parser; some tools track the decorator but
  do not correlate it to a Route label
- Fallback: text search on `@app.route` / `@blueprint.route` patterns with glob scope
- Evidence tier: empirical

### FastAPI
- Package signal: `fastapi` in deps
- Blind spot: same as Flask — `@app.get` / `@app.post` / `@router.get` decorators
- Fallback: same pattern — text search on the decorator forms
- Evidence tier: empirical

### SQLAlchemy
- Package signal: `SQLAlchemy` / `sqlalchemy` in deps
- Blind spot: declarative model relationships — `relationship(...)` / `ForeignKey(...)`
  parameters are string-typed in many patterns, undetectable by static analysis
- Fallback: text search on `relationship(` / `ForeignKey(` patterns
- Evidence tier: documented

---

## Ruby

Detection file: `Gemfile`, `Gemfile.lock`, `*.gemspec`.

### Rails
- Gem signal: `rails` in Gemfile
- Blind spot: `config/routes.rb` — DSL-based route definitions using `resources`,
  `get`, `post` methods at module level
- Reason: Rails routing is a DSL evaluated at boot; no named symbol corresponds
  to a route
- Fallback: text search or AST parse of `config/routes.rb`
- Evidence tier: documented

### Sinatra
- Gem signal: `sinatra` in Gemfile
- Blind spot: inline `get '/path' do ... end` blocks — same imperative DSL problem
- Fallback: text search on `get |post|put|delete` method calls at top level
- Evidence tier: documented

---

## Rust

Detection file: `Cargo.toml`, `Cargo.lock`.

### Axum
- Crate signal: `axum` in `[dependencies]`
- Blind spot: route definitions via `Router::new().route("/path", handler)` chains —
  imperative call sites, no declarative Route symbols
- Fallback: graph `CALLS` edges from `Router::route` to handler functions; text
  search for `.route("..."` patterns
- Evidence tier: empirical

### Actix Web
- Crate signal: `actix-web` in `[dependencies]`
- Blind spot: macro-based route definitions — `#[get("/path")]` attribute macros
  are expanded at compile time, pre-expansion parsers miss the route binding
- Fallback: text search on `#[get(` / `#[post(` / `#[route(` patterns
- Evidence tier: empirical

### Rocket
- Crate signal: `rocket` in `[dependencies]`
- Blind spot: same macro-expansion problem as Actix — `#[get("/path")]`
- Fallback: same — text search on the macro attribute patterns
- Evidence tier: empirical

---

## Go

Detection file: `go.mod`, `go.sum`.

### Gin
- Module signal: `github.com/gin-gonic/gin` in `go.mod`
- Blind spot: route registration via `r.GET("/path", handler)` chains — imperative
  call sites
- Fallback: call-site detection via graph `CALLS` edges from router methods; text
  search on `.GET|.POST|.PUT|.DELETE` method invocations
- Evidence tier: empirical

### Echo
- Module signal: `github.com/labstack/echo` in `go.mod`
- Blind spot: same as Gin — `e.GET` / `e.POST` imperative call sites
- Fallback: same
- Evidence tier: empirical

### Fiber
- Module signal: `github.com/gofiber/fiber` in `go.mod`
- Blind spot: same imperative call-site pattern as Gin / Echo
- Fallback: same
- Evidence tier: empirical

### gRPC (Go)
- Module signal: `google.golang.org/grpc` in `go.mod`
- Blind spot: generated `*.pb.go` files may be excluded from indexing
- Fallback: read the `.proto` file directly; correlate service / method names
  against registration calls in `main` or server setup code
- Evidence tier: documented

---

## PHP

Detection file: `composer.json`, `composer.lock`.

### Laravel
- Package signal: `laravel/framework` in composer deps
- Blind spot: `routes/web.php` / `routes/api.php` — facade-style DSL calls
- Fallback: text search on `Route::get|post|put|delete|patch` patterns with
  glob scoped to `routes/*.php`
- Evidence tier: documented

### Symfony
- Package signal: `symfony/symfony` or `symfony/framework-bundle` in composer deps
- Blind spot: annotation-based routing (`@Route` in docblock comments) or
  attribute-based routing (`#[Route]` in PHP 8+)
- Fallback: text search on `@Route(` / `#[Route(` patterns
- Evidence tier: documented

---

## Generic blind spots (all languages)

These patterns cause silent gaps regardless of language — include them in every
project's baseline `## Framework blind spots` section when the pattern is present.

- **Attribute / decorator-based routing** — any language using attributes,
  decorators, annotations, or macros to register routes. Tree-sitter-level parsers
  often miss the attribute → symbol correlation. Fallback: text search on the
  attribute pattern.

- **Macro-expanded code** — Rust `macro_rules!`, C/C++ `#define`, Lisp macros,
  Elixir macros. Graphs are built from pre-expansion AST; expanded identifiers
  are invisible. Fallback: read the macro definition to understand the expansion;
  text search on the expansion output.

- **Source-generated code** — `*.g.cs`, `*.pb.go`, `*_pb2.py`, protobuf outputs,
  OpenAPI / GraphQL code generators, Swagger client generators. Typically
  excluded by index configurations. Fallback: never reference generated code;
  query the generator's input (`.proto`, `.graphql`, schema files) instead.

- **String-interpolated identifiers** — `getattr(obj, 'method_' + name)`,
  `eval("..." + name)`, reflection-based dispatch. Undetectable by static analysis.
  Fallback: text search on the interpolation pattern; document the runtime binding
  in the baseline `## Routing overrides` section.

- **Reflection / dynamic dispatch** — C# `MethodInfo.Invoke`, Java `Method.invoke`,
  Python `getattr` / `__getattr__`, Ruby `method_missing`. `CALLS` edges are
  silently missing for these invocations. Fallback: grep for the reflection API
  call site; manually trace possible targets.

- **Plugin / extension architectures** — any system loading code at runtime via
  `LoadFrom` / `dlopen` / `importlib.import_module`. Static graphs cannot see
  across the dynamic-load boundary. Fallback: enumerate the plugin manifest /
  directory; index each plugin as a separate project if graph traversal is needed.

- **Template engines** — Jinja2, Handlebars, Liquid, ERB, Mustache, HTML-embedded
  scripts (`.ejs`, `.pug`, `.haml`). LSP-based parsers typically skip these files
  entirely. Fallback: text search with glob scoped to the template extension.

- **DSL-style configuration** — Ruby `Rakefile`, Groovy `build.gradle`, Python
  `setup.py` / `conftest.py`, any imperative-configuration file. Structure is
  semantic to the runner, not to a symbol graph. Fallback: read the file as a
  whole; treat the DSL as opaque.

---

## Usage by `/cmm-baseline init`

1. Detect manifest files present at project root.
2. For each manifest, extract package / dependency names.
3. Match names against the catalog entries above (case-insensitive substring match
   on the signal).
4. For each match, emit a `## Framework blind spots` entry in the baseline with:
   `{Node_label}: {coverage_if_known}/{total_if_known}  # {framework} — use {fallback}`
5. For each match with a fallback that implies a routing change, emit a
   `## Routing overrides` entry:
   `# {Node_label} queries unreliable under {framework} -> prefer {fallback}`

Unknown frameworks produce no blind-spot entries — they are not an error. The
baseline grows organically as `/reflect` promotes learnings into additional
catalog entries.
