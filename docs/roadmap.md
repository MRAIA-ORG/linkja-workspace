# Roadmap: run config and linkage functions

This roadmap takes linkja from its input today to a full privacy-preserving record linkage tool. Each step ships and works before the next one starts. Terms in bold are defined in `GLOSSARY.md`.

Goals:

1. A site describes one hashing run in one clear file, the **run config**.
2. linkja covers the functions a linkage network needs. These are common patient details, phonetic and location hash rules, and a majority match rule. They also include a separate key per site, re-keying at the aggregator, and re-keyed output for other recipients.
3. A network can estimate what linkja costs to run per day, with its own staff rates.

## Today

A site gives the Java hashing program its inputs in two places:

- Command-line flags: `--encryptionKey`, `--saltFile`, `--patientFile`, `--privateDate`, and the optional `--outDirectory` and `--delimiter` (`linkja-hashing/README.md`, "Hashing").
- The header row of the input extract. linkja-hashing finds each column by a fixed list of header names, e.g. `fname` or `first name` for the first name (`linkja-hashing/src/main/resources/configuration/canonical-header-names.csv`). A header name that is not in the list needs a code change and a new build.

The legacy SQL Server scripts use a third shape, `SQL-hashing/Config.txt`, with keys such as `name1=` and `dob=`. Their output does not match the Java output (`SQL-hashing/README.md`, "Its hash values do not match linkja-hashing").

linkja hashes the patient ID, first name, last name, birth date and the last 4 digits of the SSN. It accepts an SSN of 4 or 9 digits and keeps only the last 4. It has no field for sex, ZIP, street address, phone or email.

## The MVP: one run config

A site writes one key=value file and runs `java -Djava.library.path=. -jar Hashing-<version>-jar-with-dependencies.jar --config run.properties`. The keys:

```properties
# Secrets and keys
site.salt_file=keys/project1_salt.txt
aggregator.public_key=keys/aggregator_public.key
site.private_date=01/01/2018

# The input extract
input.file=data/extract.csv
input.delimiter=,
input.date_format=uuuu/MM/dd

# Column map: linkja field = column name in the input extract
column.patient_id=PAT_ID
column.first_name=GIVEN
column.last_name=SURNAME
column.birth_date=DOB_TXT
column.ssn=SOC

output.directory=out/
```

Rules for the MVP:

- Required keys: `site.salt_file`, `aggregator.public_key`, `site.private_date` and `input.file`. Each can come from the file or from its command-line flag. All other keys are optional.
- For each field, a `column.` key wins, even when the fixed header list maps that header to another field. With a `column.` key for a field, the other fixed-list headers for that field are ignored.
- The fixed header list is used only for a field with no `column.` key.
- A column that is neither named by a `column.` key nor in the fixed header list is ignored. So a site can use an extract it already has, with extra columns, as it is.
- In a run with a run config, two columns that resolve to one field stop the run. A run with no `--config` works exactly as today. Today two columns for one field give no error: the ID check reads the first and hashing uses the last (#88).
- `input.date_format` is a Java date pattern with `uuuu` for the year, because the date parser is strict. When it is set, only that format is accepted. With the key left out, the 8 birth date formats accepted today still apply.
- A command-line flag wins over the same key in the file.
- The run config holds the private date, so it is a secret file like the salt file. A site may leave `site.private_date` out and give `--privateDate` on the command line.
- A missing required key stops the run before hashing. So does a `column.` key that names no column of the extract. The message names the key.

## Steps

| Step | What it adds | Depends on |
|---|---|---|
| 1 | The run config and column map above. | nothing |
| 2 | Hash file format v2 in the linkja-core hash file module, and the hash mask input in the linkja-crypto C library. A row holds a variable number of hash values, named in the header. linkja-matching finds each hash value by its name. The step also fixes the v1 problems that ADR 0001 leaves for v2, and the hash mask input (#21). | 1, #11 (golden test), #14 (hash file module), #15 (hashing writes through the module), #16 (matching reads through the module) |
| 3 | New fields with their validation: sex, ZIP, street address, phone, email, and the full 9-digit SSN. New hash rules that combine them with names and birth date. | 2 |
| 4 | The **majority match rule** in linkja-matching, with its majority thresholds as settings. | 3 |
| 5 | A **site key** for each site, and the **re-key** step at the aggregator. | 2, and 3 for release order only |
| 6 | Re-keyed output from the aggregator for one **recipient** at a time. | 5 |
| 7 | Privacy review of the new fields and site keys, then rollout to sites. | 3, 5 |

Steps 2, 3 and 5 all change hash file format v2. Format v1 stays byte-identical (`docs/adr/0001-keep-hash-file-v1-byte-identical.md`). Format v2 is released only after step 5, so no site holds a v2 file without site keys.

Step 3 and step 5 change what linkja hashes. Before rollout, the network has the new fields and site keys reviewed for de-identification.

ADR 0001 says that sites on old and new versions must be able to join one project. Site keys change this for v1 sites. ADR 0002, at step 5, settles it.

## Cost per day

A network that plans to run linkja can estimate its cost per day as the sum of:

- One-time costs, spread over 3 years: the work for steps 1 to 6, the privacy review in step 7, and setup at each site.
- Yearly costs, divided by 365: aggregator machine and storage, and upkeep of the code (security updates, Java and OpenSSL updates). Yearly costs also include staff time at each site and at the aggregator for each run.

Each input is an estimate that a network replaces with its own figures.
