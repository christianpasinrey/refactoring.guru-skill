# NestJS · Express · Node / TypeScript

[← back to router](../framework-idioms.md)

---

## What NestJS already gives you

NestJS is Angular's architecture applied to the server: a DI container, decorators, and modules.
Almost every classic pattern has a first-class home.

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Abstract Factory + DI** | The Nest DI container; `@Injectable()`, provider tokens | Constructor injection. Custom providers with `useFactory` for dynamic resolution |
| **Singleton** | Default provider scope | Container-managed. Never a module-level mutable global |
| **Strategy** | Provider tokens; `useClass` chosen at module registration; injecting an array of providers | A provider token *is* a strategy key |
| **Chain of Responsibility** | Middleware → Guards → Interceptors → Pipes → Filters, in that order | Learn the order. Reimplementing it is the most common Nest mistake |
| **Decorator** | Interceptors; TypeScript decorators; custom param decorators | Interceptors wrap the handler on both sides — before and after |
| **Command** | CQRS module (`@nestjs/cqrs`) `ICommand`/`ICommandHandler`; BullMQ jobs | |
| **Observer** | `EventEmitter2` module; CQRS `IEvent` | |
| **Mediator** | `CommandBus`, `QueryBus`, `EventBus` in `@nestjs/cqrs` | |
| **Facade** | A service with a narrow API over several collaborators | |
| **Adapter** | Platform adapters (Express/Fastify); custom transport strategies | |
| **Template Method** | `PassportStrategy`; lifecycle hooks (`OnModuleInit`, `OnApplicationShutdown`) | |
| **Proxy** | Scoped providers; lazy modules | |
| **DTO / Parse-don't-validate** | `class-validator` + `ValidationPipe`, or Zod pipes | Validate at the boundary once. This is the pattern done properly |
| **Data Mapper** | TypeORM, MikroORM, Prisma | |
| **Unit of Work** | TypeORM `QueryRunner` / `EntityManager.transaction`; Prisma `$transaction` | |
| **Repository** | TypeORM `Repository<T>`, custom repositories | Already provided; a wrapper on top is a wrapper on a wrapper |
| **Retry / Circuit Breaker** | Not built in | `cockatiel` or `opossum`. Do not hand-roll |
| **Front Controller** | The Nest router | |

**The Nest request lifecycle order matters** and is worth memorising, because most "my
interceptor doesn't see the validated body" bugs come from misremembering it:

```
Middleware → Guards → Interceptors (pre) → Pipes → Handler → Interceptors (post) → Exception filters
```

---

## Express and the unopinionated end

Express gives you almost nothing, which means every pattern is a decision you must make.

| Pattern | The idiomatic answer |
|---|---|
| **Chain of Responsibility** | `app.use()` middleware — the one pattern Express does provide, and it is the core abstraction |
| **DI** | Explicit constructor arguments, or a factory function per module. A container (`tsyringe`, `awilix`) only once wiring genuinely hurts |
| **Front Controller** | The Express app itself |
| **Strategy** | A function passed in. TypeScript's structural typing means no interface declaration is needed |
| **Command** | BullMQ / Agenda jobs |
| **Repository** | Justified more often here, simply because there is no framework default to conflict with |

**Do not import a NestJS-shaped architecture into Express.** Decorators, modules and a DI
container bolted onto Express gives you Nest's ceremony without Nest's tooling. Either use Nest
or embrace explicit wiring — the middle is the worst of both.

---

## Prisma changes the pattern calculus

Prisma is not an ORM in the Active Record or Data Mapper sense — it is a generated, type-safe
query builder returning plain objects.

- **No Identity Map, no Unit of Work change tracking.** `$transaction` is the transaction boundary and there is no dirty tracking.
- **Returned objects are plain data.** There is no entity to hang behaviour on, so Domain Model requires mapping to your own classes.
- **A Repository layer is more defensible with Prisma than with TypeORM**, because there is no repository already provided and the generated client's types leak the schema shape everywhere.

The practical shape: Prisma client → a thin data-access module per aggregate → services holding
the use cases. Map to domain types only if the rules are complex enough to need them.

---

## TypeScript language features that replace patterns

| Feature | Replaces |
|---|---|
| **Discriminated unions + exhaustive `switch`** | Visitor, State, and most polymorphic dispatch. The highest-value feature in the language |
| **Structural typing** | Extract Interface — a type is satisfied by shape, no `implements` needed |
| **Branded / nominal types** | Value Object for identifiers (`type UserId = string & { __brand: 'UserId' }`) |
| **`satisfies` + `as const`** | Type-checked configuration objects |
| **Mapped and conditional types** | Hand-written DTO variants |
| **Utility types** (`Pick`, `Omit`, `Partial`, `Readonly`) | Boilerplate type declarations |
| **Zod / Valibot / ArkType** | Parse-don't-validate at the boundary, with types derived from the schema |
| **`neverthrow` / union result types** | Result/Either for expected failures |
| **Closures** | Strategy, Command, and most single-method classes |
| **`readonly` + `as const`** | Immutability |

**Zod deserves special emphasis.** `z.infer<typeof schema>` derives the static type from the
runtime validator, so validation and typing cannot drift apart. This is the single most
valuable idiom in the TypeScript ecosystem and it eliminates a whole class of DTO-mismatch
bugs.

---

## Node-specific concurrency notes

- **The event loop is the Reactor pattern.** Never block it — one synchronous CPU-heavy call stalls every request.
- **Worker threads / child processes** for CPU-bound work; a job queue for anything long-running.
- **`AsyncLocalStorage`** is the correct way to propagate request context (correlation IDs, tenant, user) without threading it through every signature. It is the Node answer to thread-local storage.
- **Streams** are Pipes and Filters, built into the runtime. Use them for large files instead of buffering.
- **Unhandled promise rejections** terminate the process by default in modern Node. Handle or explicitly ignore them.

See [../concurrency-patterns.md](../concurrency-patterns.md).

---

## Going against the grain

- A DI container in a small Express app where three factory functions would do.
- An interface per service with one implementation — TypeScript is structurally typed.
- A generic repository over TypeORM's `Repository<T>`.
- Classes with a single method and no state — that is a function.
- Hand-rolled event emitters when `EventEmitter2` or the CQRS module exists.
- `any` used to escape a type problem that indicates a design problem.
- Reimplementing the Nest request lifecycle inside a controller.
