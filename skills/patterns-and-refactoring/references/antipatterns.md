# Anti-patterns

Two kinds live here:

1. **Pattern anti-patterns** — patterns applied where they do not belong, which is the most common way a design gets worse while everyone feels productive.
2. **Structural anti-patterns** — recurring bad shapes with well-known names and known cures.

**The default assumption when reaching for a pattern should be "probably not yet."** Patterns
are cheap to add later and expensive to remove — removing one means changing every call site
that adapted to it.

---

## Part 1 — Pattern anti-patterns

### Speculative Generality

The parent of all the others.

- **Looks like** — Interfaces with one implementation; abstract classes with one subclass; a `$options` array nobody passes; a plugin system with no plugins; `handle(mixed $input)` that only ever receives one type.
- **Justified by** — "We might need it." "It is more flexible."
- **Why it fails** — The guessed extension point is almost never where change actually arrives. You pay the indirection cost permanently and get the flexibility somewhere you did not need it. Meanwhile the abstraction, shaped by one case, does not fit the second case when it finally appears.
- **Cure** — Collapse Hierarchy, Inline Class, Remove Parameter. Write the direct code; refactor when the second case is real.
- **The gate** — Rule of Three. Two real variants today, a third concretely foreseen.

### Singleton

The pattern with the worst benefit-to-damage ratio in the catalogue.

- **The bundled mistake** — Singleton conflates *one instance* (usually fine) with *globally reachable* (almost never fine). Your DI container gives you the first without the second.
- **What it costs** — Dependencies invisible in the signature, so callers cannot know what a class needs. Tests that leak state between cases and must run in order. No way to have two when requirements change — and requirements always change, usually as multi-tenancy or a second environment.
- **Cure** — Register the class in the container as a shared binding and inject it. One instance, explicit dependency, substitutable in tests.
- **Legitimate uses** — Genuinely process-wide, stateless infrastructure where injection is impossible: a logger of last resort, a hardware handle. In application code, essentially none.

### Pattern-name theatre

- **Looks like** — `AbstractRequestHandlerFactoryProvider`. Class names announcing patterns while the code does something trivial. Every folder named after a pattern.
- **Why it fails** — Names should describe the *domain*, not the mechanism. `PricingStrategy` is fine because pricing strategies are a domain concept. `UserServiceFactoryImpl` tells a reader nothing they needed.
- **Cure** — Rename to the domain concept. If no domain concept fits, the class probably should not exist.

### The Repository that is a worse query builder

- **Looks like** — `findActiveUsersByRoleCreatedAfterOrderedByName()` and forty siblings.
- **Why it fails** — The abstraction promised a collection interface and became a per-query method dump. You lost the ORM's composability and gained a maintenance surface.
- **Cure** — Query objects or scopes for named queries; keep the repository interface small if it exists at all. See [enterprise-patterns.md](enterprise-patterns.md#repository).

### Factories all the way down

- **Looks like** — A factory whose only job is to call a factory. A builder for an object with two fields. `new UserFactory()->create()` where `new User()` would do.
- **Cure** — Inline it. Creational patterns earn their keep when creation has genuine complexity: invariants, subclass selection, expensive assembly. Wrapping `new` does not qualify.

### Observer as spooky action at a distance

- **Looks like** — Events dispatched to decouple two things that are actually coupled; a chain of listeners triggering listeners; nobody able to answer "what happens when a user registers?" without grepping.
- **Why it fails** — Control flow becomes invisible. Nothing at the call site shows what runs, ordering is usually unspecified, and debugging means reconstructing the graph by hand.
- **Cure** — Direct calls for things that always happen. Reserve events for genuine fan-out across module boundaries where the publisher legitimately should not know the subscribers.

### Middleware / decorator soup

- **Looks like** — Eight wrappers around a client, a 60-frame stack trace, and no clarity on which layer swallowed the error.
- **Cure** — Collapse layers that always appear together into one. Order them deliberately and document why. Each layer must have a reason to exist independently.

### Abstraction on top of a stable dependency

- **Looks like** — A wrapper around your ORM, HTTP client, or logger "so we can swap it later."
- **Why it fails** — You will not swap it. If you did, the wrapper — shaped by the current library's semantics — would not fit the replacement anyway. Meanwhile you have a permanently weaker version of a well-documented API that new developers must learn separately.
- **Legitimate version** — Wrap what is *genuinely* unstable or hostile: a third-party API with a bad model, a vendor SDK likely to be replaced, a payment provider. That is a Gateway or an Anti-Corruption Layer, and it is justified by the instability, not by principle.

### Premature microservices

- **Looks like** — A distributed system built by one team before the domain boundaries are known.
- **Why it fails** — You converted in-process calls into network calls, and boundary mistakes from local refactors into cross-service migrations with versioned APIs and data migrations. Microservices solve an organisational problem you may not have.
- **Cure** — Modular monolith. Extract a service when a boundary has proven stable, not while you are still discovering it. See [architectural.md](architectural.md#distribution-topologies).

---

## Part 2 — Structural anti-patterns

### God Object / Big Ball of Mud

- **Symptom** — One class or module knowing and doing everything. `User` with 4,000 lines.
- **Cure** — Extract Class along the axes of change. See Large Class and Divergent Change in [code-smells.md](code-smells.md).

### Anemic Domain Model

- **Symptom** — Entities with only getters and setters; all logic in "service" classes.
- **Why it is an anti-pattern** — You pay for the object graph, the ORM mapping and the ceremony, and get procedural code anyway. Rules cannot be enforced by the objects that own the data, so they are re-checked (or forgotten) at every call site.
- **Cure** — Move Method to bring behaviour to the data. Or make a deliberate choice: honest Transaction Script is *better* than a fake domain model. See [enterprise-patterns.md](enterprise-patterns.md#domain-logic).

### Golden Hammer

- **Symptom** — Every problem solved with the same tool. Every feature becomes a microservice, an event, a new abstraction layer.
- **Cure** — This skill's Step 1: name the force before naming the solution. A pattern chosen before the problem is understood is a hammer.

### Lava Flow

- **Symptom** — Dead code nobody dares delete because nobody knows if it is used.
- **Cure** — Instrument it. Log invocations for a full business cycle, then delete what never ran. Version control is the archive; "we might need it" is not a reason to keep it in the tree.

### Boat Anchor

- **Symptom** — A dependency, framework or subsystem kept "because we paid for it" or "we might use it."
- **Cure** — Delete. Sunk cost is sunk.

### Copy-Paste Programming

- **Symptom** — The same logic in eight places, drifting apart.
- **Cure** — Extract Method / Extract Class. **Careful:** coincidental duplication is not duplication. Two fragments that look alike but change for different reasons must stay apart.

### Cargo Cult Programming

- **Symptom** — Structure copied from a blog post, a conference talk, or another company's scale, without the constraints that made it right.
- **Cure** — Ask what problem the original was solving and whether you have it. Netflix's architecture solves Netflix's problems.

### Inner-Platform Effect

- **Symptom** — Building a configurable system so general it reimplements the platform underneath. A database inside the database (EAV tables), a scripting language inside your config, a workflow engine nobody can debug.
- **Cure** — Use the platform. Extreme configurability is almost always more expensive than the code changes it was meant to avoid.

### Magic Numbers and Stringly-Typed Code

- **Symptom** — `if ($status === 3)`, `$type === 'admin'` scattered everywhere.
- **Cure** — Replace Magic Number with Symbolic Constant; enums; Replace Type Code with Class.

### Exception Swallowing

- **Symptom** — `catch (\Throwable $e) {}` or a catch that logs and continues as if nothing happened.
- **Why it is the worst on this list** — It converts a loud, diagnosable failure into silent data corruption discovered weeks later.
- **Cure** — Handle it meaningfully, or let it propagate. Catch specific exception types, never bare `Throwable`, unless you are at a top-level boundary that reports properly.

### Premature Optimization

- **Symptom** — Caching, denormalising, or hand-rolling a data structure with no measurement.
- **Cure** — Profile first. The bottleneck is almost never where it is assumed to be — in web applications it is usually N+1 queries or a missing index, not the algorithm someone rewrote.
- **Note** — This does not license *pessimisation*: choosing an obviously worse algorithm or writing an N+1 query when the correct version costs nothing extra is not "avoiding premature optimization."

---

## The honest checklist

Before adding any pattern or abstraction:

- [ ] Can I name the force in one sentence, with a real source of variation?
- [ ] Do two variants exist **today**, with a third concretely foreseen?
- [ ] Would a competent developer reading this in a year understand why it is here?
- [ ] Is the direct version genuinely worse, not just less impressive?
- [ ] Does my framework already provide this? ([framework-idioms.md](framework-idioms.md))
- [ ] Does this make the code **easier** to test, not harder?
- [ ] Can I delete this later if I am wrong, or has it become load-bearing?

Any "no" means write the direct code and revisit when the need is real.

---

## Sources

William Brown et al., *AntiPatterns* (1998) · Martin Fowler on
[Anemic Domain Model](https://martinfowler.com/bliki/AnemicDomainModel.html) and
[YAGNI](https://martinfowler.com/bliki/Yagni.html) · Michael Nygard, *Release It!* ·
Microsoft, [Antipatterns for cloud applications](https://learn.microsoft.com/azure/architecture/antipatterns/).
Original commentary.
