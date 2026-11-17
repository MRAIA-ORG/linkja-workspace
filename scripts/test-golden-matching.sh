#!/bin/sh
# Golden test of matching: it locks today's Global ID assignment end to end.
# It hashes the linkja-test-data patients as two sites, decrypts the two hash
# files and runs linkja-matching on them (load, all match rules, report). Then it
# compares the report and the match counts of each match rule with the saved
# files in tests/golden-matching/.
#
# Usage: scripts/test-golden-matching.sh [parent-dir]
#   parent-dir  folder with linkja-crypto, linkja-hashing, linkja-matching and
#               linkja-test-data side by side. Default: the folder that holds
#               this workspace repo (the layout of clone-all.sh).
# The three programs are built from their committed HEAD (git archive), so
# local edits that are not committed are not tested. linkja-test-data files
# are read as they are on disk.
# GOLDEN_UPDATE=1 writes the expected files from this run, and compares nothing.
# Needs Java 25, Maven, CMake, OpenSSL 3 and python3. On macOS, set
# OPENSSL_ROOT_DIR="$(brew --prefix openssl@3)" for CMake.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
parent=$(cd "${1:-$(dirname "$(dirname "$here")")}" && pwd)
expected="$(dirname "$here")/tests/golden-matching"
data="$parent/linkja-test-data"
# A fixed private date, so the PIDHASH values do not change from run to run.
private_date=01/01/2018
# Site 1 gets the first 600 patients and site 2 the last 600, so 200 patients are at both sites.
split_rows=600
# Every match rule that linkja-matching has (GlobalMatchSqlite.matchRule).
match_rules=0,1,2,3,4,5,6,7,8,9,10,11,12
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*"; exit 1; }

# A copy of each program, so the build output and the test secret never land in a clone.
for repo in linkja-crypto linkja-hashing linkja-matching; do
  mkdir "$work/$repo"
  git -C "$parent/$repo" archive -o "$work/$repo.tar" HEAD || fail "git archive of $parent/$repo failed"
  tar -xf "$work/$repo.tar" -C "$work/$repo"
  echo "$repo: $(git -C "$parent/$repo" rev-parse --short HEAD)"
done

# The secret build with the published test secret. CMake writes a random
# secret when src/include/linkja_secret.h is not there, so check it after cmake.
secret="$data/crypto/secret/linkja_secret.h"
cp "$secret" "$work/linkja-crypto/src/include/"
(cd "$work/linkja-crypto" && cmake . -DCMAKE_BUILD_TYPE=Release > /dev/null)
cmp -s "$secret" "$work/linkja-crypto/src/include/linkja_secret.h" || fail "cmake changed the test secret header"
(cd "$work/linkja-crypto" && make linkjacrypto > /dev/null)
lib="$work/linkja-crypto/target"

(cd "$work/linkja-hashing" && mvn -B -q package -DskipTests)
(cd "$work/linkja-matching" && mvn -B -q package -DskipTests)
hashing_jar=$(echo "$work"/linkja-hashing/target/*-jar-with-dependencies.jar)
matching_jar=$(echo "$work"/linkja-matching/target/*-jar-with-dependencies.jar)

# Two sites from salt-engine/sites.csv. They share the project salt and project
# name of the sample salt file. Each private salt is the SHA-256 of the sample
# private salt and the site ID, so it is fixed and different for each site.
# Each site hashes its own part of the patients.
run="$work/run"
mkdir -p "$run/data/input" "$run/data/output" "$run/data/processed" "$run/config"
python3 - "$data" "$work" "$split_rows" <<'PY'
import csv, hashlib, sys
data, work, split = sys.argv[1], sys.argv[2], int(sys.argv[3])
site_id, site_name, private, project_salt, project = open(data + "/hashing/salt.txt").read().strip().split(",")
sites = [row for row in csv.reader(open(data + "/salt-engine/sites.csv")) if row][:2]
lines = open(data + "/hashing/project-data.csv", newline="").read().splitlines()
header, rows = lines[0], lines[1:]
parts = [rows[:split], rows[-split:]]
if len(sites) != 2 or len(rows) <= split:
    sys.exit("FAIL: need two sites in sites.csv and more than %d patients" % split)
for (sid, name), part in zip(sites, parts):
    salt = hashlib.sha256((private + sid).encode()).hexdigest()
    with open("%s/salt-%s.txt" % (work, sid), "w") as f:
        f.write(",".join([sid, name, salt, project_salt, project]) + "\n")
    with open("%s/patients-%s.csv" % (work, sid), "w") as f:
        f.write("\n".join([header] + part) + "\n")
PY
sites=$(cut -d, -f1 "$data/salt-engine/sites.csv" | head -n 2)
[ "$(echo "$sites" | wc -l)" -eq 2 ] || fail "expected two sites in sites.csv"

cp "$data/matching/private-agg.key" "$run/"
for site in $sites; do
  mkdir "$work/hashing-$site"
  (cd "$run" && java -Djava.library.path="$lib" -jar "$hashing_jar" \
    --encryptionKey "$data/hashing/public-agg.key" --saltFile "$work/salt-$site.txt" \
    --patientFile "$work/patients-$site.csv" --privateDate "$private_date" --outDirectory "$work/hashing-$site")
  set -- "$work/hashing-$site"/hashes_*.enc
  [ $# -eq 1 ] && [ -f "$1" ] || fail "expected one hash file for site $site, found: $*"
  cp "$1" "$run/data/input/"
done
(cd "$run" && java -Djava.library.path="$lib" -jar "$matching_jar" \
  --decrypt --directory . --prefix hashes --suffix .enc --decryptionKey private-agg.key)

# Matching needs its database tables and a config folder before it runs.
python3 - "$work/linkja-matching/src/main/resources/GlobalMatchDDL-v2.txt" "$run/data/matching.db" <<'PY'
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
matching() { java -jar "$matching_jar" --directory "$run" "$@" >> "$work/matching.log"; }
for site in $sites; do
  set -- "$run"/data/input/hashes_"$site"_*.csv
  [ $# -eq 1 ] && [ -f "$1" ] || fail "expected one decrypted CSV for site $site, found: $*"
  matching --load --prefix "hashes_${site}_" --suffix .csv
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
  mkdir -p "$expected"
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
