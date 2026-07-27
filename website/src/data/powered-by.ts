/**
 * The stack named in the footer's "Powered by" row.
 *
 * Marks are official brand glyphs from simple-icons (CC0-1.0 icon data; each
 * glyph remains its owner's trademark), rendered monochrome in
 * `currentColor`. Monochrome is not merely a palette preference: GSAP
 * publishes its logo in a cream tuned for dark backgrounds and would vanish on
 * the light theme, while Vercel and Three.js are monochrome by design and
 * publish no colour vector at all. A single `currentColor` treatment is the
 * only one that renders every brand correctly in both themes.
 *
 * `mark` is null wherever a brand has no glyph that survives 14px, and those
 * entries render as plain text:
 *   - Lenis publishes no compact glyph at all, only a 1360x336 wordmark.
 *   - GSAP's GreenSock swirl carries 8.6KB of path data and still reads as a
 *     smudge that small — a bad trade twice over, since this row ships on all
 *     195 pages.
 *   - Three.js's mark reads as a smudge at the same size.
 * Checked by rendering them, not by assumption. Re-check before adding one
 * back.
 */
export interface PoweredByEntry {
  /** Display name, shown as text beside the mark. */
  name: string;
  /** Homepage, recorded for provenance. Not rendered as a link: the row is a
   *  credit, not a promotion, and six outbound links would add six focus stops
   *  to the footer for no reader benefit. */
  href: string | null;
  /** Official glyph, or null when the brand publishes none legible at 14px. */
  mark: { viewBox: string; d: string } | null;
}

/** Ordered as the stack is layered: framework, host, then the runtime libraries. */
export const POWERED_BY: readonly PoweredByEntry[] = [
  {
    name: "Astro",
    href: "https://astro.build",
    mark: {
      viewBox: "0 0 24 24",
      d: "M8.358 20.162c-1.186-1.07-1.532-3.316-1.038-4.944.856 1.026 2.043 1.352 3.272 1.535 1.897.283 3.76.177 5.522-.678.202-.098.388-.229.608-.36.166.473.209.95.151 1.437-.14 1.185-.738 2.1-1.688 2.794-.38.277-.782.525-1.175.787-1.205.804-1.531 1.747-1.078 3.119l.044.148a3.158 3.158 0 0 1-1.407-1.188 3.31 3.31 0 0 1-.544-1.815c-.004-.32-.004-.642-.048-.958-.106-.769-.472-1.113-1.161-1.133-.707-.02-1.267.411-1.415 1.09-.012.053-.028.104-.045.165h.002zm-5.961-4.445s3.24-1.575 6.49-1.575l2.451-7.565c.092-.366.36-.614.662-.614.302 0 .57.248.662.614l2.45 7.565c3.85 0 6.491 1.575 6.491 1.575L16.088.727C15.93.285 15.663 0 15.303 0H8.697c-.36 0-.615.285-.784.727l-5.516 14.99z",
    },
  },
  {
    name: "Vercel",
    href: "https://vercel.com",
    mark: { viewBox: "0 0 24 24", d: "m12 1.608 12 20.784H0Z" },
  },
  { name: "GSAP", href: "https://gsap.com", mark: null },
  { name: "Three.js", href: "https://threejs.org", mark: null },
  { name: "Lenis", href: null, mark: null },
  {
    name: "Sass",
    href: "https://sass-lang.com",
    mark: {
      viewBox: "0 0 24 24",
      d: "M12 0c6.627 0 12 5.373 12 12s-5.373 12-12 12S0 18.627 0 12 5.373 0 12 0zM9.615 15.998c.175.645.156 1.248-.024 1.792l-.065.18c-.024.061-.052.12-.078.176-.14.29-.326.56-.555.81-.698.759-1.672 1.047-2.09.805-.45-.262-.226-1.335.584-2.19.871-.918 2.12-1.509 2.12-1.509v-.003l.108-.061zm9.911-10.861c-.542-2.133-4.077-2.834-7.422-1.645-1.989.707-4.144 1.818-5.693 3.267C4.568 8.48 4.275 9.98 4.396 10.607c.427 2.211 3.457 3.657 4.703 4.73v.006c-.367.18-3.056 1.529-3.686 2.925-.675 1.47.105 2.521.615 2.655 1.575.436 3.195-.36 4.065-1.649.84-1.261.766-2.881.404-3.676.496-.135 1.08-.195 1.83-.104 2.101.24 2.521 1.56 2.43 2.1-.09.539-.523.854-.674.944-.15.091-.195.12-.181.181.015.09.091.09.21.075.165-.03 1.096-.45 1.141-1.471.045-1.29-1.186-2.729-3.375-2.7-.9.016-1.471.091-1.875.256-.03-.045-.061-.075-.105-.105-1.35-1.455-3.855-2.475-3.75-4.41.03-.705.285-2.564 4.8-4.814 3.705-1.846 6.661-1.335 7.171-.21.733 1.604-1.576 4.59-5.431 5.024-1.47.165-2.235-.404-2.431-.615-.209-.225-.239-.24-.314-.194-.12.06-.045.255 0 .375.12.3.585.825 1.396 1.095.704.225 2.43.359 4.5-.45 2.324-.899 4.139-3.405 3.614-5.505l.073.067z",
    },
  },
] as const;
