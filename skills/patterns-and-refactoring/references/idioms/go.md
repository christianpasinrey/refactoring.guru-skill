# Go

[← back to router](../framework-idioms.md)

---

## Go deliberately omits most of the catalogue

Go's design removes the need for a large part of the GoF catalogue rather than implementing it.
Reaching for a classic pattern in Go is usually a sign of writing Java in Go's syntax.

| GoF pattern | Why Go does not need it |
|---|---|
| **Abstract Factory / Factory Method** | A function returning an interface is a factory. No hierarchy required |
| **Singleton** | A package-level variable plus `sync.Once`. Still a global — prefer passing it |
| **Null Object** | Zero values are usable: `var buf bytes.Buffer` works with no constructor |
| **Iterator** | `range`; the `iter.Seq` iterators added in Go 1.23 |
| **Template Method** | Struct embedding plus an interface. Composition, not inheritance |
| **Decorator** | A function taking and returning the same interface — the middleware idiom |
| **Command** | A `func()` value, or a struct sent on a channel |
| **Observer** | Channels; a slice of callbacks |
| **Strategy** | An interface with one method, or a function type. Often just a `func` field |
| **Adapter** | `http.HandlerFunc` is the canonical example: a function type adapted to an interface |
| **Visitor** | Type switches over a closed set. Verbose but explicit |
| **Prototype** | Struct copy is a value copy by default |

---

## The idioms that replace them

### Accept interfaces, return structs

Define the interface **where it is consumed**, not where it is implemented. Interfaces in Go are
satisfied structurally, so the consumer declares exactly what it needs:

```go
// in the consuming package — small, specific, defined by the need
type UserStore interface {
    ByID(ctx context.Context, id int64) (*User, error)
}
```

This is Extract Interface and Ports & Adapters, done without ceremony and without a `Repository`
directory. The interface is one method wide because that is all the consumer uses.

### The bigger the interface, the weaker the abstraction

`io.Reader` and `io.Writer` are one method each and compose into everything. A ten-method
interface is describing an implementation, not an abstraction.

### Middleware — Chain of Responsibility as function composition

```go
func Logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // before
        next.ServeHTTP(w, r)
        // after
    })
}
```

Decorator and Chain of Responsibility in one idiom. Every Go HTTP router uses it, and hand-rolling
a handler chain instead is fighting the ecosystem.

### Functional options — Builder for constructors

```go
func New(opts ...Option) *Client
func WithTimeout(d time.Duration) Option
```

The idiomatic answer to Long Parameter List and optional configuration. It keeps the zero value
useful and the API backward-compatible when options are added.

### Errors are values

`(T, error)` returns are Result/Either without a type. `errors.Is` and `errors.As` give typed
inspection; `fmt.Errorf("...: %w", err)` gives a wrapping chain.

**Never** `_ = err`. The one thing Go's verbosity buys you is that ignoring an error is visible
in review — do not spend that.

`panic` is for programmer error and unrecoverable state, not for control flow.

### `context.Context` — Cancellation Token, framework-wide

First parameter, always. Carries deadlines, cancellation and request-scoped values through the
call tree. It is the standard-library implementation of the Cancellation Token pattern.

Do not store a `Context` in a struct, and do not use its values for dependencies — only for
request-scoped data like trace IDs.

---

## Concurrency: the actual pattern layer

Go's real pattern catalogue is concurrency, not object structure. See
[../concurrency-patterns.md](../concurrency-patterns.md).

| Pattern | Go idiom |
|---|---|
| **Producer-Consumer** | Buffered channel between goroutines |
| **Worker Pool** | N goroutines ranging over one channel |
| **Fan-out / Fan-in** | Several goroutines reading one channel; results merged onto another |
| **Pipeline** | Stages connected by channels, each closing its output |
| **Semaphore** | A buffered channel used as a token bucket, or `golang.org/x/sync/semaphore` |
| **Barrier** | `sync.WaitGroup` |
| **Scatter-Gather** | `errgroup.Group` with a context |
| **Single-Flight** | `golang.org/x/sync/singleflight` — the cache-stampede cure, in the standard extended library |
| **Backpressure** | Bounded channel capacity |
| **Mutex / RWMutex** | `sync.Mutex`, `sync.RWMutex` |
| **Immutability** | Value semantics; copy on pass |

**"Share memory by communicating"** is the design rule. But `sync.Mutex` is idiomatic too — a
channel is not automatically better for guarding a simple shared counter.

**The channel rules that prevent most bugs:** the sender closes, never the receiver; a nil
channel blocks forever; a goroutine with no exit path is a leak; always pair a goroutine with a
way to stop it.

---

## Project structure

Go's community has largely rejected layered architectures imported from other ecosystems.

- **Package by feature, not by layer.** `internal/billing/` containing its handler, store and logic — not `handlers/`, `services/`, `repositories/`.
- **`internal/`** enforces module boundaries at compile time. This is the strongest modular-monolith enforcement of any mainstream language.
- **Keep `main` thin.** Wire dependencies there explicitly; that wiring *is* your DI container, and being able to read it is a feature.
- **No DI framework.** Explicit constructor arguments in `main`. `wire` generates that wiring at compile time if it grows unwieldy; runtime reflection containers are not idiomatic.

---

## Database access

There is no dominant ORM, and that is deliberate.

| Approach | Pattern |
|---|---|
| **`database/sql`** | Table Data Gateway, by hand |
| **`sqlc`** | Generates type-safe Go from your SQL. Query Object, compile-checked |
| **`sqlx`** | `database/sql` with struct scanning |
| **GORM** | Active Record-ish. Popular, and the least idiomatic option |
| **`pgx`** | Postgres-native driver, best performance |

**`sqlc` is the idiomatic modern answer:** you write SQL, it generates typed methods. You get
the Repository benefit — a named, typed data-access surface — without an abstraction layer,
and the compiler checks the queries.

A hand-written `Repository` interface is more defensible in Go than in Rails or Laravel, because
there is no framework default it duplicates. Keep it small and define it at the consumer.

---

## Going against the grain

- A `services/`, `repositories/`, `models/` layer split imported from Java or C#.
- Interfaces defined in the same package as their single implementation.
- Large interfaces mirroring a struct's whole method set.
- A reflection-based DI container.
- Getters and setters on structs — exported fields are fine.
- `panic` used for expected errors.
- Goroutines started without a way to stop them.
- Generics used where an interface or a concrete type would be clearer. Go generics are for containers and constraints, not for architecture.
