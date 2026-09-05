#!/usr/bin/env node
// check-codegraph-perms.mjs — keep the CodeGraph index unreadable by other
// local users.
//
// `.codegraph/codegraph.db` holds the full text of every indexed source file.
// CodeGraph creates both the directory and the database with the process
// umask (`022` here), so they land world-readable at `755`/`644`.
//
// Three attempts were needed. The two that failed are recorded because each
// looks correct until you test it:
//
//  1. `chmod 600 .codegraph/codegraph.db` — does not hold. Every
//     `codegraph index` rewrites the database and the new file gets `644`.
//  2. `chmod 700 .codegraph` by hand — holds across `index` and `sync`
//     (neither recreates the directory) but not across a fresh index:
//     `codegraph init` after an `uninit`, or a clone that has never been
//     indexed, recreates the directory at `755`.
//
// Hence a check rather than a line in a document. Mode `0700` on the directory
// blocks traversal for every other local user regardless of the modes of the
// files inside it, which is why it also covers the WAL/SHM sidecars,
// `errors.log`, and any daemon socket — none of which a per-file chmod reached.
//
// SYMLINKS ARE REFUSED, NOT FOLLOWED. `statSync`/`chmodSync` resolve symlinks,
// so an earlier version of this script would happily `chmod 700` whatever
// `.codegraph` pointed at — verified by pointing it at a directory outside the
// repository and watching `--fix` lock that directory instead, reporting
// success. Since `npm run codegraph` runs `--fix` automatically after every
// index, a `.codegraph` symlink to a real working directory would silently
// make it owner-only. The directory is therefore opened with
// `O_NOFOLLOW | O_DIRECTORY` and every subsequent operation goes through that
// file descriptor, so the path is resolved exactly once and cannot be swapped
// between the check and the chmod.
//
// Two modes:
//   (default) verify — exit 1 if the index directory is not `0700`.
//   --fix          — set it to `0700`, then verify. Used by `npm run codegraph`
//                    so a fresh index self-heals instead of relying on memory.
//
// A missing `.codegraph/` is not a failure: the index is local-only,
// gitignored, and optional, so a clone that has never been indexed must not go
// red. Stdlib only, matching the other tools/ scripts.

import { closeSync, constants, fchmodSync, fstatSync, lstatSync, openSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** Directory holding the local CodeGraph index, resolved from this script. */
const INDEX_DIR = resolve(join(dirname(fileURLToPath(import.meta.url)), "..", ".codegraph"));

/** Octal mode the index directory must carry: owner-only, no group or other. */
const REQUIRED_MODE = 0o700;

/** Open flags that refuse a symlink and refuse anything that is not a directory. */
const SAFE_OPEN_FLAGS = constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_DIRECTORY;

/**
 * Classify the path for the error message only.
 *
 * This is deliberately *not* the security boundary — `O_NOFOLLOW` is. macOS
 * reports both a symlink and a regular file as `ENOTDIR` when `O_DIRECTORY` is
 * set, which would produce a misleading message on its own, so the kind is
 * resolved separately with `lstat`. A race here changes only the wording.
 *
 * @param {string} path Absolute path to classify.
 * @returns {"absent" | "symlink" | "not-a-directory" | "directory"}
 */
function classify(path) {
  try {
    const info = lstatSync(path);
    if (info.isSymbolicLink()) return "symlink";
    return info.isDirectory() ? "directory" : "not-a-directory";
  } catch {
    return "absent";
  }
}

/**
 * Verify — and optionally repair — the index directory's permissions.
 *
 * @param {boolean} fix Whether to chmod before verifying.
 * @returns {number} Process exit code: 0 on pass or when no index exists.
 */
function run(fix) {
  let fd;
  try {
    fd = openSync(INDEX_DIR, SAFE_OPEN_FLAGS);
  } catch (error) {
    if (error.code === "ENOENT") {
      console.log("check:codegraph — no .codegraph/ index present, nothing to check.");
      return 0;
    }

    const kind = classify(INDEX_DIR);
    if (kind === "symlink") {
      console.error(
        "check:codegraph — .codegraph/ is a symlink, which this check refuses to follow.\n" +
          "Following it would chmod 0700 whatever it points at, anywhere on disk, and " +
          "`npm run codegraph` applies that automatically after every index.\n" +
          "Fix: replace the symlink with a real directory (`rm .codegraph && codegraph init .`), " +
          "or set 0700 on the target yourself and keep the index out of this repository.",
      );
      return 1;
    }

    console.error(
      `check:codegraph — .codegraph/ could not be opened as a directory (${error.code}).\n` +
        (kind === "not-a-directory"
          ? "It exists but is not a directory. Remove it and re-run `codegraph init .`."
          : "Resolve the path, then re-run this check."),
    );
    return 1;
  }

  try {
    const before = fstatSync(fd).mode & 0o777;
    if (fix && before !== REQUIRED_MODE) fchmodSync(fd, REQUIRED_MODE);

    const after = fstatSync(fd).mode & 0o777;
    if (after === REQUIRED_MODE) {
      const repaired = fix && before !== REQUIRED_MODE;
      console.log(
        `check:codegraph — .codegraph/ is 0${after.toString(8)}` +
          (repaired ? ` (repaired from 0${before.toString(8)}).` : "."),
      );
      return 0;
    }

    console.error(
      `check:codegraph — .codegraph/ is 0${after.toString(8)}, expected 0700.\n` +
        "The index holds the full text of every source file in this repository " +
        "and is readable by any other local user at this mode. A fresh " +
        "`codegraph init` creates it world-readable; chmod on the database file " +
        "alone does not hold, because every index rewrites it.\n" +
        "Fix: npm run codegraph:perms",
    );
    return 1;
  } finally {
    closeSync(fd);
  }
}

/**
 * True when this file was executed directly rather than imported, so importing
 * it never chmods anything as a side effect.
 *
 * @returns {boolean}
 */
function invokedAsScript() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (invokedAsScript()) {
  process.exitCode = run(process.argv.includes("--fix"));
}

export { INDEX_DIR, REQUIRED_MODE, classify };
