import type { Locale } from "../paraglide/runtime.js";

// Endonyms — each language's own name for itself, shown identically in the
// language switcher regardless of the page's current locale. UI metadata,
// not translatable copy, so it stays a plain constant rather than a Paraglide
// message.
export const localeNames: Record<Locale, string> = {
  en: "English",
  es: "Español",
  vi: "Tiếng Việt",
};
