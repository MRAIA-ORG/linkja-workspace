# Keep the hash file format v1 byte-identical during the redesign

The header and envelope code is already in linkja-core. The new hash file module there takes over the row writer from linkja-hashing and the row reader from linkja-matching. Its output stays byte-for-byte equal to today's version 1 files.

Sites may already hold v1 files. Sites on old and new versions must be able to join one project.

A test must prove the bytes do not change. Several inputs change from run to run or from build to build: the session key, the RSA padding, the library secret and the row order. Ticket MRAIA-ORG/linkja-workspace#14 holds the test design.

Known v1 format problems wait for a later v2:

- The header stores the character count of the site ID and the project ID. It should store their byte count. Non-ASCII IDs therefore break the file.
- The row-count position is computed from the same character counts.
- Text is encoded with the platform default charset, so non-ASCII IDs give different bytes on different platforms.

## Considered options

- A v2 that the reader accepts with v1: fixes the problems now, but sites must upgrade hashing to send v2.
- Free to break the format: simplest code, but every site in a project must run hashing again.
