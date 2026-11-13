/**
 * Generates `lib/shared/icons/lucide_icons.dart` from the exact
 * `lucide-react` package that the Ennvo web app uses.
 *
 * The web app imports ~145 icons from `lucide-react`. The native port keeps
 * the original SVG markup, so the Flutter build and the web build draw
 * identical glyphs — the same path data, the same 24x24 viewBox, the same
 * round caps and joins and the same default stroke width of 2.
 *
 * The icons are rendered with `flutter_svg`, which supports every SVG
 * command the set uses, including elliptical arcs.
 */
const fs = require('fs');
const path = require('path');

const ENNVO = 'C:/Users/erfan/3D Objects/Ennvo';
const LUCIDE_ICONS = path.join(ENNVO, 'node_modules/lucide-react/dist/esm/icons');
const OUT =
  'C:/Users/erfan/3D Objects/Ennvo native androide/lib/shared/icons/lucide_icons.dart';

// ---------------------------------------------------------------------
// 1. Collect the icon names the Ennvo web app actually imports.
// ---------------------------------------------------------------------
const srcRoot = path.join(ENNVO, 'src');
const used = new Set();

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (/\.(tsx?|jsx?)$/.test(entry.name)) {
      const code = fs.readFileSync(full, 'utf8');
      const re = /import\s*\{([^}]+)\}\s*from\s*['"]lucide-react['"]/g;
      let m;
      while ((m = re.exec(code)) !== null) {
        m[1]
          .split(',')
          .map((s) => s.trim().split(/\s+as\s+/)[0].trim())
          .filter(Boolean)
          .forEach((n) => used.add(n));
      }
    }
  }
}
walk(srcRoot);

// ---------------------------------------------------------------------
// 2. Resolve each name to a file in the lucide package.
// ---------------------------------------------------------------------
function toKebab(name) {
  return name
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1-$2')
    .replace(/([a-zA-Z])(\d+)/g, '$1-$2')
    .toLowerCase();
}

function resolveIcon(name) {
  const base = toKebab(name);
  const withoutIcon = base.replace(/-icon$/, '');
  return [
    `${base}.js`,
    `${withoutIcon}.js`,
    `${name.replace(/Icon$/, '')}.js`,
    `${withoutIcon.replace(/-\d+$/, '')}.js`,
    `${withoutIcon}-square.js`,
    `${withoutIcon}-round.js`,
  ];
}

// ---------------------------------------------------------------------
// 3. Parse the `__iconNode` array out of the module.
// ---------------------------------------------------------------------
function parseIconNode(file, depth = 0) {
  if (depth > 8) return null;
  const code = fs.readFileSync(file, 'utf8');

  // Some icons are aliases that only re-export another module.
  const reExport = code.match(
    /export\s*\{\s*default\s*\}\s*from\s*['"]\.\/(.+?)\.js['"]/,
  );
  if (reExport) {
    return parseIconNode(
      path.join(path.dirname(file), `${reExport[1]}.js`),
      depth + 1,
    );
  }

  const start = code.indexOf('const __iconNode = ');
  if (start < 0) return null;
  const open = code.indexOf('[', start);
  let bracketDepth = 0;
  let end = -1;
  let inStr = null;
  for (let i = open; i < code.length; i++) {
    const ch = code[i];
    if (inStr) {
      if (ch === '\\') {
        i++;
        continue;
      }
      if (ch === inStr) inStr = null;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      inStr = ch;
      continue;
    }
    if (ch === '[' || ch === '{' || ch === '(') bracketDepth++;
    else if (ch === ']' || ch === '}' || ch === ')') {
      bracketDepth--;
      if (bracketDepth === 0) {
        end = i;
        break;
      }
    }
  }
  if (end < 0) return null;
  return eval(code.slice(open, end + 1)); // trusted local npm package data
}

// ---------------------------------------------------------------------
// 4. Turn the node list into SVG markup.
// ---------------------------------------------------------------------
const num = (v) => (v === null || v === undefined ? '0' : String(v));

function attrsToSvg(tag, a) {
  const parts = [];
  for (const [key, value] of Object.entries(a)) {
    if (key === 'key') continue;
    parts.push(`${key}="${String(value).replace(/"/g, '&quot;')}"`);
  }
  return `<${tag} ${parts.join(' ')}/>`;
}

function buildSvg(node) {
  const body = node
    .map(([tag, a]) => {
      switch (tag) {
        case 'path':
          return `<path d="${String(a.d).replace(/"/g, '&quot;')}"/>`;
        case 'circle':
          return `<circle cx="${num(a.cx)}" cy="${num(a.cy)}" r="${num(a.r)}"/>`;
        case 'line':
          return `<line x1="${num(a.x1)}" y1="${num(a.y1)}" x2="${num(a.x2)}" y2="${num(a.y2)}"/>`;
        case 'rect':
          return `<rect x="${num(a.x)}" y="${num(a.y)}" width="${num(a.width)}" height="${num(a.height)}"${a.rx != null ? ` rx="${num(a.rx)}"` : ''}${a.ry != null ? ` ry="${num(a.ry)}"` : ''}/>`;
        case 'ellipse':
          return `<ellipse cx="${num(a.cx)}" cy="${num(a.cy)}" rx="${num(a.rx)}" ry="${num(a.ry)}"/>`;
        case 'polyline':
          return `<polyline points="${String(a.points).trim()}"/>`;
        case 'polygon':
          return `<polygon points="${String(a.points).trim()}"/>`;
        default:
          return '';
      }
    })
    .join('');

  return (
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" ' +
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
    'stroke-linecap="round" stroke-linejoin="round">' +
    body +
    '</svg>'
  );
}

// ---------------------------------------------------------------------
// 5. Emit the Dart file.
// ---------------------------------------------------------------------
const entries = [];
const missing = [];

for (const name of [...used].sort()) {
  let resolved = null;
  let node = null;

  for (const candidate of resolveIcon(name)) {
    const full = path.join(LUCIDE_ICONS, candidate);
    if (!fs.existsSync(full)) continue;
    const parsed = parseIconNode(full);
    if (parsed) {
      resolved = candidate;
      node = parsed;
      break;
    }
  }

  if (!resolved) {
    missing.push(name);
    continue;
  }

  const field = name.charAt(0).toLowerCase() + name.slice(1);
  const svg = buildSvg(node).replace(/'/g, "\\'");

  entries.push({
    name,
    field,
    source: resolved.replace(/\.js$/, ''),
    svg,
  });
}

const dart = `// ============================================================================
//  ENNVO — LUCIDE ICONS
//
//  GENERATED FILE — do not edit by hand.
//
//  Source: the exact \`lucide-react@0.546.0\` package that the Ennvo web app
//  depends on. Every icon the web app imports keeps its original SVG
//  markup, so the native build and the web build draw identical glyphs —
//  the same path data, the same 24x24 viewBox, the same round caps and
//  joins and the same default stroke width of 2.
//
//  Regenerate with:  node tools/generate_lucide_icons.js
// ============================================================================

export 'svg_icon.dart';

/// The Lucide icon set used by the Ennvo app.
abstract final class LucideIcons {
${entries
  .map(
    (e) => `  /// Source: \`lucide-react\` \`${e.source}\`
  static const String ${e.field} =
      '${e.svg}';`,
  )
  .join('\n\n')}
}
`;

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, dart, 'utf8');

console.log(`Generated ${entries.length} icons -> ${OUT}`);
console.log(`Used names: ${used.size}`);
if (missing.length) {
  console.log(`Missing (${missing.length}): ${missing.join(', ')}`);
}
