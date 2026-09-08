# The 22 Gang of Four patterns

The taxonomy follows [refactoring.guru's catalogue](https://refactoring.guru/design-patterns/catalog):
5 creational, 7 structural, 10 behavioral. The original 1994 book lists 23 — the missing one is
**Interpreter**, noted at the end of this file.

Every entry answers the same five questions. **When NOT to use it** and **Cost** are the two
that actually prevent bad decisions, so read those before committing.

---

## Creational patterns

*The force is: which concrete object gets created, or how it is assembled.*

### Factory Method

- **Intent** — Define an interface for creating an object, but let subclasses decide which class to instantiate.
- **Force** — The *creator* varies alongside the *product*: each subclass of the caller needs its own kind of object.
- **Use when** — A framework or base class must create objects it cannot know the type of; the subclass supplies the type. Classic in extension points: `Application::createDocument()`.
- **Do NOT use when** — You only need "pick a class by a string key". That is a Simple Factory (a static method or a container binding) and needs no inheritance hierarchy.
- **Cost** — A parallel class hierarchy: one creator subclass per product subclass. This is the pattern most often adopted where a one-line container binding would do.

### Abstract Factory

- **Intent** — Produce families of related objects without naming their concrete classes.
- **Force** — Several products must vary *together and consistently*. A `MacButton` must never end up next to a `WindowsCheckbox`.
- **Use when** — There is a real "theme" or "platform" dimension: UI toolkits, database dialects (connection + grammar + schema builder), cloud provider SDKs.
- **Do NOT use when** — Only one product varies. That is Factory Method or Strategy. The word "family" must be literally true, or you are paying for coordination you do not need.
- **Cost** — Adding a new *product type* means changing the factory interface and every concrete factory. Easy to add a family, hard to add a member.

### Builder

- **Intent** — Construct a complex object step by step, letting the same process yield different representations.
- **Force** — Construction has many optional parts, ordering rules, or several output representations.
- **Use when** — The telescoping-constructor smell appears (four-plus parameters, several optional); or the same build sequence must produce different results (a query builder emitting SQL, a report emitting HTML or PDF).
- **Do NOT use when** — The object has three simple fields. Named arguments, a value object, or a static factory method is clearer.
- **Cost** — Objects can be observed half-built. Prefer immutable builders that return a finished object from `build()`, and validate completeness there.

### Prototype

- **Intent** — Copy existing objects without coupling to their concrete classes.
- **Force** — Construction is expensive, or the exact runtime configuration of an object is not reproducible from a constructor.
- **Use when** — Cloning a fully configured object is genuinely cheaper or safer than rebuilding it: parsed documents, pre-warmed connections, editor objects being duplicated by the user.
- **Do NOT use when** — Construction is cheap. This is the least-used GoF pattern in modern code for good reason.
- **Cost** — Deep versus shallow copy is a permanent source of bugs. Circular references need explicit handling. In PHP, `__clone()` must be written and maintained carefully.

### Singleton

- **Intent** — Ensure a class has one instance and provide a global access point to it.
- **Force** — Genuinely one shared resource *and* a need for global reach.
- **Use when** — Almost never in application code. See [antipatterns.md](antipatterns.md#singleton).
- **Do NOT use when** — You want convenient access to a shared service. That is dependency injection, and your container already gives you a single instance without the global.
- **Cost** — Hidden dependencies, hostile to tests, unsafe under concurrency, and impossible to have two of when requirements change. The two legitimate needs it bundles — *one instance* and *global access* — should be separated: keep the first, refuse the second.

---

## Structural patterns

*The force is: how objects are composed, wrapped, or reached.*

### Adapter

- **Intent** — Let objects with incompatible interfaces collaborate.
- **Force** — An interface you need and an interface you have, and you cannot change either.
- **Use when** — Wrapping a third-party SDK, a legacy class, or a vendor API behind the interface your domain wants. The single most consistently worthwhile structural pattern.
- **Do NOT use when** — You own both sides. Then fix the interface instead of papering over it.
- **Cost** — One extra layer, and adapters tend to leak: when the target interface can't express something the adaptee does, resist adding `getUnderlyingClient()`.

### Bridge

- **Intent** — Split a large class or set of related classes into two independent hierarchies — abstraction and implementation — that can vary separately.
- **Force** — **Two** independent axes of change. This is the whole point, and the reason Bridge is confused with Strategy.
- **Use when** — Class count multiplies: shapes × renderers, notifications × transports, reports × formats. Without Bridge you get `CircleSvgRenderer`, `CircleCanvasRenderer`, `SquareSvgRenderer`… a combinatorial explosion.
- **Do NOT use when** — Only one axis varies. Use Strategy.
- **Cost** — Two hierarchies to navigate. Justified only when the multiplication is real.
- **vs Strategy** — Same structure, different intent and lifetime. Strategy swaps an *algorithm*, usually per call. Bridge separates a whole *implementation dimension*, usually fixed at construction.

### Composite

- **Intent** — Compose objects into tree structures and treat individual objects and compositions uniformly.
- **Force** — The client should not care whether it holds a leaf or a branch.
- **Use when** — The domain is genuinely a tree: file systems, menus, org charts, nested form fields, page-builder blocks, permission groups.
- **Do NOT use when** — The data is flat, or the tree is only two levels deep and always will be. A collection is simpler.
- **Cost** — The shared interface drifts toward the union of leaf and branch operations, and leaves end up with `add()` methods that throw. Keep the common interface small.

### Decorator

- **Intent** — Attach new responsibilities to an object dynamically by wrapping it.
- **Force** — Optional, combinable behaviours that must stack in arbitrary order at runtime.
- **Use when** — Cross-cutting layers over one contract: caching, logging, retry, compression, encryption over a repository or HTTP client. Composition instead of a subclass per combination.
- **Do NOT use when** — There is exactly one combination, forever. Just write it into the class.
- **Cost** — Deep wrapping makes stack traces and debugging painful, and identity comparisons break — the decorated object is not the original.
- **vs Proxy** — Same shape. Decorator *adds* behaviour and you choose to stack it; Proxy *controls access* to the subject and the client generally doesn't know it exists.

### Facade

- **Intent** — Provide a simplified interface to a complex subsystem.
- **Force** — Callers must use a subsystem, but only need a fraction of it, and you want to stop the subsystem's shape leaking into every caller.
- **Use when** — Taming a sprawling library or a legacy area, or defining a narrow public surface for a module.
- **Do NOT use when** — The facade is a pass-through with no simplification. That is an extra file, not a pattern.
- **Cost** — Facades attract methods and become god objects. Watch its size; a growing facade means the subsystem needs splitting.
- **vs Adapter** — Adapter changes an interface to match an expectation. Facade *simplifies* an interface without any external contract to match.

### Flyweight

- **Intent** — Share common state between many objects instead of storing it in each one.
- **Force** — Memory, and only memory: thousands or millions of objects with large duplicated intrinsic state.
- **Use when** — You have measured a real memory problem. Particle systems, tile maps, glyph rendering.
- **Do NOT use when** — You have not measured. In a request-scoped web application this is almost never the bottleneck.
- **Cost** — Splitting intrinsic from extrinsic state makes the API awkward — extrinsic state must be threaded through every call. Pay this only against a profiler reading.

### Proxy

- **Intent** — Provide a placeholder for another object to control access to it.
- **Force** — Something must happen *around* access: laziness, caching, permission checks, remoting, logging.
- **Use when** — Lazy loading (Doctrine and Eloquent both do this), access control, expensive remote resources, virtual objects.
- **Do NOT use when** — You are adding behaviour the caller explicitly opted into — that is a Decorator.
- **Cost** — Indirection that is invisible by design, which is exactly what makes it confusing to debug when it misbehaves.

---

## Behavioral patterns

*The force is: which algorithm runs, who reacts, how work is dispatched.*

### Chain of Responsibility

- **Intent** — Pass a request along a chain of handlers until one handles it.
- **Force** — The set and order of processing steps varies, and the sender must not know who will handle it.
- **Use when** — Middleware, validation chains, escalation, event filters. Laravel's `Pipeline` is this pattern.
- **Do NOT use when** — Exactly one handler always handles it. Call it directly.
- **Cost** — No guarantee anyone handles the request; silent drops are the classic bug. Chains are hard to trace — log which handler took it.

### Command

- **Intent** — Turn a request into a stand-alone object carrying all information about it.
- **Force** — Requests need a life of their own: queued, logged, retried, undone, scheduled, permission-checked.
- **Use when** — Job queues, undo/redo, transactional operations, audit trails, CLI actions. Laravel's queued jobs and Vue/Redux action objects are Commands.
- **Do NOT use when** — You just need to call a method. A Command that is only ever executed immediately, once, with no metadata, is a method call with extra files.
- **Cost** — One class per action. Fine when the metadata earns it, noise when it doesn't.

### Iterator

- **Intent** — Traverse elements of a collection without exposing its underlying representation.
- **Force** — Traversal must be decoupled from structure, or several traversal orders are needed.
- **Use when** — Custom aggregates, paginated APIs, streaming large result sets (PHP `Generator`, `IteratorAggregate`).
- **Do NOT use when** — An array or a first-class collection type already does it. Every mainstream language ships this pattern built in.
- **Cost** — Almost none, because you rarely implement it from scratch. Use the language's interfaces.

### Mediator

- **Intent** — Reduce chaotic dependencies between objects by forcing them to collaborate through a mediator.
- **Force** — Many-to-many coupling; every component knows every other.
- **Use when** — Complex form widgets that constrain each other, chat rooms, coordinating UI components.
- **Do NOT use when** — Coupling is manageable. Mediators grow into god objects faster than any other pattern.
- **Cost** — Complexity is moved, not removed. It concentrates in the mediator. Only worth it when the concentration is easier to read than the web it replaced.

### Memento

- **Intent** — Capture and restore an object's internal state without violating encapsulation.
- **Force** — Undo, snapshots, or rollback are required *and* the state must stay private.
- **Use when** — Editors, wizards with back navigation, transactional in-memory state, game saves.
- **Do NOT use when** — Public state can simply be copied, or the persistence layer already handles versioning.
- **Cost** — Memory, and a serialization format that becomes a compatibility burden once mementos are persisted.

### Observer

- **Intent** — Define a subscription mechanism to notify multiple objects about events happening to the object they observe.
- **Force** — One thing happens; an open-ended, unknown-at-write-time set of things must react.
- **Use when** — Domain events, model lifecycle hooks, reactive UI state, webhooks, pub/sub.
- **Do NOT use when** — Exactly one known thing reacts, and always will. A direct call is traceable; an event is not.
- **Cost** — Control flow becomes invisible: you cannot see from the call site what will run. Ordering is usually unspecified, and leaked subscriptions leak memory. Use it for genuine fan-out, not for decoupling two things that are actually coupled.

### State

- **Intent** — Let an object alter its behaviour when its internal state changes, as if it changed class.
- **Force** — Behaviour changes *wholesale* by state, and the legal transitions between states are themselves a rule worth enforcing.
- **Use when** — Order lifecycles, subscription status, document workflows, connection handling — anywhere a `status` field is checked in more than a couple of methods.
- **Do NOT use when** — One method branches on status. That is an `if`.
- **Cost** — A class per state, plus a decision about who owns transitions.
- **vs Strategy** — Structurally identical. In Strategy the *client* picks the object and the strategies do not know about each other. In State the object transitions *itself*, and states usually know their successors.

### Strategy

- **Intent** — Define a family of interchangeable algorithms and make them swappable at runtime.
- **Force** — One thing varies: *how* a step is performed, selected at runtime.
- **Use when** — Payment providers, shipping cost rules, export formats, sorting or pricing policies, notification channels. The highest value-to-cost ratio of any behavioral pattern.
- **Do NOT use when** — There are two branches and no third in sight. A `match` expression is honest and readable. A catalogue "Use when" is not a "use now": one export format in the ticket plus a wish for a second still fails the Rule of Three — leave the seam, not the interface (see `SKILL.md` Step 4).
- **Cost** — Low. The main trap is a strategy interface built around one implementation's needs, which the second implementation then can't satisfy. Design the interface from at least two real cases.

### Template Method

- **Intent** — Define an algorithm's skeleton in a base class, letting subclasses override specific steps.
- **Force** — The *sequence* is fixed and shared; individual *steps* vary.
- **Use when** — Import/export pipelines, report generation, test-case lifecycles, framework base classes.
- **Do NOT use when** — Subclasses need to change the order, or need more than one axis of variation. Inheritance locks you in; composition (Strategy) does not.
- **Cost** — Inheritance coupling, and the fragile-base-class problem. The `protected` hook methods are a real API — changing them breaks every subclass.
- **vs Strategy** — Template Method varies steps via inheritance at compile time; Strategy varies whole algorithms via composition at runtime. Prefer Strategy when both fit.

### Visitor

- **Intent** — Separate algorithms from the object structure they operate on.
- **Force** — New *operations* are added frequently; the set of *element types* is stable.
- **Use when** — ASTs, compilers, document trees, static analysers, exporting a stable structure to many formats.
- **Do NOT use when** — Element types change often. Every new element type forces a change to every visitor — the exact inverse trade-off, and usually the wrong one for business domains.
- **Cost** — Double dispatch is verbose and unfamiliar; it needs an `accept()` method on every element. The hardest GoF pattern to justify in typical application code.

---

## The 23rd pattern: Interpreter

Not in refactoring.guru's catalogue, and rightly deprioritised — but worth knowing it exists.

- **Intent** — Given a language, define a representation for its grammar and an interpreter that uses it.
- **Use when** — You genuinely have a small domain language: search query syntax, permission expressions, business-rule DSLs, spreadsheet-style formulas.
- **Do NOT use when** — A parser generator, an existing expression library, or plain configuration would do. Hand-rolled interpreters grow teeth.
- **Related** — Usually implemented as a Composite of expression nodes, evaluated by a Visitor.

---

## Combinations that appear constantly

| Combination | Where it shows up |
|---|---|
| Composite + Visitor | Traversing and operating on trees (ASTs, document models) |
| Composite + Decorator | Trees whose nodes carry optional stacked behaviour |
| Abstract Factory + Singleton | The factory is registered once in the container |
| Command + Memento | Undo/redo: the Command performs, the Memento restores |
| Strategy + Factory Method | The factory resolves the right strategy from a key |
| Chain of Responsibility + Command | Middleware pipelines carrying a request object |
| Observer + Mediator | The mediator becomes the event bus |
| Adapter + Facade | Wrapping a third-party subsystem into your own narrow port |

---

## Source

Taxonomy from <https://refactoring.guru/design-patterns/catalog>, with PHP implementations —
both conceptual and real-world — at <https://refactoring.guru/design-patterns/php>. Original
source: *Design Patterns: Elements of Reusable Object-Oriented Software*, Gamma, Helm, Johnson
& Vlissides, 1994. This file is original commentary, not a reproduction of either.
