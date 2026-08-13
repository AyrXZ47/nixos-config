# Plan: <project name>

> Single source of truth for the work. Committed, survives any session.
> ONLY the next wave is detailed (rolling plan). When a session dies, a new
> instance resumes from this file — never from memory.

## Goal

<One paragraph: what the project is and what "done" means. If it fits on the
back of a napkin, it's the right size.>

## Stack & constraints

<Languages, frameworks, build/test commands, deployment target, known
constraints, license (see LICENSE-SOFTWARE). Established by the planner
before wave 1.>

## Waves

| Wave | Focus | Status |
|------|-------|--------|
| 1 | <focus> | [ ] planned |
| 2 | <focus> | [ ] planned |
| 3 | <focus> | [ ] planned |

> Status legend: planned → in-flight → integrated → audited → done.
> Update after each step, by whoever ran the step.

---

## Wave <N> (current)

### File ownership map

Two executors never own the same file in the same wave. If they need it,
sequence them. Globs allowed; be explicit.

| File/glob | Owner |
|-----------|-------|
| `src/foo/` | executor-1 |
| `src/bar.go` | executor-2 |

### Tasks

- [ ] T1: <one sentence> → brief: `.workflow/briefs/wave<N>-executor-K.md`
- [ ] T2: <one sentence> → brief: `.workflow/briefs/wave<N>-executor-J.md`

### Integration plan

- <merge order, who merges, the exact build/test commands to run on the
  integrated tree>

### Audit gate

- <what the auditor must verify before this wave is done; run
  `.workflow/audit-checklist.md` on the integrated tree>

---

## Decision log

| Date | Decision | Why |
|------|----------|-----|
| <date> | <decision> | <reasoning worth keeping> |
