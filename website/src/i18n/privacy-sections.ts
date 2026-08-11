import { m } from "../paraglide/messages.js";
import type { NoticeSection } from "./notice-section";

/**
 * Assembles the privacy notice's 13 sections into the shape
 * `PrivacyPage.astro` renders, from the flat `privacy_page_section_N_*`
 * message keys. Fixed section/paragraph/bullet counts, not a generic loop:
 * the notice's structure (which sections have bullets, how many paragraphs
 * each has) is itself part of the reviewed legal content, so it is spelled
 * out here rather than inferred at runtime.
 */
export function getPrivacySections(): readonly NoticeSection[] {
  return [
    {
      heading: m.privacy_page_section_1_heading(),
      body: [m.privacy_page_section_1_body_1(), m.privacy_page_section_1_body_2()],
    },
    {
      heading: m.privacy_page_section_2_heading(),
      body: [m.privacy_page_section_2_body_1()],
      bullets: [
        m.privacy_page_section_2_bullet_1(),
        m.privacy_page_section_2_bullet_2(),
        m.privacy_page_section_2_bullet_3(),
      ],
    },
    {
      heading: m.privacy_page_section_3_heading(),
      body: [m.privacy_page_section_3_body_1(), m.privacy_page_section_3_body_2()],
    },
    {
      heading: m.privacy_page_section_4_heading(),
      body: [m.privacy_page_section_4_body_1()],
      bullets: [
        m.privacy_page_section_4_bullet_1(),
        m.privacy_page_section_4_bullet_2(),
        m.privacy_page_section_4_bullet_3(),
      ],
    },
    {
      heading: m.privacy_page_section_5_heading(),
      body: [m.privacy_page_section_5_body_1()],
      bullets: [
        m.privacy_page_section_5_bullet_1(),
        m.privacy_page_section_5_bullet_2(),
        m.privacy_page_section_5_bullet_3(),
      ],
    },
    {
      heading: m.privacy_page_section_6_heading(),
      body: [m.privacy_page_section_6_body_1()],
      bullets: [m.privacy_page_section_6_bullet_1(), m.privacy_page_section_6_bullet_2()],
    },
    {
      heading: m.privacy_page_section_7_heading(),
      body: [m.privacy_page_section_7_body_1(), m.privacy_page_section_7_body_2()],
    },
    {
      heading: m.privacy_page_section_8_heading(),
      body: [],
      bullets: [
        m.privacy_page_section_8_bullet_1(),
        m.privacy_page_section_8_bullet_2(),
        m.privacy_page_section_8_bullet_3(),
      ],
    },
    {
      heading: m.privacy_page_section_9_heading(),
      body: [
        m.privacy_page_section_9_body_1(),
        m.privacy_page_section_9_body_2(),
        m.privacy_page_section_9_body_3(),
      ],
    },
    { heading: m.privacy_page_section_10_heading(), body: [m.privacy_page_section_10_body_1()] },
    {
      heading: m.privacy_page_section_11_heading(),
      body: [m.privacy_page_section_11_body_1(), m.privacy_page_section_11_body_2()],
    },
    { heading: m.privacy_page_section_12_heading(), body: [m.privacy_page_section_12_body_1()] },
    { heading: m.privacy_page_section_13_heading(), body: [m.privacy_page_section_13_body_1()] },
  ];
}
