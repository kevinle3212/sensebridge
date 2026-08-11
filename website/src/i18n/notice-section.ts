/**
 * One headed block of a published notice — the privacy notice at `/privacy` or
 * the accessibility statement at `/accessibility`, which are the same shape.
 * `bullets` is optional because some sections are prose only; a list is used
 * where the content is genuinely a set of parallel items, not to break up a
 * paragraph — a screen-reader user hears "list, 6 items" before every one.
 *
 * Paraglide's message catalogs are flat key-value maps with no native array
 * support, so `PrivacyPage.astro`/`AccessibilityPage.astro` still render a
 * `NoticeSection[]` exactly as before; `privacy-sections.ts` and
 * `accessibility-sections.ts` are what now assemble that shape from the
 * flat, per-section message keys (`privacy_page_section_1_heading`, etc.).
 */
export interface NoticeSection {
  heading: string;
  body: readonly string[];
  bullets?: readonly string[];
}
