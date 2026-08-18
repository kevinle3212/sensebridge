import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SenseBridge admin",
  description: "Single-owner project telemetry.",
  // Belt and braces alongside the Basic-auth gate: even if this ever ends up
  // reachable, nothing here should be indexed.
  robots: { index: false, follow: false },
};

/**
 * Root layout.
 *
 * `lang` is hardcoded to English: this dashboard has one user and is not part
 * of the product's en/es/vi surface.
 */
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
