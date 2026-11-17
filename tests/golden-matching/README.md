# Golden test of matching: data

`input/hashes_001.csv` and `input/hashes_002.csv` are the decrypted hash files of two sites. They were made from the linkja-test-data patients by the earlier version of `scripts/test-golden-matching.sh`. Site 001 has the first 600 patients. Site 002 has the last 600. Hashing rejected one of the 200 shared patients, so site 002 has 599 rows and 199 patients are at both sites.

`report.txt` and `rules.txt` are the expected output. `GOLDEN_UPDATE=1` writes them again.

## Edited rows

Six rows of site 002 were edited, so that one match rule is the only link of a shared pair. Each edited row got a fresh value in all ten hash columns. Each fresh value is the upper-case SHA-256 hex of the label `golden-matching rule K hashN`, e.g. `golden-matching rule 4 hash3`. Then one column got the site 001 value that the rule compares.

| Site 002 line | Site 001 line | Rule | Changed column |
|---|---|---|---|
| 9 | 410 | 4 (hash1 to hash2) | hash2 = hash1 of site 001 |
| 10 | 411 | 5 (hash1 to hash5) | hash5 = hash1 of site 001 |
| 13 | 414 | 6 (hash1 to hash9) | hash9 = hash1 of site 001 |
| 23 | 424 | 7 (hash1 to hash10) | hash10 = hash1 of site 001 |
| 26 | 427 | 9 (hash3 to hash4) | hash4 = hash3 of site 001 |
| 30 | 431 | 10 (hash3 to hash6) | hash6 = hash3 of site 001 |

Line numbers count the header as line 1.

No row isolates rules 0, 1, 2, 3, 8, 11 or 12. Rule 0 compares each of the ten hash columns alone, so it links every pair that rules 1, 2, 3, 8, 11 and 12 link. Rules 1, 2, 3, 11 and 12 together compare all ten columns, so they link every pair that rule 0 links.
