/**
 * Minimal on-device key-value store backed by IndexedDB.
 *
 * Replaces `localStorage` for state that has no need to be read synchronously
 * before first paint (see `monitoring-consent.ts` and `debug.ts`). One object
 * store covers both call sites, so this stays a few functions rather than a
 * wrapper library — see TODO.md's "Add localStorage migration to databases"
 * entry for why `sb-theme` (Header.astro) stays on `localStorage` instead:
 * IndexedDB has no synchronous main-thread read, and that key gates the
 * no-flash script in `public/theme-init.js`, which must resolve before first
 * paint.
 */
const DB_NAME = "sensebridge";
const DB_VERSION = 1;
const STORE_NAME = "kv";

/** Opens (and lazily creates) the single key-value object store. */
function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(STORE_NAME);
    };
    request.onsuccess = () => {
      resolve(request.result);
    };
    request.onerror = () => {
      reject(new Error(request.error?.message ?? "IndexedDB open failed"));
    };
  });
}

/**
 * Reads a value, returning `undefined` on any failure — an unsupported
 * browser, blocked storage, or a missing key. Mirrors how every call site
 * this replaces already treated an unreadable `localStorage` as "unset",
 * which is the safe direction to fail in.
 */
export async function idbGet(key: string): Promise<string | undefined> {
  try {
    const db = await openDb();
    return await new Promise<string | undefined>((resolve, reject) => {
      const request = db.transaction(STORE_NAME, "readonly").objectStore(STORE_NAME).get(key);
      request.onsuccess = () => {
        resolve(request.result as string | undefined);
      };
      request.onerror = () => {
        reject(new Error(request.error?.message ?? "IndexedDB read failed"));
      };
    });
  } catch {
    return undefined;
  }
}

/**
 * Writes a value. Failures are swallowed, not thrown: the choice still
 * applies for the current page, it just will not survive a reload — the
 * browser's decision, not ours, and the same posture the `localStorage`
 * writes this replaces already had.
 */
export async function idbSet(key: string, value: string): Promise<void> {
  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      tx.objectStore(STORE_NAME).put(value, key);
      tx.oncomplete = () => {
        resolve();
      };
      tx.onerror = () => {
        reject(new Error(tx.error?.message ?? "IndexedDB write failed"));
      };
    });
  } catch {
    // Storage refused (private mode, quota, unsupported browser). Fail open.
  }
}
