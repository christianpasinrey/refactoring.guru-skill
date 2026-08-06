# ASP.NET Core · C#

[← back to router](../framework-idioms.md)

---

## What ASP.NET Core already gives you

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Abstract Factory + DI** | `IServiceCollection` / `IServiceProvider` — built into the framework | Constructor injection. `AddScoped`, `AddSingleton`, `AddTransient` |
| **Factory Method** | Factory delegate overloads: `AddScoped<T>(sp => ...)`; `IHttpClientFactory` | `IHttpClientFactory` exists because manual `HttpClient` lifetime is a known footgun |
| **Singleton** | `AddSingleton<T>()` | Container-managed. Never a static `Instance` property |
| **Strategy** | Interface + keyed services (`AddKeyedScoped`, .NET 8+); or inject `IEnumerable<T>` | Keyed services made the "resolve strategy by name" boilerplate obsolete |
| **Chain of Responsibility** | Middleware pipeline (`app.Use(...)`); `IPipelineBehavior` in MediatR | The documented pipeline, not a custom chain |
| **Observer** | `IObservable<T>`; MediatR `INotification`; `IHostedService` | |
| **Command** | MediatR `IRequest`/`IRequestHandler`; `BackgroundService`; Hangfire jobs | MediatR's `IRequest` *is* Command, and its handlers are the use-case layer |
| **Mediator** | MediatR — the pattern, named | See the warning below |
| **Data Mapper** | Entity Framework Core | .NET's default is Data Mapper |
| **Unit of Work + Identity Map** | `DbContext` provides both properly | `SaveChanges()` is the transaction boundary; change tracking is the Unit of Work |
| **Repository** | `DbSet<T>` **is already a repository**, `DbContext` is already a Unit of Work | See below — this is the argument in .NET |
| **Specification** | `IQueryable` + expression trees; Ardalis.Specification | Composable and translated to SQL |
| **Query Object** | LINQ queries; compiled queries | |
| **Decorator** | Scrutor `.Decorate<T, TDecorator>()`; `IPipelineBehavior` | Scrutor gives declarative decoration over the built-in container |
| **Proxy** | EF lazy loading proxies; Castle DynamicProxy | |
| **Adapter** | Provider model: logging, config, caching, auth handlers | |
| **Template Method** | `ControllerBase`; `BackgroundService.ExecuteAsync`; `IHostedService` | |
| **Builder** | `WebApplicationBuilder`; `StringBuilder`; fluent config; `HostBuilder` | The whole startup API is a Builder |
| **Iterator** | `IEnumerable<T>`, `yield return`, `IAsyncEnumerable<T>` | `IAsyncEnumerable` streams without buffering |
| **Value Object** | `record` / `readonly record struct`; `IEquatable<T>` | A `record` is a value object in one line |
| **Null Object** | Nullable reference types + `?.` + `??` | Enable NRTs and treat warnings as errors |
| **Retry / Circuit Breaker / Bulkhead** | Polly, integrated via `IHttpClientFactory` resilience handlers | `AddStandardResilienceHandler()` gives retry + breaker + timeout + bulkhead in one line |
| **Front Controller** | The routing middleware | |
| **Options / External Configuration Store** | `IOptions<T>`, `IOptionsMonitor<T>` | `IOptionsMonitor` gives live reload |
| **Client Session State** | JWT bearer auth | vs `ISession` = Server/Distributed Session State |

---

## Repository over EF Core: the .NET version of the argument

**`DbSet<T>` is already a Repository. `DbContext` is already a Unit of Work.** Both are named
that way in the EF Core documentation. A generic `IRepository<T>` on top is a repository over a
repository.

**Not justified when:**

- "For testability." EF Core's in-memory provider or SQLite in-memory tests the real query translation. A mocked `IRepository<T>` tests that your mocks agree with themselves.
- "To swap the ORM." You will not.
- "Best practice." It is a widely-copied template, not a reasoned decision.

**Justified when:**

- The domain project genuinely must not reference EF Core — a real constraint in Clean Architecture setups and long-lived enterprise systems.
- You are enforcing aggregate boundaries: a repository per aggregate root that returns fully-loaded aggregates, which is a DDD decision rather than a persistence one.
- Complex queries need a named home — though a Specification or a query object does that with less.

**The generic repository specifically** (`IRepository<T>` with `GetAll`, `GetById`, `Add`,
`Delete`) is the most-cargo-culted pattern in .NET. It strips `IQueryable` composability and
gives back nothing.

### MediatR: useful, and over-applied

MediatR gives you a real Command layer, pipeline behaviours for cross-cutting concerns
(validation, logging, transactions), and a natural CQRS split. That is genuine value.

The cost: navigation becomes indirect — "go to definition" on a handler is a search, not a
jump. In a small application, injecting the service directly is clearer, and a `Ping` request
class per action is ceremony.

**Adopt it when** you want pipeline behaviours or a genuine CQRS split. **Skip it when** you
just want to call a service.

---

## C# language features that replace patterns

| Feature | Replaces |
|---|---|
| **`record` / `readonly record struct`** | Value Object, DTO, and most immutable Builders |
| **Pattern matching + switch expressions** | Visitor, State dispatch |
| **Nullable reference types** | Null Object; makes absence a compile-time concern |
| **`required` members and primary constructors** | Builder for construction-time invariants |
| **Extension methods** | Introduce Foreign Method; Decorator without a wrapper |
| **`IAsyncEnumerable<T>`** | Iterator over async sources without buffering |
| **`Func<T>` / `Action<T>`** | Strategy and Command for single-method cases |
| **Source generators** | Reflection-based Metadata Mapping, at compile time |
| **`init` accessors** | Immutability with object-initializer syntax |
| **Generic math / static abstract members** | Strategy at the type level |

---

## Clean Architecture in .NET: the honest version

The .NET ecosystem has adopted Clean Architecture templates more enthusiastically than any
other. Four projects — Domain, Application, Infrastructure, Web — with strict dependency rules.

**It is genuinely right when** the domain is complex, the system is long-lived, and multiple
entry points drive the same use cases.

**It is expensive ceremony when** the application is CRUD. Four projects, an interface per
service, a DTO per layer, and AutoMapper profiles between them — to save a row. The cost lands
on every future change and it never reads back.

Signals you are in the wrong place: `Application` handlers that only call one repository
method; a DTO, an entity and a view model with identical fields; AutoMapper profiles that are
pure field-for-field copies.

**The middle path:** Minimal APIs or controllers → a service or handler holding the use case →
EF Core directly. Add layers when a specific pain justifies a specific layer.

---

## Going against the grain

- A generic `IRepository<T>` over `DbSet<T>`.
- An interface per service with one implementation, for mocking.
- Hand-written retry loops where Polly exists.
- `AutoMapper` for identical-shape mappings — a constructor or `record` copy is clearer and compile-checked.
- Service Locator (`IServiceProvider.GetService` inside a class) instead of constructor injection.
- `async void` outside event handlers.
- Blocking on async with `.Result` or `.Wait()`.
- MediatR requests that wrap a single service call with no pipeline behaviours in use.
