# Rails · Ruby

[← back to router](../framework-idioms.md)

---

## What Rails already gives you

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Active Record** | `ActiveRecord::Base` — the pattern is named after this | It is the whole philosophy of the framework. Fighting it is fighting Rails |
| **Query Object** | Scopes; `ActiveRecord::Relation` | A scope *is* a composable query object. Chainable, lazy, mergeable |
| **Unit of Work** | `ActiveRecord::Base.transaction` | Nested blocks need `requires_new: true` for real savepoints |
| **Identity Map** | **Removed in Rails 5** | Two queries for the same row give two objects |
| **Observer** | `ActiveSupport::Notifications`; model callbacks | Callbacks for persistence concerns only — see below |
| **Chain of Responsibility** | Rack middleware; `before_action` / `around_action` chains | The documented filter chain, not a custom dispatcher |
| **Template Method** | `ApplicationController`, `ApplicationRecord`, `ActiveJob::Base` | Override hooks; do not reimplement the lifecycle |
| **Strategy** | Duck typing; a block; a lambda; a class responding to `#call` | Ruby needs no interface. `#call` is the community's de facto Strategy contract |
| **Command** | ActiveJob; service objects responding to `#call` | An ActiveJob *is* a Command: serialisable, retryable, schedulable |
| **Decorator** | `Module#prepend`; `SimpleDelegator`; Draper | `prepend` gives real method wrapping with `super` |
| **Proxy** | Lazy `Relation` evaluation; `has_many` association proxies | Already there — N+1 is the risk, `includes` is the cure |
| **Adapter** | ActiveStorage services, ActionMailer delivery methods, cache stores | Write an adapter to the documented interface |
| **Builder** | Relation chaining; `FormBuilder`; FactoryBot | |
| **Iterator** | `Enumerable`; `find_each`; `in_batches`; `Enumerator::Lazy` | `find_each` batches; never `.all.to_a` on a large table |
| **Value Object** | `composed_of`; `Data.define` (Ruby 3.2+); `Struct` | `Data.define` gives an immutable value object in one line |
| **Null Object** | `&.`; a null object class responding to the same interface | Ruby's duck typing makes Null Object almost free |
| **Front Controller** | `config/routes.rb` + the router | |
| **Template View / Two Step View** | ERB/HAML + layouts | Layouts *are* Two Step View |
| **Presenter** | Helpers; Draper decorators; ViewComponent | ViewComponent is the modern answer for reusable, testable view logic |
| **Memento** | `paper_trail`; `audited` | |
| **Retry / Circuit Breaker** | ActiveJob `retry_on` / `discard_on` | `retry_on` handles job retries; use a gem for circuit breaking |

### Callbacks: the Rails equivalent of the signals problem

`before_save`, `after_create` and friends are Observer, and they are the most common source of
untraceable Rails behaviour. A model with eight callbacks has an invisible control flow that
fires in tests, in seeds, in console sessions, and in bulk imports where you did not want it.

**Use callbacks for:** persistence-adjacent concerns that must *always* happen — normalising a
column, maintaining a counter cache, touching a timestamp.

**Do not use callbacks for:** sending email, calling an API, or anything a business use case
decided to do. That belongs in the service object that made the decision. Callbacks that reach
outside the database are the reason `Model.save` becomes something people fear.

---

## Fat model, skinny controller — and what came after

The original Rails advice produced 2,000-line models. The community's answer is a middle layer,
and the naming is unsettled but the shape is consistent:

```
app/models/       → persistence, associations, scopes, validations, invariants
app/services/     → one class per use case, responding to #call
app/queries/      → read-side queries that cross models
app/forms/        → form objects for multi-model input
app/components/   → ViewComponents for reusable view logic
app/jobs/         → async commands
```

**A service object is Transaction Script.** That is not a criticism — for most use cases it is
the correct pattern, and Rails' culture of naming it something else has caused a lot of
needless debate.

**The trap:** one service class per controller action regardless of complexity, each three
lines long, each calling one model method. That is not a Service Layer, it is an extra file.
Add the layer when the use case has orchestration, a transaction boundary, or logic that spans
models.

**Repository over ActiveRecord:** essentially never. ActiveRecord *is* the pattern, scopes are
the query objects, and the Rails ecosystem has no tooling that expects a repository. If the
domain genuinely must not know about the database, you are building something Rails was not
designed for.

---

## Ruby language features that replace patterns

| Feature | Replaces |
|---|---|
| **Blocks and procs** | Strategy, Command, Template Method — all first-class |
| **Duck typing** | Extract Interface. No interface declaration needed |
| **Modules / mixins** | Multiple inheritance of behaviour; Decorator via `prepend` |
| **`Module#prepend`** | Decorator with working `super` — better than wrapper classes |
| **`SimpleDelegator`** | Decorator and Proxy, in one line |
| **`method_missing` + `respond_to_missing?`** | Proxy, dynamic Adapter. Powerful and easy to abuse |
| **`Data.define`** (3.2+) | Immutable Value Object |
| **`Struct`** | Lightweight value types |
| **`Comparable` / `Enumerable`** | Iterator and ordering, by defining one method |
| **Refinements** | Scoped monkey-patching instead of global Introduce Foreign Method |
| **`case/in` pattern matching** (3.0+) | Visitor and State dispatch |
| **`freeze`** | Immutability |

**The Ruby-specific warning:** metaprogramming makes almost every pattern expressible in a few
lines, which means the cost signal that stops over-engineering in other languages is absent
here. `method_missing` can implement a Proxy in three lines — and make the class undebuggable.
Prefer explicit delegation you can read.

---

## Going against the grain

- A `repositories/` directory wrapping ActiveRecord.
- Interfaces or abstract base classes declared for their own sake — Ruby has duck typing.
- Getters and setters written by hand instead of `attr_reader` / `attr_accessor`.
- A hand-rolled DI container. Pass collaborators as constructor arguments with sensible defaults.
- Callbacks that make HTTP calls or send mail.
- A service object per action, each one a single delegation.
- `class << self` singletons where a module of functions would read better.
