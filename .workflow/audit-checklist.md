# Audit checklist

The auditor runs this on the INTEGRATED tree (merged worktrees) in a fresh
session — never the planner's session. Evidence over narration: every check
is a command the auditor runs and records. A claim without output is a failed
check. After the audit, copy this file to `.workflow/audits/wave<N>.md`
(create the dir) with findings filled in.

## 1. Integration integrity

- [ ] All wave worktrees merged into the integration branch.
- [ ] `git status` clean; no uncommitted work, no stashes.
- [ ] Diff vs plan: every task in the wave has its change present; nothing
      outside the ownership map was modified
      (check `git log --stat` per executor branch).

## 2. Build & tests

- [ ] Build command passes: `<command>` → record output.
- [ ] Test command passes: `<command>` → record output.
- [ ] Each brief's verify command passes on the INTEGRATED tree, not just on
      its worktree.

## 3. Scope discipline (ponytail)

- [ ] No new dependencies that stdlib/native/installed code already covers.
- [ ] No abstractions or boilerplate not requested by the briefs.
- [ ] Smallest diff that satisfies the tasks; `ponytail:` comments present
      where corners are cut deliberately, each naming its ceiling.

## 4. Security

Pre-release wave: run `skills/security-audit` on the integrated tree.
Otherwise at minimum:

- [ ] Trust-boundary inputs validated (files written at trust boundaries).
- [ ] No secrets/credentials committed (scan for keys, tokens, `.env` dumps).
- [ ] Release gate: `skills/security-audit` run; zero CRITICAL/HIGH findings
      or documented exceptions with an owner.
- [ ] Dependency licenses compatible with `LICENSE-SOFTWARE`.

## 5. Handoff

- [ ] Audit result written to `.workflow/audits/wave<N>.md`: findings,
      evidence, exceptions.
- [ ] Decision log in `.workflow/plan.md` updated with learnings.
- [ ] Plan updated for the next wave (rolling).

## Verdict

- [ ] APPROVED — next wave may start.
- [ ] APPROVED WITH EXCEPTIONS — listed above, with owners and deadlines.
- [ ] REJECTED — reasons and what must change before the wave can pass.
