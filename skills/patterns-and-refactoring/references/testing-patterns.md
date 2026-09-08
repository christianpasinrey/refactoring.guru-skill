# Testing patterns and refactorings

Tests are not a follow-up to a design decision. They are the first piece of evidence about
whether the decision was right.

**Testability is design feedback.** If a pattern makes the code harder to test, the pattern is
wrong for this code — that is not a testing problem to be solved with a cleverer mock. A test
that needs five doubles to run one method is describing the method's dependencies, not the
test framework's limits. Fix the design; the test gets simple by itself.

This file says *which* tests each pattern and each refactoring needs. The mechanics of
building a safety net around legacy code — seams, sprout and wrap, the Mikado Method — are in
[refactoring-workflow.md](refactoring-workflow.md).

---

## What each pattern needs from its tests

The pattern absorbed one axis of change. The tests must exercise **that axis**, not just the
happy path through one variant. A Strategy with one implementation tested is an `if` with
extra files.

| Pattern | The tests it needs | Do NOT |
|---|---|---|
| **Strategy** ([catalogue](gof-catalog.md#strategy)) | One **contract test suite** run against *every* implementation (same inputs, same guarantees), plus one **selection test** proving the right strategy is resolved for each key | Test only the implementation you wrote today. The contract is the point |
| **Decorator** ([catalogue](gof-catalog.md#decorator)) | Each layer alone over a stub subject, plus one **wrapping-order** test on the composed stack (logging-around-retry differs from retry-around-logging) | Test the full stack only; a broken inner layer hides behind an outer one |
| **Observer / events** ([catalogue](gof-catalog.md#observer)) | Each listener in isolation with a hand-built event, plus one **wiring** assertion that the event is dispatched (`Event::fake()`-style) and one that the listener is registered | Assert side effects through the whole event chain; that pins the wiring *and* every listener in one brittle test |
| **State** ([catalogue](gof-catalog.md#state)) | A **transition table** test: every legal transition succeeds, every illegal one throws or is refused, and the object's behaviour differs per state | Test transitions only via the happy path; the illegal transitions are the rule being enforced |
| **Chain / pipeline / middleware** ([catalogue](gof-catalog.md#chain-of-responsibility)) | Each handler alone (handles, passes, or short-circuits), plus one test of the **full chain's order** and one for "nobody handled it" | Assume order; it is the classic silent bug in this pattern |
| **Command / job** ([catalogue](gof-catalog.md#command)) | Runs twice, one effect (**idempotent on retry**); serialises and deserialises without losing state; failure path leaves no half-applied change | Test only a single successful run; queues retry |
| **Adapter / Gateway / ACL** ([catalogue](gof-catalog.md#adapter)) | A **contract test** against recorded real responses (fixtures), covering the error shapes too; one **live smoke test** run on demand, not in CI | Mock the SDK's internals. You then test your assumptions about the vendor, which is what the adapter exists to isolate |
| **Repository / query object** ([catalogue](enterprise-patterns.md#repository)) | An **integration test against the real database**, in a transaction that rolls back | Mock the repository to unit-test the service. That mostly tests that the mock agrees with itself |
| **Template Method** ([catalogue](gof-catalog.md#template-method)) | Through **concrete subclasses**, each proving its steps run in the skeleton's order | Test the abstract class through a test-only subclass; that pins the hooks, which are the fragile part |
| **Factory / Builder** ([catalogue](gof-catalog.md#builder)) | **Invariants of the produced object**: it is never observable half-built, required parts are enforced, subclass selection matches the key | Assert on the factory's internals or on `instanceof` alone |
| **Value Object** ([catalogue](ddd-patterns.md#value-object)) | Equality by value, immutability (mutation yields a new instance), **invalid construction rejected**, and the arithmetic or rules it owns (`Money` refuses mixed currencies) | Skip the invalid-construction tests; they are the whole reason the type exists |
| **Saga / Outbox / Idempotent Receiver** ([catalogue](distributed-patterns.md#saga)) | **Duplicate delivery** (same message twice, one effect), **crash between steps** (state and event agree after recovery), compensation actually undoes | Test the sequence only in the order it was designed to run |

A refactoring that *reached* a pattern (Path B → Path A) inherits this table: the pinned
characterization cases stay green, and the pattern's own tests are added on top in the commit
that introduces it.

---

## Test doubles

Five kinds. Naming which one you are using is most of the way to using it correctly.

| Double | What it does | Reach for it when |
|---|---|---|
| **Dummy** | Passed but never used | A signature demands an argument the test does not care about |
| **Stub** | Returns canned answers | The subject needs input from a collaborator; you assert on the subject's *output* |
| **Spy** | Records what was called | You assert on the subject's *outgoing* calls after the fact, without failing mid-run |
| **Mock** | Pre-programmed expectations that fail the test if unmet | An outgoing call to a boundary *is* the behaviour under test (a payment was charged, an email was sent) |
| **Fake** | A working, simplified implementation (in-memory store, fake clock, fake transport) | The double has real behaviour the test depends on — ordering, lookups, state across calls |

**Mock only what you own, and only at a boundary.** A mock of a third-party SDK asserts your
guess about its contract; wrap the SDK in a Gateway you own and mock that. Inside the boundary,
prefer real objects — a real value object, a real domain service — over doubles.

**A fake beats a mock when the double has behaviour.** An in-memory `UserStore` that actually
stores and finds is less code than three mocks with call expectations, and it does not break
when the subject reorders its calls.

**The signal:** a test that needs more than two mocks is telling you the unit boundary is
wrong. Either the subject has too many collaborators (Large Class, Divergent Change — see
[code-smells.md](code-smells.md#large-class)) or the test is drawn around the wrong unit. Move
the boundary; do not add a fourth mock.

---

## Safety nets for refactoring

Mechanics in [refactoring-workflow.md](refactoring-workflow.md#when-there-are-no-tests). The
shapes:

### Characterization tests

- **Shape** — A generator over representative inputs; run the *current* code; freeze the actual outputs into a cases file; a test that replays the cases with **strict equality, including types**. `0` and `0.0` are different results, and Extract Method with a return type will silently change one into the other.
- **Coverage target** — Every branch you intend to touch, plus the boundaries around it (empty input, zero, null, the largest realistic case). Not every path in the file.
- **The pinned bug** — When a case captures wrong behaviour, it stays pinned through the whole refactor. Its expectation moves in exactly one commit: the fix. If the correct behaviour is ambiguous, it does not move at all until someone decides.
- **Do NOT** — Write the expected values by hand from the spec. That is a test of the spec, and it will fail on the first divergence, which is the moment you most need it green.

### Approval / snapshot tests

- **Shape** — Capture a large output (report, document, payload, rendered HTML) as a committed baseline; the test diffs against it.
- **Use when** — Assertions by hand would number in the hundreds. The only practical net around a 900-line generator.
- **Cost** — Coarse. A diff tells you *that* something changed, not why. Pair with targeted tests on the part you are refactoring, and review every baseline update as deliberately as a code change.

### No runner installed

The absence of `vendor/` or `node_modules` is not the absence of a safety net.

- Put the cases in a plain data file. Write a plain script that loads it, runs the code, compares strictly, and exits non-zero on drift. Run it after every step.
- Write the real test class against the same cases file so CI consumes it later without rewriting the cases.
- Do NOT skip the net because the runner is missing, and do NOT let the plain script drift into a second test framework.

---

## Testing the constraints a decision depends on

Decisions often rest on a non-functional requirement — "must stream", "must retry", "must run
once". If the tests do not pin it, the next refactor removes it without noticing.

| Constraint | Assert on | Never assert on |
|---|---|---|
| **Memory / streaming** | The query count with N+1 rows over the chunk size (chunking happened); the return type is a `Generator` / iterator; the first row arrives before the last is loaded | `memory_get_usage()` or wall-clock memory. Environment-dependent, flaky, and it measures the runtime, not your design |
| **Timeouts / retries** | A **fake clock** and a **fake transport**: N failures then success yields N+1 calls with the expected backoff; the final failure surfaces; a `429` honours `Retry-After` | Real sleeps, real network. See [distributed-patterns.md](distributed-patterns.md#retry) |
| **Concurrency / idempotency** | Run the handler twice with the same message → one effect; run two interleaved → one wins, the other is rejected or merged as designed. See [concurrency-patterns.md](concurrency-patterns.md#idempotency-and-exactly-once) | A single run passing. Duplicates are the case |
| **Ordering** | The observed **sequence** (a spy recording calls, an outbox table, an event log) | Timestamps or sleeps to force order |
| **Isolation / tenancy** | A second tenant's data is *absent* from the result, explicitly | Only the presence of the right tenant's rows |

---

## Test smells

Tests rot the same way production code does, and the smells have names.

| Smell | Looks like | Cure |
|---|---|---|
| **Mystery Guest** | The test depends on a fixture file, a seeded row or an env var not visible in the test | Build the data in the test, or name the fixture in the test body |
| **Eager Test** | One test method checks six behaviours | Split. One behaviour per test; the name says which |
| **Assertion Roulette** | Ten unlabelled assertions; the failure message says `false is not true` | Fewer assertions per test, or messages that name the expectation |
| **Conditional Test Logic** | `if` / loops inside the test deciding what to assert | Parametrise (data providers). A test with branches has untested branches |
| **Test Logic in Production** | `if (app()->runningUnitTests())` in the code under test | Introduce a seam and inject the double instead |
| **Fragile Test** | Over-specified mocks: exact call order, exact argument count, on internal collaborators | Assert on outcomes; mock at the boundary only; replace mocks with fakes |
| **Slow Test** | `sleep()` waiting for something async | Wait on a condition or a fake clock, never on time. See [concurrency-patterns.md](concurrency-patterns.md#async-composition) |
| **Obscure Test** | Forty lines of setup before one assertion | Extract builders / object mothers; keep the relevant values visible in the test |
| **Duplicated fixture setup** | The same ten-line arrangement in thirty tests | A builder or factory with sensible defaults, overriding only what the test is about |
| **Testing private methods** | Reflection to reach a `private` method | The method wants to be public on a class of its own. Extract Class is due — see [refactoring-techniques.md](refactoring-techniques.md#2-moving-features-between-objects) |

---

## The honest pyramid

Where each kind of test earns its place, and the one that usually does not.

- **Unit tests** — for pure logic and value objects: pricing rules, parsers, state machines, `Money`. Fast, precise, no doubles needed because the code has no collaborators worth doubling. This is where a Domain Model pays back.
- **Integration tests** — with the real database and the real framework, in a rolled-back transaction, for anything that touches the ORM, the container, routing, validation, or events. Slower, and they catch the bugs that actually ship: a missing binding, a wrong column, an N+1, a policy not applied.
- **End-to-end** — a handful, at the boundary (HTTP, CLI, queue), proving the wiring for the critical paths. Expensive; keep them few and stable.

**The mocked-repository unit test is usually the worst of the three.** It is slower to write
than the integration test, it proves that the service calls the mock in the way the mock
expects, and it goes green while the real query is wrong. If the service is worth unit-testing
without a database, that is evidence for a real domain layer — not for a mock.

**Coverage on changed lines, not global coverage.** Global coverage is a vanity metric and it
is gamed by testing getters. The question that matters for a change is whether the lines that
moved are exercised by a test that would fail if they moved wrongly.

---

## Sources

Gerard Meszaros, *xUnit Test Patterns* (doubles taxonomy, test smells) · Martin Fowler,
[*Mocks Aren't Stubs*](https://martinfowler.com/articles/mocksArentStubs.html) · Michael
Feathers, *Working Effectively with Legacy Code* (characterization tests) · Vladimir Khorikov,
*Unit Testing Principles, Practices, and Patterns* · Kent Beck, *Test-Driven Development by
Example*. Original commentary.
