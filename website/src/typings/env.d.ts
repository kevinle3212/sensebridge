/// <reference types="astro/client" />

// Env vars read via `process.env` (astro.config.mjs, scripts/*.js) rather
// than `import.meta.env` — see .env.example for what each one does.
declare namespace NodeJS {
  interface ProcessEnv {
    SITE_URL?: string;
    ELEVENLABS_API_KEY?: string;
    ELEVENLABS_VOICE_ID?: string;
    ELEVENLABS_MODEL_ID?: string;
    RAILWAY_TOKEN?: string;
    VERCEL_TOKEN?: string;
    PUBLIC_SENTRY_DSN?: string;
    SENTRY_AUTH_TOKEN?: string;
    SENTRY_ORG?: string;
    SENTRY_PROJECT?: string;
  }
}

// Env vars read via `import.meta.env` from code that ships to the browser —
// today only sentry.client.config.js. Interface merging onto the declaration in
// astro/client, so these are typed rather than `any`; without this, every read
// trips @typescript-eslint/no-unsafe-assignment.
//
// Only `PUBLIC_`-prefixed names may appear here. Astro strips everything else
// from the client bundle at build time, so declaring an unprefixed variable
// would type a value that is always `undefined` in the browser — and inviting a
// secret to be read from client code is the mistake this comment exists to
// prevent. SENTRY_AUTH_TOKEN above is deliberately absent for that reason.
interface ImportMetaEnv {
  readonly PUBLIC_SENTRY_DSN?: string;
  readonly PUBLIC_SENTRY_ENVIRONMENT?: string;
}
