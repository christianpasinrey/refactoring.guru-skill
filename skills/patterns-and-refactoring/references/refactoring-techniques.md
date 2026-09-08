> **Precondition:** tests are green before you start and after every step. If that is not true,
> go to [refactoring-workflow.md](refactoring-workflow.md) first.

# The 66 refactoring techniques

Catalogue from <https://refactoring.guru/refactoring/techniques>, six groups. Each entry is
*what it does* and *when to reach for it*. Many are trivially automated by your IDE — prefer the
automated version, it cannot make a typo.

Notation: **↔** marks pairs that are exact inverses. Refactoring is bidirectional; the right
direction depends on where the code needs to go, and reversing an earlier refactoring is a
normal move, not an admission of error.

---

## 1. Composing Methods

*Most refactoring work lives here. Long, tangled methods are the root of most other smells.*

| Technique | What it does | Reach for it when |
|---|---|---|
| **Extract Method** ↔ | Move a fragment into its own well-named method | Almost always. The workhorse of refactoring. Any fragment needing a comment |
| **Inline Method** ↔ | Replace a call with the method body, delete the method | The body is as clear as the name, or indirection adds nothing |
| **Extract Variable** ↔ | Give a sub-expression an explaining name | Complex conditions or arithmetic that need decoding |
| **Inline Temp** ↔ | Replace a variable with the expression that produced it | A temp used once, adding no clarity, blocking Extract Method |
| **Replace Temp with Query** | Move the expression into a method and call it | Temps prevent Extract Method; the value is derivable |
| **Split Temporary Variable** | One variable per responsibility | A variable reassigned for two different purposes |
| **Remove Assignments to Parameters** | Assign to a new local instead of the parameter | A parameter is mutated — hides intent, breaks in by-reference languages |
| **Replace Method with Method Object** | Turn the method into a class, locals become fields | A method too tangled with locals to extract from. The escape hatch when Extract Method won't apply |
| **Substitute Algorithm** | Swap the body for a clearer or correct one | The algorithm is convoluted, or a library does it properly |

**Order that works:** Extract Variable to name the pieces → Replace Temp with Query to unblock
→ Extract Method to carve out the section → Rename Method once its real job is visible.

**Traps when extracting** — each one passes a loosely-typed test and fails in production:

- **Return-type coercion.** An extracted method declared `: float` silently turns the `int` `0` the caller used to expose into `0.0`. Pin outputs with strict equality, types included, *before* extracting — and **preserve the wart** during the refactor (`int|float`, or no declared type). Normalising the output shape is a behaviour change for its own commit, after callers are checked.
- **Parameter-type tightening.** Declaring `string $country` on the extracted method turns a `null` that used to fall through to the default branch into a `TypeError`. Leave parameters untyped during the extraction if the callers' input is untyped; tighten them in a later commit, once the inputs are pinned or validated.
- **Null vs empty vs falsy.** A fragment that returned `null` in one branch now returns `''` or `[]` because the new signature demanded a type.
- **Exception scope moves.** A `try` that wrapped more or less than the extracted fragment now catches different things. Extract the whole `try`, or none of it.
- **By-reference parameters and mutated locals.** A local the fragment assigned becomes a copy inside the new method; the caller stops seeing the change.
- **Evaluation order and short-circuit.** Extracting a sub-expression of `a() && b()` into a variable evaluates `b()` unconditionally.
- **A temp assigned twice.** The extracted code read the second meaning; the caller passes the first. Split Temporary Variable first.

---

## 2. Moving Features Between Objects

*The cure for Feature Envy, Divergent Change and Shotgun Surgery. Puts behaviour where its data is.*

| Technique | What it does | Reach for it when |
|---|---|---|
| **Move Method** | Relocate a method to the class it actually uses | Feature Envy; a method uses another class more than its own |
| **Move Field** | Relocate a field to the class that uses it most | The field is read and written mostly from elsewhere |
| **Extract Class** ↔ | Split one class into two along a responsibility | Large Class, Divergent Change, Data Clumps |
| **Inline Class** ↔ | Fold a class into another and delete it | Lazy Class; it no longer does enough to exist |
| **Hide Delegate** ↔ | Add a delegating method so clients stop navigating | Message Chains; clients traverse `a->b()->c()` |
| **Remove Middle Man** ↔ | Delete pure delegation, let clients call directly | Middle Man; the wrapper only forwards |
| **Introduce Foreign Method** | Add a helper taking the foreign object as an argument | Incomplete Library Class, one or two missing methods |
| **Introduce Local Extension** | Subclass or wrap the library class | Incomplete Library Class, several missing methods |

Hide Delegate and Remove Middle Man are the two ends of one dial. Neither is correct in the
abstract — judge by how much the client should know about the structure behind the boundary.

---

## 3. Organizing Data

*Turns primitives and raw structures into domain concepts. Cures Primitive Obsession, the
highest-payback smell in typical business code.*

| Technique | What it does | Reach for it when |
|---|---|---|
| **Self Encapsulate Field** | Access your own field through getter/setter | A subclass needs to override access; lazy loading is coming |
| **Replace Data Value with Object** | Turn a primitive into a class | `string $email`, `int $cents` — a primitive with rules |
| **Change Value to Reference** ↔ | Many identical objects become one shared instance | The instances represent the same identity and must share updates |
| **Change Reference to Value** ↔ | Shared object becomes an immutable value | The object is small, immutable, and identity does not matter |
| **Replace Array with Object** | Positional array becomes a typed object | `$row[0]`, `$row[1]` — positions have meanings |
| **Duplicate Observed Data** | Split domain data out of GUI code | Domain data trapped in a UI class |
| **Change Unidirectional Association to Bidirectional** ↔ | Add the back-reference | One side genuinely needs to navigate back |
| **Change Bidirectional Association to Unidirectional** ↔ | Drop the back-reference | Inappropriate Intimacy; one direction is unused |
| **Replace Magic Number with Symbolic Constant** | Name the literal | Any unexplained number or string in logic |
| **Encapsulate Field** | Make a public field private with accessors | Public mutable fields |
| **Encapsulate Collection** | Return a copy/read-only view; add `add`/`remove` | A getter returns a mutable collection callers modify directly |
| **Replace Type Code with Class** | Type code becomes a typed object | A code with no behaviour differences, but needing validation |
| **Replace Type Code with Subclasses** | One subclass per code | Behaviour differs by code and the code never changes after construction |
| **Replace Type Code with State/Strategy** | Delegate to a State or Strategy object | Behaviour differs by code **and** the code changes at runtime |
| **Replace Subclass with Fields** | Collapse subclasses that differ only in constant data | Subclasses whose only difference is a returned constant |

The three "Replace Type Code" variants are the bridge from refactoring to patterns. Choose by
two questions: *does behaviour differ?* and *does the code change at runtime?* No/no → Class.
Yes/no → Subclasses. Yes/yes → State or Strategy.

---

## 4. Simplifying Conditional Expressions

*Conditional logic accretes faster than any other kind and is where most bugs hide.*

| Technique | What it does | Reach for it when |
|---|---|---|
| **Decompose Conditional** | Extract condition, then-branch and else-branch into methods | A complex `if` whose parts each need a name |
| **Consolidate Conditional Expression** | Merge conditions with the same result into one method | Several checks all leading to the same outcome |
| **Consolidate Duplicate Conditional Fragments** | Move code identical in all branches outside the conditional | The same line appears at the start or end of every branch |
| **Remove Control Flag** | Use `break`, `continue` or `return` instead of a flag variable | A boolean drives loop or branch exit |
| **Replace Nested Conditional with Guard Clauses** | Return early on the exceptional cases | Deep nesting; the "happy path" is buried and hard to find |
| **Replace Conditional with Polymorphism** | One subclass or strategy per branch | Switch Statements smell; the same branching repeated in several methods |
| **Introduce Null Object** | A do-nothing object replacing `null` | Repeated `if ($x === null)` checks scattered around |
| **Introduce Assertion** | Make an assumption explicit and checked | Code silently relies on a precondition |

Guard clauses are the highest-value item in this group: they flatten nesting, put error
handling next to the error, and leave the main path unindented at the bottom of the method.

**Note on Null Object** — cures the null checks but can hide genuine errors by silently doing
nothing. Prefer it for "absent is normal" (a guest user, an empty discount); prefer an explicit
`Option`/`Result` type for "absent is exceptional". See
[functional-patterns.md](functional-patterns.md).

---

## 5. Simplifying Method Calls

*Interface work. These change signatures, so they ripple to callers — do them with tooling
where possible.*

| Technique | What it does | Reach for it when |
|---|---|---|
| **Rename Method** | Give it a name that says what it does | The name lies, is vague, or the method's job has drifted |
| **Add Parameter** ↔ | The method needs more information | Data must come from the caller. Check first that it isn't Feature Envy |
| **Remove Parameter** ↔ | Drop an unused parameter | Nobody uses it. Do it immediately, it is free |
| **Separate Query from Modifier** | Split a method that returns a value *and* has side effects | Command/Query Separation violation — callers can't call it safely twice |
| **Parameterize Method** ↔ | Merge near-identical methods with a parameter | `raiseBy5()`, `raiseBy10()` |
| **Replace Parameter with Explicit Methods** ↔ | Split by parameter value into distinct methods | A boolean or enum parameter selects between behaviours |
| **Preserve Whole Object** | Pass the object instead of several of its fields | Long Parameter List drawn from one object |
| **Replace Parameter with Method Call** | Let the callee fetch what it can reach | The caller computes a value purely to pass it in |
| **Introduce Parameter Object** | Group parameters into one object | Data Clumps in signatures |
| **Remove Setting Method** | Delete the setter | The field should be immutable after construction |
| **Hide Method** | Reduce visibility | Nothing outside the class uses it |
| **Replace Constructor with Factory Method** | Named static creator instead of `new` | Construction needs a name, validation, or subclass selection |
| **Replace Error Code with Exception** ↔ | Throw instead of returning a sentinel | Error codes get ignored; failure must not be silent |
| **Replace Exception with Test** ↔ | Check the condition instead of catching | The exception is used for expected, checkable control flow |

**Separate Query from Modifier** is the most under-used item here. A method that both returns
and mutates cannot be safely reordered, cached, or called twice — a persistent source of
subtle bugs.

---

## 6. Dealing with Generalization

*Moving behaviour up and down hierarchies, and deciding whether the hierarchy should exist.*

| Technique | What it does | Reach for it when |
|---|---|---|
| **Pull Up Field** ↔ | Move a shared field to the superclass | Subclasses declare the same field |
| **Pull Up Method** ↔ | Move an identical method to the superclass | Duplicate Code across siblings |
| **Pull Up Constructor Body** | Shared construction moves to the parent | Subclass constructors start identically |
| **Push Down Method** ↔ | Move a method used by only one subclass down | The superclass carries behaviour only one child needs |
| **Push Down Field** ↔ | Same, for a field | Refused Bequest |
| **Extract Subclass** ↔ | New subclass for features used by some instances | Temporary Field; features only relevant in some cases |
| **Extract Superclass** ↔ | New parent for what two classes share | Duplicate Code across unrelated classes |
| **Extract Interface** | Publish the contract clients depend on | Several classes share a role; you need a test seam or a Strategy |
| **Collapse Hierarchy** | Merge a subclass into its parent | Speculative Generality; the subclass adds nothing |
| **Form Template Method** | Lift the shared skeleton, leave steps abstract | Sibling methods have the same shape, different steps |
| **Replace Inheritance with Delegation** ↔ | Hold an instance instead of extending it | Refused Bequest; only part of the parent is wanted |
| **Replace Delegation with Inheritance** ↔ | Extend instead of forwarding everything | The class delegates every method to the same field, and the is-a is real |

**Extract Interface** is the entry point to almost every pattern: Strategy, Repository,
Adapter and Ports & Adapters all start here. It is also the cheapest way to create a test seam
in legacy code.

**Default direction:** prefer delegation over inheritance. Inheritance couples subclasses to
the parent's implementation forever; composition does not. Reach for inheritance when the
substitutability guarantee is genuinely wanted — not merely to share code.

---

## Beyond the classic catalogue

Widely used, later-codified refactorings, mostly from Fowler's second edition:

| Technique | What it does |
|---|---|
| **Split Phase** | Separate one function into sequential phases with a clean intermediate data structure (parse → calculate → format) |
| **Replace Loop with Pipeline** | Rewrite loops as `map`/`filter`/`reduce` chains |
| **Combine Functions into Transform / Class** | Gather derived-value calculations into one place |
| **Replace Primitive with Object** | The modern name for Replace Data Value with Object |
| **Replace Conditional with Polymorphism** *(extended)* | Now also covers strategy objects, not just subclasses |
| **Introduce Special Case** | The generalised Null Object — a case object for any recurring special value |
| **Encapsulate Record** | Replace a raw record/array with a class controlling access |
| **Change Function Declaration** | The umbrella for Rename Method + Add/Remove Parameter |
| **Slide Statements** | Move related statements together before extracting |
| **Extract Function/Variable in parallel** | Language-agnostic naming of Extract Method/Variable |

---

## Choosing a technique

1. **Name the smell first** — [code-smells.md](code-smells.md) lists the cures per smell.
2. **Prefer the smallest step** that improves things. Small steps stay green and stay revertible.
3. **Prefer IDE automation** for Rename, Extract, Inline, Move and signature changes. Manual edits introduce the bugs the refactoring was supposed to avoid.
4. **Stop when the smell is gone.** Do not keep going toward an imagined ideal shape.
5. **A pattern that emerges still needs the YAGNI gate** in `SKILL.md`. Reaching a pattern by refactoring does not exempt it from justifying its cost.

---

## Source

Catalogue: <https://refactoring.guru/refactoring/techniques>. Original source: Martin Fowler,
*Refactoring: Improving the Design of Existing Code* (1999, 2nd ed. 2018). This file is
original commentary.
