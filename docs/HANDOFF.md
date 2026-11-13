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
- **Reviews of documents grow their own scope.** Written after 4 glossary rounds (2, 4, 1, 2 blocking). Superseded the same afternoon: the glossary took 7 rounds, see the last section. Round 2 rose because a fix added new terms. Two changes brought the count down. We dropped terms for code that does not run. We moved the byte-test design out of the ADR into ticket 14.

## 2026-11-10: plan agreed, first lanes built

**What happened.** The owner and Claude audited all MRAIA linkja repos for platform support and codebase design. They agreed a plan in a grilling session. They created this repo and published the plan as tickets in its issues. Three lanes were built and reviewed. One PR merged (SQL-hashing legacy README).

**Decisions (owner, 2026-11-10).**
- Clones live side by side in one parent folder (`~/code/linkja/` on the owner's Mac). Local linking uses `mvn install` of `-SNAPSHOT` versions.
- The 5 code repos (linkja-core, linkja-crypto, linkja-hashing, linkja-matching, linkja-salt-engine) keep `develop` + `master`. Work goes to `develop` by PR. Support repos and this repo use `master` only. linkja-crypto got a new `develop` branch equal to `master`.
- `develop` and `master` will require a PR and passing CI, with admin bypass and 0 required approvals. Every PR still gets an independent review before merge.
- **Java 25** for all repos. Superseded the same day: Java 17, chosen before the `develop` branches were read.
- C library platforms: Windows x64, Linux x64, macOS universal.
- CI: one Linux job per repo. It compiles linkja-crypto with a throwaway secret, then runs the tests. Superseded 2026-11-13 by the owner: CI compiles the public build, because no current test uses the secret. The golden test (ticket 10) is the first job that needs the secret build.
- Released jars stay in MRAIA-ORG/linkja-mvn-repo. The three program poms must point there (the old `linkja` address returns 404).
- Hash file format v1 stays byte-identical during the redesign (ADR 0001, on `master`).
- SQL-hashing is legacy. No work beyond its README.
- Test secret files in linkja-test-data stay, with a warning.
- Glossary words: "salt" and "hash value". "Token" is not used.
- `develop` is the default branch of the 5 code repos. `master` gets only releases. Decided by the owner later on 2026-11-10.
- Ticket 19 (two salt-like strings in SQL-hashing) is closed as not planned. Do not raise it again.
- Design order: foundation, then golden tests, then design work (crypto seam, hash file module, Engine split, match rules as data).

**Decisions Claude made, open to the owner's overrule.**
- This repo's default branch was renamed `main` to `master`, to match the others.
- Feature PRs squash-merge. The release PR from `develop` to `master` uses a merge commit, because a squash makes the two branches split apart.
- The glossary role name is "Coordinator". The old hashing README says "project manager".

**Merged.** SQL-hashing PR 1: README that marks the repo legacy. Two clean review rounds.

**Open branches at the end of the morning.** Four branches had review findings. All four merged in the afternoon. Their findings and fixes are in the PR bodies named in the next section.

**Deliberately not done.** No branch protection yet (ticket 9 waits for every repo's CI job name). The old clone at `/Users/yw1084/code/linkja-core` was kept because the first session ran from it. `origin/linux-build` in linkja-crypto was not deleted.

## 2026-11-10: four lanes merged in the afternoon

**What happened.** The four open branches from the morning went through review and fix loops and merged:
- linkja-test-data PR 1: the test-secret notice. It closed ticket 3.
- linkja-workspace PR 26: the glossary and ADR 0001.
- linkja-workspace PR 31: the clone script, CONTRIBUTING, PR template and `.editorconfig`. It refs ticket 1.
- linkja-crypto PR 1 into `develop`: system OpenSSL 3, current compilers and the first CI job. It refs ticket 2.

The old `linux-build` branch in linkja-crypto was deleted. Its tip was `5974d36`, which is also in the local linkja-crypto clone.

**Decisions Claude made, open to the owner's overrule.**
- Ticket 3 was reopened, then closed by the test-data PR. SQL-hashing PR 1 had closed it early.
- The glossary hit the three-round rule. It took 7 rounds, see the `Rounds:` line of PR 26. The change of direction: a fix only deletes or splits text, and a length check runs before each review.
- The setup branch passed round 2 with nits. They were fixed before merge, because some were doc errors that make a new developer fail.

**Traps.**
- Read the pipeline that calls a class before you write a claim about it. `HashingStep` has code for derived rows, but hashing turns that feature off (`PermuteStep(false)`).
- A fix to one long sentence can change what the next sentence points back to. Two rounds were spent on that.
- `gh pr merge` is blocked for a PR with 25 or more lines of code and no review. Post the verdict as a PR comment with a line that starts with `PASS` or `BLOCK`.

**Deliberately not done.** No branch protection yet (ticket 9). The old clone at `/Users/yw1084/code/linkja-core` is still there.

**Next.**

**First task:** ticket 4 (linkja-core: Java 25, current dependencies, CI). Tickets 4 to 8 have no blockers. Their links to ticket 2 were removed on 2026-11-10, because the linkja-crypto PR they waited on is merged.

Facts for ticket 4:
- linkja-core tests fail on a clean clone. `linkja-core/lib` holds no native library, so the tests cannot load it.
- The C library fixes are on linkja-crypto `develop` only. linkja-core CI must compile linkja-crypto from `develop`.
- The secret build and the no-secrets build of linkja-crypto share one CMake cache. Reconfigure with `-DINCLUDE_SECRETS=OFF` or `=ON`, then `make`, to switch.

**Then, in order:**
1. Tickets 5, 6 and 7 (Java 25 and CI in linkja-hashing, linkja-matching, linkja-salt-engine). They can run in parallel lanes after ticket 4.
2. Ticket 8 (Docker images).
3. Ticket 9 (branch protection). It needs a CI job name in each repo.
   GitHub lists tickets 2 and 4 to 7 as its blockers.
   Ticket 2 stays open for a Windows build check and ticket 28.
   When tickets 4 to 7 close, remove the ticket 2 link and start ticket 9.
4. Ticket 24 (README links). When it merges, close ticket 1.
5. Follow-ups filed today: 23, 25, 27, 28, 29, 30, 32. Also 20 and 21, which have no blockers.

Recount open tickets: `gh issue list -R MRAIA-ORG/linkja-workspace --state open`. See which can start: `gh api repos/MRAIA-ORG/linkja-workspace/issues/<n>/dependencies/blocked_by --jq '[.[].number]'`.

**Waits on the owner.**
- Optional: overrule any decision Claude made above.

## 2026-11-13: Java 25 and CI in all four Java repos

**What happened.** Tickets 4 to 7 are merged into `develop` and closed. linkja-core, linkja-hashing, linkja-matching and linkja-salt-engine now build on Java 25 from a clean machine, with current dependencies, pinned plugins and one Linux CI job each. Each PR body has a `Rounds:` line and a `## Review findings` section with every finding fixed, ticketed or rejected. Read them with `gh pr view 1 -R MRAIA-ORG/<repo>`.

**Decisions (owner, 2026-11-13).**
- linkja-matching ships one jar per platform. The Intel Mac and Apple Silicon JavaFX files have the same names, so one jar cannot hold both. Only `--gui` needs the jar of its own platform. Command-line matching and `--decrypt` load no JavaFX and run from any jar.
- Program CI compiles the public build of the C library. This supersedes the 2026-11-10 plan of a secret build with a throwaway secret.

**Decisions Claude made, open to the owner's overrule.**
- Ticket 5 closed with Bouncy Castle 1.61 still in the hashing jar. It comes from the released linkja-core 1.1.0. The fix is the next linkja-core release (ticket 37).
- The last review of linkja-matching found README and CI nits for arm64. They went into ticket 46, with no fifth review round for README wording.
- Ticket 8 pins each image to a `develop` commit, and the crypto image uses linkja-crypto `develop`. The ticket text says "a fixed tag" and "`master` of linkja-crypto", but it was written before the Java 25 work. No tag holds Java 25 code, and the C library fixes are only on `develop`. The ticket allows "a fixed tag or commit".

**Facts the next tickets need.**
- Every CI job in the five code repos is named `linux` (linkja-crypto included). Ticket 9 needs that name for the required check.
- Three program CI jobs compile the public build of the C library: linkja-core, linkja-hashing and linkja-salt-engine. linkja-matching CI only packages the jar and resolves JavaFX, so it needs no C library and no cmocka.
- linkja-core: two tests failed on Java 25 before this work. `AES/GCM/PKCS5Padding` stopped resolving in Java 14 (OpenJDK JDK-8180392), and `AES/GCM/NoPadding` gives the same bytes. The C library accepts only 2048-bit RSA keys, and the old test keys were 1024-bit.
- Tests find the C library through the `native.lib.dir` Maven property (default `lib/`). The committed `lib/` libraries in salt-engine and matching are x86_64 only (ticket 43).
- The released linkja-core 1.1.0 in linkja-mvn-repo differs from linkja-core `develop`, which is also labelled 1.1.0. Never `mvn deploy` before ticket 37 picks a new version.

**Traps.**
- **GitHub runs no CI on a PR with a merge conflict, and says nothing.** `gh pr checks` reports "no checks". Jonathan Carr pushed README commits to hashing and matching `develop` on 2026-11-12, after the lanes started. On an open PR, check `gh pr view <n> --json mergeable` before you wait for CI.
- **linkja-crypto CMake requires cmocka on Linux and macOS.** Its find module sets `LIBCMOCKA_FOUND`, never `CMOCKA_FOUND` (ticket 38). Every CI job that compiles the C library installs `libcmocka-dev`.
- **linkja-crypto `cmake` on macOS needs `JAVA_HOME`** and `-DOPENSSL_ROOT_DIR="$(brew --prefix openssl@3)"`. Homebrew `openssl@3` is keg-only (ticket 39).
- **Parallel lanes need their own Maven folder.** Each builder used `-Dmaven.repo.local=<scratch>/m2-<repo>`. That also proves a clean machine resolves everything.
- **`git -C <worktree> commit` from a folder on `master` can be blocked** by the safety hook. Run the commit from inside the worktree.

**Deliberately not done.** No branch protection yet (ticket 9 is next). No linkja-core release (ticket 37 waits on the owner). The secret hash path in hashing has no test (ticket 10).

**Next.**

**First task:** ticket 8 (linkja-docker: Java 25 images from MRAIA-ORG at fixed versions). It has no open blockers.

Facts for ticket 8:
- Pin each image to a `develop` commit of its repo, and build linkja-crypto from `develop`. See the decision above. Pick the commits with `git ls-remote https://github.com/MRAIA-ORG/<repo> refs/heads/develop`.
- The current Dockerfiles clone `github.com/linkja/...` with no ref, and use `adoptopenjdk/openjdk11` base images.
- The crypto image clones `-b linux-build`. That branch was deleted on 2026-11-10, so the image cannot build today.
- `test-data/liblinkjacrypto.so` in linkja-docker is a committed binary. Find out what uses it before you change it.
- linkja-matching on Linux needs the `linux` JavaFX classifier, which the profile picks on an x64 builder.

**Then, in order:**
1. Ticket 9 (branch protection on `develop` and `master` of the five code repos). Its blockers are closed. The required check is `linux` in each repo. `master` of the five code repos has no CI file until the next release PR from `develop`, so check that requiring `linux` on `master` does not block that PR.
2. Ticket 24 (workspace README links). When it merges, close ticket 1.
3. Ticket 38 (linkja-crypto CMake without cmocka). Then drop cmocka from the three program CI jobs that compile the C library (core, hashing, salt-engine). linkja-crypto CI keeps it for its C tests.
4. Ticket 10 (golden test, hashing to decrypted output). Its CI needs the secret build. Then ticket 11 (golden test, matching output), then the design tickets 12 to 18 in the 2026-11-10 design order. Ticket 2 stays open until the Windows build check and ticket 28.
5. Follow-ups, `ready-for-agent` first: 34, 35, 36, 39, 40, 41, 42, 44, 45. Then 46 and 43 (43 waits on 28). Older: 20, 21, 23, 25, 27, 28, 29, 30, 32.

Recount open tickets: `gh issue list -R MRAIA-ORG/linkja-workspace --state open`. Agent-ready: `gh issue list -R MRAIA-ORG/linkja-workspace --label ready-for-agent`. See which can start: `gh api repos/MRAIA-ORG/linkja-workspace/issues/<n>/dependencies/blocked_by --jq '[.[] | select(.state=="open") | .number]'`.

**Waits on the owner.**
- **Ticket 37: pick the next linkja-core version (e.g. 1.2.0).** Needed before any deploy to linkja-mvn-repo. It also removes Bouncy Castle 1.61 from the program jars.
- Optional: overrule any decision Claude made above.
