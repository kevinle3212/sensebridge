/**
 * Emits schema.org JSON-LD describing the site itself.
 *
 * This is the site's only React component, and it is deliberately
 * **server-rendered with no `client:*` directive**: Astro renders it to static
 * HTML at build time, so it ships zero JavaScript to a visitor. That keeps the
 * site's zero-JS-by-default invariant intact while giving the React toolchain
 * (`react-doctor`) real `.tsx` to analyse.
 *
 * A `<script type="application/ld+json">` block is inert data, not executable
 * code — browsers parse it for search engines and never run it.
 *
 * **Honesty doctrine (`.agents/context/PRODUCT.md`).** Only `WebSite` and
 * `Organization` are described. `SoftwareApplication`, `offers`,
 * `downloadUrl`, and `aggregateRating` are deliberately absent: SenseBridge is
 * pre-launch, and emitting any of them would let a search engine advertise an
 * app that cannot be downloaded — exactly the "implies a download exists"
 * failure the site's copy rules forbid. Do not add them until the app ships.
 */

import type { Locale } from "../i18n";

/**
 * Maps this site's locale codes to the BCP-47 tags schema.org consumers expect.
 *
 * A `Map`, not a `Record`, throughout this file: indexing a plain object with
 * a variable is a generic object-injection sink, and `eslint-plugin-security`
 * is set to `error` for every rule in this repo. `Map.get()` also returns
 * `string | undefined`, which forces the fallback below to be explicit rather
 * than an unchecked index.
 */
const BCP47_BY_LOCALE = new Map<Locale, string>([
  ["en", "en-US"],
  ["es", "es-ES"],
  ["vi", "vi-VN"],
]);

/** BCP-47 tag used when a locale somehow has no mapping; matches `defaultLocale`. */
const FALLBACK_LANGUAGE = "en-US";

/**
 * Characters that are safe inside JSON but unsafe raw inside a `<script>`
 * element, mapped to the `\uXXXX` escape a JSON parser treats as identical.
 */
const SCRIPT_UNSAFE_ESCAPES = new Map<string, string>([
  ["\u003c", "\\u003c"],
  ["\u003e", "\\u003e"],
  ["&", "\\u0026"],
  ["\u2028", "\\u2028"],
  ["\u2029", "\\u2029"],
]);

/** Matches every key of {@link SCRIPT_UNSAFE_ESCAPES} in one pass. */
const SCRIPT_UNSAFE_PATTERN = /[\u003c\u003e&\u2028\u2029]/g;

/**
 * Escapes a JSON string so it cannot break out of its `<script>` element.
 *
 * Every value rendered here is a build-time constant (the i18n dictionaries
 * and `astro.config.mjs`), so none of it is attacker-controlled today. This
 * runs anyway as defence in depth: the cost is one pass over a short string,
 * and the failure it prevents — a future translator or config edit
 * introducing `</script>` — is silent HTML injection that no test would catch.
 *
 * `<` and `>` cover the closing-tag breakout. `&` prevents HTML-entity
 * ambiguity. U+2028 and U+2029 are valid JSON but illegal raw in a JavaScript
 * string literal, which breaks strict parsers.
 *
 * @param json - Serialized JSON to embed.
 * @returns The same JSON with those characters replaced by `\uXXXX` escapes,
 *   which are equivalent to a JSON parser and inert to an HTML parser.
 */
function escapeJsonForScript(json: string): string {
  return json.replace(
    SCRIPT_UNSAFE_PATTERN,
    (character) => SCRIPT_UNSAFE_ESCAPES.get(character) ?? character,
  );
}

/** Props for {@link StructuredData}. */
export interface StructuredDataProps {
  /** Absolute origin of the deployed site, e.g. `https://sensebridge.vercel.app`. */
  siteUrl: string;
  /** Absolute canonical URL of the page being rendered. */
  pageUrl: string;
  /** Site name, used as both `WebSite.name` and `Organization.name`. */
  name: string;
  /** Localized one-line description of the site. */
  description: string;
  /** Locale this page is rendered in; becomes `WebSite.inLanguage`. */
  locale: Locale;
  /** Canonical public source repository, used as `Organization.sameAs`. */
  repositoryUrl: string;
}

/**
 * Renders the JSON-LD `<script>` for the current page.
 *
 * Intended for `<head>`. Renders a single element and nothing visible, so it
 * has no accessibility surface of its own.
 *
 * The payload is passed as a **text child**, not via
 * `dangerouslySetInnerHTML`. Both were tried: React 19 renders text children
 * of `<script>` verbatim rather than HTML-escaping them, so the emitted JSON
 * parses either way — but the child form keeps the raw-HTML sink out of the
 * codebase entirely, and React Doctor's `Unescaped JSON in HTML or script
 * sink` security rule fires on the `dangerouslySetInnerHTML` form (correctly:
 * it cannot see that the value was escaped first). Verified against the built
 * `dist/index.html`, not assumed. Keep the child form.
 */
export default function StructuredData({
  siteUrl,
  pageUrl,
  name,
  description,
  locale,
  repositoryUrl,
}: StructuredDataProps) {
  const language = BCP47_BY_LOCALE.get(locale) ?? FALLBACK_LANGUAGE;

  const graph = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        "@id": `${siteUrl}/#website`,
        url: siteUrl,
        name,
        description,
        inLanguage: language,
        publisher: { "@id": `${siteUrl}/#organization` },
      },
      {
        "@type": "Organization",
        "@id": `${siteUrl}/#organization`,
        name,
        url: siteUrl,
        sameAs: [repositoryUrl],
      },
      {
        "@type": "WebPage",
        "@id": `${pageUrl}#webpage`,
        url: pageUrl,
        name,
        description,
        inLanguage: language,
        isPartOf: { "@id": `${siteUrl}/#website` },
      },
    ],
  };

  return <script type="application/ld+json">{escapeJsonForScript(JSON.stringify(graph))}</script>;
}
