#!/bin/sh
# Golden test of matching: it locks today's Global ID assignment.
# It runs linkja-matching (load, match rules, report) on the fixed decrypted
# hash files of two sites in tests/golden-matching/input/. Then it compares the
# report and the match counts of each match rule with the saved files in
# tests/golden-matching/. Hashing is tested by test-golden-hashing.sh.
#
# Usage: scripts/test-golden-matching.sh [parent-dir]
#   parent-dir  folder with linkja-matching in it. Default: the folder that
#               holds this workspace repo (the layout of clone-all.sh).
# linkja-matching is built from its committed HEAD (git archive), so local
# edits that are not committed are not tested.
# GOLDEN_UPDATE=1 writes the expected files from this run, and compares nothing.
# GOLDEN_RULES=0,1,... runs only these match rules. Use it to check by hand
# that a missing rule makes the test fail. It stops with GOLDEN_UPDATE=1, so
# the expected files always hold every rule.
# Needs Java 25, Maven and python3.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
parent=$(cd "${1:-$(dirname "$(dirname "$here")")}" && pwd)
expected="$(dirname "$here")/tests/golden-matching"
# Every match rule that linkja-matching has (GlobalMatchSqlite.matchRule).
match_rules=${GOLDEN_RULES:-0,1,2,3,4,5,6,7,8,9,10,11,12}
fail() { echo "FAIL: $*"; exit 1; }
if [ "${GOLDEN_UPDATE:-}" = 1 ] && [ -n "${GOLDEN_RULES:-}" ]; then
  fail "GOLDEN_UPDATE=1 with GOLDEN_RULES would write expected files for fewer rules"
fi

# The site IDs come from the input file names, hashes_<site ID>.csv. Each row
# must have the same ID in its siteid column, the first column. The ""
# makes awk compare text, so "2" is not the same ID as "002".
export LC_ALL=C # glob order, so the sites load in the same order everywhere
set -- "$expected"/input/hashes_*.csv
[ $# -eq 2 ] || fail "expected two input files in $expected/input, found: $*"
for f in "$@"; do
  site=${f##*/hashes_}
  site=${site%.csv}
  awk -F, -v s="$site" 'NR > 1 && $1 "" != s { exit 1 }' "$f" || fail "a row of $f has a siteid other than $site"
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A copy of the program, so the build output never lands in the clone.
repo=linkja-matching
mkdir "$work/$repo"
git -C "$parent/$repo" archive -o "$work/$repo.tar" HEAD || fail "git archive of $parent/$repo failed"
tar -xf "$work/$repo.tar" -C "$work/$repo"
echo "$repo: $(git -C "$parent/$repo" rev-parse --short HEAD)"
(cd "$work/$repo" && mvn -B -q package -DskipTests)
matching_jar=$(echo "$work"/$repo/target/*-jar-with-dependencies.jar)

run="$work/run"
mkdir -p "$run/data/input" "$run/data/output" "$run/data/processed" "$run/config"
cp "$expected"/input/hashes_*.csv "$run/data/input/"

# Matching needs its database tables and a config folder before it runs.
python3 - "$work/$repo/src/main/resources/GlobalMatchDDL-v2.txt" "$run/data/matching.db" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[2])
for sql in open(sys.argv[1]).read().split(";"):
    if sql.strip().upper().startswith("CREATE TABLE"):
        db.execute(sql)
db.commit()
PY
cat > "$run/config/global-match.properties" <<EOF
InputFilesDirectory=%ProjectRoot%/data/input
OutputFilesDirectory=%ProjectRoot%/data/output
ProcessedFilesDirectory=%ProjectRoot%/data/processed
DbDirectory=%ProjectRoot%/data/
DbName=matching.db
InputFileNamePrefix=hashes
InputFileNameSuffix=.csv
MatchingRules=$match_rules
EOF
echo "0 | start" > "$run/config/global-match-globalId.txt"

# One load for each site, in site order. Rows get their database IDs in load
# order, and Global IDs follow those IDs. One load of both files would take
# them in directory list order, which differs between file systems.
# "$@" still holds the input files from the site ID check.
matching() { java -jar "$matching_jar" --directory "$run" "$@" >> "$work/matching.log"; }
for f in "$@"; do
  site=${f##*/hashes_}
  matching --load --prefix "hashes_${site%.csv}" --suffix .csv
done
matching --match "$match_rules"
matching --report All

# The report name holds the time of the run, so look it up by its fixed start.
set -- "$run"/data/output/report1-All-*.txt
[ $# -eq 1 ] && [ -f "$1" ] || fail "expected one report, found: $*"
[ -s "$1" ] || fail "linkja-matching wrote an empty report"
cp "$1" "$work/report.txt"
# The match count of each match rule, from the console lines. They hold no time or path.
counts='Match Rule [0-9]+ .*(matches found|patient matches)'
counts="$counts|matching patient groups|new global ids|global ids to patients"
grep -E "$counts" "$work/matching.log" > "$work/rules.txt" || fail "linkja-matching printed no match counts"

if [ "${GOLDEN_UPDATE:-}" = 1 ]; then
  cp "$work/report.txt" "$work/rules.txt" "$expected/"
  echo "Wrote the expected files in $expected"
  exit 0
fi

failed=0
for f in report.txt rules.txt; do
  [ -s "$expected/$f" ] || fail "no expected file, or an empty one: $expected/$f"
  if ! cmp -s "$expected/$f" "$work/$f"; then
    echo "FAIL: $f differs from $expected/$f (first lines of the diff):"
    diff -u "$expected/$f" "$work/$f" | head -n 20 || true
    failed=1
  fi
done
[ "$failed" -eq 0 ] || exit 1
echo "PASS: Global IDs and match counts match tests/golden-matching/"
