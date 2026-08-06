# Frontend patterns

Component-based UIs have their own catalogue. Most of it is GoF wearing different clothes —
Compound Components is Composite, a Provider is a Registry with scoping, reactivity is Observer
— but the constraints (rendering cost, async data, browser state) make the trade-offs different
enough to be worth stating separately.

Framework-neutral where possible; React/Vue names given because that is what the ecosystem uses.

---

## Component composition

### Presentational / Container

- **Intent** — Separate components that *fetch and decide* from components that *render*.
- **Why** — Presentational components become trivially testable and reusable; the data-fetching decision lives in one place.
- **Modern status** — Hooks and composables softened the strict split. The *principle* — a component that does data work should not also do complex layout — still holds.

### Compound Components

- **Intent** — A set of components sharing implicit state through context: `<Tabs><Tab/><TabPanel/></Tabs>`.
- **Use when** — The parts only make sense together and the consumer needs control over arrangement.
- **Payoff** — A flexible API without a props explosion on the parent.
- **Related** — Composite in [gof-catalog.md](gof-catalog.md#composite).

### Slots / Render Props / Children as Function

- **Intent** — The parent owns behaviour and state; the consumer supplies the markup.
- **Vue** — Scoped slots. **React** — render props, or children as a function.
- **Use when** — Behaviour is reusable but presentation is not: a data table with sorting, an infinite scroller, a drag handler.

### Hooks / Composables

- **Intent** — Extract stateful logic into a reusable function, independent of any component.
- **Why it replaced HOCs and mixins** — No wrapper hell, no implicit name collisions, explicit dependencies, and composition instead of inheritance.
- **Rule** — One concern per hook. `useUser()`, `usePagination()`, `useDebouncedSearch()` — not `useEverything()`.
- **Related** — This is Strategy and Template Method as functions. See [functional-patterns.md](functional-patterns.md).

### Higher-Order Components

- **Status** — Largely superseded by hooks/composables. Recognise it in older code; do not write new ones.
- **Problem** — Wrapper hell, prop collisions, lost types, and an unreadable component tree.

### Provider / Injection

- **Intent** — Supply a value to a subtree without prop drilling. React Context, Vue `provide`/`inject`.
- **Careful** — A context whose value changes often re-renders the entire subtree. Split contexts by change frequency: rarely-changing config separate from frequently-changing state.
- **Related** — Registry in [enterprise-patterns.md](enterprise-patterns.md), scoped to a tree.

---

## State management

### Where state should live

Ask in this order, and stop at the first yes:

1. **Can it be derived?** Then compute it — do not store it. Duplicated derived state is the most common source of frontend inconsistency bugs.
2. **Does one component use it?** Local state.
3. **Do a few nearby components use it?** Lift it to the nearest common ancestor.
4. **Is it server data?** A server-state library (React Query, TanStack Query, SWR, Pinia Colada), *not* the global store. See below.
5. **Is it genuinely global client state?** Then a store — and it is a smaller set than most apps assume: theme, auth session, feature flags, open modals.

**Server cache is not client state.** Putting fetched data in Redux/Pinia means hand-rolling
caching, invalidation, deduplication, retries, and staleness. Dedicated server-state libraries do
that already. This one distinction removes most of a typical global store.

### Store patterns

| Pattern | Shape | Fits |
|---|---|---|
| **Flux / Redux** | Unidirectional: action → reducer → new state → view | Complex shared state where an auditable change history matters |
| **Proxy-based store** | Mutate a reactive object directly (Pinia, Vue reactivity, Zustand, MobX) | Most apps. Far less boilerplate |
| **Atomic state** | Many small independent atoms (Jotai, Recoil, Vue `ref`) | Fine-grained updates, minimal re-render surface |
| **State machine** | Explicit states and legal transitions (XState) | Multi-step flows, wizards, media players, anything with illegal-state bugs |
| **Signals** | Fine-grained reactive primitives with automatic dependency tracking | Solid, Svelte 5, Vue reactivity, Angular signals |

**State machines are under-used.** Any component with `isLoading`, `isError`, `isSuccess`,
`isEditing` booleans has 16 representable combinations, most of them illegal. A machine with
four named states makes them unrepresentable — the [functional-patterns.md](functional-patterns.md)
idea applied to UI.

### Immutable updates

Reducers and reactive systems depend on detecting change. Mutating nested state in place is the
classic "why does the UI not update" bug. Use structural sharing helpers (Immer, `structuredClone`,
spread) — or a proxy-based store where mutation *is* the tracked operation. Know which model
you are in; mixing them is where the confusion comes from.

---

## Data fetching and rendering

| Pattern | Intent | Trade-off |
|---|---|---|
| **CSR** | Browser fetches and renders | Slow first paint, weak SEO, cheap hosting |
| **SSR** | Server renders per request | Fast first paint, good SEO, server cost |
| **SSG** | Rendered at build time | Fastest and cheapest; stale until rebuilt |
| **ISR / on-demand revalidation** | Static, regenerated in the background | SSG speed with bounded staleness |
| **Islands** | Static HTML with independently hydrated interactive regions | Minimal JS shipped (Astro) |
| **Streaming SSR** | Send HTML progressively as it becomes ready | Better perceived performance, more complexity |
| **Resumability** | Skip hydration; resume server state on the client | Newest approach (Qwik), smallest JS cost |

**Fetching strategies:** *fetch-on-render* (simplest, causes waterfalls), *fetch-then-render*
(one round trip, blocks on the slowest), *render-as-you-fetch* (start fetching before rendering
— what loaders and suspense-aware libraries do).

**Waterfalls are the main frontend performance bug.** A child that fetches only after its parent
rendered serialises what should have been parallel. Hoist the fetch or declare the requirement
at the route level.

### Optimistic UI

- **Intent** — Apply the expected result immediately, reconcile when the server responds, roll back on failure.
- **Use when** — Success is overwhelmingly likely and the latency is felt: likes, toggles, reordering, sending a message.
- **Requirement** — A genuine rollback path and a visible failure state. Optimistic updates without rollback are a lie that costs the user their data.

---

## Performance

| Pattern | Problem it solves |
|---|---|
| **Virtualisation / windowing** | Rendering 10,000 rows when 20 are visible |
| **Memoization** (`memo`, `computed`) | Re-rendering unchanged subtrees. *Measure first — memoization is not free* |
| **Code splitting / lazy loading** | Shipping the whole app to render one route |
| **Debounce / Throttle** | Handlers firing on every keystroke or scroll frame |
| **Single-Flight** | Duplicate in-flight requests for the same data |
| **Skeletons over spinners** | Perceived latency and layout shift |
| **Prefetch on intent** | Hover or viewport-entry triggers the fetch before the click |

**Do not memoize by default.** Comparison cost plus memory is real, and premature memoization
obscures the actual bottleneck, which is usually a waterfall, an oversized bundle, or a list
rendering everything.

---

## Structure at scale

| Pattern | Intent |
|---|---|
| **Feature-Sliced / Modular by feature** | Group by feature, not by file type. `features/checkout/` beats `components/`, `hooks/`, `utils/` at scale |
| **Atomic Design** | Atoms → molecules → organisms → templates → pages. Useful vocabulary for a design system; a rigid taxonomy to fight if enforced literally |
| **Design tokens** | Colour, spacing and type as named values consumed by both design and code |
| **Headless components** | Behaviour and accessibility with zero styling (Radix, Headless UI, Reka UI) — separates the hard part from the easy part |
| **BFF** | A backend shaped for this specific client — see [distributed-patterns.md](distributed-patterns.md) |
| **Micro-frontends** | Independently deployed frontend slices. High cost: duplicate runtimes, version skew, styling conflicts. Needs an organisational reason, exactly like microservices |
| **Module Federation** | Runtime sharing of modules between separately built apps |

**Group by feature, not by type.** A change to checkout should touch one directory. Grouping by
file type guarantees Shotgun Surgery — see [code-smells.md](code-smells.md#shotgun-surgery).

---

## Forms

Consistently the most under-designed part of frontend code.

- **Controlled vs uncontrolled** — Controlled gives full control at the cost of a render per keystroke; uncontrolled is faster and simpler for large static forms. Choose deliberately.
- **Validation in three places** — Client (immediate feedback), server (the only one that is real), and the database (constraints as the last line). Never trust the first, never omit the second.
- **Schema-driven** — Define the shape once (Zod, Yup, Valibot) and derive types, validation and error messages from it. This is *parse, don't validate* in [functional-patterns.md](functional-patterns.md) applied to forms.
- **Submission state is a state machine** — idle → validating → submitting → success/error. Boolean flags for this produce the illegal-combination bugs described above.

---

## Server-driven UI

Worth naming because Livewire, Hotwire, HTMX, LiveView and React Server Components all belong
to it: the server holds the state and sends markup or diffs; the client is thin.

- **Wins** — One language, one source of truth, no API to design, no client-side state duplication.
- **Costs** — A round trip per interaction (latency shows), a stateful server connection, and a hard ceiling on offline or highly interactive experiences.
- **Fits** — CRUD-heavy admin panels, dashboards, forms-over-data. **Does not fit** — offline-capable apps, drawing tools, anything needing sub-100ms local interaction.

---

## Sources

React, Vue, Svelte and Astro documentation · Kent C. Dodds on state colocation and compound
components · Dan Abramov on presentational/container (including his later revision) ·
Feature-Sliced Design methodology · Brad Frost, *Atomic Design*. Original commentary.
