# Django · FastAPI · Python

[← back to router](../framework-idioms.md)

---

## What Django already gives you

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Active Record** | The Django ORM — models carry data *and* queries | Accept it. Django is opinionated and fighting it is expensive |
| **Query Object** | `QuerySet`, custom `Manager`, `Q` objects | A custom `Manager` *is* a named, composable query object. Use it instead of a repository |
| **Specification** | `Q` objects composed with `&`, `|`, `~` | Genuinely composable rules that translate to SQL — better than most hand-rolled specifications |
| **Unit of Work** | `transaction.atomic()` | Context manager or decorator. Nested blocks use savepoints |
| **Observer** | Signals (`post_save`, `pre_delete`, custom) | **Use sparingly** — see below |
| **Chain of Responsibility** | Middleware | The documented middleware contract, not a custom handler chain |
| **Template Method** | Class-based views (`ListView`, `CreateView`); `Form`; `TestCase` | Override the hook methods (`get_queryset`, `form_valid`) rather than reimplementing dispatch |
| **Strategy** | Any callable; `Protocol` for a typed contract; settings-driven backends | A function is a strategy. A class with one method is usually not needed |
| **Abstract Factory** | Pluggable backends: storage, cache, email, auth | Configure via settings, `import_string` to resolve |
| **Decorator** | Python decorators; view decorators; `@property` | The language feature, not a wrapper class |
| **Proxy** | Lazy `QuerySet` evaluation; `SimpleLazyObject`; deferred fields | Already there — the risk is N+1, not the pattern |
| **Adapter** | Database backends, storage backends, auth backends | Write a backend to the documented interface |
| **Facade** | `django.contrib` app APIs; a `services.py` with a narrow surface | |
| **Builder** | `QuerySet` chaining; `FormSet` factories | |
| **Iterator** | Generators; `QuerySet.iterator()`; `values_list(flat=True)` | `.iterator()` streams; never `list(qs)` on a large table |
| **Value Object** | Custom model fields; `dataclass(frozen=True)`; `NamedTuple` | A custom field maps a column to a value object transparently |
| **Command** | Management commands; Celery tasks | A Celery task *is* a Command: serialisable, retryable, schedulable |
| **Memento** | `django-reversion`; `django-simple-history` | |
| **Front Controller** | URL dispatcher (`urls.py`) | |
| **Template View** | The Django template language | |
| **Identity Map** | **Not provided** | Two queries for the same row give two objects. Same trap as Eloquent |
| **Retry / Circuit Breaker** | Not provided | `tenacity` for retry, `pybreaker` for circuit breaking |

### Signals: the one to be careful with

Signals are Observer, and they are the most-abused feature in Django. Because they are
invisible at the call site, a `post_save` chain becomes impossible to trace and impossible to
disable in tests.

**Use signals for:** genuine cross-app decoupling where the sender legitimately must not know
the receivers.

**Do not use signals for:** logic that always runs when you save. Put it in the service
function that does the saving, or override `save()`. "What happens when a User is created?"
should be answerable by reading one function, not by grepping for receivers.

---

## Repository over the Django ORM?

Almost never worth it, for the same reason as Eloquent: the ORM is Active Record, and the
`Manager`/`QuerySet` API already provides named, composable, testable queries.

The idiomatic Django architecture for non-trivial apps:

```
models.py      → data + invariants + custom Managers (queries)
services.py    → use cases; the transaction boundary; orchestration
selectors.py   → read-side queries that cross models
views.py       → HTTP only: parse, call a service, render
```

This is Transaction Script plus a Service Layer, and it is the right shape for the overwhelming
majority of Django applications. It gives you testable use cases without a persistence
abstraction.

**Repository becomes justified** only when the domain layer must not import Django at all —
which is a real requirement in some regulated or long-lived systems, and ceremony everywhere
else.

---

## Python language features that replace patterns

| Feature | Replaces |
|---|---|
| **First-class functions** | Strategy, Command, Observer callbacks — for single-method cases |
| **Decorators** | GoF Decorator, without a wrapper class |
| **Context managers** (`with`, `contextmanager`) | Unit of Work, resource acquisition, temporary state |
| **`functools.singledispatch`** | Visitor, for type-based dispatch |
| **`dataclass(frozen=True)`** | Value Object, with equality and immutability free |
| **`Enum` / `StrEnum`** | Replace Type Code with Class; simple State |
| **`Protocol`** (structural typing) | Extract Interface, without inheritance |
| **`match` statements** | Visitor and State dispatch over sum types |
| **Generators / `yield`** | Iterator; lazy pipelines |
| **`functools.partial`** | Pre-bound factories and configured strategies |
| **`__getattr__` / `__call__`** | Proxy and Command, at the language level |
| **`typing.NewType`** | Branded types for identifiers |

**The Python-specific warning:** the language makes patterns so easy to express that the
temptation is to build class hierarchies where a module of functions would do. Python is not
Java. A module *is* a namespace, a function *is* a strategy, and `if` is often the right
answer.

---

## FastAPI specifics

| Pattern | Where it lives |
|---|---|
| **Dependency Injection** | `Depends()` — declarative, scoped, overridable in tests |
| **Chain of Responsibility** | Middleware; nested `Depends` |
| **DTO / Parse-don't-validate** | Pydantic models at the boundary. This is the pattern done properly |
| **Adapter** | Pydantic `model_validate` mapping external shapes to internal ones |
| **Data Mapper** | SQLAlchemy — a real Data Mapper, with Unit of Work and Identity Map in the `Session` |
| **Repository** | Justified more often here than in Django, because SQLAlchemy is a Data Mapper and the domain can genuinely stay clean |
| **Command** | Background tasks; Celery / ARQ / Dramatiq |

**`Depends()` overrides are the best testing seam in the Python web ecosystem.** Use them
instead of patching.

**SQLAlchemy's `Session` gives you Unit of Work and Identity Map properly** — the two things
Django and Eloquent lack. If those matter to your domain, that is a real argument for the
SQLAlchemy stack over Django.

---

## Going against the grain

- A `repositories/` package wrapping single ORM calls.
- Abstract base classes with one concrete subclass, where a `Protocol` or a function would do.
- Getters and setters on Python classes — use plain attributes and `@property` when logic is needed.
- Signal chains implementing core business flow.
- A hand-written DI container in a Django project. Pass dependencies as arguments.
- `class Config: pass` singletons instead of a module-level value — a module is already a singleton.
