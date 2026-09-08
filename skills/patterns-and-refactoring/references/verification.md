# Verification — auditing the code against the decision

The decision happens before the code. The damage happens during it. An interface "for the
tests", a base class "to share the two lines", a generic helper "since we are here" — none of
these are decided, they accrete while typing. This file is the audit that runs after
implementation and before "done", on every path, at every level above TRIVIAL.

**The audit has teeth only if it can fail.** If every audit reports "all good", it is not being
run. Expect to inline or delete something roughly one time in three.

---

## The abstraction audit

Count, do not estimate. Open the diff and answer with numbers.

| Check | Pass condition | Fail means |
|---|---|---|
| **Interfaces and abstract classes added** | Each has ≥ 2 implementations *in this change*, or is named in the decision as a deliberate seam with its trigger | Speculative Generality. Inline to the concrete class; keep the seam as a plain method boundary |
| **Generic components** ("reusable" writer, mapper, base controller, helper) | ≥ 2 consumers in this change | A library with one user. Inline into the consumer; extract when the second appears |
| **New files vs level** | STANDARD ≈ 1–4 files; ARCHITECTURAL declared as such | Either the triage was wrong (re-triage, write the Pattern Decisions section) or the design is inflated |
| **Class names** | Every new class names a domain concept a product owner would recognise | Pattern-name theatre. Rename to the concept; if no concept fits, the class should not exist |
| **Rejected alternative** | Absent from the code | The `match` next to the Strategy, the wrapper beside the framework feature, the DTO for the internal call — remove one of the two |
| **Framework feature chosen in the decision** | Actually used, not re-implemented beside it | Delete the hand-rolled version |
| **Parameters** | No boolean flags added; no `$options = []` nobody passes | Replace Parameter with Explicit Methods; Remove Parameter |
| **Exceptions** | No new bare `catch (\Throwable)` / `except Exception: pass` | Exception Swallowing. Handle specifically or propagate |
| **Direct version, re-sketched now** | Still genuinely worse than what was built | Rewrite to the direct version. It is cheaper now than after review |

---

## The test audit

Tests are the proof that the axis of change is real. Check that they exercise *the variation*,
not just the happy path.

| You built | Tests must include |
|---|---|
| **Strategy / interchangeable implementations** | One contract test run against every implementation, plus one test that the right one is selected |
| **Decorator / middleware / pipeline** | Each layer alone, and the order of the full stack |
| **Observer / event / listener** | The listener in isolation, and an assertion that the event is dispatched from the right place |
| **State / status transitions** | The transition table: each legal transition passes, illegal ones are rejected |
| **Adapter / gateway / third-party client** | Contract tests against recorded responses; error and timeout paths |
| **Command / job / handler** | Runs twice, one effect (idempotency); serialises and deserialises |
| **Value object** | Invalid input rejected at construction; equality by value; immutability |
| **Refactoring (Path B)** | The characterization or existing suite, green, run *after* the last step — paste the result |
| **NO-PATTERN direct code** | The feature test; nothing else is owed |

Shapes and doubles in detail: [testing-patterns.md](testing-patterns.md).

A test that needed three mocks to reach the code under test is reporting a design problem.
Do not fix the test; look at the boundary.

---

## The simplification pass

Once, after the audit, with the diff open:

1. **Inline** any method, class, or file with one caller that adds a name but not a concept.
2. **Delete** any parameter, branch, or configuration that no caller exercises.
3. **Collapse** any hierarchy with one leaf.
4. **Rename** anything whose name is a mechanism (`Manager`, `Handler`, `Processor`, `Helper`, `Impl`) to what it does in the domain — or accept that the vagueness is the finding.
5. **Read it as the reviewer** who has not seen the decision. Does the code say why it is shaped this way? If the decision is needed to understand the shape, either the shape is wrong or a one-line comment naming the force belongs at the seam.

Then report — three lines, template in
[decision-templates.md](decision-templates.md#verification-report-step-6-every-path).

---

## Failure modes this audit exists to catch

The shapes that appear most often in AI-assisted and enthusiastic-junior code, in order of
frequency. Each is invisible from inside the task and obvious in review.

| Shape | Looks like | Why it appears |
|---|---|---|
| **Interface with one implementation** | `FooInterface` + `Foo`, bound in the container | "For DI" or "for tests". Neither needs it: inject the concrete class; fake at the boundary |
| **Generic utility for one caller** | `CsvWriter`, `ArrayMapper`, `BaseService` used once | "It might be reused." Rule of Three applies to reuse too |
| **DTO for an internal call** | `RecalculateTotalsInputDTO { int $orderId }`, built and consumed in the same class | DTOs cross process or module boundaries; inside a class they are a wrapped int |
| **Wrapper around a stable dependency** | `MyHttpClient` over Guzzle, `CacheService` over the cache facade | "So we can swap it." The wrapper is shaped by the current library and will not fit the replacement |
| **Layer added for symmetry** | A Service that forwards to the model; a Repository that forwards to the ORM | "The other modules have one." Consistency with a smell is still a smell — say so in the decision instead |
| **Pattern folder taxonomy** | `Strategies/`, `Factories/`, `Decorators/` | Files grouped by mechanism, guaranteeing Shotgun Surgery per feature. Group by feature |
| **Event for a direct call** | `UserRegistered` with one listener that always runs | Control flow made invisible for nothing. Call it |
| **Configuration for a decision** | `'exporters' => [...]` in config with one entry | Soft-coding; a `match` would be readable and greppable |
| **Boolean flag added to avoid a second method** | `export($orders, bool $withHeaders)` | Replace Parameter with Explicit Methods |
| **Early abstraction with the wrong shape** | An interface derived from the single existing case | It will not fit the second case; designing it from two costs less than designing it twice |

---

## When the audit fails late

The audit ran, something failed, and the code is already written. The temptation is to keep it
"since it is done".

- **Removing now is cheaper than removing later.** Once callers, tests, and the next feature adapt to the abstraction, it becomes load-bearing and the cost of removal doubles every quarter.
- **Removal is a refactoring** — Inline Class, Collapse Hierarchy, Remove Parameter — with the same rules: tests green before and after, its own commit.
- **The decision text is updated**, not the code bent to match it. If the audit reveals the decision was wrong (a second variant really did exist), rewrite the decision; do not leave a NO-PATTERN decision above a Strategy.

---

## Sources

Martin Fowler on [YAGNI](https://martinfowler.com/bliki/Yagni.html) and
[Speculative Generality]; Sandi Metz, *Practical Object-Oriented Design* (the "wrong
abstraction" argument); John Ousterhout, *A Philosophy of Software Design* (deep vs shallow
modules). Original commentary.
