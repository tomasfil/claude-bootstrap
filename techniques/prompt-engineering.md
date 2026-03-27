# Prompt Engineering Techniques Reference

> Referenced by bootstrap modules and generated agents/skills. Apply these patterns when creating any LLM instruction file.

---

## RCCF Framework

Every agent/skill file should be structured with these four components:

### Role
Define WHO the agent is. Be specific — expertise area, seniority, mindset.
```markdown
<role>
You are a senior .NET engineer specializing in FastEndpoints API design
with deep knowledge of EF Core, DI patterns, and clean architecture.
</role>
```

### Context
Ground the agent in WHAT it's working with. Reference real project state.
```markdown
<context>
This project uses:
- .NET 10.0 / C# 14 with file-scoped namespaces
- FastEndpoints 7.x with REPR pattern (Request-Endpoint-Response)
- EF Core 10.0 with SQL Server, fluent configurations in separate files
- ErrorOr pattern for business logic errors
- IDataService<AppDbContext> for all data access (never inject DbContext directly)
</context>
```

### Constraints
Define boundaries — what NOT to do is as important as what to do.
```markdown
<constraints>
- NEVER inject AppDbContext directly — always use IDataService<AppDbContext>
- NEVER set audit fields manually — managed by IDataService interceptors
- Max function length: 50 lines. Split if longer.
- Use guard clauses over nested if-else
- Use collection expressions over .ToList()
</constraints>
```

### Format
Specify expected output structure — reduces hallucination by constraining generation.
```markdown
<format>
For each new endpoint, generate:
1. Request record (in Contracts project): `{Entity}{Action}Request.cs`
2. Response record (in Contracts project): `{Entity}{Action}Response.cs`
3. Endpoint class (in Api/Endpoints/{Entity}/): `{Action}.cs`
4. Mapper extension (in Api/Mappers/): update `{Entity}Mapper.cs`
Each file must use file-scoped namespace matching its directory path.
</format>
```

---

## Structured Output Patterns

### Classification Trees
Use decision trees for component-type routing. Structure as nested conditions:

```markdown
## Component Classification

Determine component type BEFORE writing code:

1. **Is it a data entity?** → Entity Pattern
   - New entity → Create Entity + Configuration + Migration + DTO + Mapper
   - Modify entity → Update Entity + Migration + DTO + Mapper

2. **Is it an API endpoint?** → Endpoint Pattern
   - CRUD operation → Use CrudServiceBase + standard endpoint template
   - Custom operation → Use typed Endpoint<TRequest, TResponse>

3. **Is it a service?** → Service Pattern
   - Simple (IDataService only) → Type A: direct mock IDataService
   - Complex (multiple deps) → Type B: mock all dependencies
   - Extends CrudServiceBase → Type C: use real ServiceCollection
```

### Enum-Based Routing
When a decision maps to a finite set of options, enumerate them:

```markdown
Determine the error handling strategy:
- `ErrorOr<T>` → Use for business logic errors (return result.Errors)
- `Exception` → Use only for truly exceptional conditions (throw)
- `HTTP status` → Use for API-layer validation (AddError + SendErrorsAsync)
```

---

## Few-Shot Examples

### When to Use
- Component types the agent will generate repeatedly
- Patterns that are project-specific and non-obvious
- Conventions that differ from framework defaults

### Template
```markdown
### Example: Create a new GET endpoint

**Input:** "Get all active divisions for a brand"

**Output:**
```csharp
namespace MyProject.Api.Endpoints.Divisions;

public class GetByBrand : AuthenticatedEndpoint<GetDivisionsByBrandRequest, GetDivisionsByBrandResponse>
{
    private readonly IDivisionService _divisionService;

    public GetByBrand(IDivisionService divisionService)
    {
        _divisionService = divisionService;
    }

    public override void Configure()
    {
        Get(GetDivisionsByBrandResponse.Path);
    }

    protected override async Task HandleAuthenticatedAsync(GetDivisionsByBrandRequest req, CancellationToken ct)
    {
        var divisions = await _divisionService.GetActiveByBrandAsync(req.BrandId);
        await Send.OkAsync(new GetDivisionsByBrandResponse(divisions.Select(d => d.MapToDto()).ToList()), ct);
    }
}
```(triple backtick)
```

---

## Context Caching Layout

Order content for optimal prompt caching:

1. **Static content first** (cached across calls):
   - System instructions / role definition
   - Tool definitions
   - Few-shot examples
   - Code standards / rules

2. **Semi-static content** (cached per session):
   - Project architecture description
   - Component classification tree
   - Pipeline trace map

3. **Variable content last** (never cached):
   - Current task description
   - User's specific request
   - Session state / conversation history

---

## Front-Loading and Recency

### Primacy Effect
Place the most critical rules in the FIRST section of any prompt:
- Safety constraints
- Anti-hallucination instructions
- "Read before write" mandate

### Recency Effect
Repeat critical rules at the END:
- Verification checklist
- "Did you verify all imports exist?"
- "Did you run the build?"

### The Middle
Less critical but still important content:
- Detailed patterns and examples
- Edge case handling
- Optional conventions

---

## Taxonomy-Guided Prompting

For complex decisions, provide a hierarchical taxonomy:

```markdown
## Decision Taxonomy

### Level 1: What layer?
├── Data Layer → go to Level 2A
├── Service Layer → go to Level 2B
├── API Layer → go to Level 2C
└── Client Layer → go to Level 2D

### Level 2A: Data Layer — What operation?
├── New entity → Entity + Configuration + Migration
├── Modify entity → Migration + update Configuration if needed
├── New relationship → Both entity Configurations + Migration
└── Query optimization → Add index via Migration

### Level 2B: Service Layer — What type?
├── CRUD service → Extend CrudServiceBase<Context, Entity, Guid>
├── Business logic → Standalone service with IDataService injection
├── External integration → Wrapper service with HttpClient/SDK
└── Event handler → IDomainEventHandler<TEvent>
```

---

## Sources
- RCCF Framework: Thomas Wiegold (2026)
- Structured outputs: Red Hat Developer, Parasoft
- Context caching: Anthropic Prompt Caching docs
- Taxonomy-guided: Springer, Emergent Mind
- Few-shot patterns: SUSE AI Documentation
- Front-loading: Microsoft Tech Community
