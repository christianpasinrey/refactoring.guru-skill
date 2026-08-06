# Enterprise application patterns (PoEAA)

Martin Fowler's *Patterns of Enterprise Application Architecture* catalogue. These are the
patterns that decide **how your domain logic and your database relate** — which is where most
application code actually lives, and where most frameworks have already made a choice for you.

Catalogue: <https://martinfowler.com/eaaCatalog/>. Commentary below is original, with emphasis
on which of these your framework already implements.

---

## Domain logic

How business rules are organised. Pick by complexity, and be honest about which one you have.

| Pattern | Shape | Fits |
|---|---|---|
| **Transaction Script** | One procedure per use case, top to bottom | Simple CRUD, reports, admin actions, scripts. Massively under-rated — most code should be this |
| **Domain Model** | Objects with data *and* behaviour, rich invariants | Genuinely complex rules that interact: pricing engines, scheduling, insurance, clinical logic |
| **Table Module** | One class per table, operating on record sets | Table-oriented environments; rare in modern PHP/JS |
| **Service Layer** | A boundary of use-case operations over the domain | Multiple clients (HTTP, CLI, queue, API) need the same operations, transactions, and auth |

**Choosing:** complexity of the *rules*, not size of the app. A large application with simple
rules wants Transaction Script plus a Service Layer. A small application with genuinely knotty
rules wants a Domain Model. Applying a Domain Model to CRUD produces ceremony; applying
Transaction Script to complex rules produces 600-line methods with duplicated conditions.

**The anemic domain model trap** — classes with only getters and setters plus "service" classes
holding all logic. That is Transaction Script wearing a Domain Model costume: you pay for the
object graph and get none of the benefit. Either commit to behaviour on the objects, or drop
the pretence and write honest procedures.

---

## Data source architecture

| Pattern | Shape | Trade-off |
|---|---|---|
| **Table Data Gateway** | One object per table, all SQL for it inside | Simple, no mapping, no domain objects |
| **Row Data Gateway** | One object per row, no domain logic | Rare on its own |
| **Active Record** | Object *is* the row, and carries behaviour | Fast to write, couples the domain to the schema. Eloquent, Rails AR |
| **Data Mapper** | A separate mapper moves data between objects and tables | Domain stays persistence-ignorant. Doctrine, Hibernate |

**Active Record vs Data Mapper is the defining choice of your persistence layer.**

Active Record wins on velocity and on schema-shaped domains — the overwhelming majority of
applications. Data Mapper wins when the domain model must diverge from the table structure,
when the domain must be unit-testable with no database, or when the schema is legacy and ugly
while the domain must be clean.

Do not mix them arbitrarily. If you are on Eloquent, the natural design is Active Record plus a
Service Layer — not Eloquent hidden behind a Repository pretending to be a Data Mapper, which
gives you the cost of both and the benefit of neither. See
[framework-idioms.md](framework-idioms.md#repository-over-eloquent-when-is-it-justified).

---

## Object-relational behavioural

| Pattern | Solves | Note |
|---|---|---|
| **Unit of Work** | Track changed objects, write them in one transaction | Doctrine's `EntityManager`. In Laravel, `DB::transaction()` is the poor man's version |
| **Identity Map** | One in-memory instance per row per request | Prevents two objects representing the same row from diverging. Eloquent does *not* do this by default — a real source of bugs |
| **Lazy Load** | Defer loading until accessed | Eloquent relations. The N+1 query problem is Lazy Load's failure mode; eager loading is the cure |

**Identity Map is the one most people do not realise they lack.** In Eloquent, loading the same
row twice gives two objects; mutating one does not affect the other, and whichever saves last
wins. Within a request that touches the same entity from several paths, this bites.

---

## Object-relational structural

Mostly implemented by your ORM; worth knowing by name so you can describe what it is doing.

| Pattern | What it maps |
|---|---|
| **Identity Field** | The primary key stored on the object |
| **Foreign Key Mapping** | A reference between objects as an FK |
| **Association Table Mapping** | Many-to-many via a join table |
| **Dependent Mapping** | A child whose persistence the parent controls |
| **Embedded Value** | A value object flattened into the owner's columns (a `Money` as `amount` + `currency`) |
| **Serialized LOB** | An object graph stored as JSON/blob in one column |
| **Single Table Inheritance** | All subclasses in one table with a type column |
| **Class Table Inheritance** | One table per class, joined |
| **Concrete Table Inheritance** | One table per concrete class, no join |
| **Inheritance Mappers** | The mapper structure that handles the above |

**Inheritance mapping, in practice:** Single Table is simplest and costs you nullable columns.
Class Table normalises and costs joins. Concrete Table avoids joins and costs you duplicated
columns and painful polymorphic queries. Single Table is the right default; reach past it only
when the nullable-column count becomes genuinely unmanageable. Better still, ask whether
composition would remove the hierarchy entirely.

**Serialized LOB** is now everywhere as a JSON column. It is excellent for schemaless
attributes and terrible for anything you need to query, index, or constrain. The moment you
write a `WHERE` clause against its contents, it should have been a table.

---

## Object-relational metadata mapping

| Pattern | What it does |
|---|---|
| **Metadata Mapping** | Mapping described as metadata (attributes, annotations, config) rather than code |
| **Query Object** | A query represented as an object, composable and database-agnostic |
| **Repository** | A collection-like interface over the domain, hiding query construction |

### Repository

The most-argued pattern in this catalogue.

- **Intent** — Mediate between the domain and data mapping, so the domain talks to something that behaves like an in-memory collection.
- **Legitimate reasons to add it** — Swapping the persistence mechanism is a real requirement; the domain must be unit-testable with no database; queries are complex enough to deserve a named home; you are behind a Ports & Adapters boundary and this is the port.
- **Bad reasons** — "It is best practice." "For testing" (a database test with transactions is usually faster to write and catches more than a mocked repository). "To swap the database" (nobody swaps the database, and if they did, the ORM was already the abstraction).
- **Cost** — Either the interface stays small and you lose the ORM's query expressiveness, or it grows a method per query and becomes a worse query builder.

**Query Object** is often the better answer to the real problem. When the pain is scattered,
duplicated query logic rather than coupling to the ORM, a query object or a scope gives you a
named, composable, testable query without an extra abstraction layer.

---

## Web presentation

| Pattern | What it does |
|---|---|
| **Model View Controller** | Separate input handling, data, and rendering |
| **Page Controller** | One controller per page or action (invokable controllers) |
| **Front Controller** | One entry point routes all requests (every framework's front door) |
| **Template View** | Render by embedding markers in markup (Blade, Twig) |
| **Transform View** | Transform data into output element by element |
| **Two Step View** | Logical page first, then a presentation pass (layouts, themes) |
| **Application Controller** | Centralised screen-flow and navigation logic |

Modern frameworks give you Front Controller + Page Controller + Template View by default. The
one worth deliberately reaching for is **Two Step View** when the same content must render into
several skins, themes, or channels.

---

## Distribution

| Pattern | What it does |
|---|---|
| **Remote Facade** | A coarse-grained interface over fine-grained objects, to cut round trips |
| **Data Transfer Object** | A behaviourless object carrying data across a boundary |

**DTO** is one of the most valuable and most misused patterns here. It exists to cross a
*process or system boundary* — an HTTP payload, a queue message, a module contract. A DTO for
every internal method call is ceremony. And a DTO *should* be anemic: giving it behaviour makes
it a domain object with a confusing name.

**Fowler's original warning still holds:** do not distribute unless forced. Every remote call
is orders of magnitude more expensive and more failure-prone than an in-process one. Remote
Facade exists because the first instinct — exposing fine-grained objects remotely — performs
terribly.

---

## Offline concurrency

The patterns for "two users edited the same record", which every multi-user application needs
and most handle by accident.

| Pattern | Approach | Fits |
|---|---|---|
| **Optimistic Offline Lock** | Version column; the second writer is rejected on conflict | Conflicts are rare. The right default |
| **Pessimistic Offline Lock** | Acquire a lock before editing | Conflicts are common and losing work is unacceptable |
| **Coarse-Grained Lock** | Lock a whole aggregate at once | Related objects must stay consistent — pairs with DDD Aggregates |
| **Implicit Lock** | The framework acquires locks so developers cannot forget | Any lock a developer can forget will be forgotten |

Optimistic locking is a few lines — a `version` or `updated_at` check in the `WHERE` of the
update — and it turns silent data loss into a visible, handleable conflict. It is close to free
and routinely omitted.

---

## Session state

| Pattern | Where state lives | Trade-off |
|---|---|---|
| **Client Session State** | With the client (cookie, JWT, hidden fields) | Scales freely; size limits, tamper risk, revocation is hard |
| **Server Session State** | In server memory or a session store | Simple; needs sticky sessions or a shared store |
| **Database Session State** | In the database | Survives restarts, fully shared; slowest |

The stateless-JWT-vs-server-session argument is exactly this trade-off. JWTs are Client Session
State: they scale beautifully and you cannot revoke them without adding server state back.

---

## Base patterns

| Pattern | What it does |
|---|---|
| **Gateway** | An object encapsulating access to an external system or resource |
| **Mapper** | Moves data between two subsystems that stay ignorant of each other |
| **Layer Supertype** | A base class for all objects in a layer |
| **Separated Interface** | Interface in one package, implementation in another — the mechanism behind dependency inversion |
| **Registry** | A well-known object others use to find services. *A global by another name — prefer injection* |
| **Value Object** | Equality by value, immutable (`Money`, `DateRange`, `Email`) |
| **Money** | A value object for currency amounts, with correct arithmetic and rounding |
| **Special Case** | A subclass supplying behaviour for a special value (`GuestUser`, `NullDiscount`) |
| **Plugin** | Link a class at configuration time rather than compile time |
| **Service Stub** | A stand-in for a problematic external service during testing |
| **Record Set** | An in-memory representation of tabular data |

**Value Object** is the highest-value pattern in this file and the most neglected. Most
Primitive Obsession in business code is a missing value object. **Money** specifically: never
store or compute currency in floats, never let two currencies be added, always make rounding an
explicit decision. This has caused more production incidents than any other item on this page.

**Gateway** is the pattern to reach for around every third-party API. It gives you one place to
handle their errors, retries, rate limits, and eventual deprecation — and one place to stub in
tests.

---

## Source

Martin Fowler, *Patterns of Enterprise Application Architecture* (2002).
Catalogue: <https://martinfowler.com/eaaCatalog/>. This file is original commentary.
