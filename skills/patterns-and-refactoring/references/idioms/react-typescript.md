# React · Next.js · TypeScript

[← back to router](../framework-idioms.md)

See also [../frontend-patterns.md](../frontend-patterns.md) for framework-neutral frontend
patterns (state placement, data fetching, rendering strategies).

---

## What React already gives you

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Observer** | `useState`, `useSyncExternalStore`, context subscriptions | |
| **Strategy** | A function passed as a prop; a custom hook | A hook is a strategy with state |
| **Template Method** | Render props; children as a function | |
| **Composite** | The component tree; `children` | |
| **Decorator** | Wrapper components; hooks composing hooks | HOCs are the legacy version — recognise, do not write |
| **Registry / Provider** | Context (`createContext` + `useContext`) | Split contexts by change frequency |
| **Command** | Reducer actions (`useReducer`, Redux) | An action object *is* a Command |
| **Facade** | A custom hook exposing a narrow API over complex logic | The primary unit of reuse |
| **State** | `useReducer` with a discriminated union; XState | Not four independent booleans |
| **Memento** | Undo stacks over immutable state; `useHistoryState` implementations | |
| **Flyweight** | `memo`, `useMemo` — **only after measuring** | |
| **Lazy Load / Proxy** | `lazy()` + `Suspense`; route-level splitting | |
| **Iterator** | `.map()` with a stable `key` | |
| **Adapter** | An API layer mapping server DTOs to view models | |
| **Null Object** | `??`, optional chaining, default props | |

### Hooks are the pattern layer

`useUser()`, `usePagination()`, `useDebouncedSearch()` — each is a Strategy, Facade or Template
Method expressed as a function. **One concern per hook.**

**The Rules of Hooks are not style advice.** Hooks are matched positionally per render, so a
conditional or looped hook call silently corrupts state. The lint rule exists because the
failure is invisible.

---

## The two things that matter most in React

### 1. Server cache is not client state

The single highest-value architectural decision in a React app.

Putting fetched data in Redux/Zustand means hand-rolling caching, invalidation, deduplication,
retries, background refetch and staleness. TanStack Query, SWR, or the framework's own loaders
already do all of it.

Once server data moves out, the global store shrinks to what is genuinely global client state:
theme, auth session, feature flags, open modals. For most apps that is small enough to be
context plus `useState`, and the store disappears entirely.

### 2. Derived state should be computed, not stored

```
// wrong — two sources of truth that will diverge
const [items, setItems] = useState([])
const [total, setTotal] = useState(0)

// right — one source of truth
const [items, setItems] = useState([])
const total = items.reduce((sum, i) => sum + i.price, 0)
```

Duplicated derived state is the most common source of "the UI shows the wrong number" bugs. Do
not reach for `useEffect` to keep two pieces of state in sync — that is the symptom, not the
cure.

---

## `useEffect` is not an event handler

The most-misused API in React, and most misuse looks like a pattern problem.

| You are doing this | Do this instead |
|---|---|
| `useEffect` to sync one state from another | Compute it during render |
| `useEffect` to respond to a user action | Do it in the event handler |
| `useEffect` to reset state when a prop changes | A `key` prop on the component |
| `useEffect` to transform props for rendering | Transform during render |
| `useEffect` to fetch data | A query library, or the framework's loader |

**Effects are for synchronising with systems outside React** — subscriptions, DOM measurement,
third-party widgets, timers. That is the whole legitimate list.

---

## State management, in order of preference

1. **Derived** → compute during render.
2. **Local** → `useState` / `useReducer`.
3. **Lifted** → the nearest common ancestor.
4. **Server data** → TanStack Query / SWR / route loaders.
5. **Context** → for slowly-changing global values. Split by change frequency; a context that changes often re-renders its entire subtree.
6. **A store** (Zustand, Jotai, Redux Toolkit) → only for genuinely global, frequently-changing client state.

**Redux Toolkit is the right choice when** you need an auditable change history, complex shared
client state, or time-travel debugging. **Zustand or Jotai when** you just need a shared value
without the ceremony. **Neither, when** the answer was actually a query library.

---

## Next.js specifics

| Pattern | Where it lives |
|---|---|
| **Server Components** | Components that run only on the server — no bundle cost, direct data access. The default in the App Router |
| **BFF** | Route handlers (`app/api/`) and Server Actions |
| **Command** | Server Actions — a form submission is a Command executed on the server |
| **Front Controller** | File-based routing |
| **Chain of Responsibility** | `middleware.ts` |
| **Two Step View** | Nested layouts |
| **Cache-Aside** | `fetch` caching, `unstable_cache`, `revalidateTag` |
| **Materialized View** | Static generation with on-demand revalidation |
| **Streaming SSR** | `Suspense` boundaries with progressive HTML |
| **Islands-like** | `"use client"` boundaries — client JS only where declared |

**The mental model that matters:** a Server Component is the default and cannot use hooks or
browser APIs. Push `"use client"` **down** the tree, as close to the interactive leaf as
possible. Marking a layout as a client component drags the entire subtree into the bundle.

**Server Actions are Commands with a network boundary** — validate their input as untrusted,
exactly like an API route, because that is what they are. Their ergonomics make it easy to
forget.

---

## TypeScript features that replace patterns

| Feature | Replaces |
|---|---|
| **Discriminated unions + exhaustive `switch`** | Visitor, State; makes illegal UI states unrepresentable |
| **Structural typing** | Extract Interface — no `implements` needed |
| **Zod + `z.infer`** | Parse-don't-validate at boundaries, with types derived from the schema |
| **`satisfies` / `as const`** | Type-checked configuration and route maps |
| **Branded types** | Value Objects for IDs |
| **Utility types** | Hand-written prop-type variants |
| **`neverthrow` / result unions** | Result/Either for expected failures |

---

## Going against the grain

- Class components in new code.
- HOCs where a hook would do.
- Redux for server data.
- `useEffect` used as an event handler or to sync derived state.
- `useMemo` / `memo` applied everywhere without profiling — the comparison cost is real.
- A "services" layer of classes duplicating what hooks do better.
- Prop drilling six levels where context or composition would be traceable.
- `"use client"` at the root of a Next.js App Router tree.
- Context holding frequently-changing values, causing whole-subtree re-renders.
