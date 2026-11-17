# Golden test of matching: data

`input/hashes_001.csv` and `input/hashes_002.csv` are the decrypted hash files of two sites. They were made from the 1001 patients in linkja-test-data `hashing/project-data.csv`, with these steps:

1. Site 001 gets the first 600 patients. Site 002 gets the last 600. So 199 patients are at both sites.
2. Each site uses the sample salt file `hashing/salt.txt`, with its own site ID and name from the two rows of `salt-engine/sites.csv`: `001,Test 1` and `002,Test 2`. Its private salt is the SHA-256 hex of the sample private salt followed by the site ID.
3. linkja-hashing hashes each site with the published test secret (linkja-test-data `crypto/secret/linkja_secret.h`), `hashing/public-agg.key` and the private date `01/01/2018`.
4. linkja-matching `--decrypt` decrypts the two hash files with `matching/private-agg.key`. The files are renamed to `hashes_<site ID>.csv`.

Hashing rejected one patient of site 002 that is not at site 001. So site 002 has 599 rows.

`report.txt` and `rules.txt` are the expected output. `GOLDEN_UPDATE=1` writes them again.

## Edited rows

These six rows of site 002 were edited, so that one match rule is the only link of a shared pair. Each edited row got a fresh value in all ten hash columns. Each fresh value is the upper-case SHA-256 hex of the label `golden-matching rule K hashN`, e.g. `golden-matching rule 4 hash3`. Then one column got the site 001 value that the rule compares.

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

## Rows that differ in some columns

Seven more rows of site 002 differ from their site 001 partner in some columns. The other columns still link each pair. These rows catch a match rule that reads the incorrect column, e.g. rule 3 reading hash2 in place of hash1. Each changed column got a fresh value with the label scheme above. The rule number in the label is only a tag that keeps the fresh values of different rows apart. E.g. line 37 has the label rule 3 on hash2, but rule 3 reads only hash1.

| Site 002 line | Site 001 line | Label rule | Changed columns |
|---|---|---|---|
| 37 | 438 | 3 | hash1, hash2, hash5, hash9, hash10 |
| 40 | 441 | 11 | hash2, hash5, hash7, hash9, hash10 |
| 42 | 443 | 0 | hash2, hash5, hash7, hash9, hash10 |
| 2 | 403 | 8 | hash3, hash4, hash6 |
| 3 | 404 | 12 | hash4, hash6, hash8 |
| 4 | 405 | 0 | hash4, hash6, hash8 |
| 44 | 445 | 3 | hash3, hash4, hash6, hash8 |

So of the 45 pairs with all ten columns, 1 differs in hash1, 2 in hash7 and 3 in each of hash2, hash5, hash9 and hash10. Of the 193 pairs with hash3, 2 differ in hash3, 3 in hash8 and 4 in each of hash4 and hash6. Rules 3, 8, 11 and 12 each read one column: hash1, hash3, hash7 and hash8. Each of these columns has its own match count in `rules.txt`. So the count of the rule changes when it reads another column and scans in the order of that column.

When the rule still scans in the order of its own column, it compares each row only with the row before it. The two rows of a pair are next to each other, because they agree on that column. So the rule counts the pairs that agree on its own column and on the column it reads in error. For each of the four rules and each of the other nine columns, some pair agrees on the rule column and has no shared value in the other column (the values differ, or one is empty). E.g. line 44 agrees with its partner on hash1 and hash7, and differs in hash3, hash4, hash6 and hash8. Without line 44, rule 3 reading hash3 or hash8, and rule 11 reading hash8, gave the same counts as the correct rules.

Rules 4, 5, 6, 7, 9 and 10 need no such rows. When one of them reads another column, the pair that only it links loses its link, so `report.txt` changes. E.g. rule 4 reading hash9 in place of hash2 gives 198 matching patient groups in place of 199.
