# Laravel · Symfony · PHP

[← back to router](../framework-idioms.md)

---

## What Laravel already gives you

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Abstract Factory + DI** | The service container | `$this->app->bind(Port::class, Adapter::class)`. Do not write a factory class to pick an implementation |
| **Factory Method** | `bind()` with a closure; contextual binding | Contextual binding gives different implementations per consumer |
| **Singleton** | `$this->app->singleton()` | One instance, injected, testable. Never a static `getInstance()` |
| **Strategy** | Container binding by key; the Manager pattern (`Cache`, `Queue`, `Mail`) | Extend an existing manager with `extend()` before writing a new resolver |
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
| **Iterator** | `IteratorAggregate`, generators, `cursor()`, `lazy()`, `chunk()` | `Model::lazy()` streams rows; never `->all()` on a large table |
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
| **Enums** (backed, with methods and interfaces) | Replace Type Code with Class; State when transitions are simple; whole Strategy hierarchies |
| **First-class callable syntax** `$obj->method(...)` | Strategy and Command objects for single-method cases |
| **Readonly properties / classes** | Immutable value objects without hand-written guards |
| **Constructor property promotion** | Boilerplate in value objects and DTOs |
| **Named arguments** | Long Parameter List; the Builder for simple objects |
| **Attributes** | Metadata Mapping; declarative routing, validation, listeners |
| **Generators** | Iterator; streaming large datasets without memory blowup |
| **`match`** | Simple Strategy dispatch. **Two branches do not need a pattern** |
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

## Going against the grain — signs you are fighting the framework

- A `Repositories/` directory of classes that each wrap one Eloquent call.
- An `Interfaces/` directory where every interface has exactly one implementation.
- A hand-written event dispatcher or DI container.
- Service classes that only forward to the model, with no logic of their own.
- Doctrine-style entities with private properties and getters, mapped onto Eloquent by hand.
- A `Domain/` layer that imports `Illuminate\*`.

Each of these costs real maintenance and buys nothing that the framework was not already
providing.
