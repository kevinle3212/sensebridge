#!/usr/bin/env node
/**
 * Render the Graphify knowledge graph as an animated SVG for the README.
 *
 * GitHub renders Markdown with JavaScript disabled, so an interactive graph
 * cannot work there. A declarative animated SVG can: CSS keyframes and SMIL
 * both run inside an `<img>`-referenced SVG, which is why this emits one
 * self-contained file rather than a canvas widget.
 *
 * Input:  graphify-out/graph.json (generated, git-ignored — run `graphify .`)
 * Output: docs/assets/graph.svg   (committed, since the input never is)
 *
 * Deterministic: a seeded PRNG drives the layout, so an unchanged graph
 * produces a byte-identical SVG and the README asset does not churn.
 *
 * Usage: node tools/graph-visual.mjs [--graph <path>] [--out <path>]
 *        node tools/graph-visual.mjs --verify   # lint the committed SVGs (CI)
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/** Layout, sampling, and canvas constants — the only tuning surface. */
const CONFIG = {
  /** Nodes kept in the visual, highest-degree first. */
  nodeCount: 340,
  /** Hub nodes that get a visible text label. */
  labelCount: 16,
  /** Force-simulation passes. Deterministic, so this is a quality/time dial. */
  iterations: 420,
  /** Edge buckets; each becomes one `<path>` with its own flow phase. */
  edgeBuckets: 8,
  width: 1200,
  height: 660,
  seed: 0x5e115e,
};

/**
 * Directories whose contents are vendored or mirrored agent tooling rather
 * than SenseBridge itself. The same skill scripts are copied verbatim into
 * five per-harness config directories, so leaving them in would make the
 * picture a portrait of the tooling mirror, not of the project.
 */
const EXCLUDED_PATH = new RegExp(
  "^(" +
    [
      "\\.claude",
      "\\.cursor",
      "\\.gemini",
      "\\.agents",
      "\\.continue",
      "\\.codex",
      "\\.copilot",
      "\\.openclaw",
      "\\.windsurf",
      "\\.impeccable",
      "_bmad",
      "\\.github/skills",
    ].join("|") +
    ")/",
);

/**
 * Subsystem clusters, in render order. `match` runs against a node's
 * `source_file`; the first hit wins, so order is significant.
 */
const CLUSTERS = [
  {
    id: "app",
    name: "app · Swift/SwiftUI",
    color: "#f0733a",
    match: (f) => f.startsWith("app/"),
  },
  {
    id: "web",
    name: "website · Astro",
    color: "#a970ff",
    match: (f) => f.startsWith("website/"),
  },
  {
    id: "docs",
    name: "docs",
    color: "#3fa9e0",
    match: (f) => f.startsWith("docs/"),
  },
  {
    id: "build",
    name: "tools · scripts · CI",
    color: "#e0a03f",
    match: (f) =>
      f.startsWith("tools/") ||
      f.startsWith("scripts/") ||
      f.startsWith("docker/") ||
      f.startsWith(".github/"),
  },
  {
    id: "gov",
    name: "audits · legal · models · security",
    color: "#e0607a",
    match: (f) =>
      f.startsWith("audits/") ||
      f.startsWith("legal/") ||
      f.startsWith("models/") ||
      f.startsWith("security/"),
  },
  {
    id: "root",
    name: "root orientation docs",
    color: "#3fbf8f",
    match: () => true,
  },
];

/** Deterministic PRNG (mulberry32) so the layout never drifts between runs. */
function createRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Reads the graph, dropping vendored paths and any node with no source file. */
function loadGraph(graphPath) {
  const raw = JSON.parse(readFileSync(graphPath, "utf8"));
  const kept = new Map();
  for (const node of raw.nodes ?? []) {
    const file = node.source_file ?? "";
    if (!file || EXCLUDED_PATH.test(file)) continue;
    kept.set(node.id, node);
  }
  const links = (raw.links ?? []).filter(
    (link) => kept.has(link.source) && kept.has(link.target) && link.source !== link.target,
  );
  return { nodes: kept, links, commit: raw.built_at_commit ?? "" };
}

/** Keeps the highest-degree induced subgraph, which is the readable core. */
function sampleSubgraph({ nodes, links }) {
  const degree = new Map();
  for (const link of links) {
    degree.set(link.source, (degree.get(link.source) ?? 0) + 1);
    degree.set(link.target, (degree.get(link.target) ?? 0) + 1);
  }
  const ranked = [...degree.entries()]
    .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1))
    .slice(0, CONFIG.nodeCount)
    .map(([id]) => id);

  const keep = new Set(ranked);
  const kept = ranked.map((id) => {
    const node = nodes.get(id);
    const file = node.source_file;
    const cluster = CLUSTERS.findIndex((c) => c.match(file));
    return { id, label: node.label ?? id, file, degree: degree.get(id), cluster };
  });

  // Deduplicate parallel edges: the visual reads relationship presence, not
  // multiplicity, and collapsing them roughly halves the emitted path data.
  const seen = new Set();
  const edges = [];
  for (const link of links) {
    if (!keep.has(link.source) || !keep.has(link.target)) continue;
    const key =
      link.source < link.target
        ? `${link.source}\u0000${link.target}`
        : `${link.target}\u0000${link.source}`;
    if (seen.has(key)) continue;
    seen.add(key);
    edges.push({ source: link.source, target: link.target });
  }
  return { nodes: kept, edges };
}

/**
 * Force-directed layout: edge springs pull related nodes together, an
 * all-pairs repulsion keeps them legible, and a per-cluster anchor keeps each
 * subsystem in its own region so the picture stays readable at README width.
 */
function layout(nodes, edges) {
  const random = createRandom(CONFIG.seed);
  const index = new Map(nodes.map((node, i) => [node.id, i]));
  const { width, height } = CONFIG;
  const centerX = width / 2;
  const centerY = height / 2 - 10;

  const usedClusters = [...new Set(nodes.map((n) => n.cluster))].sort((a, b) => a - b);
  const anchors = new Map();
  usedClusters.forEach((cluster, i) => {
    const angle = (i / usedClusters.length) * Math.PI * 2 - Math.PI / 2;
    anchors.set(cluster, {
      x: centerX + Math.cos(angle) * width * 0.235,
      y: centerY + Math.sin(angle) * height * 0.235,
    });
  });

  const points = nodes.map((node) => {
    const anchor = anchors.get(node.cluster);
    return {
      x: anchor.x + (random() - 0.5) * 160,
      y: anchor.y + (random() - 0.5) * 160,
      vx: 0,
      vy: 0,
    };
  });

  const springs = edges.map((edge) => [index.get(edge.source), index.get(edge.target)]);

  for (let step = 0; step < CONFIG.iterations; step += 1) {
    const cooling = 1 - step / CONFIG.iterations;

    for (let i = 0; i < points.length; i += 1) {
      for (let j = i + 1; j < points.length; j += 1) {
        let dx = points[i].x - points[j].x;
        let dy = points[i].y - points[j].y;
        let distanceSquared = dx * dx + dy * dy;
        if (distanceSquared < 0.01) {
          dx = (random() - 0.5) * 0.1;
          dy = (random() - 0.5) * 0.1;
          distanceSquared = 0.01;
        }
        const force = 900 / distanceSquared;
        const distance = Math.sqrt(distanceSquared);
        const fx = (dx / distance) * force;
        const fy = (dy / distance) * force;
        points[i].vx += fx;
        points[i].vy += fy;
        points[j].vx -= fx;
        points[j].vy -= fy;
      }
    }

    for (const [a, b] of springs) {
      const dx = points[b].x - points[a].x;
      const dy = points[b].y - points[a].y;
      const distance = Math.hypot(dx, dy) || 0.01;
      const force = (distance - 46) * 0.012;
      const fx = (dx / distance) * force;
      const fy = (dy / distance) * force;
      points[a].vx += fx;
      points[a].vy += fy;
      points[b].vx -= fx;
      points[b].vy -= fy;
    }

    for (let i = 0; i < points.length; i += 1) {
      const anchor = anchors.get(nodes[i].cluster);
      points[i].vx += (anchor.x - points[i].x) * 0.014;
      points[i].vy += (anchor.y - points[i].y) * 0.014;
      points[i].x += points[i].vx * cooling * 0.55;
      points[i].y += points[i].vy * cooling * 0.55;
      points[i].vx *= 0.82;
      points[i].vy *= 0.82;
    }
  }

  // Fit to the canvas. The axes are scaled independently so the graph fills
  // the README's wide aspect ratio, but the ratio between them is clamped so
  // clusters never stretch into visibly distorted smears.
  const margin = 54;
  const xs = points.map((p) => p.x);
  const ys = points.map((p) => p.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const usableWidth = width - margin * 2;
  const usableHeight = height - margin * 2 - 30;
  let scaleX = usableWidth / Math.max(maxX - minX, 1);
  let scaleY = usableHeight / Math.max(maxY - minY, 1);
  const maxAnisotropy = 1.22;
  if (scaleX / scaleY > maxAnisotropy) scaleX = scaleY * maxAnisotropy;
  if (scaleY / scaleX > maxAnisotropy) scaleY = scaleX * maxAnisotropy;
  const offsetX = (width - (maxX - minX) * scaleX) / 2 - minX * scaleX;
  const offsetY = (height - 30 - (maxY - minY) * scaleY) / 2 - minY * scaleY;

  return points.map((point) => ({
    x: round(point.x * scaleX + offsetX),
    y: round(point.y * scaleY + offsetY),
  }));
}

/** One decimal is below the visible threshold and keeps the file small. */
function round(value) {
  return Math.round(value * 10) / 10;
}

/** Escapes text for use in SVG character data and attribute values. */
function escapeXml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/**
 * Places hub labels in whitespace rather than on top of the graph.
 *
 * The densest cluster is exactly where the highest-degree nodes live, so
 * naively drawing a label beside each hub stacks them into an unreadable pile.
 * Each hub instead gets a ring of candidate offsets scored by how many nodes
 * it covers and how far it sits from the graph's centre; a candidate that
 * would overlap an already-placed label is rejected outright, and a hub with
 * no clean placement is silently skipped in favour of the next one down.
 *
 * @param {Array<{node: object, point: {x: number, y: number}}>} hubs Candidates, highest degree first.
 * @param {Array<{x: number, y: number}>} positions Every laid-out node, for overlap tests.
 * @returns {{labels: string, labelled: number}} SVG markup and the count actually drawn.
 */
function placeLabels(hubs, positions) {
  const centroidX = positions.reduce((sum, p) => sum + p.x, 0) / positions.length;
  const centroidY = positions.reduce((sum, p) => sum + p.y, 0) / positions.length;
  const charWidth = 6.55;
  const lineHeight = 14;
  const placed = [];
  const markup = [];

  for (const { node, point } of hubs) {
    if (placed.length >= CONFIG.labelCount) break;

    const text = node.label.length > 24 ? `${node.label.slice(0, 23)}…` : node.label;
    const textWidth = text.length * charWidth;
    const outwardX = point.x - centroidX;
    const outwardY = point.y - centroidY;
    const outwardLength = Math.hypot(outwardX, outwardY) || 1;

    let best = null;
    for (let a = 0; a < 12; a += 1) {
      const angle = (a / 12) * Math.PI * 2;
      const dirX = Math.cos(angle);
      const dirY = Math.sin(angle);
      for (const distance of [16, 27, 40, 56, 74, 94]) {
        const anchorX = point.x + dirX * distance;
        const anchorY = point.y + dirY * distance + 4;
        const anchor = dirX > 0.34 ? "start" : dirX < -0.34 ? "end" : "middle";
        const left =
          anchor === "start"
            ? anchorX
            : anchor === "end"
              ? anchorX - textWidth
              : anchorX - textWidth / 2;
        const box = {
          left: left - 3,
          right: left + textWidth + 3,
          top: anchorY - lineHeight + 2,
          bottom: anchorY + 4,
        };
        if (box.left < 6 || box.right > CONFIG.width - 6) continue;
        if (box.top < 6 || box.bottom > CONFIG.height - 34) continue;
        if (placed.some((other) => overlaps(box, other))) continue;

        let covered = 0;
        for (const other of positions) {
          if (
            other.x > box.left - 5 &&
            other.x < box.right + 5 &&
            other.y > box.top - 5 &&
            other.y < box.bottom + 5
          ) {
            covered += 1;
          }
        }
        // Hard reject rather than soft-penalise: a label sitting on even a
        // few nodes is unreadable, and walking further out with a leader line
        // is always the better trade.
        if (covered > 2) continue;
        const outwardness = (dirX * outwardX + dirY * outwardY) / outwardLength;
        const cost = covered * 8 + distance * 0.06 - outwardness * 9;
        if (!best || cost < best.cost) {
          best = { cost, box, anchorX, anchorY, anchor, distance };
        }
      }
    }
    if (!best) continue;

    placed.push(best.box);
    const color = CLUSTERS[node.cluster].color;
    const delay = (2.1 + placed.length * 0.07).toFixed(2);
    if (best.distance > 30) {
      markup.push(
        `<line class="ll" x1="${round(point.x)}" y1="${round(point.y)}" ` +
          `x2="${round(best.anchorX)}" y2="${round(best.anchorY - 4)}" stroke="${color}" ` +
          `style="animation-delay:${delay}s"/>`,
      );
    }
    markup.push(
      `<text class="l" x="${round(best.anchorX)}" y="${round(best.anchorY)}" ` +
        `text-anchor="${best.anchor}" fill="${color}" ` +
        `style="animation-delay:${delay}s">${escapeXml(text)}</text>`,
    );
  }

  return { labels: markup.join(""), labelled: placed.length };
}

/** Axis-aligned box intersection test used for label collision rejection. */
function overlaps(a, b) {
  return !(a.right < b.left || a.left > b.right || a.bottom < b.top || a.top > b.bottom);
}

/**
 * Assembles the SVG document.
 *
 * @param {boolean} animated When false, emits the reduced-motion twin: same
 *   layout and colours, no keyframes, no travelling sparks. Chrome does not
 *   propagate `prefers-reduced-motion` into an `<img>`-referenced SVG, so the
 *   in-document media query alone cannot honour the preference on GitHub —
 *   the README selects between the two files with `<picture media="...">`,
 *   which *is* evaluated against the outer document.
 */
function renderSvg({ nodes, edges, positions, commit, animated = true }) {
  const { width, height } = CONFIG;
  const index = new Map(nodes.map((node, i) => [node.id, i]));
  const maxDegree = Math.max(...nodes.map((node) => node.degree));

  // Edges are grouped into a few multi-subpath `<path>` elements rather than
  // one element each: it cuts the file size by an order of magnitude and gives
  // each bucket its own flow phase, so the signals do not pulse in lockstep.
  const buckets = Array.from({ length: CONFIG.edgeBuckets }, () => []);
  edges.forEach((edge, i) => {
    const a = positions[index.get(edge.source)];
    const b = positions[index.get(edge.target)];
    // A slight arc reads as a fibre rather than a wireframe strut.
    const midX = round((a.x + b.x) / 2 + (b.y - a.y) * 0.075);
    const midY = round((a.y + b.y) / 2 - (b.x - a.x) * 0.075);
    buckets[i % CONFIG.edgeBuckets].push(`M${a.x} ${a.y}Q${midX} ${midY} ${b.x} ${b.y}`);
  });

  const structure = buckets.map((paths) => `<path class="w" d="${paths.join("")}"/>`).join("");
  const flow = animated
    ? buckets
        .map(
          (paths, i) =>
            `<path class="f" style="animation-delay:-${(i * 0.9).toFixed(1)}s" d="${paths.join("")}"/>`,
        )
        .join("")
    : "";

  const circles = nodes
    .map((node, i) => {
      const point = positions[i];
      const radius = round(2.2 + Math.sqrt(node.degree / maxDegree) * 7.4);
      const cluster = CLUSTERS[node.cluster];
      if (!animated) {
        return `<circle cx="${point.x}" cy="${point.y}" r="${radius}" fill="${cluster.color}"/>`;
      }
      const delay = ((i % 40) * 0.055).toFixed(2);
      const period = (3.4 + (i % 7) * 0.45).toFixed(2);
      return (
        `<circle cx="${point.x}" cy="${point.y}" r="${radius}" fill="${cluster.color}" ` +
        `style="animation-delay:${delay}s,${delay}s;animation-duration:.9s,${period}s"/>`
      );
    })
    .join("");

  const hubs = nodes
    .map((node, i) => ({ node, point: positions[i] }))
    .sort((a, b) => b.node.degree - a.node.degree);

  const { labels, labelled } = placeLabels(hubs, positions);

  // A handful of SMIL-driven dots travelling real edges. This is the strongest
  // "the graph is alive" cue and costs a dozen elements, not hundreds.
  const sparks = !animated
    ? ""
    : hubs
        .slice(0, 10)
        .map(({ node }, i) => {
          const edge = edges.find((e) => e.source === node.id || e.target === node.id);
          if (!edge) return "";
          const a = positions[index.get(edge.source)];
          const b = positions[index.get(edge.target)];
          const color = CLUSTERS[node.cluster].color;
          return (
            `<circle class="s" r="2.6" fill="${color}">` +
            `<animateMotion dur="${(2.6 + i * 0.37).toFixed(2)}s" begin="${(i * 0.6).toFixed(2)}s" ` +
            `repeatCount="indefinite" path="M${a.x} ${a.y}L${b.x} ${b.y}"/></circle>`
          );
        })
        .join("");

  const usedClusters = [...new Set(nodes.map((node) => node.cluster))].sort((a, b) => a - b);
  let legendX = 24;
  const legend = usedClusters
    .map((clusterIndex) => {
      const cluster = CLUSTERS[clusterIndex];
      const x = legendX;
      legendX += cluster.name.length * 6.6 + 34;
      return (
        `<circle cx="${x}" cy="${height - 16}" r="4.5" fill="${cluster.color}"/>` +
        `<text class="g" x="${x + 10}" y="${height - 12}" fill="${cluster.color}">${escapeXml(cluster.name)}</text>`
      );
    })
    .join("");

  const description =
    `${nodes.length} of the most connected symbols in the SenseBridge repository, ` +
    `laid out as a force-directed graph and joined by ${edges.length} extracted ` +
    "relationships — imports, calls, definitions, and references. Nodes are " +
    `coloured by subsystem: ${usedClusters.map((c) => CLUSTERS[c].name).join(", ")}. ` +
    `The ${labelled} most connected are named. ` +
    (animated
      ? "Pulses travel the edges to show how the subsystems connect. "
      : "This is the still version, shown when the reader prefers reduced motion. ") +
    "Generated by tools/graph-visual.mjs from the Graphify knowledge graph" +
    (commit ? ` at commit ${commit.slice(0, 7)}` : "") +
    ".";

  const motionStyles = `
.f{fill:none;stroke:#8fa4c0;stroke-opacity:.55;stroke-width:1.1;stroke-dasharray:3 15;animation:flow 2.4s linear infinite}
circle{animation:wake .9s ease-out both,breathe 4s ease-in-out infinite}
.s{animation:none;opacity:.9}
.l{animation:fade .8s ease-out both}
.ll{animation:fade .8s ease-out both}
@keyframes flow{to{stroke-dashoffset:-18}}
@keyframes wake{from{opacity:0;transform:scale(0)}to{opacity:1;transform:scale(1)}}
@keyframes breathe{0%,100%{opacity:.72}50%{opacity:1}}
@keyframes fade{from{opacity:0}to{opacity:1}}
@keyframes sway{0%,100%{transform:translate(0,0) scale(1)}50%{transform:translate(0,-6px) scale(1.008)}}
#brain{transform-origin:${width / 2}px ${height / 2}px;animation:sway 16s ease-in-out infinite}
@media (prefers-reduced-motion:reduce){
*{animation:none!important}
.f{display:none}
.s{display:none}
}`;

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="img" aria-labelledby="t d">
<title id="t">SenseBridge knowledge graph</title>
<desc id="d">${escapeXml(description)}</desc>
<style>
.w{fill:none;stroke:#7f8ca0;stroke-opacity:.28;stroke-width:.9}
.l{font:600 12px ui-sans-serif,-apple-system,"Segoe UI",Roboto,sans-serif}
.ll{stroke-width:.8;stroke-opacity:.5}
.g{font:500 11px ui-sans-serif,-apple-system,"Segoe UI",Roboto,sans-serif;opacity:.85}${animated ? motionStyles : ""}
</style>
<g id="brain">
<g>${structure}</g>
<g>${flow}</g>
<g>${circles}</g>
<g>${sparks}</g>
<g>${labels}</g>
</g>
${legend}
</svg>
`;
}

function main() {
  const args = process.argv.slice(2);
  const readFlag = (name, fallback) => {
    const i = args.indexOf(name);
    return i === -1 ? fallback : args[i + 1];
  };
  const graphPath = resolve(REPO_ROOT, readFlag("--graph", "graphify-out/graph.json"));
  const outPath = resolve(REPO_ROOT, readFlag("--out", "docs/assets/graph.svg"));
  const staticPath = outPath.replace(/\.svg$/, "-static.svg");

  // Verification reads the committed files only — no graph.json, no rebuild —
  // so it runs on a clean CI checkout where graphify-out/ does not exist.
  if (args.includes("--verify")) {
    verify(outPath, staticPath);
    return;
  }

  let graph;
  try {
    graph = loadGraph(graphPath);
  } catch (error) {
    if (error.code === "ENOENT") {
      console.error(
        `No graph at ${graphPath}. Build it first: graphify . (see README, "Knowledge Graph").`,
      );
      process.exit(1);
    }
    throw error;
  }

  const { nodes, edges } = sampleSubgraph(graph);
  if (nodes.length === 0) {
    console.error("Graph contains no renderable nodes after filtering.");
    process.exit(1);
  }
  const positions = layout(nodes, edges);
  const animatedSvg = renderSvg({ nodes, edges, positions, commit: graph.commit });
  const staticSvg = renderSvg({
    nodes,
    edges,
    positions,
    commit: graph.commit,
    animated: false,
  });
  assertRenderable(animatedSvg, { animated: true });
  assertRenderable(staticSvg, { animated: false });

  writeFileSync(outPath, animatedSvg);
  writeFileSync(staticPath, staticSvg);

  const kb = (svg) => (Buffer.byteLength(svg) / 1024).toFixed(1);
  console.log(
    `${nodes.length} nodes, ${edges.length} edges\n` +
      `  ${outPath} — ${kb(animatedSvg)} kB (animated)\n` +
      `  ${staticPath} — ${kb(staticSvg)} kB (reduced-motion twin)`,
  );
}

/**
 * The invariants that make this asset safe to embed in a README: an accessible
 * name and description, a motion state matching the variant, and a size that
 * will not dominate a repository clone. Returns one string per violation.
 */
function renderProblems(svg, { animated }) {
  const problems = [];
  if (!svg.includes('<title id="t">')) problems.push("missing <title>");
  if (!svg.includes('<desc id="d">')) problems.push("missing <desc>");
  if (!svg.includes('role="img"')) problems.push("missing role=img");
  if (animated && !svg.includes("prefers-reduced-motion")) {
    problems.push("animated variant has no reduced-motion fallback");
  }
  if (!animated && svg.includes("@keyframes")) {
    problems.push("static variant still declares keyframes");
  }
  if (!animated && svg.includes("<animateMotion")) {
    problems.push("static variant still declares SMIL motion");
  }
  const kb = Buffer.byteLength(svg) / 1024;
  if (kb > 220) problems.push(`too large for a README asset (${kb.toFixed(1)} kB)`);
  return problems;
}

/** Write-path guard: refuse to emit an SVG that violates any invariant. */
function assertRenderable(svg, { animated }) {
  const problems = renderProblems(svg, { animated });
  if (problems.length > 0) {
    console.error(`Refusing to write ${animated ? "animated" : "static"} SVG:`);
    for (const problem of problems) console.error(`  - ${problem}`);
    process.exit(1);
  }
}

/**
 * Structural damage a committed file can suffer that the write path cannot:
 * truncation, a hand edit that unbalances a group, an unescaped entity.
 *
 * Deliberately not a full XML parse. These are the failures that actually
 * befall a generated artifact in git, and none of them can false-positive on
 * valid generator output — which matters more than completeness for a gate
 * that blocks merges.
 */
function structureProblems(svg) {
  const count = (pattern) => (svg.match(pattern) ?? []).length;
  const problems = [];
  if (!svg.startsWith("<svg ")) problems.push("does not begin with the <svg> root");
  if (!svg.trimEnd().endsWith("</svg>")) problems.push("truncated: no closing </svg>");
  if (count(/<g[\s>]/g) !== count(/<\/g>/g)) problems.push("unbalanced <g> groups");
  if (count(/<style[\s>]/g) !== count(/<\/style>/g)) problems.push("unbalanced <style>");
  if (count(/&(?!(?:amp|lt|gt|quot|apos|#\d+);)/g) > 0) {
    problems.push("unescaped & — not well-formed XML");
  }
  if (!/<title id="t">[^<]+<\/title>/.test(svg)) problems.push("<title> is empty");
  if (!/<desc id="d">[^<]+<\/desc>/.test(svg)) problems.push("<desc> is empty");
  return problems;
}

/**
 * Lints the committed SVGs without rebuilding them. This is the CI gate.
 *
 * `assertRenderable` only runs when this script writes, so nothing re-checks
 * the bytes once they are in git — a hand edit, a bad merge, or a half-written
 * file would ship silently. CI cannot regenerate and diff instead: the source
 * commit is baked into the image (see `renderSvg`), so a fresh build at a
 * different HEAD is legitimately different bytes. Linting the committed
 * artifact is the only check that can run on a clean checkout without
 * installing graphify or producing false failures.
 */
function verify(outPath, staticPath) {
  const problems = [];
  const loaded = [];
  for (const [path, animated] of [
    [outPath, true],
    [staticPath, false],
  ]) {
    let svg;
    try {
      svg = readFileSync(path, "utf8");
    } catch (error) {
      problems.push(
        error.code === "ENOENT"
          ? `${path}: missing — regenerate with \`npm run graph\``
          : `${path}: ${error.message}`,
      );
      continue;
    }
    loaded.push(svg);
    for (const problem of [...structureProblems(svg), ...renderProblems(svg, { animated })]) {
      problems.push(`${path}: ${problem}`);
    }
  }

  // Both files come out of one layout pass, so any divergence means only one
  // of the pair was regenerated — the reduced-motion twin would then stand in
  // for a picture of a different graph. Compared on the facets the two variants
  // are supposed to share; the animated file legitimately carries extra
  // `class="s"` pulse circles and a different closing sentence in <desc>.
  if (loaded.length === 2) {
    const signature = (svg) =>
      [
        svg.match(/viewBox="[^"]*"/)?.[0],
        svg.match(/<desc id="d">(\d+) of the/)?.[1],
        svg.match(/joined by (\d+) extracted/)?.[1],
        svg.match(/at commit ([0-9a-f]+)/)?.[1],
        (svg.match(/<circle(?![^>]*class="s")/g) ?? []).length,
      ].join("|");
    if (signature(loaded[0]) !== signature(loaded[1])) {
      problems.push(
        "animated and static variants render different graphs " +
          `(${signature(loaded[0])} vs ${signature(loaded[1])}) — regenerate both with \`npm run graph\``,
      );
    }
  }

  if (problems.length > 0) {
    console.error("Knowledge graph visual is not shippable:");
    for (const problem of problems) console.error(`  - ${problem}`);
    process.exit(1);
  }
  console.log(`${outPath} + ${staticPath} — every render invariant holds.`);
}

main();
