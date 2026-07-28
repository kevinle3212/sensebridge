import type { APIRoute } from "astro";

/**
 * Emits `/robots.txt` at build time.
 *
 * This is a route rather than a static `public/robots.txt` because the
 * `Sitemap:` line has to carry an absolute URL, and that origin belongs to
 * whoever deployed the site — see `SITE_URL` in `astro.config.mjs`. As a
 * static file it silently baked one deployment's domain into every fork.
 */
export const GET: APIRoute = ({ site }) => {
  const sitemap = new URL("sitemap-index.xml", site);

  return new Response(`User-agent: *\nAllow: /\n\nSitemap: ${sitemap.href}\n`, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
};
