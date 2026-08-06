# CLAUDE.md snippet

Skills are invoked at the model's discretion, based on their `description`. That works well most
of the time, but it will occasionally skip a task that *looks* trivial and is not.

Adding the block below to your **global** `~/.claude/CLAUDE.md` (or a project `CLAUDE.md`) makes
invocation deterministic. Copy everything between the markers.

<!-- BEGIN patterns-and-refactoring -->
```markdown
## Design decisions — mandatory gate

Before designing or writing any non-trivial code, and before any refactor,
invoke the `patterns-and-refactoring` skill.

- TRIVIAL work (one-line fixes, config values, copy changes, bug fixes that
  introduce no abstraction) is explicitly exempt. Do not invoke the skill and
  do not narrate a decision for it.
- For everything else, state the force (or the smell), the choice made, and the
  alternative rejected — before writing code, not after.
- Never refactor code that has no test coverage without first writing
  characterization tests that pin current behaviour.
- Never refactor and change behaviour in the same commit.
```
<!-- END patterns-and-refactoring -->

## Why the exemption is spelled out

The exemption line is not padding — it is what keeps the rule credible.

A gate with no exit fires on every task, including one-line fixes. People and models both learn
within days to skim past a prompt that is always wrong, and at that point the rule protects
nothing. Naming the exempt category explicitly means that when the gate *does* fire, it means
something.

## Scope

- **Global** (`~/.claude/CLAUDE.md`) — applies to every project on the machine. Recommended.
- **Project** (`<repo>/CLAUDE.md`) — applies to one repository. Use this when only some of your work warrants the gate, or when introducing it to a team gradually.
