# Who holds which key, salt and library

This page says which party holds each secret and each file of a linkja project. It shows what the code does today. It does not give a target design.

The source is the `develop` branch of linkja-crypto, linkja-core, linkja-hashing, linkja-matching and linkja-salt-engine, as read on November 17, 2026. Each cell gives the code that shows it. A path starts with the repository name.

The citations were checked at these `origin/develop` commits:

- linkja-crypto: `6f39670`
- linkja-core: `aa5d146`
- linkja-hashing: `4592f57`
- linkja-matching: `a391ddf`
- linkja-salt-engine: `b35a1d0`

The crypto library is linkjacrypto. It is written in C. The glossary calls it the crypto library, and this page uses the same name.

## The parties

- **Coordinator**: runs linkja-salt-engine to make the salt files. The ticket calls this party the key master.
- **Site**: runs linkja-hashing on its input extract.
- **Aggregator**: runs linkja-matching on the hash files of all sites.

Each cell says one of three things:

- **Holds**: a program of that party reads or writes the item.
- **Must not hold**: no program of that party reads the item, and the item would let that party learn something. The cell says what.
- **Not needed**: no program of that party reads the item.

## The table

| Item | Coordinator | Site | Aggregator | Code |
|---|---|---|---|---|
| Crypto library (linkjacrypto) | Holds a build. The salt engine calls only `generateToken` and `getLibrarySignature`, which every build has. So the public build is enough. See open question 4. | Holds the secret build. Hashing calls `createSecureHash`. The public build throws an error on that call. | Holds a build. Matching calls `revertSecureHash`, which every build has, so the public build is enough. See open question 1. | `linkja-crypto/CMakeLists.txt:7`<br>`linkja-crypto/src/CMakeLists.txt:17`<br>`linkja-crypto/src/linkja-crypto.c:705`<br>`linkja-crypto/src/linkja-crypto.c:785`<br>`linkja-crypto/src/linkja-crypto.c:826`<br>`linkja-crypto/src/linkja-crypto.c:832`<br>`linkja-crypto/src/linkja-crypto.c:1087`<br>`linkja-salt-engine/src/main/java/org/linkja/saltengine/SaltEngine.java:170`<br>`linkja-salt-engine/src/main/java/org/linkja/saltengine/Runner.java:61`<br>`linkja-hashing/src/main/java/org/linkja/hashing/Engine.java:580`<br>`linkja-matching/src/main/java/org/linkja/matching/Decrypt/DecryptFiles.java:70` |
| Project salt | Holds. The salt engine makes one project salt and writes it into the salt file of every site. To add sites, it reads the project salt back from an old salt file. | Holds. Hashing reads it from the salt file and adds it to every hash rule except PIDHASH. | Must not hold. With the project salt and a secret build, the aggregator could hash guessed patient details and compare them with the hash values it unlocks. | `linkja-salt-engine/src/main/java/org/linkja/saltengine/SaltEngine.java:101`<br>`linkja-salt-engine/src/main/java/org/linkja/saltengine/SaltEngine.java:114`<br>`linkja-core/src/main/java/org/linkja/core/SaltFile.java:115`<br>`linkja-hashing/src/main/java/org/linkja/hashing/Runner.java:274`<br>`linkja-hashing/src/main/java/org/linkja/hashing/steps/HashingStep.java:206` |
| Private salt | Holds the private salt of every site. The salt engine makes a new one for each site. See open question 2. | Holds its own. Hashing adds it to PIDHASH only. | Must not hold. PIDHASH also uses the site ID and the days from the birth date to the private date. With the private salt, private date and a secret build, the aggregator could test a guessed patient ID together with a guessed birth date. | `linkja-salt-engine/src/main/java/org/linkja/saltengine/SaltEngine.java:103`<br>`linkja-core/src/main/java/org/linkja/core/SaltFile.java:113`<br>`linkja-hashing/src/main/java/org/linkja/hashing/Runner.java:273`<br>`linkja-hashing/src/main/java/org/linkja/hashing/steps/HashingStep.java:177`<br>`linkja-hashing/src/main/java/org/linkja/hashing/steps/HashingStep.java:180`<br>`linkja-hashing/src/main/java/org/linkja/hashing/steps/HashingStep.java:182` |
| Aggregator RSA private key | Must not hold. The coordinator holds the project salt. If it also holds the secret build, this key and a hash file let it test guessed patient details against the unlocked values. | Must not hold. A site holds the project salt and the secret build. With this key and the hash file of another site, it could unlock that file and test guessed patient details against it. | Holds. Matching reads it to unlock the session key and the library signature of each hash file. | `linkja-matching/src/main/java/org/linkja/matching/Decrypt/DecryptFilesRunner.java:78`<br>`linkja-core/src/main/java/org/linkja/core/EncryptedHashFileMetadata.java:172`<br>`linkja-core/src/main/java/org/linkja/core/EncryptedHashFileMetadata.java:173`<br>`linkja-core/src/main/java/org/linkja/core/EncryptedHashFileMetadata.java:174` |
| Aggregator RSA public key | Not needed. The salt engine reads no RSA key. | Holds. The run config names it as `aggregator.public_key`. Hashing locks the session key and the library signature with it. | Not needed. Matching reads only the private key. See open question 3. | `linkja-hashing/src/main/java/org/linkja/hashing/Runner.java:133`<br>`linkja-core/src/main/java/org/linkja/core/EncryptedHashFileMetadata.java:91`<br>`linkja-core/src/main/java/org/linkja/core/EncryptedHashFileMetadata.java:94` |
| Hash file | Not needed. No program of the coordinator reads hash files. | Holds its own. Hashing writes it as `hashes_<site ID>_<project ID>_<time>.enc`. | Holds the hash file of every site. Matching reads each file in `data/input` that has the given prefix and suffix. | `linkja-hashing/src/main/java/org/linkja/hashing/Engine.java:227`<br>`linkja-hashing/src/main/java/org/linkja/hashing/Engine.java:618`<br>`linkja-matching/src/main/java/org/linkja/matching/Decrypt/DecryptFilesRunner.java:69`<br>`linkja-matching/src/main/java/org/linkja/matching/Decrypt/DecryptFiles.java:25` |
| Crosswalk | Must not hold. With it, the coordinator would see the patient IDs of that site. | Holds. Hashing writes it as `DONOTSEND_crosswalk_<site ID>_<project ID>_<time>.csv`. Each row pairs a patient ID with its PIDHASH value in the unlocked form. | Must not hold. Its PIDHASH values are the same values that matching unlocks. With it, the aggregator could put the patient ID of the site on each row it unlocks. | `linkja-hashing/src/main/java/org/linkja/hashing/Engine.java:229`<br>`linkja-hashing/src/main/java/org/linkja/hashing/Engine.java:615`<br>`linkja-hashing/src/main/java/org/linkja/hashing/Engine.java:616`<br>`linkja-matching/src/main/java/org/linkja/matching/Decrypt/DecryptFiles.java:70` |
| Salt file encryption key | Not needed. No such key exists. The salt engine writes the salt file as plain text. | Not needed. Hashing reads the salt file as plain text. | Not needed. Matching reads no salt file. | `linkja-core/src/main/java/org/linkja/core/SaltFile.java:84`<br>`linkja-core/src/main/java/org/linkja/core/SaltFile.java:103` |

The "not needed" cells also rest on searches that find nothing. Run each command below in the folder that holds the five repositories. Each prints no line:

```
grep -rniE 'salt|crosswalk' linkja-matching/src/main
grep -rniE 'rsa|publicKey|privateKey|\.pem|\.key' linkja-salt-engine/src/main
```

## Notes on the table

- The salt file holds both salts of a site in plain text (`linkja-core/src/main/java/org/linkja/core/SaltFile.java:103`). So it must reach the site by a secure route. The help text of the salt engine calls it an "encrypted salt file" (`linkja-salt-engine/src/main/java/org/linkja/saltengine/Runner.java:94`). The code writes no encrypted file.
- CMake writes the library secret into `src/include/linkja_secret.h` when it configures the library, before the compile (`linkja-crypto/src/CMakeLists.txt:17`). Git ignores that file (`linkja-crypto/.gitignore:8`).
- Matching unlocks each hash value with the session key alone (`linkja-crypto/src/linkja-crypto.c:832`). Hashing added the library secret into each hash (`linkja-crypto/src/linkja-crypto.c:572`). Nobody can read the secret back from the hash. So the aggregator needs the secret build and the project salt to test a guess. That is why the project salt row is "must not hold" for the aggregator.

## Open questions

The code does not answer these. This page lists them and does not settle them.

1. **May the aggregator hold the crypto library?** Unpublished design notes say the aggregator must not hold the crypto library. Today matching calls `Library.revertSecureHash` (`linkja-matching/src/main/java/org/linkja/matching/Decrypt/DecryptFiles.java:70`). So it must load linkjacrypto (`linkja-crypto/src/main/java/Library.java:5`). That function is outside the `INCLUDE_SECRETS` block (`linkja-crypto/src/linkja-crypto.c:832`), so the public build is enough for it. The code does not say if the aggregator must not hold the secret build.
2. **How long does the coordinator keep the salts?** The salt engine writes the salt file of every site into one folder (`linkja-salt-engine/src/main/java/org/linkja/saltengine/SaltEngine.java:129`). No code removes them. So the coordinator holds the project salt and every private salt at the same time. If the party that compiles the secret build is the coordinator, it also holds the secret build.
3. **Who makes the aggregator key pair?** No program in the five repositories makes it. Only tests make one (`linkja-hashing/src/test/java/org/linkja/hashing/EngineRunTest.java:497`). The code does not say how the public key gets to the sites.
4. **Who compiles the secret build?** The `INCLUDE_SECRETS` option is on by default (`linkja-crypto/CMakeLists.txt:7`). The glossary says every site must use the same secret build. No code says which party compiles it or how it gets to the sites.
