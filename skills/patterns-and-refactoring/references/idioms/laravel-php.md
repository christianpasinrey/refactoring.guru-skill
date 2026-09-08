# Laravel · Symfony · PHP

[← back to router](../framework-idioms.md)

---

## What Laravel already gives you

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Abstract Factory + DI** | The service container | `$this->app->bind(Port::class, Adapter::class)`. Do not write a factory class to pick an implementation |
| **Factory Method** | `bind()` with a closure; contextual binding | Contextual binding gives different implementations per consumer |
| **Singleton** | `$this->app->singleton()` | One instance, injected, testable. Never a static `getInstance()` |
| **Strategy** | **Notification channels:** `Notification::via()` + channel drivers. **Driver-keyed:** the Manager pattern (`Cache`, `Queue`, `Mail`, `Storage`). **Your own:** container binding by key | A notification channel *is* a Strategy — add it to `via()`, never a channel factory. Extend an existing manager with `extend()` before writing a new resolver |
| **Chain of Responsibility** | Middleware; `Illuminate\Pipeline\Pipeline` | `Pipeline::send($x)->through([...])->thenReturn()` |
| **Observer** | Events + listeners; model observers; `Model::booted()` | Model events for lifecycle; domain events for cross-module fan-out |
| **Command** | Queued jobs; console commands; `Bus::dispatch()` | A job *is* a Command object: serialisable, retryable, delayable |
| **Active Record** | Eloquent | Accept it — see below |
| **Data Mapper** | Doctrine, if you deliberately chose it | Do not simulate it on top of Eloquent |
| **Unit of Work** | `DB::transaction()` | Eloquent has no change tracker; the transaction is the boundary |
| **Identity Map** | **Not provided** | Loading the same row twice gives two objects. A real source of bugs |
| **Query Object** | Eloquent scopes; custom `Builder` classes | A scope *is* a composable query object |
| **Specification** | Scopes + `when()`; conditional builder chains | Composable rules without a specification framework |
| **Decorator** | Container `extend()`; middleware | `$this->app->extend(Client::class, fn($c) => new LoggingClient($c))` |
| **Proxy** | Eloquent lazy relations; `Lazy` collections; deferred providers | Already there — the risk is N+1, not the pattern |
| **Adapter** | Filesystem (Flysystem), Mail, Queue, Cache drivers | Write a driver, register it with `extend()` |
| **Facade** *(GoF)* | Service classes with a narrow API | **Laravel Facades are not the GoF Facade** — they are a static Service Locator over the container |
| **Template Method** | `FormRequest`, `TestCase`, `Notification`, `Command` | Extend the provided base rather than inventing a parallel lifecycle |
| **Builder** | Query Builder; `Notification`/`Mailable` fluent APIs | Fluent methods returning `$this`, then a terminal method |
| **Iterator** | `IteratorAggregate`, generators, `cursor()`, `lazy()`, `lazyById()`, `chunk()` | `lazyById()` streams in constant memory but orders by the key — it cannot take `latest('placed_at')`. `cursor()` is one query but MySQL's PDO driver still buffers the whole result unless buffering is off. Never `->all()` on a large table |
| **Value Object** | Custom casts (`CastsAttributes`); enums; `Stringable` | Casts turn a column into a value object transparently |
| **Null Object / Special Case** | `optional()`, nullsafe `?->`, `Collection::whenEmpty()` | |
| **Retry / Rate Limiting** | `Http::retry()`; `RateLimiter`; job `backoff()`, `retryUntil()` | Built in. Do not hand-roll retry loops |
| **Circuit Breaker** | Not provided | Add a library, or implement with the cache — see [distributed-patterns.md](../distributed-patterns.md) |
| **Transactional Outbox** | Not provided | Implement it. `afterCommit` on jobs is a partial mitigation, not the pattern |
| **Front Controller / Page Controller** | `public/index.php` + routing; invokable controllers | |
| **Template View / Two Step View** | Blade; layouts and components | |
| **Client Session State** | Sanctum tokens, JWT | vs the `session` driver = Server/Database Session State |

---

## Repository over Eloquent: when is it justified?

The most-argued decision in Laravel codebases. Be explicit about which case you are in.

**Justified when:**

- The domain must be unit-testable with no database *and* the rules are complex enough for that to pay off.
- You are behind a Ports & Adapters boundary and the repository is the port.
- Persistence genuinely may change — as a known requirement, not in theory.
- You are writing a package that must not force a persistence choice on consumers.

**Not justified when:**

- "It is best practice." Eloquent *is* Active Record; the pattern is already chosen.
- "For testing." `RefreshDatabase` against a transactional database is usually faster to write and catches more than mocked repositories, which mostly assert that your mocks agree with themselves.
- "To swap the database." You will not, and the ORM was already that abstraction.

**The middle path most teams should take:** Eloquent models + a thin Action/Service layer for
use cases + query scopes for named queries. Testable use cases and named queries, without a
persistence abstraction that fights the framework.

---

## PHP language features that replace patterns

| Feature | Replaces |
|---|---|
| **Enums** (backed, with methods and interfaces) | Replace Type Code with Class; State when transitions are simple; whole Strategy hierarchies. Casting an existing column to an enum changes its PHP type for *every* reader — land the enum first, migrate readers, then add the cast (Parallel Change) |
| **First-class callable syntax** `$obj->method(...)` | Strategy and Command objects for single-method cases |
| **Readonly properties / classes** | Immutable value objects without hand-written guards |
| **Constructor property promotion** | Boilerplate in value objects and DTOs |
| **Named arguments** | Long Parameter List; the Builder for simple objects |
| **Attributes** | Metadata Mapping; declarative routing, validation, listeners |
| **Generators** | Iterator; streaming large datasets without memory blowup |
| **`match`** | Simple Strategy dispatch. **Two branches do not need a pattern.** Note: `match` compares with `===`; converting an `if`/`elseif` chain that used `==` on untyped input is a behaviour change unless the values are pinned as typed |
| **Interfaces + union types** | Sum types, approximately |
| **`never` return type** | Documents non-returning guard helpers to static analysis |

---

## Symfony specifics

Symfony makes several different choices, and the idioms differ accordingly.

| Pattern | Where it lives |
|---|---|
| **DI container** | Compiled container, autowiring, `services.yaml`. Compile-time, not runtime resolution |
| **Data Mapper** | Doctrine ORM — the default, unlike Laravel |
| **Unit of Work + Identity Map** | Doctrine's `EntityManager` provides both properly |
| **Repository** | `EntityRepository` is idiomatic here, because Doctrine is a Data Mapper. The Laravel argument above does not transfer |
| **Observer** | Event Dispatcher; Doctrine lifecycle events |
| **Chain of Responsibility** | Kernel events, `HttpKernel` middleware-equivalents |
| **Strategy** | Tagged services + service locators; `#[AutowireLocator]` |
| **Decorator** | `decorates:` in service configuration — first-class, declarative |
| **Command** | Messenger component; `MessageBusInterface` |
| **Specification** | Doctrine `Criteria` |

**The key difference:** in Symfony, Repository is the default and *not* adding one is the
unusual choice. In Laravel it is the reverse. Copying a Symfony/DDD architecture into a Laravel
project is the single most common source of over-engineered Laravel codebases.

---

## Livewire · Inertia specifics

Both are [server-driven UI](../frontend-patterns.md#server-driven-ui) and inherit its fit
(forms over data, admin panels, dashboards) and its misfit (offline, sub-100 ms interaction,
drawing tools). The pattern questions are the same; the answers differ.

### Livewire

A component is a **presenter + state + actions**. It is not where domain rules live.

| Concern | Do this | Not that |
|---|---|---|
| **Domain rules** | Call an Action / Service from the component method | Pricing, eligibility, or workflow logic inside the component |
| **Lifecycle** | Thin `mount()` and `render()`; hydrate, delegate, return the view | Queries and rules in `render()` re-run on every request |
| **Validation + form state** | A Form object (Livewire 3) — validation rules, state and `save()` in one class | Twenty `public` properties plus a `rules()` array on the component |
| **Derived values** | `#[Computed]` — cached per request, invalidated on change | Recomputing the same query in `render()` and in three methods |
| **Input binding** | The deferred default; `wire:model.live` only when the UI must react per keystroke | `.live` everywhere — a round trip per keystroke is the cost of server-driven UI, spend it deliberately |
| **Size** | One concern per component; extract nested components before it reaches a screen's worth of properties | A component with 30 public properties — Large Class, same cure |
| **Parent ↔ child** | Direct calls: props down, `$parent` or return values up | `dispatch()` between a parent and its own child |
| **Cross-component fan-out** | `dispatch()` — Observer, with Observer's cost: nobody can see what runs | Events used to hide a coupling that is real |

### Inertia

The controller shapes the page. **The props are the DTO at the boundary.**

| Concern | Do this | Not that |
|---|---|---|
| **Props** | API Resources or explicit arrays with exactly what the page renders | Passing a whole model with its relations — every column becomes public contract |
| **Data access** | Controllers only; no JSON API for the same screens | A parallel `/api/*` layer that the SPA never needed |
| **Global state** | Shared data via middleware (`HandleInertiaRequests`): auth user, flash, feature flags | Per-page state promoted to shared data |
| **Freshness** | Partial reloads and lazy props | A hand-rolled client cache in front of Inertia |
| **Forms** | `useForm` — a Command with a network boundary; validate server-side as untrusted | Trusting client validation; skipping the FormRequest |

**Choosing, by force:**

- **Interaction latency or offline is the requirement** → API + SPA. Server-driven UI cannot get there.
- **The team writes PHP and the app is forms over data** → Livewire. One language, no API to design.
- **The team writes Vue/React and wants the SPA feel without an API** → Inertia. Controllers stay, JSON contracts do not appear.

FluxUI and Blade components are the Template View / component layer — markup with slots, no
domain logic.

## Going against the grain — signs you are fighting the framework

- A `Repositories/` directory of classes that each wrap one Eloquent call.
- An `Interfaces/` directory where every interface has exactly one implementation.
- A hand-written event dispatcher or DI container.
- Service classes that only forward to the model, with no logic of their own.
- Doctrine-style entities with private properties and getters, mapped onto Eloquent by hand.
- A `Domain/` layer that imports `Illuminate\*`.
- Domain rules inside a Livewire component method — the component is the presenter, not the model.
- A Livewire component with 30 public properties. Large Class; extract a Form object and nested components.
- An Inertia page receiving a whole Eloquent model with its relations as props — the schema has become the public contract.

Each of these costs real maintenance and buys nothing that the framework was not already
providing.
