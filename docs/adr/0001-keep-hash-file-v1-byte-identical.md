# Keep the hash file format v1 byte-identical during the redesign

The new hash file module in linkja-core takes over the write and read code from linkja-hashing and linkja-matching, but its output stays byte-for-byte equal to today's version 1 files. Sites may already hold v1 files, and sites on old and new versions must be able to join one project. A golden-file test proves the bytes do not change. Known format problems (e.g. the header stores a site ID's character count where it should store its byte count, so non-ASCII IDs break) wait for a later v2.

## Considered options

- A new v2 that the reader accepts alongside v1: fixes the problems now, but every site must upgrade hashing before it sends v2 files.
- Free to break the format: simplest code, but every site in a project must run hashing again.
