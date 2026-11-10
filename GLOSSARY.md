# linkja

linkja lets several hospital sites find the patients they have in common without sharing names or other direct identifiers. Each site scrambles its patient details with shared secrets, and one aggregator compares the scrambled results.

## People and places

**Project**:
One linkage effort that a group of sites joins. All sites in a project use the same project salt.
_Avoid_: study, job

**Site**:
One hospital or health system that holds patient records and runs hashing on them.
_Avoid_: hospital (in code), partner, source

**Coordinator**:
The person who sets up a project and makes its salt files.
_Avoid_: admin, project manager

**Aggregator**:
The party that receives every site's hash file and runs matching. It holds the aggregator key pair.
_Avoid_: hub, central site, matcher

**Aggregator key**:
The RSA key pair of the aggregator. Sites use its public key to lock the session key, and only the aggregator can unlock it.
_Avoid_: project key, site key

## Secrets

**Salt**:
A random secret text added to patient details before they are hashed, so that outsiders cannot guess the input.
_Avoid_: token, secret, key

**Project salt**:
The salt shared by every site in one project.
_Avoid_: shared token

**Private salt**:
The salt that belongs to one site only.
_Avoid_: site token, site-specific secret

**Salt file**:
A plain text file that gives one site its site ID, site name, project name, project salt and private salt. It is not encrypted, so it must reach the site by a secure route.
_Avoid_: token file, key file, encrypted salt file

**Private date**:
A secret date that each site chooses and keeps. The number of days between it and a patient's birth date goes into that patient's PIDHASH.
_Avoid_: offset date, site date

**Library secret**:
A secret compiled into the secret build of the crypto library. It is added to each hash value before the hash value is written to the hash file.
_Avoid_: salt, project secret

**Library signature**:
A fingerprint of the library secret. It is written into the header so the aggregator can tell which secret build made a hash file.
_Avoid_: library hash, version

**Public build / Secret build**:
The two builds of the crypto library. The secret build holds a library secret and is used by sites for hashing. The public build has none and is safe to share.
_Avoid_: test build, private build

## Hashing and files

**Hash rule**:
One fixed mix of patient details that is hashed together, e.g. first name + last name + birth date.
_Avoid_: token type, composite, combination

**Hash value**:
The scrambled result of one hash rule for one patient row. Each row has 11 hash value slots, one per hash rule. A slot is empty when the row lacks a detail its rule needs, e.g. an SSN.
_Avoid_: token, hash column, hash

**PIDHASH**:
The hash value made from the site's own patient ID, the site ID, the private date and the private salt. It is the first of the 11 hash values.
_Avoid_: patient token

**Derived row**:
An extra patient row that hashing makes from one input row, e.g. for a second last name, so the same person can match under each form of the name.
_Avoid_: duplicate row, variant

**Crosswalk**:
The file each site keeps that pairs its own patient IDs with their PIDHASH values. The site needs it to apply the matching result to its own records, and it never leaves the site.
_Avoid_: mapping file, lookup

**Hash file**:
The file a site sends to the aggregator. It holds a header and the locked hash values of every patient row.
_Avoid_: output file, encrypted file, token file

**Header**:
The first part of a hash file. It names the site and project, gives the number of hash values per row and the row count, and ends with the envelope.
_Avoid_: metadata block

**Envelope**:
The last part of the header. It holds the session key and the library signature, each locked with the aggregator key.
_Avoid_: key block, wrapper

**Session key**:
A random key made for one hash file. It locks the hash values in that file.
_Avoid_: AES key, file key

## Matching

**Exclusion**:
A patient row that matching sets aside because the hash values its match rules need are empty.
_Avoid_: dropped row, skipped row

**Match rule**:
A test that says two patient rows are the same person when a given set of their hash values are equal.
_Avoid_: rule (alone), match pass

**Global ID**:
The ID that matching gives to every group of rows that belong to the same person, across all sites.
_Avoid_: universal ID, UPI, link ID
