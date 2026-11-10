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

- **The commit safety hook reads the wrong folder.** `git-safety-guard.sh` finds the target repo from the last `cd` or `-C` in the command. It does not expand `~` or shell variables, and it uses only the last `-C`. With anything else it checks the session's start folder, which may be on `master`, and blocks the commit. Write `git -C /absolute/path commit ...` with a literal path, one repo per command.
- **Maven picks the newest JDK.** Homebrew `openjdk` is Java 27 on this Mac. Every Maven command needs `JAVA_HOME=/opt/homebrew/opt/openjdk@25`.
- **Read `develop`, not only `master`.** The first audit read `master` only and missed that the three programs on `develop` already target Java 25 with current dependencies (work by Jonathan Carr, March and April 2026). The Java 17 decision had to be reversed.
- **linkja-crypto `master` does not compile on Apple Silicon.** A prototype mismatch fails with clang `-Werror`, and the bundled OpenSSL is x86_64 only. The branch `feat/platform-builds-ci` corrects both.
- **Reviews of documents grow their own scope.** The glossary went through 4 review rounds (2, 4, 1, 2 blocking). Round 2 rose because new terms were added in a fix. Scoping back (dropping terms for code that does not run, moving the byte-test design out of the ADR into ticket 14) is what brought the count down.

## 2026-11-10: plan agreed, first lanes built

**What happened.** The owner and Claude audited all MRAIA linkja repos (platform support and codebase design), agreed a plan in a grilling session, created this repo, and published the plan as tickets in this repo's issues. Three lanes were built and reviewed. One PR merged (SQL-hashing legacy README).

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

**Open branches, pushed, no PRs yet.**
- `docs/glossary-and-adr` (this repo): glossary, ADR 0001, README. Round 4 found 2 problems, both corrected after it. **Needs a round 5 review.** Merge it before `chore/workspace-setup`, because CONTRIBUTING links the glossary.
- `docs/secret-warning` (linkja-test-data): passed review. One wording change after the pass (unlocking needs only the sample private key) needs one short review round.
- `chore/workspace-setup` (this repo, ticket 1): round 1 BLOCK with 4. (a) The linkja-matching `.editorconfig` snippet in CONTRIBUTING claims `GlobalMatchSqlite.java` is CRLF; it is LF, and the snippet would rewrite it. (b) Local linking fails on a new machine: install linkja-crypto first, and use `mvn install -DskipTests` for linkja-core until its tests load the C library. (c) The PR template example still says Java 17. (d) The README links that ticket 1 asks for need a follow-up ticket, so the PR says "Refs #1", not "Closes #1". Nits worth taking: a test case for local commits and detached HEAD in `test-clone-all.sh` (the reviewer replaced the guard with `reset --hard` and the test still passed), say branch protection is not yet on, the `[*.bat] end_of_line = crlf` section.
- `feat/platform-builds-ci` (linkja-crypto, ticket 2): round 1 BLOCK with 2. (a) `NoSecretsTest` runs nowhere automatically: add a no-secrets configure, build and test step to CI. (b) macOS output is arm64 only, so the PR does not close ticket 2: file a follow-up for the universal library, and delete `origin/linux-build` after merge. The reviewer proved hash output did not change against `master` on 978 calls, and that the library signature fix keeps old signatures for an existing `linkja_secret.h`. Nits worth tickets: a test that the signature has 32 hex characters, an out-of-bounds read in `revertSecureHash` for input shorter than 64 hex characters (an old bug), `build-win.bat` still adds the old OpenSSL path, hide libcrypto's exported symbols, a CI `concurrency` group.

**Deliberately not done.** No branch protection yet (ticket 9 waits for every repo's CI job name). The old clone at `/Users/yw1084/code/linkja-core` was kept because the first session ran from it. `origin/linux-build` in linkja-crypto was not deleted.

## Next

**First task:** run a round 5 review on `docs/glossary-and-adr`. If it passes, open its PR and merge it.

**Then, in order:**
1. `docs/secret-warning` in linkja-test-data: one short review round, then PR and merge. It closes ticket 3 together with SQL-hashing PR 1.
2. `chore/workspace-setup` (ticket 1): send the 4 blocking findings above to a fixer, review again, then PR with "Refs #1".
3. `feat/platform-builds-ci` (ticket 2): fix the 2 blocking findings, review again, PR into `develop`. File the follow-ups named above.
4. Tickets 4 to 8 (Java 25, dependencies, CI in each Java repo, Docker). They can run in parallel lanes once ticket 2 merges.

Recount open tickets: `gh issue list -R MRAIA-ORG/linkja-workspace --state open`. See which can start: `gh api repos/MRAIA-ORG/linkja-workspace/issues/<n>/dependencies/blocked_by --jq '[.[].number]'`.

**Waits on the owner.**
- Ticket 19: whether two salt-like strings in SQL-hashing comments ever protected real data. The owner marked it not urgent.
- Optional: overrule any of the three decisions Claude made above.
- `Closes #N` closes nothing for PRs into `develop`, because `master` is the default branch in the code repos. Decide: make `develop` the default branch, or close tickets at release.
