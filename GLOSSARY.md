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
The person who sets up a project and makes its salts.
_Avoid_: admin, project manager

**Aggregator**:
The party that receives every site's hash file and runs matching.
_Avoid_: hub, central site, matcher

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
The file that gives one site its project salt and private salt, locked with that site's public key.
_Avoid_: token file, key file

**Library secret**:
A secret compiled into the secret build of the crypto library and added to every hash it makes.
_Avoid_: salt, project secret

**Public build / Secret build**:
The two builds of the crypto library. The secret build holds a library secret and is used by sites for hashing. The public build has none and is safe to share.
_Avoid_: test build, private build

## Hashing and files

**Hash rule**:
One fixed mix of patient details that is hashed together, e.g. first name + last name + birth date.
_Avoid_: token type, composite, combination

**Hash value**:
The scrambled result of one hash rule for one patient. Each patient row has 11 hash values, one per hash rule.
_Avoid_: token, hash column, hash

**PIDHASH**:
The hash value made from the site's own patient ID. It is the first of the 11 hash values.
_Avoid_: patient token

**Hash file**:
The encrypted file a site sends to the aggregator. It holds a header and the hash values of every patient row.
_Avoid_: output file, encrypted file, token file

**Header**:
The first part of a hash file. It names the site and project, gives the row count, and holds the locked session key.
_Avoid_: metadata block, envelope

**Session key**:
A random key made for one hash file. It locks the hash values in that file.
_Avoid_: AES key, file key

## Matching

**Match rule**:
A test that says two patient rows are the same person when a given set of their hash values are equal.
_Avoid_: rule (alone), match pass

**Global ID**:
The ID that matching gives to every group of rows that belong to the same person, across all sites.
_Avoid_: universal ID, UPI, link ID
