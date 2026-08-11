import { m } from "../paraglide/messages.js";
import type { NoticeSection } from "./notice-section";

/**
 * Assembles the accessibility statement's 11 sections into the shape
 * `AccessibilityPage.astro` renders, from the flat
 * `accessibility_page_section_N_*` message keys. See `privacy-sections.ts`
 * for why this is fixed structure rather than a generic loop.
 */
export function getAccessibilitySections(): readonly NoticeSection[] {
  return [
    {
      heading: m.accessibility_page_section_1_heading(),
      body: [
        m.accessibility_page_section_1_body_1(),
        m.accessibility_page_section_1_body_2(),
        m.accessibility_page_section_1_body_3(),
      ],
    },
    {
      heading: m.accessibility_page_section_2_heading(),
      body: [m.accessibility_page_section_2_body_1()],
    },
    {
      heading: m.accessibility_page_section_3_heading(),
      body: [m.accessibility_page_section_3_body_1()],
      bullets: [
        m.accessibility_page_section_3_bullet_1(),
        m.accessibility_page_section_3_bullet_2(),
        m.accessibility_page_section_3_bullet_3(),
        m.accessibility_page_section_3_bullet_4(),
        m.accessibility_page_section_3_bullet_5(),
      ],
    },
    {
      heading: m.accessibility_page_section_4_heading(),
      body: [m.accessibility_page_section_4_body_1()],
      bullets: [
        m.accessibility_page_section_4_bullet_1(),
        m.accessibility_page_section_4_bullet_2(),
        m.accessibility_page_section_4_bullet_3(),
        m.accessibility_page_section_4_bullet_4(),
        m.accessibility_page_section_4_bullet_5(),
      ],
    },
    {
      heading: m.accessibility_page_section_5_heading(),
      body: [m.accessibility_page_section_5_body_1(), m.accessibility_page_section_5_body_2()],
    },
    {
      heading: m.accessibility_page_section_6_heading(),
      body: [m.accessibility_page_section_6_body_1()],
      bullets: [
        m.accessibility_page_section_6_bullet_1(),
        m.accessibility_page_section_6_bullet_2(),
        m.accessibility_page_section_6_bullet_3(),
        m.accessibility_page_section_6_bullet_4(),
      ],
    },
    {
      heading: m.accessibility_page_section_7_heading(),
      body: [],
      bullets: [
        m.accessibility_page_section_7_bullet_1(),
        m.accessibility_page_section_7_bullet_2(),
        m.accessibility_page_section_7_bullet_3(),
        m.accessibility_page_section_7_bullet_4(),
      ],
    },
    {
      heading: m.accessibility_page_section_8_heading(),
      body: [m.accessibility_page_section_8_body_1(), m.accessibility_page_section_8_body_2()],
    },
    {
      heading: m.accessibility_page_section_9_heading(),
      body: [
        m.accessibility_page_section_9_body_1(),
        m.accessibility_page_section_9_body_2(),
        m.accessibility_page_section_9_body_3(),
      ],
    },
    {
      heading: m.accessibility_page_section_10_heading(),
      body: [m.accessibility_page_section_10_body_1(), m.accessibility_page_section_10_body_2()],
    },
    {
      heading: m.accessibility_page_section_11_heading(),
      body: [m.accessibility_page_section_11_body_1()],
    },
  ];
}
