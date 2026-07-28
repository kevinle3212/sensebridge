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
  }
}
