/**
 * Sets Paraglide's active locale for every static render from Astro's own
 * i18n routing (`context.currentLocale`), so every `m.*()` call during that
 * page's render — anywhere in the component tree — resolves to the same
 * locale Astro already picked for the route.
 *
 * Static rendering has no incoming request to read a locale from, so
 * Paraglide's `url` strategy alone cannot resolve it during `astro build`;
 * this is the setup Paraglide's Astro SSG guide recommends instead of its
 * `paraglideMiddleware()` (which de-localizes request URLs for SSR, not SSG).
 * In the browser, `m.*()` calls resolve locale via the `url` strategy
 * directly from the visited path, so no equivalent step is needed client-side.
 */
import { defineMiddleware } from "astro:middleware";
import { assertIsLocale, baseLocale, setLocale } from "./paraglide/runtime.js";

export const onRequest = defineMiddleware((context, next) => {
  // `setLocale()`'s return type covers async strategies generically, but the
  // "globalVariable" strategy this project uses resolves synchronously —
  // `void` marks that deliberately, per this repo's no-floating-promises gate.
  void setLocale(assertIsLocale(context.currentLocale ?? baseLocale));
  return next();
});
