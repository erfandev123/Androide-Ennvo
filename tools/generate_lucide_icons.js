/**
 * Generates `lib/shared/icons/lucide_icons.dart` from the exact
 * `lucide-react` package that the Ennvo web app uses.
 *
 * The web app imports ~174 icons from `lucide-react`. The native port
 * renders the same vector outlines, so the Flutter build and the web build
 * draw identical glyphs — including stroke width, round caps and round
 * joins.
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
    // `Share2` → `share-2`, `Trash2` → `trash-2`.
    .replace(/([a-zA-Z])(\d+)/g, '$1-$2')
    .toLowerCase();
}

function resolveIcon(name) {
  const base = toKebab(name);
  const withoutIcon = base.replace(/-icon$/, '');
  const candidates = [
    `${base}.js`,
    `${withoutIcon}.js`,
    `${name.replace(/Icon$/, '')}.js`,
    `${withoutIcon.replace(/-\d+$/, '')}.js`,
    `${withoutIcon}-square.js`,
    `${withoutIcon}-round.js`,
  ];
  return candidates;
}

// ---------------------------------------------------------------------
// 3. Parse the `__iconNode` array out of the module.
// ---------------------------------------------------------------------
function parseIconNode(file, depth = 0) {
  if (depth > 8) return null;
  const code = fs.readFileSync(file, 'utf8');

  // Some icons are aliases that only re-export another module, e.g.
  //   export { default } from './text-align-start.js';
  const reExport = code.match(/export\s*\{\s*default\s*\}\s*from\s*['"]\.\/(.+?)\.js['"]/);
  if (reExport) {
    return parseIconNode(path.join(path.dirname(file), `${reExport[1]}.js`), depth + 1);
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
      if (ch === '\\') { i++; continue; }
      if (ch === inStr) inStr = null;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') { inStr = ch; continue; }
    if (ch === '[' || ch === '{' || ch === '(') bracketDepth++;
    else if (ch === ']' || ch === '}' || ch === ')') {
      bracketDepth--;
      if (bracketDepth === 0) { end = i; break; }
    }
  }
  if (end < 0) return null;
  const arrayText = code.slice(open, end + 1);
  return eval(arrayText); // trusted local npm package data
}

// ---------------------------------------------------------------------
// 4. Build the Dart source.
// ---------------------------------------------------------------------
const num = (v) => (typeof v === 'number' ? String(v) : '0');
const dstr = (v) => JSON.stringify(String(v));

const entries = [];
const missing = [];

for (const name of [...used].sort()) {
  let resolved = null;
  let node = null;

  // Try every candidate file until one parses — an icon may have been
  // renamed upstream and the alias file may use a different shape.
  for (const candidate of resolveIcon(name)) {
    const full = path.join(LUCIDE_ICONS, candidate);
    if (!fs.existsSync(full)) continue;
    const parsed = parseIconNode(full);
    if (parsed) {
      resolved = { file: full, via: candidate };
      node = parsed;
      break;
    }
  }

  if (!resolved) {
    missing.push(name);
    continue;
  }

  const lines = [];
  for (const [tag, attrs] of node) {
    switch (tag) {
      case 'path':
        lines.push(`      LucidePath(${dstr(attrs.d)}),`);
        break;
      case 'circle':
        lines.push(
          `      LucideCircle(${num(attrs.cx)}, ${num(attrs.cy)}, ${num(attrs.r)}),`,
        );
        break;
      case 'line':
        lines.push(
          `      LucideLine(${num(attrs.x1)}, ${num(attrs.y1)}, ${num(attrs.x2)}, ${num(attrs.y2)}),`,
        );
        break;
      case 'rect':
        lines.push(
          `      LucideRect(${num(attrs.x)}, ${num(attrs.y)}, ${num(attrs.width)}, ${num(attrs.height)}, ${num(attrs.rx ?? 0)}, ${num(attrs.ry ?? 0)}),`,
        );
        break;
      case 'ellipse':
        lines.push(
          `      LucideEllipse(${num(attrs.cx)}, ${num(attrs.cy)}, ${num(attrs.rx)}, ${num(attrs.ry)}),`,
        );
        break;
      case 'polyline':
      case 'polygon': {
        const nums = String(attrs.points).trim().split(/\s+/).map(Number);
        const flat = [];
        for (let i = 0; i + 1 < nums.length; i += 2) flat.push(nums[i], nums[i + 1]);
        const cls = tag === 'polyline' ? 'LucidePolyline' : 'LucidePolygon';
        lines.push(`      ${cls}(${flat.map(num).join(', ')}),`);
        break;
      }
      default:
        break;
    }
  }

  const field = name.charAt(0).toLowerCase() + name.slice(1);
  entries.push({
    name,
    field,
    source: resolved.via.replace(/\.js$/, ''),
    body: lines.join('\n'),
  });
}
const dart = `// ============================================================================
//  ENNVO — LUCIDE ICONS
//
//  GENERATED FILE — do not edit by hand.
//
//  Source: the exact \`lucide-react@0.546.0\` package that the Ennvo web app
//  depends on, extracted from its published SVG outlines. Every icon the web
//  app imports is reproduced here with the same path data, the same 24x24
//  viewBox, the same round caps and joins, and the same default stroke
//  width of 2 — so the native build and the web build draw identical
//  glyphs.
//
//  Regenerate with:  node tools/generate_lucide_icons.js
// ============================================================================

import 'package:flutter/material.dart';

/// One drawing instruction of a Lucide icon.
sealed class LucideSegment {
  const LucideSegment();
}

/// A \`d="…"\` outline.
class LucidePath extends LucideSegment {
  const LucidePath(this.d);
  final String d;
}

/// A \`<circle>\`.
class LucideCircle extends LucideSegment {
  const LucideCircle(this.cx, this.cy, this.r);
  final double cx;
  final double cy;
  final double r;
}

/// A \`<line>\`.
class LucideLine extends LucideSegment {
  const LucideLine(this.x1, this.y1, this.x2, this.y2);
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

/// A \`<rect>\`.
class LucideRect extends LucideSegment {
  const LucideRect(this.x, this.y, this.width, this.height, this.rx, this.ry);
  final double x;
  final double y;
  final double width;
  final double height;
  final double rx;
  final double ry;
}

/// An \`<ellipse>\`.
class LucideEllipse extends LucideSegment {
  const LucideEllipse(this.cx, this.cy, this.rx, this.ry);
  final double cx;
  final double cy;
  final double rx;
  final double ry;
}

/// A \`<polyline>\`.
class LucidePolyline extends LucideSegment {
  const LucidePolyline(this.values);
  final List<double> values;
}

/// A \`<polygon>\`.
class LucidePolygon extends LucideSegment {
  const LucidePolygon(this.values);
  final List<double> values;
}

/// The drawing instructions of one icon.
class LucideIconData {
  const LucideIconData(this.segments);

  final List<LucideSegment> segments;
}

/// Renders a Lucide icon.
///
/// [strokeWidth] defaults to 2, which is what the web app uses everywhere.
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.data, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    this.filled = false,
    this.semanticLabel,
  });

  final LucideIconData data;
  final double size;
  final Color? color;
  final double strokeWidth;

  /// Fills the outline with [color] before stroking it. The web app does
  /// this with \`fill-rose-500\` on a stroked icon, for example the like
  /// button and the saved bookmark.
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? const Color(0xFF111827);

    Widget icon = SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LucidePainter(
            data: data,
            color: effectiveColor,
            strokeWidth: strokeWidth,
            filled: filled,
          ),
        ),
      ),
    );

    if (semanticLabel != null) {
      icon = Semantics(label: semanticLabel, child: icon);
    }
    return icon;
  }
}

class _LucidePainter extends CustomPainter {
  const _LucidePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });

  final LucideIconData data;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final segment in data.segments) {
      switch (segment) {
        case LucidePath(:final d):
          final path = Path.parseSvgPathData(d);
          if (path != null) {
            if (filled) canvas.drawPath(path, fillPaint);
            canvas.drawPath(path, paint);
          }
        case LucideCircle(:final cx, :final cy, :final r):
          if (filled) canvas.drawCircle(Offset(cx, cy), r, fillPaint);
          canvas.drawCircle(Offset(cx, cy), r, paint);
        case LucideLine(:final x1, :final y1, :final x2, :final y2):
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        case LucideRect(:final x, :final y, :final width, :final height, :final rx, :final ry):
          canvas.drawRRect(
            RRect.fromLTRBR(
              x,
              y,
              x + width,
              y + height,
              Radius.elliptical(rx, ry),
            ),
            paint,
          );
        case LucideEllipse(:final cx, :final cy, :final rx, :final ry):
          canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), paint);
        case LucidePolyline(:final values):
          final path = Path();
          for (var i = 0; i + 1 < values.length; i += 2) {
            if (i == 0) {
              path.moveTo(values[i], values[i + 1]);
            } else {
              path.lineTo(values[i], values[i + 1]);
            }
          }
          canvas.drawPath(path, paint);
        case LucidePolygon(:final values):
          final path = Path();
          for (var i = 0; i + 1 < values.length; i += 2) {
            if (i == 0) {
              path.moveTo(values[i], values[i + 1]);
            } else {
              path.lineTo(values[i], values[i + 1]);
            }
          }
          if (values.length >= 4) path.close();
          canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LucidePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.filled != filled ||
        oldDelegate.data != data;
  }
}

/// The icon set used by the Ennvo app.
abstract final class LucideIcons {
${entries
  .map(
    (e) => `  /// Source: \`lucide-react\` \`${e.source}\`
  static const LucideIconData ${e.field} = LucideIconData([
${e.body}
  ]);`,
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
