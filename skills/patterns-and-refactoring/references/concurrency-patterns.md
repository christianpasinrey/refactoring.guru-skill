# Concurrency and asynchrony patterns

Concurrency bugs are the most expensive kind: they are intermittent, environment-dependent, and
rarely reproducible in a debugger. These patterns exist to make concurrent code *structurally*
correct rather than correct by inspection.

**The strongest pattern is avoidance.** Immutable data cannot race. A queue with one consumer
does not need locks. Before reaching for anything here, check whether the shared mutable state
can simply be removed.

---

## The problems, named

| Problem | What happens |
|---|---|
| **Race condition** | Outcome depends on timing between threads |
| **Deadlock** | Two holders each wait for the other's lock, forever |
| **Livelock** | Threads keep responding to each other and make no progress |
| **Starvation** | One thread never gets scheduled or never acquires the lock |
| **Lost update** | Two read-modify-writes; the second overwrites the first silently |
| **Torn read** | A partially-updated value is observed |
| **Thundering herd** | Every waiter wakes at once for one available resource |
| **Priority inversion** | A low-priority holder blocks a high-priority waiter |

Being able to name which one you have is most of the fix.

---

## Structural patterns

### Producer-Consumer

- **Intent** — Producers put work on a bounded queue; consumers take it off. The queue is the only shared state.
- **Use when** — Work arrives at a different rate than it is processed. Job queues, import pipelines, log shipping.
- **The bound matters.** An unbounded queue converts backpressure into an out-of-memory crash. Bound it and decide explicitly what happens when it is full: block, drop, or reject.
- **Related** — Competing Consumers and Queue-Based Load Leveling in [distributed-patterns.md](distributed-patterns.md).

### Thread Pool / Worker Pool

- **Intent** — A fixed set of workers pulls from a shared queue, instead of spawning a thread per task.
- **Use when** — Tasks are numerous and short. Thread creation is expensive and unbounded threads are a self-DoS.
- **Sizing** — CPU-bound: roughly the core count. IO-bound: much higher, since workers spend their time blocked. Measure; do not guess.
- **Trap** — Pool-within-pool deadlock: a task in the pool blocks waiting on another task in the *same* pool. Use separate pools for dependent stages (this is Bulkhead).

### Actor Model

- **Intent** — Independent actors own private state and communicate only by asynchronous messages. No shared memory, so no locks.
- **Use when** — Many independent stateful entities: connections, game sessions, devices, chat rooms.
- **Trade-off** — Removes data races by construction. Introduces message ordering, mailbox growth, and supervision/restart semantics as new concerns.
- **Seen in** — Erlang/Elixir processes, Akka, Orleans virtual actors.

### Reactor / Event Loop

- **Intent** — A single thread demultiplexes IO events and dispatches handlers. Concurrency without parallelism.
- **Use when** — IO-bound work with many connections. Node.js, Nginx, ReactPHP, Swoole, Python asyncio.
- **The rule** — Never block the loop. One synchronous CPU-heavy call stalls every connection. Offload heavy work to a pool or another process.
- **Proactor** — The variant where the OS completes the IO and *then* calls you (Windows IOCP, io_uring), rather than telling you it is ready.

### Half-Sync/Half-Async

- **Intent** — An async layer accepts events and hands work to a synchronous layer through a queue.
- **Use when** — Business logic is far simpler written synchronously, but IO must be async. This is what a web server plus a job queue already is.

### Pipeline / Fork-Join

- **Pipeline** — Stages run concurrently, each handing off to the next. Throughput is bounded by the slowest stage.
- **Fork-Join** — Split a task recursively, run the parts in parallel, combine results. Fits divide-and-conquer over large in-memory data.
- **Scatter-Gather** — The distributed cousin: fan out requests, gather responses, with a timeout for stragglers.

---

## Synchronisation patterns

| Pattern | Intent | Watch for |
|---|---|---|
| **Monitor / Mutex** | One thread at a time inside the critical section | Keep sections tiny; acquire locks in a globally consistent order or you will deadlock |
| **Read-Write Lock** | Many readers, or one writer | Only wins when reads massively outnumber writes; writer starvation under constant reads |
| **Semaphore** | Cap concurrent access to N | The standard way to bound calls to a rate-limited API |
| **Barrier** | All participants wait until everyone arrives | One slow participant holds everyone |
| **Latch** | Wait until a one-time event fires | Single-use, unlike a barrier |
| **Double-Checked Locking** | Lock only if the check fails | **Subtly broken** without proper memory barriers. Use the language's lazy-init primitive instead |
| **Thread-Local Storage** | Per-thread state, no sharing | Leaks in pooled threads — the next task inherits it |
| **Copy-on-Write** | Readers see an immutable snapshot; writers copy | Excellent for read-heavy config and caches |
| **Optimistic locking** | Version check on write, retry on conflict | The database-level version — see [enterprise-patterns.md](enterprise-patterns.md#offline-concurrency) |

**Lock ordering is the deadlock cure.** If every code path acquires locks in the same global
order, circular waits are impossible. Document the order; enforce it in review.

---

## Async composition

| Pattern | Intent |
|---|---|
| **Future / Promise** | A handle on a value that will exist later |
| **Async/Await** | Sequential-looking syntax over promise chains |
| **Deferred / Completion Source** | A promise you complete manually from elsewhere |
| **Cancellation Token** | Cooperative cancellation propagated through a call tree |
| **Debounce** | Run once after activity stops (search-as-you-type) |
| **Throttle** | Run at most once per interval (scroll handlers) |
| **Single-Flight / Request Coalescing** | Collapse concurrent identical requests into one, share the result |
| **Backpressure** | The consumer signals the producer to slow down |
| **Circuit Breaker** | See [distributed-patterns.md](distributed-patterns.md#circuit-breaker) |

**Single-Flight** deserves attention: it is the cure for the cache stampede, and it is a dozen
lines. When a hot key expires, one request recomputes and the rest wait on the same promise
rather than all hammering the database.

**Async traps worth naming:**

- **Sequential awaits** where parallel would do — `await a(); await b();` when neither depends on the other. Use `Promise.all` / `Task.WhenAll`.
- **Floating promises** — an un-awaited promise whose rejection is never handled and vanishes silently.
- **Async in a loop** over a large collection, launching thousands of concurrent operations. Bound the concurrency.
- **Blocking on async** (`.Result`, `.wait()`) from a synchronous context — classic deadlock in single-threaded-context runtimes.

---

## Immutability and isolation

The patterns that eliminate the problem rather than manage it.

| Approach | Effect |
|---|---|
| **Immutable objects** | Cannot race — no writes to observe. The single most effective concurrency technique |
| **Value semantics / copy on pass** | Each holder gets its own copy |
| **Confinement** | State is reachable from exactly one thread; no synchronisation needed |
| **Message passing (CSP / channels)** | Share by communicating, not by sharing memory. Go channels, Rust `mpsc` |
| **Persistent data structures** | Structural sharing gives cheap immutable updates |
| **Event sourcing / append-only** | Appends do not conflict the way in-place updates do |

**Rust's guarantee** — one mutable reference *or* many immutable ones — is this idea enforced by
a compiler. Even without such a compiler, adopting the rule by convention prevents most races.

---

## Idempotency and exactly-once

Worth stating plainly because it is widely misunderstood.

- **Exactly-once *delivery* does not exist** in a distributed system. Anyone claiming it means at-least-once delivery plus deduplication.
- **Exactly-once *processing* is achievable** — through idempotent consumers or a deduplication store keyed by message ID.
- **Design every handler to be safely repeatable.** Prefer absolute operations (`SET status = 'paid'`) over relative ones (`balance = balance - 10`); when relative is unavoidable, guard with a processed-message record in the same transaction.

---

## Concurrency in PHP specifically

Worth calling out, since the classic PHP model has no threads.

- **Process-per-request** is the default. Almost no in-process concurrency, therefore almost no data races — a real safety advantage that is easy to forget you are relying on.
- **The shared mutable state is the database and the cache.** Concurrency bugs move there: lost updates without optimistic locking, cache stampedes, double-processed jobs.
- **Queue workers are the concurrency model.** Jobs must be idempotent because retries are automatic. Use unique-job locks for work that must not run twice concurrently.
- **Atomic cache operations** (`add`, `increment`, lock helpers) are your mutex. `get`-then-`set` is a race.
- **Long-running runtimes** (Swoole, RoadRunner, FrankenPHP, Octane) remove the process-per-request safety net: static properties, container singletons and thread-local-ish state now persist between requests and leak across users. Code that was safe under FPM may not be.

---

## Sources

Douglas Schmidt et al., *Pattern-Oriented Software Architecture, Volume 2* (Reactor, Proactor,
Half-Sync/Half-Async) · Brian Goetz, *Java Concurrency in Practice* · Carl Hewitt, Actor Model ·
Tony Hoare, *Communicating Sequential Processes*. Original commentary.
