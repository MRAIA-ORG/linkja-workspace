#!/bin/sh
# Golden test of hashing: it locks today's hash values end to end.
# It hashes the linkja-test-data patients with the sample salt file and the test
# library secret, decrypts the hash file with linkja-matching, and compares the
# decrypted CSV and the plain header fields of the hash file with the saved files
# in tests/golden-hashing/. The hash file holds a random session key, so its
# own bytes change on each run.
#
# Usage: scripts/test-golden-hashing.sh [parent-dir]
#   parent-dir  folder with linkja-crypto, linkja-hashing, linkja-matching and
#               linkja-test-data side by side. Default: the folder that holds
#               this workspace repo (the layout of clone-all.sh).
# The three programs are built from their committed HEAD (git archive), so
# local edits that are not committed are not tested. The script warns about
# them, at the start and again at the end. linkja-test-data files are read as
# they are on disk.
# GOLDEN_UPDATE=1 writes the expected files from this run, and compares nothing.
# Needs Java 25, Maven, CMake, OpenSSL 3 and python3. On macOS, set
# OPENSSL_ROOT_DIR="$(brew --prefix openssl@3)" for CMake.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
parent=$(cd "${1:-$(dirname "$(dirname "$here")")}" && pwd)
expected="$(dirname "$here")/tests/golden-hashing"
data="$parent/linkja-test-data"
# A fixed private date, so the hash values do not change from run to run.
private_date=01/01/2018
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*"; exit 1; }

# A copy of each program, so the build output and the test secret never land in a clone.
for repo in linkja-crypto linkja-hashing linkja-matching; do
  mkdir "$work/$repo"
  git -C "$parent/$repo" archive -o "$work/$repo.tar" HEAD || fail "git archive of $parent/$repo failed"
  tar -xf "$work/$repo.tar" -C "$work/$repo"
  echo "$repo: $(git -C "$parent/$repo" rev-parse --short HEAD)"
  [ -z "$(git -C "$parent/$repo" status --porcelain)" ] ||
    echo "WARNING: $parent/$repo has changes that are not committed. This test does not see them." | tee -a "$work/warnings"
done

# Linkja-hashing writes the rows in input order only when all rows are in one
# batch. A second batch can finish first and change the row order. Java uses
# the last batchSize line, so the script does too.
rows=$(python3 -c 'import csv, sys; print(sum(1 for _ in csv.reader(open(sys.argv[1], newline=""))) - 1)' "$data/hashing/project-data.csv")
config="$work/linkja-hashing/src/main/resources/config.properties"
batch=$(sed -n 's/^[[:space:]]*batchSize[[:space:]]*[=:][[:space:]]*//p' "$config" | tail -n 1 | tr -d '[:space:]')
[ -n "$batch" ] || fail "batchSize is not set in linkja-hashing config.properties. Set it to $rows or more."
[ "$batch" -ge "$rows" ] || fail "batchSize $batch in linkja-hashing config.properties is less than the $rows test rows. The row order can change."

# The secret build with the published test secret. CMake writes a random
# secret when src/include/linkja_secret.h is not there, so check it after cmake.
secret="$data/crypto/secret/linkja_secret.h"
cp "$secret" "$work/linkja-crypto/src/include/"
(cd "$work/linkja-crypto" && cmake . -DCMAKE_BUILD_TYPE=Release > /dev/null)
cmp -s "$secret" "$work/linkja-crypto/src/include/linkja_secret.h" || fail "the secret header after cmake is not the test secret $secret"
(cd "$work/linkja-crypto" && make linkjacrypto > /dev/null)
lib="$work/linkja-crypto/target"

(cd "$work/linkja-hashing" && mvn -B -q package -DskipTests)
(cd "$work/linkja-matching" && mvn -B -q package -DskipTests)

# linkja-matching reads the hash files from data/input under --directory, and
# the private key from --directory itself.
run="$work/run"
mkdir -p "$run/data/input"
cp "$data/matching/private-agg.key" "$run/"
(cd "$run" && java -Djava.library.path="$lib" -jar "$work"/linkja-hashing/target/*-jar-with-dependencies.jar \
  --encryptionKey "$data/hashing/public-agg.key" --saltFile "$data/hashing/salt.txt" \
  --patientFile "$data/hashing/project-data.csv" --privateDate "$private_date" --outDirectory data/input)
(cd "$run" && java -Djava.library.path="$lib" -jar "$work"/linkja-matching/target/*-jar-with-dependencies.jar \
  --decrypt --directory . --prefix hashes --suffix .enc --decryptionKey private-agg.key)

set -- "$run"/data/input/hashes_*.enc
[ $# -eq 1 ] && [ -f "$1" ] || fail "expected one hash file, found: $*"
enc=$1
csv=${enc%.enc}.csv
[ -f "$csv" ] || fail "linkja-matching wrote no decrypted CSV"

# The CSV has CRLF line ends. The saved copy keeps LF, as .editorconfig asks.
tr -d '\r' < "$csv" > "$work/hashes.csv"

# The plain header of the hash file (format v1, ADR 0001), one field a line.
# Each marker and delimiter must match, so any changed byte in it fails.
python3 - "$enc" > "$work/header.txt" <<'PY'
import struct, sys
data = open(sys.argv[1], "rb").read()
pos = 0
def take(n):
    global pos
    part = data[pos:pos + n]
    if len(part) != n:
        sys.exit("FAIL: the header ends early")
    pos += n
    return part
def expect(marker):
    if take(len(marker)) != marker:
        sys.exit("FAIL: the header does not hold %r at byte %d" % (marker, pos - len(marker)))
def int32():
    return struct.unpack(">i", take(4))[0]
expect(b"-----BEGIN LINKJA HEADER-----\n")
print("version=%d" % int32())
expect(b"\n")
print("site_id=%s" % take(int32()).decode())
print("project_id=%s" % take(int32()).decode())
print("hash_columns=%d" % int32())
print("hash_rows=%d" % struct.unpack(">q", take(8))[0])
expect(b"\n")
print("session_key_length=%d" % int32())
print("signature_length=%d" % int32())
expect(b"\n")
expect(b"-----END LINKJA HEADER-----\n")
PY

if [ "${GOLDEN_UPDATE:-}" = 1 ]; then
  mkdir -p "$expected"
  cp "$work/hashes.csv" "$work/header.txt" "$expected/"
  echo "Wrote the expected files in $expected"
  exit 0
fi

failed=0
for f in header.txt hashes.csv; do
  [ -f "$expected/$f" ] || fail "no expected file $expected/$f"
  if ! cmp -s "$expected/$f" "$work/$f"; then
    echo "FAIL: $f differs from $expected/$f (first lines of the diff):"
    diff -u "$expected/$f" "$work/$f" | head -n 20 || true
    failed=1
  fi
done
[ "$failed" -eq 0 ] || exit 1
[ ! -f "$work/warnings" ] || cat "$work/warnings"
echo "PASS: hash values and header fields match tests/golden-hashing/"
