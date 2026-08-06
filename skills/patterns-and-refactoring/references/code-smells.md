# Code smells

A smell is a *surface indication* of a deeper problem. It is not a bug and not a rule
violation — it is a signal worth investigating. Some smells are worth living with; the entry
tells you which.

**Do not say "this code is messy."** Name the smell. The name carries the diagnosis and points
at the cure.

Taxonomy follows <https://refactoring.guru/refactoring/smells>: five groups, 22 smells.
Refactorings referenced here are detailed in
[refactoring-techniques.md](refactoring-techniques.md).

---

## Group 1 — Bloaters

*Code, methods and classes that have grown to unmanageable size, usually gradually enough that
nobody noticed.*

### Long Method

- **Symptom** — A method you cannot hold in your head at once. Rough threshold: more than ~10–15 lines, or any need for a comment explaining a *section* of it.
- **Cause** — It is always easier to add a line to an existing method than to find the right home for it.
- **Cure** — Extract Method; Replace Temp with Query; Introduce Parameter Object; Preserve Whole Object. Loop or conditional bodies are usually the natural extraction boundary. If locals get in the way, Replace Method with Method Object.
- **Payoff** — The single highest-value refactoring available. Short, well-named methods are self-documenting and make duplication visible.
- **Leave it when** — The method is a flat, linear sequence with no branching and no reuse potential — a configuration block or a long constructor of literals.

### Large Class

- **Symptom** — A class with too many fields, methods, or reasons to change. God objects, fat controllers, 2000-line models.
- **Cause** — Accretion. It was the obvious place to put things, so things kept being put there.
- **Cure** — Extract Class; Extract Subclass; Extract Interface; Duplicate Observed Data. Group fields that are always used together — that grouping is the new class.
- **Payoff** — Restores single responsibility and makes the class testable in isolation.
- **Leave it when** — It is genuinely one cohesive concept with many small accessors, such as a rich value object.

### Primitive Obsession

- **Symptom** — Strings, ints and arrays standing in for domain concepts: `string $email`, `int $cents`, `array $address`, `string $status` with magic values.
- **Cause** — Adding a field is quick; creating a type feels like ceremony.
- **Cure** — Replace Data Value with Object; Replace Type Code with Class / Subclasses / State-Strategy; Introduce Parameter Object; Replace Array with Object; Replace Magic Number with Symbolic Constant.
- **Payoff** — Validation lives in one place, the type system catches misuse, and behaviour has an obvious home. `Money` cannot be added to `Meters`.
- **Leave it when** — The value is genuinely a primitive with no rules attached and no behaviour of its own.
- **Note** — This is the most under-diagnosed smell in typical business code and the one whose cure pays back fastest.

### Long Parameter List

- **Symptom** — More than three or four parameters, especially with booleans or nullable values among them.
- **Cause** — Merging methods, or passing everything a method might need instead of what it does need.
- **Cure** — Introduce Parameter Object; Preserve Whole Object; Replace Parameter with Method Call. Boolean parameters specifically: Replace Parameter with Explicit Methods.
- **Payoff** — Call sites become readable and argument-order bugs disappear.
- **Leave it when** — Named arguments make the call site clear and the parameters have no natural grouping.

### Data Clumps

- **Symptom** — The same group of fields or parameters travelling together: `$street, $city, $postcode, $country` in six signatures.
- **Cause** — Nobody named the concept the group represents.
- **Cure** — Extract Class; Introduce Parameter Object; Preserve Whole Object.
- **Test** — Delete one member of the clump. Do the others still make sense? If not, it is an object.
- **Payoff** — Names the missing domain concept, which usually attracts behaviour that was scattered.

---

## Group 2 — Object-Orientation Abusers

*Object-oriented tools applied incompletely or incorrectly.*

### Switch Statements

- **Symptom** — A `switch` or `match` on a type code, repeated in more than one place.
- **Cause** — A concept that wants to be a type is stored as a value.
- **Cure** — Replace Conditional with Polymorphism, via Replace Type Code with Subclasses or Replace Type Code with State/Strategy. Extract Method then Move Method to relocate each branch onto the right class.
- **Payoff** — Adding a case stops requiring edits in N places, which is the actual harm.
- **Leave it when** — The switch appears exactly once, is a factory choosing which object to build, or the cases are a closed set that will not grow. A single `match` is often the *right* answer — this smell is about repetition, not about branching.

### Temporary Field

- **Symptom** — A field only populated during certain operations, empty or meaningless the rest of the time.
- **Cause** — Avoiding a long parameter list by stashing values on the instance.
- **Cure** — Extract Class for the fields and the algorithm that uses them; Replace Method with Method Object; Introduce Null Object where callers check for the empty state.
- **Payoff** — Removes invisible temporal coupling, where methods must be called in a hidden order.

### Refused Bequest

- **Symptom** — A subclass that inherits methods or fields it does not want, or overrides them to throw.
- **Cause** — Inheritance used for code reuse rather than for genuine substitutability. A Liskov violation.
- **Cure** — Replace Inheritance with Delegation; Extract Superclass so both share only what is real; Push Down Method/Field.
- **Payoff** — Restores the guarantee that a subtype can stand in for its parent — which is the only reason inheritance is safe.

### Alternative Classes with Different Interfaces

- **Symptom** — Two classes doing the same job with different method names and signatures.
- **Cause** — Parallel development, or a copy-paste that then diverged.
- **Cure** — Rename Method; Move Method; Add/Remove Parameter to converge signatures; then Extract Superclass or Extract Interface. If one is third-party, Adapter.
- **Payoff** — Makes them substitutable, which is a precondition for Strategy or any polymorphic dispatch.

---

## Group 3 — Change Preventers

*Structures where one change forces many others. The most expensive group, because the cost is
paid on every future change rather than once.*

### Divergent Change

- **Symptom** — One class changed for many unrelated reasons. "When the tax rules change I edit `Order`; when the export format changes I edit `Order`."
- **Cause** — Multiple responsibilities in one class.
- **Cure** — Extract Class along the axes of change. One class, one reason to change.
- **Payoff** — Changes stop touching unrelated logic, which is where regressions come from.

### Shotgun Surgery

- **Symptom** — The inverse: one conceptual change forces small edits in many classes. Adding a currency means touching eleven files.
- **Cause** — A responsibility smeared thin across the codebase.
- **Cure** — Move Method; Move Field; Inline Class to consolidate. The goal is one obvious place for that kind of change.
- **Payoff** — Reduces the chance of forgetting one of the eleven — the most common source of production bugs in this shape of code.
- **Note** — Divergent Change and Shotgun Surgery are opposites. Curing one carelessly creates the other; aim for cohesive modules, not for either extreme.

### Parallel Inheritance Hierarchies

- **Symptom** — Every new subclass of `A` requires a new subclass of `B`.
- **Cause** — Two hierarchies modelling the same variation.
- **Cure** — Move Method and Move Field to make one hierarchy reference the other; often collapses into Bridge, Strategy, or Visitor.
- **Leave it when** — The duplication is two classes deep and stable. The cure can cost more than the smell.

---

## Group 4 — Dispensables

*Things whose removal makes the code better. The cheapest wins available.*

### Duplicate Code

- **Symptom** — The same or near-same fragment in several places.
- **Cause** — Copy-paste, or parallel work by different people.
- **Cure** — Same class: Extract Method. Sibling classes: Pull Up Method, Form Template Method. Unrelated classes: Extract Class, or Substitute Algorithm first to make them identical. Similar-but-different conditionals: Consolidate Conditional Expression.
- **Careful** — Coincidental duplication is not duplication. Two fragments that look alike but change for different reasons must stay separate; unifying them creates coupling that is worse than the copy. Ask whether they would always change together.

### Dead Code

- **Symptom** — Unreachable code, unused variables, parameters, classes, feature flags never toggled.
- **Cure** — Delete it. Version control is the archive.
- **Payoff** — Immediate. Dead code costs reading time forever and misleads during debugging.
- **Note** — Commented-out code is dead code. Delete it.

### Lazy Class

- **Symptom** — A class that does too little to justify existing.
- **Cause** — Aggressive early splitting, or a class left behind after refactoring shrank it.
- **Cure** — Inline Class; Collapse Hierarchy.
- **Leave it when** — It exists to name a domain concept, or it is a deliberate seam for testing or future extension that is already planned.

### Speculative Generality

- **Symptom** — Abstractions, hooks, parameters and interfaces added for needs that never arrived. Interfaces with one implementation. Abstract classes with one subclass. `handle($data, $options = [])` where `$options` is never passed.
- **Cause** — "We might need it." The direct cause of most over-engineering.
- **Cure** — Collapse Hierarchy; Inline Class; Remove Parameter; Rename Method to say what it actually does.
- **Note** — This is the smell the YAGNI gate in `SKILL.md` exists to prevent. Every unnecessary pattern becomes this smell within a year.

### Data Class

- **Symptom** — A class of fields with getters and setters and no behaviour, whose data is manipulated by other classes.
- **Cause** — Anemic modelling: data here, logic elsewhere.
- **Cure** — Move Method to bring behaviour to the data; Encapsulate Field; Encapsulate Collection; Remove Setting Method for values that should be immutable.
- **Leave it when** — It is deliberately a DTO at a system boundary — an API payload, a serialization shape, a value crossing a process. DTOs *should* be behaviourless. Anemic *domain* models are the smell; anemic *transfer* objects are the pattern.

### Comments

- **Symptom** — Comments explaining *what* the code does, or apologising for it.
- **Cause** — Complex code written, then annotated instead of clarified.
- **Cure** — Extract Method with a name that says what the comment said; Rename Method; Introduce Assertion for assumptions; Extract Variable for confusing expressions.
- **Keep comments that** — explain *why* a non-obvious decision was made, cite a spec, warn about a workaround for a known upstream bug, or document a public API. Those are documentation, not smell.

---

## Group 5 — Couplers

*Excessive coupling between classes, or coupling replaced by too much delegation.*

### Feature Envy

- **Symptom** — A method more interested in another class's data than its own: repeated `$order->getCustomer()->getAddress()->getCountry()`.
- **Cause** — Behaviour placed where it was convenient rather than where the data lives.
- **Cure** — Move Method; Extract Method then Move Method for the envious portion.
- **Rule** — Put the behaviour where the data is. That is most of what object orientation buys you.
- **Leave it when** — The behaviour deliberately lives outside for a reason: a reporting layer, a Visitor, a Strategy that must stay outside the data class.

### Inappropriate Intimacy

- **Symptom** — Two classes reaching into each other's private parts, bidirectional references, or friend-like access.
- **Cure** — Move Method/Field; Extract Class for shared concerns; Change Bidirectional Association to Unidirectional; Hide Delegate; Replace Inheritance with Delegation.
- **Payoff** — Each class becomes independently understandable and testable.

### Message Chains

- **Symptom** — `$a->b()->c()->d()->e()`. The client is coupled to the whole navigation path.
- **Cure** — Hide Delegate; Extract Method then Move Method to move the operation to where the chain ends.
- **Related** — The Law of Demeter. Note that fluent builders and query builders are chains *by design* and are not this smell — the test is whether the chain traverses *different objects' internals*.
- **Careful** — Over-applying Hide Delegate produces Middle Man. These two smells are the two ends of one dial.

### Middle Man

- **Symptom** — A class where most methods just delegate onward.
- **Cause** — Over-zealous delegate hiding, or a layer that stopped earning its keep.
- **Cure** — Remove Middle Man; Inline Method; Replace Delegation with Inheritance if the relationship is genuinely an is-a.
- **Leave it when** — It is a deliberate Facade, Proxy, Adapter, or Anti-Corruption Layer. Those *should* delegate — the point is the boundary, not the work.

### Incomplete Library Class

- **Symptom** — A third-party class missing something you need, and you cannot modify it.
- **Cure** — Introduce Foreign Method for one or two additions; Introduce Local Extension (subclass or wrapper) for several; Adapter when your domain wants a different interface entirely.
- **Payoff** — Keeps the workaround in one place instead of scattering helper functions.

---

## Working with smells

1. **One smell at a time.** Fixing several at once makes bisecting a regression impossible.
2. **Tests before treatment.** Always. See [refactoring-workflow.md](refactoring-workflow.md).
3. **A smell is evidence, not a verdict.** Investigate before treating; sometimes the code is fine and the surrounding design is the problem.
4. **Prioritise Change Preventers.** Bloaters cost reading time; Change Preventers cost every future change. Divergent Change and Shotgun Surgery are where refactoring effort pays back most.
5. **Do not refactor and change behaviour in the same commit.** Ever. It makes review and revert impossible.

---

## Source

Taxonomy: <https://refactoring.guru/refactoring/smells>. Original source: Martin Fowler,
*Refactoring: Improving the Design of Existing Code*, with the smell catalogue co-authored
with Kent Beck. This file is original commentary.
