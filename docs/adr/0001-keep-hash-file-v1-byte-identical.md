# Keep the hash file format v1 byte-identical during the redesign

The new hash file module in linkja-core takes over the write and read code from linkja-hashing and linkja-matching. Its output stays byte-for-byte equal to today's version 1 files.

Sites may already hold v1 files. Sites on old and new versions must be able to join one project.

A test must prove the bytes do not change. Three inputs differ from run to run or from build to build:

- The session key is random.
- The RSA padding (OAEP) is randomized.
- Each secret build has its own library secret, and the public build cannot make hash values at all.

So the test fixes the session key, replaces the RSA step with a predictable one, and fixes the library secret (a test secret header, or a stand-in for the secure hash through the crypto seam). Then it compares bytes.

Known v1 format problems wait for a later v2:

- The header stores the character count of the site ID and the project ID. It should store their byte count, so non-ASCII IDs break the file.
- The row-count position is computed from the same character counts.
- Text is encoded with the platform default charset, so non-ASCII IDs give different bytes on different platforms.

## Considered options

- A new v2 that the reader accepts alongside v1: fixes the problems now, but every site must upgrade hashing before it sends v2 files.
- Free to break the format: simplest code, but every site in a project must run hashing again.
