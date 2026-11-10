# Contributing to MRAIA linkja

These rules hold for every repo in the MRAIA linkja suite. Each code repo links here.
Words follow [GLOSSARY.md](GLOSSARY.md): say "salt", "hash value" and "hash file". Never say "token" in new text.

Every command below was run on macOS with Homebrew, unless it is marked **release time, not run here**.

## The repos

| Kind | Repos | Branches |
|---|---|---|
| Code | linkja-core, linkja-crypto, linkja-hashing, linkja-matching, linkja-salt-engine | `develop` and `master` |
| Support | linkja-mvn-repo, linkja-docker, linkja-test-data, SQL-hashing (legacy) | `master` |
| Workspace | linkja-workspace (this repo) | `master` |

linkja-core and linkja-crypto are libraries. linkja-hashing, linkja-matching and linkja-salt-engine are programs that use them.

## Setup

### Tools

You need Java 25, Maven, CMake, OpenSSL 3 and cmocka (the C unit test library).

Install them with Homebrew (**not run here**: the tools were already installed on the test machine):

```sh
brew install openjdk@25 maven cmake openssl@3 cmocka
```

Check what you have:

```sh
brew list --versions openjdk@25 maven cmake openssl@3 cmocka
```

Every Maven command needs Java 25. Maven uses the newest JDK it finds, and on a Mac with a newer Homebrew `openjdk`, that is not Java 25.
Set `JAVA_HOME` to your Java 25 install in every shell where you build. With Homebrew:

```sh
export JAVA_HOME="$(brew --prefix openjdk@25)"
mvn -v
```

`mvn -v` must show `Java version: 25`.

### Get all the repos

Make one parent folder. Clone this repo into it, then run the clone script:

```sh
mkdir linkja && cd linkja
git clone https://github.com/MRAIA-ORG/linkja-workspace.git
linkja-workspace/scripts/clone-all.sh
```

The script puts all 10 repos side by side in the parent folder. It checks out `develop` in each repo that has one.
You can give another parent folder as the first argument.

Run the same script again at any time to update. For each repo it:

- fetches, then fast-forwards the current branch to its upstream,
- skips the repo and says so if it has local changes (staged, unstaged or untracked files),
- fetches only, and says so, if the branch has local commits or no upstream.

The repo list is in `scripts/repos.txt`. To check the script itself (it clones from GitHub into a new temp folder):

```sh
linkja-workspace/scripts/test-clone-all.sh
```

### Install the libraries

linkja-core needs the linkja-crypto jar in your local Maven repository (`~/.m2`). Install linkja-crypto first, then linkja-core:

```sh
cd linkja-crypto
mvn install
cd ../linkja-core
mvn install -DskipTests
```

Use `-DskipTests` in linkja-core for now, because its tests cannot load the native linkja-crypto library yet (see Known gaps).

## Branches

Code repos have two long-lived branches:

- `develop` gets all work, by PR.
- `master` gets only releases. A release merges `develop` into `master` and gets a tag `vX.Y.Z`.

Support repos and this workspace repo have `master` only. Work goes into `master` by PR.

Branch protection is not turned on yet. It waits for the CI job name of each repo ([linkja-workspace#9](https://github.com/MRAIA-ORG/linkja-workspace/issues/9)).
Until then, GitHub lets anyone with write access push to `develop` and `master`. Do not do it. Use a PR.

When protection is on, `develop` and `master` will require a PR and passing CI. An admin can bypass this.

## Make a change

1. Make a short-lived branch from `develop` (or from `master` in a support repo). Name it `type/short-description`:

   ```sh
   git fetch origin
   git switch --no-track -c fix/short-name origin/develop
   ```

2. Commit with Conventional Commits (see below). One logical change per commit.
3. Push and open a PR into `develop` (**not run here**, it makes a real PR):

   ```sh
   git push -u origin fix/short-name
   gh pr create --base develop
   ```

4. Fill in the PR template. It asks for the change and its reason, the issue, the commands you ran, and the review.
5. When the repo has CI, it must pass. No code repo has CI yet (see Known gaps).
6. Get a review from someone who did not write the change. The person who merges checks that this happened.
   Branch protection ([linkja-workspace#9](https://github.com/MRAIA-ORG/linkja-workspace/issues/9)) will require CI and no approvals, so this rule stays with people.
   Fix what the review finds and get the fix reviewed too.
7. Squash-merge.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `type(scope): description`.
Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`. The body says why.

```
fix(hashing): reject a salt file with a short project salt

The minimum salt length was checked for the private salt only.
```

## Code style

Write new code in the style of the code around it. Do not reformat old code, in a PR of its own or as part of another change.
`.editorconfig` in this repo holds the settings below. Copy it into each repo.

### Java

- New code indents with 2 spaces and no tabs. Some older files use 4 spaces or tabs. Keep the style of the file you edit.
- The opening brace goes at the end of the line, for classes, methods and blocks.
- Most code writes `} else {` and `} catch (...) {` on one line. Some older code puts `else` and `catch` on a new line. Match the file.
- Put a space after `if`, `for` and `while`.
- Constants are `UPPER_SNAKE_CASE`. Classes are `UpperCamelCase`. Methods and fields are `lowerCamelCase`.
- Keep lines to 120 characters.

Older files that indent another way:

- linkja-crypto: `Library.java`, `AesResult.java` and `RsaResult.java` use 4 spaces.
- linkja-hashing: `Engine.java`, `EngineTest.java` and `DataHeaderMapTest.java` have some lines with tabs.
- linkja-matching: `BinaryFileBuffer.java` uses 4 spaces. `ExternalSort.java`, `GlobalMatchSqlite.java` and `GlobalMatchTasks.java` use tabs.

In linkja-matching, `ExternalSort.java`, `GlobalMatchTasks.java`, `BinaryFileBuffer.java` and `StringSizeEstimator.java` have CRLF line ends. `GlobalMatchSqlite.java` has LF line ends.
`GlobalMatchTasks.java` has trailing spaces. `BinaryFileBuffer.java` and `StringSizeEstimator.java` have no newline at the end of the file.
Keep them as they are. When you copy `.editorconfig` into linkja-matching, add these sections at the end, so that an editor does not rewrite those files:

```ini
[src/main/java/org/linkja/matching/{ExternalSort,GlobalMatchTasks}.java]
indent_style = tab
end_of_line = crlf

[src/main/java/org/linkja/matching/GlobalMatchTasks.java]
trim_trailing_whitespace = false

[src/main/java/org/linkja/matching/GlobalMatchSqlite.java]
indent_style = tab

[src/main/java/org/linkja/matching/{BinaryFileBuffer,StringSizeEstimator}.java]
end_of_line = crlf
insert_final_newline = false
```

### C (linkja-crypto)

- The opening brace of a function goes on its own line. The opening brace of an `if`, `for` or `while` block goes at the end of the line.
- Indent with 2 spaces in most of `linkja-crypto.c`. The OpenSSL wrapper functions at the top of the file use 4 spaces. Match the function you edit.
- The C tests mix tabs and spaces. Use spaces in new code.
- Put a space after `if`, `for` and `while`.
- Functions and variables are `snake_case`. Macros are `UPPER_SNAKE_CASE`.
- Many functions have a `/* name - what it does */` block comment above them. Comments inside functions use `//`.

### Shell

- Start with `set -eu` (or `set -e` as the older build scripts do).
- Indent with 2 spaces.
- Run `shellcheck` on the script before you open the PR. It must report nothing.

## Use a library build in a program (local linking)

During development, a program uses a `-SNAPSHOT` build of linkja-core or linkja-crypto from your local Maven repository (`~/.m2`).

1. Install linkja-crypto first (see Install the libraries). Then give linkja-core's `develop` the next version with `-SNAPSHOT` and install it:

   ```sh
   cd linkja-core
   mvn versions:set -DnewVersion=1.2.0-SNAPSHOT -DgenerateBackupPoms=false
   mvn install -DskipTests
   ```

2. In the program's `pom.xml`, set the `<version>` of the `linkja-core` dependency to the same `1.2.0-SNAPSHOT`.
3. Build the program. Maven finds the library in `~/.m2`.

To build linkja-crypto's Java classes and install its jar the same way:

```sh
cd linkja-crypto
mvn install
```

## Release a code repo

Do these steps in this order. All of them are **release time, not run here**, except `mvn versions:set` and `mvn deploy`. Those two were run in a scratch clone, `mvn deploy` with `-DskipTests` (see Known gaps).

1. On a branch from `develop`, set the release version and merge it into `develop` by PR:

   ```sh
   mvn versions:set -DnewVersion=1.2.0 -DgenerateBackupPoms=false
   ```

2. Open a release PR from `develop` into `master`. Merge it with a merge commit. Do not squash a release PR.
   A squash gives `master` a commit that `develop` does not have. The next release then has conflicts.

   ```sh
   gh pr create --base master --head develop --title "chore(release): v1.2.0"
   gh pr merge --merge
   ```

3. Tag the merge on `master` and push the tag:

   ```sh
   git fetch origin
   git tag -a v1.2.0 origin/master -m "v1.2.0"
   git push origin v1.2.0
   ```

4. Libraries only (linkja-core, linkja-crypto): deploy the jar into your clone of linkja-mvn-repo. The pom sends it to `../linkja-mvn-repo`, so the clone must sit beside the library, as the clone script puts it.

   ```sh
   git switch master && git pull --ff-only
   mvn deploy -DskipTests
   ```

   `-DskipTests` is necessary for linkja-core, because its tests cannot load the native library yet (see Known gaps).

   `mvn deploy` overwrites a version that is already in linkja-mvn-repo and does not warn you. Check that the version is new before you run it.

5. Libraries only: commit the new files in linkja-mvn-repo and merge them into its `master` by PR:

   ```sh
   cd ../linkja-mvn-repo
   git switch -c release/linkja-core-v1.2.0
   git add org/linkja
   git commit -m "chore(release): linkja-core v1.2.0"
   git push -u origin release/linkja-core-v1.2.0
   gh pr create --base master
   ```

6. On a branch from `develop`, set the next `-SNAPSHOT` version and merge it into `develop` by PR:

   ```sh
   mvn versions:set -DnewVersion=1.2.1-SNAPSHOT -DgenerateBackupPoms=false
   ```

## Known gaps

These were true when this file was written. Each one is a separate piece of work.

- linkja-core and linkja-crypto still compile for Java 8 (`1.8`). The three programs on `develop` already compile for Java 25.
- The poms carry release versions (e.g. `1.1.0`) on `develop`. The `-SNAPSHOT` flow above starts when a PR sets the first `-SNAPSHOT` version.
- The programs download linkja-core and linkja-crypto from `https://raw.github.com/linkja/linkja-mvn-repo/master`, the old organization.
- The linkja-core tests load the native linkja-crypto library from `linkja-core/lib`. That folder has no library in it.
  Until a build puts it there, `mvn install` in linkja-core fails. Use `mvn install -DskipTests`.
  On `develop`, the native library does not compile with Apple clang. A declaration in `linkja-crypto.h` does not match `linkja-crypto.c`.
- No code repo has CI yet. [linkja-workspace#2](https://github.com/MRAIA-ORG/linkja-workspace/issues/2) and #4 to #7 add one Linux CI job per repo.
