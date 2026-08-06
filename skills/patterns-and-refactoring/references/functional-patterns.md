# Functional patterns

These are not GoF alternatives — they are complements, and several GoF patterns collapse into a
single function once first-class functions exist. Strategy is a function. Command is a closure.
Template Method is a higher-order function taking the varying steps as arguments.

**The core idea:** push side effects to the edges, keep the middle pure. A pure function —
same input, same output, no observable effect — is trivially testable, trivially cacheable,
trivially parallelisable, and impossible to break from a distance.

---

## Foundations

### Pure functions and immutability

- **Pure** — Output depends only on input; nothing observable changes. No IO, no clock, no randomness, no mutation of arguments.
- **Why it matters here** — Most of the hard bugs in a codebase live in the impure parts. Concentrating impurity in a thin shell around a pure core shrinks the surface where those bugs can exist.
- **Practical shape** — *Functional core, imperative shell*: parse and validate at the edge, compute in pure functions, write and send at the edge. Related to Split Phase in [refactoring-techniques.md](refactoring-techniques.md#beyond-the-classic-catalogue).
- **Immutability** — Return new values instead of mutating. Removes aliasing bugs and races. See [concurrency-patterns.md](concurrency-patterns.md#immutability-and-isolation).

### Higher-order functions

Functions taking or returning functions. This is the mechanism behind most of what follows.

| Idiom | Replaces |
|---|---|
| **Callback / handler** | Observer, Command, Strategy — for the simple cases |
| **Decorator function** | GoF Decorator, without the class |
| **Partial application** | A factory that pre-binds configuration |
| **Currying** | A builder for functions: supply arguments over time |
| **Memoization** | Flyweight-ish caching for pure functions |

**When a class earns its place over a closure:** the strategy has more than one method, needs a
name in the domain vocabulary, must be discoverable by other developers, or must be resolvable
from configuration. Otherwise a function is less code and less indirection.

### Composition

- **Pipe / Compose** — Build a bigger function from small ones: `pipe(parse, validate, calculate, format)`.
- **Why** — Each stage is independently testable, and the sequence reads as a description of the process.
- **Related** — Pipes and Filters at the architectural level; Chain of Responsibility at the class level. Laravel's `Pipeline` and Unix pipes are the same idea.

---

## Handling absence and failure

The highest-value functional patterns for ordinary application code.

### Option / Maybe

- **Intent** — Make "might be absent" explicit in the type instead of returning `null`.
- **Why** — `null` is not visible in a signature, so every caller must remember to check and the compiler cannot help. `Option<User>` cannot be used as a `User` by accident.
- **In practice** — Even without a real `Option` type, a nullable return type plus a strict static analyser (PHPStan/Psalm at max level, TypeScript `strictNullChecks`) gets most of the benefit.
- **Related** — Null Object and Special Case in [gof-catalog.md](gof-catalog.md) and [enterprise-patterns.md](enterprise-patterns.md). Null Object *hides* absence behind do-nothing behaviour; Option *surfaces* it. Choose by whether absence is normal or exceptional.

### Result / Either

- **Intent** — A return value that is either success or a typed failure, instead of throwing.
- **Use when** — Failure is expected and part of the domain: validation, parsing, business-rule rejection, calls to unreliable services. The caller must handle it, and the signature says so.
- **Do NOT use when** — Failure is genuinely exceptional and unrecoverable. Exceptions are correct for programmer errors, invariant violations, and infrastructure collapse. `Result` for everything creates as much noise as exceptions for everything.
- **The line** — Exceptions for *exceptional*; Result for *expected*. "The card was declined" is a business outcome, not an exception. "The database is unreachable" is an exception.

### Railway-Oriented Programming

- **Intent** — Chain operations that each return a Result, short-circuiting to the failure track on the first error.
- **Shape** — `parse($in)->then(validate)->then(save)->match(onOk, onErr)`. No nested `if`s, no early-return ladder, and errors cannot be silently skipped.
- **Payoff** — Cures deeply nested validation-and-error blocks, one of the most common shapes of unreadable business code.

---

## Data transformation

### Map / Filter / Reduce

- **Replace Loop with Pipeline** — Named as a refactoring for a reason: `->filter()->map()->sum()` states *what* is computed, where a loop states *how*.
- **Careful** — A chain doing five things is not automatically clearer than a well-named loop, and each stage is a full pass over the data. Do not chain for its own sake.

### Transducer

- **Intent** — Compose transformations without materialising the intermediate collections.
- **Use when** — Long chains over large datasets where each step allocating a new array is a real cost. In PHP, generators achieve the same result more idiomatically.

### Lens / Optics

- **Intent** — Composable getters/setters for nested immutable structures, so a deep update does not require hand-written spread ladders.
- **Use when** — Deeply nested immutable state, most often in frontend state management. Otherwise over-engineering — see the immutable-update helpers in [frontend-patterns.md](frontend-patterns.md).

### Memoization

- **Intent** — Cache a pure function's results by argument.
- **Requires purity.** Memoizing an impure function caches a lie.
- **Watch** — Unbounded memo maps are memory leaks. Bound them or scope them to a request.

---

## Types as design

| Idea | Effect |
|---|---|
| **Make illegal states unrepresentable** | If a `PaidOrder` cannot exist without a payment reference, no runtime check is needed |
| **Parse, don't validate** | Convert unstructured input into a type that *proves* validity at the boundary, once. An `Email` that exists is valid everywhere downstream |
| **Smart constructors** | Private constructor plus a factory returning `Result` — construction is the only validation point |
| **Sum types / discriminated unions** | Model "one of these shapes" so exhaustiveness is checkable |
| **Phantom / branded types** | `UserId` and `OrderId` both wrap `int` but cannot be swapped |

**Parse, don't validate** is the most useful idea on this page for typical business code. The
common alternative — validating repeatedly and passing raw primitives onward — means every
function must re-establish the same guarantees, and one that forgets is the bug.

This is the same insight as Value Object in [ddd-patterns.md](ddd-patterns.md) and the cure for
Primitive Obsession in [code-smells.md](code-smells.md), arrived at from the type-system
direction.

---

## Effects at the edges

| Pattern | Intent |
|---|---|
| **Dependency rejection** | Do not inject a dependency into pure logic — return a *description* of what to do and let the caller do it |
| **Effect as data** | Represent side effects as values (a list of commands to execute), so the decision is testable without performing them |
| **Interpreter of effects** | One place executes the described effects. GoF Interpreter, applied to IO |

Practical version: instead of a method that calculates *and* emails, have it return the
decision (`SendReminder(userId, template)`), and let a thin shell perform it. The rule is now
testable with no mail fake, and the shell is trivial enough not to need tests.

---

## When functional is the wrong call

- **The team does not read it.** Point-free code and heavy currying are illegible to most teams; unread code is unmaintained code.
- **The language fights you.** PHP has closures, first-class callables and generators, but no pattern matching on sum types and no persistent collections. Force-fitting produces verbose code that reads worse than the imperative version.
- **The domain is genuinely stateful.** A game loop, a UI, a device driver. Model the state honestly and keep the *transitions* pure.
- **Performance-critical inner loops.** Allocation per stage is real. Measure before choosing elegance.

Aim for *mostly pure with an impure shell*, not for purity as an ideology. The concrete, always-worth-it
subset: pure business calculations, immutable value objects, Result for expected failures, and
parsing at the boundary.

---

## Sources

Scott Wlaschin, *Domain Modeling Made Functional* and railway-oriented programming ·
Alexis King, *Parse, Don't Validate* · Gary Bernhardt, *Functional Core, Imperative Shell* ·
Rich Hickey on transducers and persistent data structures. Original commentary.
