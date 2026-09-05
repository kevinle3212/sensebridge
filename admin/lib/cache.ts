/**
 * Per-process TTL cache for upstream responses.
 *
 * Sentry rate-limits per organisation and WakaTime per API key, and this
 * dashboard is refreshed by hand — without this, leaving a tab open and
 * hitting reload a few times is enough to start collecting 429s from an
 * account the rest of the project also uses.
 *
 * In-memory on purpose: the cache exists to smooth a human pressing refresh,
 * not to survive a restart, and a real cache store would be a second service
 * to run for a single-user dashboard.
 *
 * ponytail: per-process, so N server processes mean N× the upstream calls.
 * Swap in a shared store only if this ever runs multi-instance.
 */
interface Entry<T> {
  value: T;
  expiresAt: number;
}

const store = new Map<string, Entry<unknown>>();

/**
 * Returns the cached value for `key`, or computes and caches a fresh one.
 *
 * A rejected `compute` is not cached: a transient upstream failure should not
 * pin an error in place for the whole TTL.
 *
 * @param key Cache key, unique per upstream resource.
 * @param ttlSeconds How long a successful result stays fresh.
 * @param compute Produces the value on a miss.
 */
export async function cached<T>(
  key: string,
  ttlSeconds: number,
  compute: () => Promise<T>,
): Promise<T> {
  const now = Date.now();
  const hit = store.get(key);
  if (hit && hit.expiresAt > now) {
    return hit.value as T;
  }
  const value = await compute();
  store.set(key, { value, expiresAt: now + ttlSeconds * 1000 });
  return value;
}

/** A tile's payload: either data, or a reason it is missing. Never a throw. */
export type TileResult<T> = { ok: true; data: T } | { ok: false; reason: string };

/**
 * Runs `compute`, converting any failure into an `unavailable` tile.
 *
 * Every tile fails soft by contract: one unreachable upstream renders as
 * "unavailable" in its own card and leaves the rest of the page working.
 *
 * The caught error's message is deliberately not forwarded — an upstream
 * client can include a request URL, and these URLs carry tokens in query
 * strings often enough that echoing one into the browser is not worth the
 * debugging convenience. The real error goes to the server log.
 */
export async function tile<T>(label: string, compute: () => Promise<T>): Promise<TileResult<T>> {
  try {
    return { ok: true, data: await compute() };
  } catch (error) {
    console.error(`[admin] ${label} tile failed:`, error);
    return { ok: false, reason: `${label} is unavailable. See the server log.` };
  }
}
