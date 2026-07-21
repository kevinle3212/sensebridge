import { en } from "./en";
import { es } from "./es";
import { vi } from "./vi";
import type { Locale, Translations } from "./types";

export type { Locale, ThemeMode, Translations } from "./types";

export const defaultLocale: Locale = "en";

export const translations: Record<Locale, Translations> = { en, es, vi };

// Endonyms — each language's own name for itself, shown identically in the
// language switcher regardless of the page's current locale.
export const localeNames: Record<Locale, string> = {
  en: "English",
  es: "Español",
  vi: "Tiếng Việt",
};

function isLocale(value: string | undefined): value is Locale {
  return value === "en" || value === "es" || value === "vi";
}

// t()/useTranslations(): resolves the dictionary for a given locale — pass
// `Astro.currentLocale` in components, or `document.documentElement.lang`
// in client scripts — falling back to the default locale for anything else.
export function useTranslations(locale: string | undefined): Translations {
  // `locale` is narrowed to `Locale` by `isLocale`; `defaultLocale` is a
  // fixed constant — neither is attacker-controlled.
  // eslint-disable-next-line security/detect-object-injection
  return isLocale(locale) ? translations[locale] : translations[defaultLocale];
}
