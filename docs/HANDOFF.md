# Handoff

## Start here

You are a fresh session. This file and the open `lane` issues are your
whole briefing. Nobody writes you a separate prompt. Do these in order.

1. Load skills `ship-loop`, `git-lanes` and `fresh-eye` before touching
   anything. Read the repo `CLAUDE.md`.
2. Check that the repo has the label. This prints `lane` if it does:
   `gh label list --search lane --json name --jq '.[] | select(.name == "lane") | .name'`
   It prints nothing: this repo has no lane label yet. Read the LAST
   section of this file for the tasks, and go to step 6.
3. List the open lanes. Free lanes come first, lowest issue number
   first. Held lanes follow, oldest time first:

   gh issue list --label lane --state open --limit 100 --json number,title,body --jq '(now | strftime("%Y-%m-%dT%H:%MZ")) as $now | map(((.body // "") | split("\n") | first // "" | rtrimstr("\r")) as $h | {n: .number, t: .title, h: $h, s: (($h | capture("^Held by: (?<name>.+), since (?<time>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}Z)$") | select(.name != "nobody" and .time <= $now) | .time) // null)}) | sort_by(if .s then [1, .s, .n] else [0, .n] end) | .[] | "#\(.n) \(.t) | \(if .s or .h == "Held by: nobody" then .h else "Held by: (malformed)" end)"'

   No lines: no lane is open. Read the LAST section of this file for the
   tasks, and go to step 6. 100 lines: raise `--limit`, list again.
4. Pick a lane. A lane is free when its `Held by:` line says nobody or
   is malformed, or its time is over 24 hours old and ListAgents does
   not show that session live. Else it is held. The owner named a lane:
   take it, and if it is held, tell the owner and stop. Else, one free
   lane: take it. More than one: ask the owner with one AskUserQuestion,
   one option per free lane in list order, the first recommended. No
   owner present (a cloud routine, a headless run): take the first free
   lane. No free lane: tell the owner, and stop.
5. Claim it, after any answer from the owner:
   `python3 scripts/lane_claim.py claim <N> "<name>"`. Add
   `--holder-not-live` only when step 4 found the lane free by its
   24-hour rule. Exit 0: you hold the lane. Exit 1: it says why. Change
   nothing. The owner named this lane: tell the owner and stop. Else go
   back to step 4. Any other exit, e.g. no `scripts/lane_claim.py` or a
   failed `gh`: change nothing, stop, and tell the owner. <name> is your
   session name as ListAgents prints it. With no ListAgents, use your
   harness and worktree, e.g. `laptop:04-handoff-lanes`. A cloud routine
   adds its run start, e.g. `cloud routine nightly 2026-11-10T06:17Z`.
6. Read the lane issue's `## Next`, or with no lane the LAST section.
   Read the recent sections of this file for traps. Run the recount
   commands before trusting any number. A task with no mark is `parallel`
   unless it names another task it waits for. Start every `parallel`
   task it names in the same turn, each in its own worktree (`git-lanes`), two
   to four at once. Start any more as earlier tasks merge or stop. Start an
   `after` task when its dependency merges. If you stop before that,
   leave it in `## Next` with its `after` mark for the next session. Ask
   the owner nothing it already answers.

Write a lane body only with `scripts/lane_claim.py write` or `release`,
and if it refuses, change nothing, stop, and tell the owner. Update
`## Next` with `python3 scripts/lane_claim.py write <N> "<name>" <file>`,
and free the lane with `python3 scripts/lane_claim.py release <N> "<name>"`
when you stop. Leave this block alone.

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
- CI: one Linux job per repo. It compiles linkja-crypto with a throwaway secret, then runs the tests. Superseded 2026-11-13 by the owner for the four program repos: their CI compiles the public build, because no program test uses the secret. linkja-crypto CI keeps the throwaway secret build, because its C tests need it. The golden test (ticket 10) is the first program job that needs the secret build.
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

## 2026-11-13: Java 25 and CI in all four Java program repos

**What happened.** Tickets 4 to 7 are merged into `develop` and closed. linkja-core, linkja-hashing, linkja-matching and linkja-salt-engine now build on Java 25 from a clean machine, with current dependencies, pinned plugins and one Linux CI job each. Each PR body has a `Rounds:` line and a `## Review findings` section with every finding fixed, ticketed or rejected. Read them with `gh pr view 1 -R MRAIA-ORG/<repo>`.

**Decisions (owner, 2026-11-13).**
- linkja-matching ships one jar per platform. The Intel Mac and Apple Silicon JavaFX files have the same names, so one jar cannot hold both. Only `--gui` needs the jar of its own platform. Command-line matching and `--decrypt` load no JavaFX and run from any jar.
- Program CI compiles the public build of the C library. This supersedes the 2026-11-10 plan of a secret build with a throwaway secret.
- Ticket 8 (Docker images) waits for real releases. No tag holds the Java 25 code, and the C library fixes are only on linkja-crypto `develop`. The images use released code only, so ticket 8 waits on the linkja-core version (ticket 37) and a linkja-crypto release (ticket 2).

**Decisions Claude made, open to the owner's overrule.**
- Ticket 5 closed with Bouncy Castle 1.61 still in the hashing jar. It comes from the released linkja-core 1.1.0. The fix is the next linkja-core release (ticket 37).
- The last review of linkja-matching found README and CI nits for arm64. They went into ticket 46, with no fifth review round for README wording.

**Facts the next tickets need.**
- Every CI job in the five code repos is named `linux` (linkja-crypto included). Ticket 9 needs that name for the required check.
- Three program CI jobs compile the public build of the C library: linkja-core, linkja-hashing and linkja-salt-engine. linkja-matching CI only packages the jar and resolves JavaFX, so it needs no C library and no cmocka.
- linkja-core: tests failed on Java 25 before this work, for two causes. `AES/GCM/PKCS5Padding` stopped resolving in Java 14 (OpenJDK JDK-8180392), and `AES/GCM/NoPadding` gives the same bytes. The C library accepts only 2048-bit RSA keys, and the old test keys were 1024-bit.
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

**First task:** ticket 9 (branch protection on `develop` and `master` of the five code repos). Superseded 2026-11-15: done, see the 2026-11-15 section.
- The required check is `linux` in each repo.
- GitHub lists no open blocker for ticket 9. The "Blocked by" list in its body is out of date and still names ticket 2.
- Read the owner's 2026-11-15 comment on ticket 9 first. It keeps `develop` plus `master`, and keeps admin bypass, because Jonathan Carr and Larry Lemmon push directly to `develop`. Admin bypass comes off only after they have used PRs with CI for a few weeks, and after the owner tells them.
- The last CI run on linkja-crypto `develop` failed. Check it with `gh run list -R MRAIA-ORG/linkja-crypto --branch develop --limit 1`. It ran on Jonathan Carr's `pom.xml` push of 2026-11-12, when Maven Central did not serve `maven-resources-plugin:3.4.0`. Do not re-run it without a change. The next PR into `develop` runs CI again.
- `master` of the five code repos has no CI file until the next release PR from `develop`. Check that requiring `linux` on `master` does not block that PR.
- linkja-core `master` is ahead of `develop`, so read both before the first release PR.

**Then, in order:**
1. Ticket 8 (Docker images), only after the releases named in the 2026-11-13 decisions (tickets 37 and 2). Facts for it:
   - The Dockerfiles clone the old `github.com/linkja/...` repos with no ref, and use `adoptopenjdk/openjdk11` base images. The matching image uses `adoptopenjdk/openjdk11:alpine` (musl). JavaFX Linux natives and a glibc C library may not load on Alpine.
   - The crypto image clones `-b linux-build` from the old `linkja` org. That branch still exists there. Only the MRAIA-ORG copy was deleted.
   - `test-data/liblinkjacrypto.so` is a committed x86-64 binary. The program READMEs name it, and the linkja-docker root README links to its folder.
   - On an Apple Silicon Mac, `docker build` gives arm64, and the matching pom has no arm64 Linux default. Use `--platform linux/amd64`.
2. Ticket 24 (workspace README links). When it merges, close ticket 1.
3. Ticket 38 (linkja-crypto CMake without cmocka). Then drop cmocka from the three program CI jobs that compile the C library (core, hashing, salt-engine). linkja-crypto CI keeps it for its C tests.
4. Ticket 10 (golden test, hashing to decrypted output). Its CI needs the secret build. Then ticket 11 (golden test, matching output), then the design tickets 12 to 18 in the 2026-11-10 design order. Ticket 2 stays open until the Windows build check, ticket 28 and the linkja-crypto release from `develop` to `master`.
5. Follow-ups, `ready-for-agent` first: 34, 35, 36, 39, 40, 41, 42, 44, 45. Then 46 and 43 (43 waits on 28). Older: 20, 21, 23, 25, 27, 28, 29, 30, 32.

Recount open tickets: `gh issue list -R MRAIA-ORG/linkja-workspace --state open`. Agent-ready: `gh issue list -R MRAIA-ORG/linkja-workspace --label ready-for-agent`. See which can start: `gh api repos/MRAIA-ORG/linkja-workspace/issues/<n>/dependencies/blocked_by --jq '[.[] | select(.state=="open") | .number]'`.

**Waits on the owner.**
- **Ticket 37: pick the next linkja-core version (e.g. 1.2.0).** Superseded 2026-11-15: the owner picked 2.0.0, see the 2026-11-15 section. Needed before any deploy to linkja-mvn-repo. It also removes Bouncy Castle 1.61 from the program jars, and ticket 8 waits on it.
- Optional: overrule any decision Claude made above.

## 2026-11-15: branch protection on, linkja-core 2.0.0-SNAPSHOT, lanes

**What happened.** The 2026-11-13 handoff merged after more review rounds (PR 47, its `Rounds:` line). Branch protection is on for `develop` and `master` in the five code repos, and ticket 9 is closed (PR 48). linkja-core `develop` is `2.0.0-SNAPSHOT` (linkja-core PR 2), the first PR under the new protection: its `linux` check ran and passed. CONTRIBUTING has the version rule (PR 49). Each PR body has its `Rounds:` line and `## Review findings`. This pass moved the handoff to `lane` issues.

**Decisions (owner, 2026-11-15).**
- Keep git flow and admin bypass (comment on ticket 9).
- Version rule: SemVer. Major for a public API change, a hash file format change, or a higher minimum Java. Minor for a new function that keeps old code working. Patch for fixes only. The next linkja-core version is 2.0.0, because 1.1.0 runs on Java 8 and `develop` needs Java 25. 1.1.1 and 1.2.0 were rejected for that reason (comment on ticket 37).
- Work from clones of the MRAIA-ORG repos, with branches in those repos. A fork was rejected: a fork of a public repo is public, so it hides nothing, and it splits branches from their PRs, tickets and CI.
- The handoff and the tickets stay public in this repo.
- Move this handoff to `lane` issues.

**Decisions Claude made, open to the owner's overrule.**
- Ticket 8 is now blocked by tickets 37 and 2 on GitHub, and ticket 43 by ticket 28. `ready-for-agent` came off ticket 8. Before this, the handoff's own command said Docker work could start.
- The old clone at `/Users/yw1084/code/linkja-core` and the orca worktrees of this repo were deleted. None held unpushed or uncommitted work.
- Lanes split the open tickets: releases, C library, golden tests and design, workspace docs, follow-ups. No ticket is a task in two lanes.
- The GitHub link "#2 blocked by #1" was removed. #1 is the workspace setup, and it does not block a C library build.

**Traps.**
- **Larry Lemmon (`llemmon`) is not a collaborator on the five code repos.** The ticket 9 comment says he pushes to `develop`. He cannot push at all today. Jonathan Carr pushes as `rainercarr` (admin). His older account `jonathancarrcch` is not a collaborator either. On a public repo, the permission API answers `read` for any user, so use the collaborator list. Recount: `gh api repos/MRAIA-ORG/linkja-core/collaborators --jq '.[] | "\(.login) \(.role_name)"'`.
- **`gh issue comment` has no `--jq` flag.** With `2>/dev/null` the failure was silent, and the owner decision did not reach ticket 37 until a reviewer found it missing. Never hide the error output of a write.
- **A handoff pass must collect notes from all repos.** The lane issues live here, but the work merges in the code repos too. Run the pass's `gh pr list` with `-R MRAIA-ORG/<repo>` for each repo in `scripts/repos.txt`. The code repos have no PR template, so their PR bodies carry a `## Handoff notes` section only when the author writes one. (Last sentence superseded 2026-11-15 night: the code repos get the org template from MRAIA-ORG/.github. A PR made with `gh pr create --body` still skips the template, so the rest of this trap holds.)
- **zsh treats a word that starts with `=` as a command path.** `echo =====` fails with "not found". Quote it.
- **A required check on a branch with no CI file.** `master` of the code repos has no `ci.yml`. A release PR from `develop` gets `linux` from its merge commit. A hotfix branch cut from `master` would never get `linux`, so only an admin could merge it. CONTRIBUTING has no hotfix flow.

**Deliberately not done.** No PR template in the five code repos (superseded 2026-11-15 night: the org template in MRAIA-ORG/.github covers them). No release yet: the first `mvn deploy` waits on the owner (releases lane).

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here. Each lane's `## Next` marks its tasks `parallel` or `after`. The lanes opened today: releases, C library, golden tests and design, workspace docs, follow-ups.

**Waits on the owner.**
- **Approve the first `mvn deploy` to linkja-mvn-repo** (releases lane).
- **If Larry Lemmon must push, give him admin access.** Write access below admin lets branch protection stop his direct pushes.
- Optional: overrule any decision Claude made above.

## 2026-11-15 (evening): workspace docs lane merged

**What happened.** The workspace docs lane merged the work of four tickets in one rebase-merged PR (PR 60): README links, Known gaps, CRLF files, and clone test cases. Each ticket has one commit, plus two review fixes. Tickets 24, 25 and 27 closed. Ticket 32 stays open for one box. Three review rounds ran (its `Rounds:` line). Ticket 56 (keep a trailing space in `GlobalMatchDDL-v2.txt`) merged after (PR 61). The yw-workflow plugin changed too: the documenter agent has `Bash`, and the fresh-eye reviewer gets the author's source lines (yw-workflow PR 126).

**Decisions (owner, 2026-11-15).**
- Move the long, mechanical part of reviews (the clone test and its mutations) into GitHub Actions. This repo is public, so the minutes cost nothing. This is ticket 59.

**Decisions Claude made, open to the owner's overrule.**
- PR 60 merged with no CI and no branch protection on `master`, after three independent review rounds. Earlier PRs in this repo merged the same way. Ticket 59 adds the first CI job.
- Ticket 32's last box (copy the PR template into the 5 code repos) stays open. The earlier handoff left it undone on purpose. (Superseded 2026-11-15 night: the owner chose the org `.github` repo, and ticket 32 closed.)
- The new clone test makes local mirrors and points each mirror's default branch away from `develop`. On GitHub, `develop` is the default branch of every repo that has it. So a plain clone cannot show whether `clone-all.sh` checks out `develop` itself.

**Traps.**
- **Agent-tool `isolation: "worktree"` fails from `~/code/linkja`.** That folder is not a git repo. Make reviewer worktrees by hand: `git -C <repo> worktree add --detach <path> <branch>`.
- **The installed documenter had no shell** (plugin 1.18.0). It could not measure a claim or commit. Plugin 1.19.1 corrects this. Check the version a session loaded before you send it measurement work.
- **A review that measures every claim again is slow.** The first review of PR 60 used 114 tool calls in about 13 minutes. Paste the builder's source lines into the review prompt, and keep later rounds to the fix.
- **`Closes #N` on a rebase merge closed the issues a few seconds late.** Check the issue state again before you close one by hand.
- **The clone test reads the default address from the text of `clone-all.sh`.** A caller-set `LINKJA_GIT_BASE` skips that check. The old `linkja` org has every repo except `linkja-workspace`, so the test asserts `repos.txt` lists it.

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here.

**Waits on the owner.**
- Ticket 32, last box: copy the PR template into the 5 code repos, or add an org `.github` repo? (Answered 2026-11-15 night: the org repo.)
- After ticket 59 merges: make its `linux` job a required check on `master`? (Answered 2026-11-15 night: yes.)
- Optional: overrule any decision Claude made above.

## 2026-11-15 (night): CI in linkja-workspace, org PR template, old org links

**What happened.** linkja-workspace has its first CI job, `linux`, which runs the clone test and its recorded mutations (PR 64). `linux` is a required check on `master`, with the same settings as the five code repos. A new public repo, MRAIA-ORG/.github, holds the org-wide PR template (MRAIA-ORG/.github PR 1). The `github.com/linkja` addresses that ticket 57 named are gone from linkja-matching, linkja-core and linkja-crypto (their PRs into `develop`). The pom `<url>` of linkja-core and linkja-crypto still names `https://linkja.github.io/` (ticket 68). A throwaway PR (PR 67, closed unmerged) applied one recorded mutation, and the `linux` job failed. Tickets 32, 56, 57 and 59 closed.

**Decisions (owner, 2026-11-15).**
- The PR template lives in an org-wide `MRAIA-ORG/.github` repo, so every repo with no template of its own gets it.
- `linux` is a required check on linkja-workspace `master`: PR required, admin bypass, 0 approvals.

**Decisions Claude made, open to the owner's overrule.**
- The mutation "old linkja org as default" stays in CI. It depends on the old org keeping its repos and never getting `linkja-workspace`. If that changes, the job fails on every PR. It is the only proof that the test rejects the old org.
- The local clone of MRAIA-ORG/.github is at `~/code/linkja/mraia-org-github`. It is not in `scripts/repos.txt`, because nothing in the suite builds from it. So a handoff pass must list its PRs by hand: `gh pr list -R MRAIA-ORG/.github --state merged`.

**Traps.**
- **The `require-code-review` hook guards only some files.** It counts lines in `.py`, `.yml`, `.yaml`, `.toml`, `.cfg`, `.sh`, `.ts` and `.js` files, and blocks `gh pr merge` at 25 or more with no review. A docs, Java or `pom.xml` PR passes it unreviewed. Review those by hand.

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here.

## 2026-11-15 (late): one PR template, mutation runner checks its data

**What happened.** The org PR template now writes a lane as `MRAIA-ORG/linkja-workspace#<N>` in a code repo and `#<N>` in linkja-workspace (MRAIA-ORG/.github PR 2). linkja-workspace deleted its own copy and uses the org template (PR 70). Ticket 65 stays open for one box: the next code repo PR must show the template. The mutation runner checks every line of `scripts/clone-all-mutations.txt` before it clones, and reads a last line with no newline (PR 72, ticket 63). `scripts/test-mutations-data.sh` holds its recorded cases, offline. A mutation gate records known breakages of the runner in `scripts/runner-mutations.txt`, and CI requires the data cases to fail on each (PR 75, housekeeping ticket 71). The review of PR 75 found six older runner guards that no case can fail (ticket 74). The handoff PR 66 was reviewed and merged. Ticket 59 closed after a throwaway PR proved the `linux` job fails on a broken script.

**Decisions Claude made, open to the owner's overrule.**
- Only a linkja-workspace PR can close a lane by itself. A code repo PR that finishes a lane writes `Lane: MRAIA-ORG/linkja-workspace#<N>. finished`, and the handoff pass lists it for the owner. The handoff skill accepts only `Lane: #<N>. finished`. Changing the skill was left to the owner.
- Ticket 63 merged after its third round still had one blocking finding. That finding is a runner check that is the same on `master`, outside the ticket. Three rounds each found one new untested runner branch, so the work was scoped back to the ticket and the pattern became housekeeping ticket 71. A fourth, independent round judged that call and passed.
- MRAIA-ORG/.github PR 2 merged with no CI, because that repo has none. Three review rounds checked it.

**Traps.**
- **Tests of the mutation runner must stay offline.** Two reviewers and one fixer started real GitHub clone runs or a self-calling `sh` loop (PR 72 notes). Run cases only through `scripts/test-mutations-data.sh`, which copies the runner beside stubs. Use `{}` as perl delimiters when the pattern has `|`.
- **The mutation gate records known breakages only.** Each new review of the runner has found one more. Expect that until ticket 74 is done.
- **The merge hook checks for the review comment before the command runs.** A verdict comment and `gh pr merge` in one Bash call is blocked. Post the comment in its own call.
- **`gh pr merge` once returned 401 with valid auth** (seen by this session on MRAIA-ORG/.github PR 2). A second try worked. Check `gh pr view <N> --json state` before you retry.

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here.

**Waits on the owner.**
- **Must a code repo PR close a lane by itself?** Then the yw-workflow handoff skill must accept `Lane: MRAIA-ORG/linkja-workspace#<N>. finished`.
- Optional: overrule any decision Claude made above.

## 2026-11-15 (wrap): workspace chores done, pom URL moved

**What happened.** The pom `<url>` of linkja-core and linkja-crypto names the MRAIA-ORG repo (linkja-core PR 4, linkja-crypto PR 3, ticket 68). Those two PRs were the first code repo PRs under the org template. GitHub reports the org template as the PR template of linkja-core, so ticket 65 closed. The clone test fails when `clone-all.sh` does not fetch, and when it fetches only for a clone that already looks behind (PRs 78 and 80, tickets 58 and 77). The mutation runner refuses an `expect` text that is short, holds `FAIL:`, or does not match exactly one `fail "..."` message in `scripts/test-clone-all.sh` (PRs 79 and 82, tickets 69 and 76). Five older runner guards got cases that fail, and the gate refuses an entry with no proof or a pattern that matches more than once (PR 82, ticket 74). Ticket 81 is open: a perl field with two substitutions joined by `;` is not fully checked.

**Decisions (owner, 2026-11-15).**
- The pom `<url>` names `https://github.com/MRAIA-ORG/<repo>`. The next release of each library publishes it in its pom.
- Ticket 81 is parked in lane 53. The owner chose to move to product work. Each runner review has found one more gap, so a review of the fix for 81 will likely file one more.

**Decisions Claude made, open to the owner's overrule.**
- Tickets 74 and 76 went into one PR with one commit each, rebase-merged. Both change the same three scripts.
- Ticket 74 items 2 and 8 are rejected (PR 82 body). Item 2: no input makes the run count differ from the line count. Item 8: CI runs the data cases in the step before the gate.
- Short reviews for small diffs: a reviewer on a one-line or four-line change gets a narrow brief. The owner asked why reviews take long. The time goes to hand mutation of the check, not to long tests.

**Traps.**
- **The runner gate takes about 55 seconds.** It took about 22 before PR 82. Each entry reruns all data cases. It runs in CI only. Running entries in parallel would cut it.
- **A reviewer left a perl probe that waited on stdin, with a backup and edit of the runner in its command.** The worktree was clean when it was stopped. Tell reviewers not to leave a process waiting on stdin, and check `git status` in the review worktree after one stops.
- **A PR with two `Closes` lines closed the second ticket a few seconds late.** Check `gh issue view <N> --json state` again before you close it by hand.
- Superseded 2026-11-15 (wrap): "The mutation gate records known breakages only. Expect that until ticket 74 is done." Ticket 74 is done, and its review still found one more gap (ticket 81). Expect it on the next runner change too.

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here.

**Waits on the owner.**
- **Must a code repo PR close a lane by itself?** Then the yw-workflow handoff skill must accept `Lane: MRAIA-ORG/linkja-workspace#<N>. finished`.
- Optional: overrule any decision Claude made above.

## 2026-11-16: roadmap, run config (step 1) and four hashing fixes

**What happened.** The roadmap for the run config and linkage functions merged (PR 86), with one ticket per step (tickets 89 to 95) and lane 87. In linkja-hashing, five PRs merged into `develop`: two columns for one field stop every run (PR 3, ticket 88), the run config and column map (PR 4, ticket 95, step 1), the list of birth date formats that read (PR 5, ticket 97), clearer run config error messages (PR 6, ticket 98), and a failed run removes the output files it made (PR 7, ticket 96). Ticket 99 (a failed run can exit 0) is built on a local branch and waits for review: see lane 87.

**Decisions (owner, 2026-11-16).**
- The roadmap order (config first) and the 3-year spread for one-time costs. Local planning files stay in the gitignored `internal/` folder. The owner gives the hash rule list and the default majority thresholds at the design reviews of steps 3 and 4.
- No change to the hashing or crypto algorithm (hash rules, salt use, secure hash, the C library, normalized output, match rules) unless the owner agrees first. Input handling (which column, how a date is read, when a run stops) is allowed.
- Ticket 97: hashing output stays exactly as today. Removing `MMdduuuu` from the date pattern would make one rare value stop reading (a date, a time, then the same date again, e.g. `12/31/2001 23:59:5912312001`). So the pattern stays, and the fix is the README list plus tests that pin today's behavior.

**Decisions Claude made, open to the owner's overrule.**
- Two columns for one field stop every run, before any output. A silent pick can hash a column the site did not mean.
- An unknown run config key stops the run. A typo such as `input.date_fromat` would else fall back to the default formats and hash 3 February as 2 March.
- A failed run removes its files, and does not rename them, because the crosswalk and invalid-data files hold patient IDs. A run never opens a file that is already there (`CREATE_NEW`), so two runs in the same second stop instead of overwriting.
- A birth date format with a zone offset or zone name is accepted. The date is kept as written and the zone is not applied.

**Traps.**
- **Roadmap step 2 order.** Step 2 (hash file format v2) folds in ticket 21 and waits on tickets 11, 15 and 16. Steps 3 and 5 build on v2. v2 is released only after step 5, so no site holds a v2 file without site keys. Step 3 keeps the last-4 SSN field and adds the 9-digit SSN as a separate field. Step 5 starts with ADR 0002.
- **The programs use released linkja-core 1.1.0.** A ticket that changes linkja-core runs `mvn -q install` in it first and moves each program pom. linkja-matching has no `src/test/java`.
- **No full hashing run on an arm64 Mac.** The test secret C library is x86_64 only, and CI builds the public library. Tests stub the secure hash through the package-private `createSecureHash` and `revertSecureHash` in `Engine`.
- **The default birth date pattern is a chain of optional sections**, tried in turn from where the last one stopped. A change to any section can change which rows hash. The pin tests in `ValidationFilterStepTest` catch it.
- **Restoring a mutated file with its old timestamp lets Maven use a stale class.** Run `mvn clean` after each restore. Restore from a backup copy, never with `git checkout` of a file that holds your edits: a fixer lost its fix that way.
- **In zsh, Maven flags in an unquoted variable are not split**, so `-Dnative.lib.dir` is lost and the run fails with `UnsatisfiedLinkError`. Put the flags on the command line.
- **A rebase that resolves a conflict changes the work**, so it needs a review round even after a PASS. Tickets 97 and 98 both edited the README run config section.
- **A `Fixes MRAIA-ORG/linkja-workspace#N` line in a linkja-hashing PR closes the ticket on merge**, because `develop` is the default branch of linkja-hashing.
- **Files over the module size limit:** `RunConfigTest.java`, `ValidationFilterStepTest.java` and `Engine.java`. Split them in a task that changes their structure.

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here.

**Waits on the owner.**
- The design review answers for tickets 90 and 91, and the reviewer contact for ticket 94 (lane 87).
- **Must a code repo PR close a lane by itself?** (carried from 2026-11-15)
- Optional: overrule any decision Claude made above.

## 2026-11-16 (evening): a failed hashing run exits non-zero

Tickets 99 and 101 merged in linkja-hashing (PRs 8 and 9).

**What changed.** A hashing run that fails partway now exits 1 with one `ERROR - ` line, and leaves no output files. Before, a mid-run failure returned normally and the run exited 0, so a script took it as a success. A C library that cannot load, on the run thread or in a worker, now gives the line "The crypto C library could not be loaded". The review compared a successful run's files with the code before the change: identical, so the hash output did not change.

**Decisions Claude made, open to the owner's overrule.**
- An `Error` from a worker thread (e.g. out of memory) prints the same as one from the run thread. The message no longer says "while writing the results".
- The salt-file error text changed from "decrypt the salt file using the private key" to "could not be read". Check operator documentation that quotes the old text.

**Traps.**
- **A real worker failure in a test:** override `newTaskFor` in the test thread pool given through `Engine.createThreadPool`. A throw from `createSecureHash` runs on the run thread, so it does not test the worker path.
- **`RunnerTest.main_RunFails_ExitsNotZero` starts a separate JVM** with `java.home` and `java.class.path`. A change to the surefire fork settings can change that classpath, so run this test after one.
- **`Runner.java` is also over the module size limit now** (`wc -l src/main/java/org/linkja/hashing/{Engine,Runner}.java` in linkja-hashing).

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here. Lane 87 has no task that can start now: its tasks wait on lane 52 (golden tests) and on the owner.

**Waits on the owner.**
- The design review answers for tickets 90 and 91, and the reviewer contact for ticket 94 (lane 87).
- **Must a code repo PR close a lane by itself?** (carried from 2026-11-15)
- Optional: overrule any decision Claude made above.

## 2026-11-17: golden hashing test, roles page, security policy, releases

Merged: the golden test of hashing (#10), the page of who holds which key, salt and library (#104, `docs/roles.md`), the org security policy (#105, `SECURITY.md` in MRAIA-ORG/.github) with Dependabot in the five code repos, and a release job for linkja-hashing (#103). The golden test of matching (#11) is built but waits on two owner questions (lane 52).

**Where the new tickets came from.** A security office review of linkja asked sites to get it only from the primary site, check each update, and watch for vulnerability news. That gave #103 (releases a site can check), #104 and #105. The owner chose these three on 2026-11-17 and approved the weekly Dependabot schedule.

**Decisions Claude made, open to the owner's overrule.**
- Private vulnerability reporting is on in every public MRAIA-ORG repo (recount: `gh repo list MRAIA-ORG --visibility public --json name --jq length`), not only the five code repos the ticket named. The org policy points every reader at that button. Undo per repo: `gh api -X DELETE repos/MRAIA-ORG/<repo>/private-vulnerability-reporting`.
- The golden hashing expected files come from the `develop` tips, because no program has a GitHub release yet.
- A release needs an annotated `vX.Y.Z` tag, with a message, on the commit the run assembles. A plain tag stops it, so the notes never say "no security fix" without a basis.

**Traps.**
- **The golden tests run committed `HEAD` of the sibling clones.** An uncommitted edit is not tested. To test a code change, commit it in a scratch clone.
- **Row order in the golden hashing test holds only because `batchSize = 10000`** in linkja-hashing's `config.properties` is larger than the 1000 test rows (#109 adds a guard).
- **The `golden-hashing` CI job is not a required check**, and program repos do not run it. A program PR that changes hash values merges, and the next workspace PR fails.
- **Hashing rejects one row of the matching test's site 2, and it is a shared patient**, so matching finds 199 groups and not 200.
- **One removed match rule does not change Global IDs** in the test data, because rules 0, 2, 8 and 12 each find every shared group. Only the per-rule counts catch it.
- **The merge guard blocks a merge of 25 or more lines that has no review.** A PR comment or a GitHub review counts. It also blocks `gh pr merge` after a `cd` to a variable or `cd -`. Post the verdict with `gh pr comment`, then run `gh pr merge <N> -R <owner/repo>` alone.
- **`git -C <clone> worktree add` with a relative path puts the worktree one folder too deep.** Use an absolute path.
- **The salt file is plain text, but the code calls it "encrypted"** in the salt engine help (`Runner.java`, two places), a variable name (`SaltEngine.java`, `encryptedSaltFile`) and a hashing error message (`EngineParameters.java`, "Unable to find encrypted salt file"). `docs/roles.md` cites only the help text. Not ticketed.
- **No program writes the aggregator key pair**, only a test. Not ticketed.

**Slice work small.** On 2026-11-17 the owner asked if work was being cut down. One builder had three repos and one review had six. Give each builder one repo and one change that one review can cover, then copy the pattern.

**Next.**

The open `lane` issues hold the tasks. List them with step 3 of Start here.

**Waits on the owner.**
- Answered 2026-11-17 (lane 52): the golden matching test reads two committed decrypted CSV files, and gets new test data so that one removed rule changes the Global IDs. The `golden-hashing` job becomes a required check, and the program repos run it too.
- When to push the first linkja-hashing release tag.
- The design review answers for tickets 90 and 91, and the reviewer contact for ticket 94 (lane 87).
- **Must a code repo PR close a lane by itself?** (carried from 2026-11-15)
