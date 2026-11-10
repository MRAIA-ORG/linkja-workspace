# Handoff

## Start here

You are a fresh session and this file is your whole briefing. Nobody
writes you a separate prompt. Do these in order, then work.

1. Load skills `ship-loop`, `git-lanes` and `fresh-eye` before touching
   anything. Read the repo `CLAUDE.md`.
2. Read the LAST section of this file (the most recent date). It names
   the first task, the tickets in order, and what waits on the owner.
3. Run the recount commands that section carries before trusting any
   number in it.
4. Start the first task it names. Ask the owner nothing that section
   already answers.

Whoever closes a session rewrites the last section so step 2 stays true,
and leaves this block alone.

Judgment and reasoning only. No counts, no SHAs, no issue tallies: those rot
within hours. Derive them with `gh issue list` and the scripts in the repo.

## Traps that cost time

- **The commit safety hook reads the wrong folder.** `git-safety-guard.sh` finds the target repo from the last `cd` or `-C` in the command. It does not expand `~` or shell variables. It uses only the last `-C`. Otherwise it checks the start folder of the session. That folder can be on `master`, so the commit is blocked. Write `git -C /absolute/path commit ...` with a literal path, one repo per command.
- **Maven picks the newest JDK.** Homebrew `openjdk` is Java 27 on this Mac. Every Maven command needs `JAVA_HOME=/opt/homebrew/opt/openjdk@25`.
- **Read `develop`, not only `master`.** The first audit read `master` only. On `develop`, the three programs already target Java 25 with current dependencies. Jonathan Carr did that work in March and April 2026. So the Java 17 decision was reversed.
- **linkja-crypto `master` does not compile on Apple Silicon.** A prototype mismatch fails with clang `-Werror`. The bundled OpenSSL is x86_64 only. linkja-crypto PR 1 corrects both on `develop`.
- **Reviews of documents grow their own scope.** The glossary went through 4 review rounds (2, 4, 1, 2 blocking). Round 2 rose because a fix added new terms. Two changes brought the count down. We dropped terms for code that does not run. We moved the byte-test design out of the ADR into ticket 14.

## 2026-11-10: plan agreed, first lanes built

**What happened.** The owner and Claude audited all MRAIA linkja repos for platform support and codebase design. They agreed a plan in a grilling session. They created this repo and published the plan as tickets in its issues. Three lanes were built and reviewed. One PR merged (SQL-hashing legacy README).

**Decisions (owner, 2026-11-10).**
- Clones live side by side in one parent folder (`~/code/linkja/` on the owner's Mac). Local linking uses `mvn install` of `-SNAPSHOT` versions.
- The 5 code repos (linkja-core, linkja-crypto, linkja-hashing, linkja-matching, linkja-salt-engine) keep `develop` + `master`. Work goes to `develop` by PR. Support repos and this repo use `master` only. linkja-crypto got a new `develop` branch equal to `master`.
- `develop` and `master` will require a PR and passing CI, with admin bypass and 0 required approvals. Every PR still gets an independent review before merge.
- **Java 25** for all repos. Superseded the same day: Java 17, chosen before the `develop` branches were read.
- C library platforms: Windows x64, Linux x64, macOS universal.
- CI: one Linux job per repo. It compiles linkja-crypto with a throwaway secret, then runs the tests.
- Released jars stay in MRAIA-ORG/linkja-mvn-repo. The three program poms must point there (the old `linkja` address returns 404).
- Hash file format v1 stays byte-identical during the redesign (ADR 0001 on branch `docs/glossary-and-adr`).
- SQL-hashing is legacy. No work beyond its README.
- Test secret files in linkja-test-data stay, with a warning.
- Glossary words: "salt" and "hash value". "Token" is not used.
- Design order: foundation, then golden tests, then design work (crypto seam, hash file module, Engine split, match rules as data).

**Decisions Claude made, open to the owner's overrule.**
- This repo's default branch was renamed `main` to `master`, to match the others.
- Feature PRs squash-merge. The release PR from `develop` to `master` uses a merge commit, because a squash makes the two branches split apart.
- The glossary role name is "Coordinator". The old hashing README says "project manager".

**Merged.** SQL-hashing PR 1: README that marks the repo legacy. Two clean review rounds.

**Open branches at the end of the morning.** Four branches had review findings. All four merged in the afternoon. Their findings and fixes are in the PR bodies named in the next section.

**Deliberately not done.** No branch protection yet (ticket 9 waits for every repo's CI job name). The old clone at `/Users/yw1084/code/linkja-core` was kept because the first session ran from it. `origin/linux-build` in linkja-crypto was not deleted.

## 2026-11-10 (afternoon): four lanes merged

**What happened.** The four open branches from the morning went through review and fix loops and merged:
- linkja-test-data PR 1: the test-secret notice. It closed ticket 3.
- linkja-workspace PR 26: the glossary and ADR 0001.
- linkja-workspace PR 31: the clone script, CONTRIBUTING, PR template and `.editorconfig`. It refs ticket 1.
- linkja-crypto PR 1 into `develop`: system OpenSSL 3, current compilers and the first CI job. It refs ticket 2.

The old `linux-build` branch in linkja-crypto was deleted. Its tip was `5974d36`.

**Decisions Claude made, open to the owner's overrule.**
- Ticket 3 was reopened, then closed by the test-data PR. SQL-hashing PR 1 had closed it early.
- The glossary hit the three-round rule (2, 4, 1, 2, 3 blocking). The change of direction: a fix only deletes or splits text, and a length check runs before each review.
- The setup branch passed round 2 with nits. They were fixed before merge, because some were doc errors that make a new developer fail.

**Traps.**
- Read the pipeline that calls a class before you write a claim about it. `HashingStep` has code for derived rows, but hashing turns that feature off (`PermuteStep(false)`).
- A fix to one long sentence can change what the next sentence points back to. Two rounds were spent on that.
- `gh pr merge` is blocked for a PR of 25 or more lines with no review on GitHub. Post the verdict as a PR comment first.

**Deliberately not done.** No branch protection yet (ticket 9). The old clone at `/Users/yw1084/code/linkja-core` is still there.

**Next.**

**First task:** ticket 4 (linkja-core: Java 25, current dependencies, CI). Ticket 2 stays open only for the macOS universal library (ticket 28). Its PR is merged, so tickets 4 to 7 can start.

**Then, in order:**
1. Tickets 5, 6 and 7 (Java 25 and CI in linkja-hashing, linkja-matching, linkja-salt-engine). They can run in parallel lanes after ticket 4.
2. Ticket 8 (Docker images).
3. Ticket 9 (branch protection), once each repo has a CI job name.
4. Follow-ups filed today: 23, 24, 25, 27, 28, 29, 30.

Recount open tickets: `gh issue list -R MRAIA-ORG/linkja-workspace --state open`. See which can start: `gh api repos/MRAIA-ORG/linkja-workspace/issues/<n>/dependencies/blocked_by --jq '[.[].number]'`.

**Waits on the owner.**
- Ticket 19: whether two salt-like strings in SQL-hashing comments ever protected real data. The owner marked it not urgent.
- Optional: overrule any decision Claude made above.
- `Closes #N` closes nothing for PRs into `develop`, because `master` is the default branch in the code repos. Decide: make `develop` the default branch, or close tickets at release. Tickets 1 and 2 stay open until then.
