/**
 * Next config for the owner-only admin dashboard.
 *
 * Deliberately minimal. This app is not the product and not the marketing
 * site; it has one user, no public surface, and no build-time integrations.
 *
 * @type {import("next").NextConfig}
 */
const nextConfig = {
  // Every route reads live data behind an auth gate, so there is nothing to
  // prerender and a static export would be actively wrong.
  output: "standalone",
  // Pinned: the repo root also has a package-lock.json, and without this
  // Next infers the workspace root as the parent and warns on every build.
  turbopack: { root: import.meta.dirname },
  reactStrictMode: true,
  // Security headers are set here rather than in a host config so they apply
  // identically to `next dev`, `next start`, and any deployment. This app
  // loads no third-party script, image, font, or frame — the policy says so.
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            key: "content-security-policy",
            value: [
              "default-src 'self'",
              "script-src 'self'",
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data:",
              "font-src 'self'",
              "connect-src 'self'",
              "frame-ancestors 'none'",
              "base-uri 'none'",
              "form-action 'none'",
            ].join("; "),
          },
          { key: "referrer-policy", value: "no-referrer" },
          { key: "x-content-type-options", value: "nosniff" },
          { key: "x-frame-options", value: "DENY" },
          { key: "permissions-policy", value: "camera=(), microphone=(), geolocation=()" },
        ],
      },
    ];
  },
};

export default nextConfig;
