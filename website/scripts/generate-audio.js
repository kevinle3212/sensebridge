// Generates the pre-rendered "natural voice" narration for the site's main
// content via the ElevenLabs TTS API, and writes it as a static asset
// (public/audio/main.mp3). This is a build-time, developer-run step — the
// ElevenLabs API key is only ever read here, on a developer machine, and is
// never bundled into the client, never held by the deployed server (there is
// no server), and never touches CI. That keeps the deployed site's attack
// surface identical to before this feature existed: a static file server
// with no secrets and no live third-party calls per page view.
//
// Usage:
//   npm run build            # required first — this script reads dist/index.html
//   npm run generate:audio   # requires ELEVENLABS_API_KEY, calls the API
//   npm run check:audio      # no network, no key — verifies public/audio/main.mp3
//                             # still matches the current page text (CI-safe;
//                             # run `npm run build` first, same as generate:audio)
import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEBSITE_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const INDEX_HTML_PATH = path.join(WEBSITE_ROOT, "dist", "index.html");
const AUDIO_DIR = path.join(WEBSITE_ROOT, "public", "audio");
const AUDIO_PATH = path.join(AUDIO_DIR, "main.mp3");
const MANIFEST_PATH = path.join(AUDIO_DIR, "manifest.json");

const DEFAULT_VOICE_ID = "21m00Tcm4TlvDq8ikWAM"; // ElevenLabs' standard "Rachel" voice
const DEFAULT_MODEL_ID = "eleven_turbo_v2_5";
const MAX_CHARACTERS = 5000; // guards against runaway cost if the built page grows unexpectedly

// Mirrors the extraction in src/scripts/read-aloud.ts (`main.textContent`
// collapsed) so the natural-voice narration always says exactly what the
// free browser-voice option says — single source of truth is the built
// dist/index.html itself (run `npm run build` first), nothing is duplicated
// by hand.
async function extractMainText() {
  const html = await readFile(INDEX_HTML_PATH, "utf8");
  const mainMatch = /<main[^>]*id="main"[^>]*>([\s\S]*?)<\/main>/.exec(html);
  if (!mainMatch) {
    throw new Error(
      `Could not find <main id="main"> in ${INDEX_HTML_PATH}. Run \`npm run build\` first.`,
    );
  }
  return mainMatch[1]
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** @param {string} text */
function hashText(text) {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

/**
 * @returns {Promise<{textHash: string, voiceId: string, modelId: string, generatedAt: string} | null>}
 */
async function readManifest() {
  try {
    const raw = await readFile(MANIFEST_PATH, "utf8");
    // JSON.parse's return type is inherently `any` in TypeScript; the JSDoc
    // cast documents the real shape for readers, but doesn't change the
    // static type of the returned expression.
    // eslint-disable-next-line @typescript-eslint/no-unsafe-return
    return /** @type {{textHash: string, voiceId: string, modelId: string, generatedAt: string}} */ (
      JSON.parse(raw)
    );
  } catch (error) {
    if (error.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

async function checkFreshness() {
  const manifest = await readManifest();
  if (!manifest) {
    console.warn(
      "No natural-voice audio generated yet — run `npm run generate:audio` " +
        "locally with ELEVENLABS_API_KEY set. Skipping freshness check.",
    );
    return;
  }

  const currentHash = hashText(await extractMainText());
  if (currentHash !== manifest.textHash) {
    console.error(
      "website/public/audio/main.mp3 is stale: the built page's main content " +
        "changed since it was generated. Run `npm run build && npm run " +
        "generate:audio` and commit the updated public/audio/main.mp3 + " +
        "public/audio/manifest.json.",
    );
    process.exitCode = 1;
    return;
  }

  console.warn("website/public/audio/main.mp3 matches the current page text.");
}

async function generate() {
  const apiKey = process.env.ELEVENLABS_API_KEY;
  if (!apiKey) {
    console.error(
      "ELEVENLABS_API_KEY is not set. Copy website/.env.example to " +
        "website/.env, fill in your key, and re-run `npm run generate:audio`.",
    );
    process.exitCode = 1;
    return;
  }

  const voiceId = process.env.ELEVENLABS_VOICE_ID ?? DEFAULT_VOICE_ID;
  const modelId = process.env.ELEVENLABS_MODEL_ID ?? DEFAULT_MODEL_ID;

  const text = await extractMainText();
  if (!text) {
    throw new Error("Extracted main content is empty — nothing to narrate.");
  }
  if (text.length > MAX_CHARACTERS) {
    throw new Error(
      `Extracted main content is ${text.length} characters, over the ${MAX_CHARACTERS} ` +
        "safety cap. Trim the page's <main> content or raise MAX_CHARACTERS deliberately.",
    );
  }

  console.warn(`Requesting narration for ${text.length} characters from ElevenLabs…`);

  const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
    method: "POST",
    headers: {
      "xi-api-key": apiKey,
      "content-type": "application/json",
      accept: "audio/mpeg",
    },
    body: JSON.stringify({
      text,
      model_id: modelId,
      voice_settings: { stability: 0.5, similarity_boost: 0.75 },
    }),
    signal: AbortSignal.timeout(30_000),
  });

  if (!response.ok) {
    // Safe to log: this is ElevenLabs' own error body, never our key.
    const body = await response.text();
    throw new Error(`ElevenLabs request failed (${response.status}): ${body}`);
  }

  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.startsWith("audio/")) {
    throw new Error(`Expected an audio response, got content-type "${contentType}".`);
  }

  const audioBuffer = Buffer.from(await response.arrayBuffer());

  await mkdir(AUDIO_DIR, { recursive: true });
  await writeFile(AUDIO_PATH, audioBuffer);
  await writeFile(
    MANIFEST_PATH,
    `${JSON.stringify(
      {
        textHash: hashText(text),
        voiceId,
        modelId,
        generatedAt: new Date().toISOString(),
      },
      null,
      2,
    )}\n`,
  );

  console.warn(`Wrote ${path.relative(WEBSITE_ROOT, AUDIO_PATH)} (${audioBuffer.length} bytes).`);
}

const isCheck = process.argv.includes("--check");
try {
  await (isCheck ? checkFreshness() : generate());
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
