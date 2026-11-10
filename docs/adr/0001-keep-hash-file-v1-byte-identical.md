# Keep the hash file format v1 byte-identical during the redesign

The new hash file module in linkja-core takes over the write and read code from linkja-hashing and linkja-matching. Its output stays byte-for-byte equal to today's version 1 files.

Sites may already hold v1 files. Sites on old and new versions must be able to join one project.

A test must prove the bytes do not change. The session key is random and the RSA padding (OAEP) is randomized, so two runs never give the same file. The test fixes the session key and replaces the RSA step with a predictable one, then compares bytes.

Known v1 format problems wait for a later v2:

- The header stores the character count of the site ID and the project ID where it should store their byte count, so non-ASCII IDs break the file.
- The row-count position is computed from the same character counts.
- Text is encoded with the platform default charset, so non-ASCII IDs give different bytes on different platforms.

## Considered options

- A new v2 that the reader accepts alongside v1: fixes the problems now, but every site must upgrade hashing before it sends v2 files.
- Free to break the format: simplest code, but every site in a project must run hashing again.
