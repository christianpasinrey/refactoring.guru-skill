# Spring · Java · Kotlin

[← back to router](../framework-idioms.md)

---

## What Spring already gives you

Spring is the framework most explicitly built out of GoF patterns. Nearly every entry below is
already named as a pattern in its own documentation.

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Abstract Factory + DI** | `ApplicationContext` / `BeanFactory` | Constructor injection. Never `new` a collaborator, never field injection |
| **Factory Method** | `@Bean` methods; `FactoryBean` | A `@Bean` method *is* a factory method |
| **Singleton** | Default bean scope | Container-managed, injected, testable. Never a static `getInstance()` |
| **Prototype** | `@Scope("prototype")` | |
| **Strategy** | Interface with multiple `@Component`s + `@Qualifier`, or inject `List<T>`/`Map<String,T>` | Injecting `Map<String, Handler>` gives keyed strategy resolution for free |
| **Chain of Responsibility** | `HandlerInterceptor`; servlet `Filter`; Spring Security filter chain | The documented chain, not a custom dispatcher |
| **Observer** | `ApplicationEvent` + `@EventListener`; `@TransactionalEventListener` | `@TransactionalEventListener(phase = AFTER_COMMIT)` is the correct hook for side effects |
| **Command** | `@Async` methods; Spring Batch steps; Spring Modulith events | |
| **Template Method** | `JdbcTemplate`, `RestTemplate`, `TransactionTemplate`, `JmsTemplate` | The `*Template` naming is literal — it *is* the pattern |
| **Data Mapper** | JPA / Hibernate | Spring's default is Data Mapper, unlike Rails or Laravel |
| **Unit of Work + Identity Map** | Hibernate's `Session` / JPA `EntityManager` — both, properly | The persistence context tracks changes and dedupes identities |
| **Repository** | `@Repository`, `JpaRepository`, derived query methods | **Idiomatic here.** Do not fight it — the Laravel argument does not transfer |
| **Specification** | `JpaSpecificationExecutor` + `Specification<T>` | First-class, composable, translates to Criteria API |
| **Query Object** | `@Query`; Criteria API; QueryDSL | |
| **Decorator** | `@Aspect` / AOP; `BeanPostProcessor` | AOP is Decorator applied declaratively via proxies |
| **Proxy** | JDK dynamic proxies and CGLIB, under `@Transactional`, `@Cacheable`, `@Async` | Know this: self-invocation bypasses the proxy, so `this.method()` skips `@Transactional` |
| **Adapter** | `HandlerAdapter`; `HttpMessageConverter` | |
| **Facade** | `@Service` classes with a narrow API | |
| **Builder** | `WebClient.builder()`, `Stream.collect`, Lombok `@Builder` | |
| **Iterator** | `Iterable`, `Stream`, `Flux` | |
| **Value Object** | `record` (Java 16+); `@Embeddable`; Kotlin `data class` | A `record` is an immutable value object in one line |
| **Null Object** | `Optional<T>`; `@Nullable` with static analysis | Return `Optional`, never `null`, from query methods |
| **Retry / Circuit Breaker / Bulkhead** | Spring Retry; Resilience4j (`@Retry`, `@CircuitBreaker`, `@Bulkhead`, `@RateLimiter`) | Declarative annotations. Never hand-roll |
| **Front Controller** | `DispatcherServlet` — the canonical implementation | |
| **Transactional Outbox** | Spring Modulith `@ApplicationModuleListener` with an event publication registry | One of the few frameworks with this built in |
| **Modular Monolith** | Spring Modulith — module boundaries verified by tests | Use it before reaching for microservices |

---

## The decisions that actually matter in Spring

### Constructor injection, always

Field injection (`@Autowired` on a field) makes dependencies invisible, prevents `final`, and
makes the class impossible to construct in a plain unit test. Constructor injection makes the
dependency list a visible signal — a constructor with nine arguments is telling you the class
has too many responsibilities, which is exactly the feedback you want.

### The `@Transactional` proxy trap

`@Transactional`, `@Async` and `@Cacheable` work through proxies. Calling an annotated method
from *within the same class* bypasses the proxy entirely and the annotation does nothing
silently. This is the single most common Spring bug.

Fix by moving the annotated method to a different bean, or by self-injecting the proxy.

### Anemic domain model

Spring's culture pushes hard toward `@Entity` classes of getters and setters plus `@Service`
classes holding all the logic — the textbook Anemic Domain Model.

For simple rules that is fine: it is Transaction Script and it works. For complex rules it is
the expensive option, because invariants cannot be enforced by the objects that own the data.
JPA does not prevent behaviour on entities; convention does. See
[../enterprise-patterns.md](../enterprise-patterns.md#domain-logic).

### Layer count

The classic Controller → Service → Repository → Entity is four layers before any business
logic. When a service method only forwards to a repository, that is Middle Man — delete the
layer for that use case rather than keeping it for symmetry.

---

## Java language features that replace patterns

| Feature | Replaces |
|---|---|
| **`record`** | Value Object, DTO, and most Builder use for immutable data |
| **Sealed interfaces + pattern matching `switch`** | Visitor, State, and exhaustive polymorphic dispatch |
| **Lambdas + functional interfaces** | Strategy, Command, Template Method — for single-method cases |
| **`Optional<T>`** | Null Object, when absence should be visible in the signature |
| **`Stream`** | Iterator, Pipes and Filters, Replace Loop with Pipeline |
| **`enum` with methods and abstract methods** | Replace Type Code with Subclasses; simple State machines |
| **Text blocks** | Readable embedded SQL and JSON |
| **Virtual threads** (21+) | Much of the reactive-programming complexity, for IO-bound work |
| **`var`** | Noise reduction; not a design tool |

**Sealed interfaces plus pattern matching are the biggest change to Java pattern usage in
twenty years.** They make Visitor essentially obsolete for closed hierarchies: the compiler
checks exhaustiveness, and adding a case is a compile error rather than a runtime surprise.

---

## Kotlin specifics

| Feature | Replaces |
|---|---|
| **`data class`** | Value Object with `equals`, `hashCode`, `copy` free |
| **`sealed class` / `sealed interface`** | Visitor, State, Result types with exhaustive `when` |
| **`object`** | Singleton, as a language keyword — still a global, so prefer DI |
| **Extension functions** | Introduce Foreign Method; Decorator without a wrapper |
| **Delegation `by`** | Decorator and Proxy, declaratively |
| **`Result<T>`** | Railway-oriented error handling |
| **Coroutines + `Flow`** | Reactive streams, Producer-Consumer, backpressure |
| **Default and named parameters** | Telescoping constructors; most Builders |
| **Null safety in the type system** | Null Object, largely |

Kotlin's `by` delegation deserves emphasis: `class Logging(private val inner: Client) : Client by inner`
gives you a Decorator that forwards everything, and you override only what you are decorating.

---

## Going against the grain

- Field injection instead of constructor injection.
- An interface per service with exactly one implementation, "for mockability". Modern mocking libraries do not need it and Spring proxies classes fine.
- A service layer that only forwards to repositories.
- Hand-written retry loops where Resilience4j annotations exist.
- Calling `@Transactional` methods from within the same class.
- Custom DTO mapping code where MapStruct or a `record` constructor would do.
- Reactive (`WebFlux`) adopted for a CRUD application. Virtual threads solve the same throughput problem with vastly less complexity.
