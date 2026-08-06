# Rust

[← back to router](../framework-idioms.md)

---

## The type system replaces most of the catalogue

Rust encodes several GoF patterns as language features, and makes others actively difficult on
purpose. Fighting the borrow checker to implement a classic pattern is almost always a signal
that the design is wrong for Rust.

| GoF pattern | Rust answer |
|---|---|
| **Strategy** | Trait + generic parameter (static dispatch) or `Box<dyn Trait>` (dynamic) |
| **Template Method** | Trait with default method implementations |
| **Adapter** | Implement the target trait for the foreign type — or a newtype wrapper |
| **Decorator** | Newtype wrapping the inner type, implementing the same trait |
| **Null Object** | `Option<T>` — absence is in the type, and the compiler enforces handling |
| **Iterator** | The `Iterator` trait; lazy, zero-cost, composable |
| **Builder** | The builder idiom, usually derived with `derive_builder` or `typed-builder` |
| **State** | Typestate: each state is a distinct type, and illegal transitions do not compile |
| **Visitor** | `match` on an enum. Exhaustiveness is checked by the compiler |
| **Command** | A closure, or a boxed `dyn FnOnce` |
| **Observer** | Channels (`std::sync::mpsc`, `tokio::sync::broadcast`) |
| **Singleton** | `OnceLock` / `LazyLock`. Deliberately awkward — take the hint |
| **Prototype** | `Clone` |
| **Flyweight** | `Rc<T>` / `Arc<T>` for shared immutable data; string interning |
| **Proxy** | `Deref`; smart pointers are the pattern, built in |

---

## The idioms that matter

### `Result<T, E>` and `?` — errors as values, ergonomically

Rust has no exceptions. `Result` is Railway-Oriented Programming built into the language, and
`?` propagates without ceremony.

- **Library code:** define your own error enum, implement `std::error::Error`, derive with `thiserror`.
- **Application code:** `anyhow::Result` with `.context("...")` for a readable chain.
- **`panic!` is for programmer error only** — a violated invariant, not a failed network call.

`#[must_use]` on `Result` means an ignored error is a compiler warning. This is the strongest
error-handling story of any mainstream language.

### `Option<T>` — no null

Absence is in the type. `map`, `and_then`, `unwrap_or`, `ok_or` compose it without branching
ladders. `unwrap()` in production code is a panic waiting to happen; use `expect("why this
cannot fail")` when you genuinely know, so the message documents the reasoning.

### Newtype — Value Object, enforced

```rust
struct UserId(u64);
struct Meters(f64);
```

Zero runtime cost, and `UserId` cannot be passed where `OrderId` is expected. This is the cure
for Primitive Obsession, and Rust makes it free. Combine with a private field and a validating
constructor for parse-don't-validate.

### Typestate — State, checked at compile time

```rust
struct Draft;   struct Published;
struct Post<S> { body: String, _state: PhantomData<S> }

impl Post<Draft>     { fn publish(self) -> Post<Published> { /* ... */ } }
impl Post<Published> { fn view(&self) -> &str { &self.body } }
```

Calling `view()` on a draft does not compile. This is the State pattern with illegal
transitions eliminated at compile time rather than guarded at runtime — something no other
mainstream language does as cleanly.

### Traits: static vs dynamic dispatch

- `impl Trait` / generics → monomorphised, zero-cost, larger binary.
- `Box<dyn Trait>` → one implementation chosen at runtime, small vtable cost, required for heterogeneous collections.

Default to generics; reach for `dyn` when you genuinely need runtime variation or a
`Vec<Box<dyn T>>`.

### Interior mutability — the escape hatch, used deliberately

`Cell`, `RefCell` (single-threaded), `Mutex`, `RwLock` (threaded), `Rc`/`Arc` for shared
ownership.

`RefCell` moves the borrow check to runtime and panics on violation. Reaching for
`Rc<RefCell<T>>` everywhere usually means an object graph designed for a garbage-collected
language. Consider an arena, indices into a `Vec`, or restructuring toward ownership instead.

---

## Async and concurrency

See [../concurrency-patterns.md](../concurrency-patterns.md).

| Pattern | Rust idiom |
|---|---|
| **Producer-Consumer** | `tokio::sync::mpsc` channels |
| **Worker Pool** | `tokio::spawn` + a shared receiver, or `rayon` for CPU work |
| **Fan-out / Fan-in** | `futures::stream` combinators; `JoinSet` |
| **Semaphore** | `tokio::sync::Semaphore` |
| **Barrier** | `tokio::sync::Barrier`; `JoinSet::join_all` |
| **Cancellation Token** | `CancellationToken`; dropping a future cancels it |
| **Backpressure** | Bounded channels; `Stream` with buffering |
| **Actor** | A task owning state, receiving commands on a channel — the idiomatic Rust actor |
| **Chain of Responsibility** | Tower `Layer` / `Service` — the middleware abstraction behind Axum, Tonic and Hyper |

**Rust's headline guarantee:** data races are prevented at compile time by `Send` and `Sync`.
Most of the concurrency patterns catalogue exists to avoid problems the compiler here refuses
to let you have.

**`Arc<Mutex<T>>` is fine.** It is idiomatic for genuinely shared mutable state. The
anti-pattern is reaching for it before considering message passing or ownership transfer.

---

## Web frameworks

| Framework | Pattern notes |
|---|---|
| **Axum** | Built on Tower — `Layer` is Decorator/Chain of Responsibility; extractors are declarative parsing at the boundary |
| **Actix Web** | Actor model underneath; its own middleware trait |
| **Rocket** | Attribute-driven routing; request guards are validation at the boundary |

| Concern | Idiom |
|---|---|
| **DI** | Explicit state passed through `State<T>` / app data. No container, and none wanted |
| **Data Mapper** | Diesel (compile-checked queries), SeaORM (async, more dynamic) |
| **Query Object** | `sqlx::query!` — SQL verified against the real database at compile time |
| **Unit of Work** | Explicit transaction guards; commit or roll back on drop |
| **Repository** | A trait defined at the consumer, small. Defensible here, since no framework provides one |
| **Retry / Circuit Breaker** | Tower layers (`tower::retry`, `tower::limit`) |

`sqlx`'s compile-time query verification is worth calling out: your SQL is checked against the
actual schema during `cargo build`. That is a stronger guarantee than any ORM abstraction
provides, and it removes most of the argument for a repository layer.

---

## Going against the grain

- Inheritance-shaped designs. Rust has no inheritance; use composition and traits.
- `Rc<RefCell<T>>` used pervasively to recreate a mutable object graph.
- `unwrap()` in production paths.
- `clone()` scattered to silence the borrow checker — usually a signal that ownership needs rethinking.
- `Box<dyn Trait>` where generics would be zero-cost.
- Getters and setters on structs with public fields.
- A `services/repositories/models` layer split imported from another ecosystem.
- Fighting the borrow checker for ten minutes to implement a pattern from a Java book. Step back and design for ownership instead.
