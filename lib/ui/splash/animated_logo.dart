import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'world_dots.dart';

/// Animated NexusTrade logo (≈4.6 s intro, then a seamless 2 s loop):
/// digital world map → trade routes → light burst → emblem (globe + N) →
/// rotating dot globe and orbits → metallic shine → "NexusTrade" reveal.
/// The same timeline is rendered to GIF/MP4 by tools/splash/render_splash.py.
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key});

  /// Length of the intro; after it the logo keeps a calm loop.
  static const intro = Duration(milliseconds: 4600);

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _LogoImages {
  const _LogoImages(this.emblem, this.word, this.line, this.mask);
  final ui.Image emblem, word, line, mask;
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);
  _LogoImages? _images;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _t.value = elapsed.inMicroseconds / 1e6,
    );
    _load();
  }

  Future<ui.Image> _image(String name) async {
    final data = await rootBundle.load('assets/splash/$name');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  Future<void> _load() async {
    final imgs = await Future.wait([
      _image('emblem.png'),
      _image('wordmark.png'),
      _image('underline.png'),
      _image('globe_mask.png'),
    ]);
    if (!mounted) return;
    setState(() => _images = _LogoImages(imgs[0], imgs[1], imgs[2], imgs[3]));
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    return ColoredBox(
      color: Colors.black,
      child: images == null
          ? const SizedBox.expand()
          : CustomPaint(size: Size.infinite, painter: _LogoPainter(images, _t)),
    );
  }
}

// ---------------------------------------------------------------- geometry
// Design space 1080 × 1920, identical to the Python renderer.
const double _w = 1080, _h = 1920;
const double _ew = 900; // emblem width
const _hubs = <String, (double, double)>{
  'Shanghai': (31.2, 121.5),
  'Qingdao': (36.1, 120.4),
  'Ningbo': (29.9, 121.6),
  "Xi'an": (34.3, 108.9),
  'Tashkent': (41.3, 69.2),
  'Almaty': (43.2, 76.9),
  'Dubai': (25.2, 55.3),
  'Istanbul': (41.0, 29.0),
  'Moscow': (55.8, 37.6),
  'Rotterdam': (51.9, 4.5),
  'Hamburg': (53.6, 10.0),
  'Poti': (42.1, 41.7),
  'Mumbai': (19.1, 72.9),
  'Singapore': (1.3, 103.8),
};
const _routes = [
  ('Shanghai', 'Tashkent'),
  ('Qingdao', 'Poti'),
  ("Xi'an", 'Tashkent'),
  ('Ningbo', 'Dubai'),
  ('Shanghai', 'Rotterdam'),
  ('Tashkent', 'Moscow'),
  ('Dubai', 'Istanbul'),
  ('Istanbul', 'Hamburg'),
  ('Singapore', 'Mumbai'),
  ('Mumbai', 'Dubai'),
  ('Almaty', 'Moscow'),
  ('Shanghai', 'Singapore'),
];
const _loop = 2.0;
const _gold = Color(0xFFE8BC5C);
const _cyan = Color(0xFF50C8FF);
const _blue = Color(0xFF1E78FF);

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _phase(double t, double a, double b) {
  final p = _clamp01((t - a) / (b - a));
  return p * p * (3 - 2 * p);
}

Offset _map(double lat, double lon) =>
    Offset(540 + (lon - 60) * 5.4, 820 - (lat - 25) * 5.4);

Offset _bez(Offset p0, Offset p1, Offset p2, double s) =>
    p0 * ((1 - s) * (1 - s)) + p1 * (2 * (1 - s) * s) + p2 * (s * s);

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.img, this.time) : super(repaint: time);

  final _LogoImages img;
  final ValueNotifier<double> time;

  late final double es = _ew / img.emblem.width;
  late final Rect emblemRect = Rect.fromCenter(
    center: const Offset(_w / 2, 820),
    width: _ew,
    height: img.emblem.height * es,
  );
  late final Offset globe = emblemRect.topLeft + Offset(453 * es, 344 * es);
  late final double gr = 300 * es;
  late final double wordW = 860;
  late final Rect wordRect = Rect.fromCenter(
    center: const Offset(_w / 2, 1300),
    width: wordW,
    height: img.word.height * wordW / img.word.width,
  );

  (Offset, double) _globeXyz(double lat, double lon, double lon0) {
    const tilt = 18 * math.pi / 180;
    final phi = lat * math.pi / 180, lam = (lon - lon0) * math.pi / 180;
    final x = math.cos(phi) * math.sin(lam);
    final y =
        math.cos(tilt) * math.sin(phi) -
        math.sin(tilt) * math.cos(phi) * math.cos(lam);
    final z =
        math.sin(tilt) * math.sin(phi) +
        math.cos(tilt) * math.cos(phi) * math.cos(lam);
    return (globe + Offset(gr * .96 * x, -gr * .96 * y), z);
  }

  (Offset, double) _orbit(int i, double theta) {
    final (rx, ry, rotDeg) = i == 0 ? (1.34, .34, -14.0) : (1.22, .50, 22.0);
    final rot = rotDeg * math.pi / 180;
    final x = gr * rx * math.cos(theta), y = gr * ry * math.sin(theta);
    return (
      globe +
          Offset(
            x * math.cos(rot) - y * math.sin(rot),
            x * math.sin(rot) + y * math.cos(rot),
          ),
      math.sin(theta),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final scale = math.min(size.width / _w, size.height / _h);
    canvas.save();
    canvas.translate(
      (size.width - _w * scale) / 2,
      (size.height - _h * scale) / 2,
    );
    canvas.scale(scale);

    // Scene 1 — digital world map
    final mapA = .30 * _phase(t, 0, 1) - .18 * _phase(t, 1.4, 2.4);
    if (mapA > 0) {
      final p = Paint()..color = _cyan.withValues(alpha: mapA);
      for (var i = 0; i < kMapDots.length; i += 2) {
        canvas.drawCircle(_map(kMapDots[i], kMapDots[i + 1]), 2.2, p);
      }
    }

    // Trade routes
    final net = _phase(t, .4, 1.6);
    final netA = 1 - .8 * _phase(t, 1.6, 2.6);
    if (net > 0) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _cyan.withValues(alpha: .43 * netA);
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _blue.withValues(alpha: .7 * netA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final pulse = Paint()
        ..color = const Color(0xFFFFF0C8).withValues(alpha: .9 * netA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      for (var k = 0; k < _routes.length; k++) {
        final (a, b) = _routes[k];
        final p0 = _map(_hubs[a]!.$1, _hubs[a]!.$2);
        final p2 = _map(_hubs[b]!.$1, _hubs[b]!.$2);
        final mid = (p0 + p2) / 2, d = p2 - p0;
        final p1 = Offset(mid.dx + d.dy * .18, mid.dy - d.dx.abs() * .18);
        final local = _clamp01(net * 1.6 - k * .05);
        if (local <= 0) continue;
        final path = Path()..moveTo(p0.dx, p0.dy);
        for (var s = 1; s <= 40; s++) {
          final q = _bez(p0, p1, p2, s / 40 * local);
          path.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(path, glow);
        canvas.drawPath(path, line);
        if (local >= 1) {
          final s = ((t / _loop) + k * .37) % 1.0;
          canvas.drawCircle(_bez(p0, p1, p2, s), 5, pulse);
        }
      }
      if (net > .2) {
        final hub = Paint()..color = _cyan.withValues(alpha: .6 * netA);
        for (final (lat, lon) in _hubs.values) {
          canvas.drawCircle(_map(lat, lon), 4, hub);
        }
      }
    }

    // Light burst
    final burst = _phase(t, .6, 1.25) * (1 - .85 * _phase(t, 1.25, 2.2));
    if (burst > 0) {
      final rad = 120 + 380 * _phase(t, .6, 1.4) - 120 * _phase(t, 1.4, 2.2);
      canvas.drawCircle(
        globe,
        rad * 2,
        Paint()
          ..shader = ui.Gradient.radial(
            globe,
            rad * 2,
            [
              _blue.withValues(alpha: .9 * burst),
              _blue.withValues(alpha: .33 * burst),
              _blue.withValues(alpha: 0),
            ],
            const [0, .5, 1],
          ),
      );
    }

    final orbitDraw = _phase(t, 1.4, 2.4);
    _orbits(canvas, t, orbitDraw, front: false);

    // Emblem materialises
    final em = _phase(t, 1.2, 2.2);
    if (em > 0) {
      final sc = .88 + .12 * em;
      final dst = Rect.fromLTRB(
        globe.dx - (globe.dx - emblemRect.left) * sc,
        globe.dy - (globe.dy - emblemRect.top) * sc,
        globe.dx + (emblemRect.right - globe.dx) * sc,
        globe.dy + (emblemRect.bottom - globe.dy) * sc,
      );
      final blur = 12 * (1 - em);
      final p = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: em);
      if (blur > .3) {
        p.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
      }
      canvas.drawImageRect(img.emblem, _src(img.emblem), dst, p);
    }

    // Rotating dot globe (masked to the blue globe) + twinkling hubs
    final gl = .26 * _phase(t, 1.6, 2.6);
    if (gl > 0) {
      final lon0 = 62 - 1.5 * t; // one 3° grid step per loop → seamless
      canvas.saveLayer(emblemRect, Paint());
      final dot = Paint();
      for (var i = 0; i < kGlobeDots.length; i += 2) {
        final (o, z) = _globeXyz(kGlobeDots[i], kGlobeDots[i + 1], lon0);
        if (z <= 0) continue;
        dot.color = _cyan.withValues(alpha: gl * math.pow(z, 1.2).toDouble());
        canvas.drawCircle(o, .8 + 2 * z, dot);
      }
      canvas.drawImageRect(
        img.mask,
        _src(img.mask),
        emblemRect,
        Paint()..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
      final tw = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      var k = 0;
      for (final (lat, lon) in _hubs.values) {
        final (o, z) = _globeXyz(lat, lon, lon0);
        if (z > .15) {
          final pulse = .5 + .5 * math.sin(2 * math.pi * (t / _loop + k * .23));
          tw.color = const Color(0xFFC8F0FF)
              .withValues(alpha: _clamp01(gl * 2.2 * z * pulse));
          canvas.drawCircle(o, 3 + 3 * pulse, tw);
        }
        k++;
      }
    }

    _orbits(canvas, t, orbitDraw, front: true);

    // Metallic shine across the emblem
    final sh = (t - 2.3) / .8;
    if (sh >= 0 && sh <= 1) {
      final w = emblemRect.width, h = emblemRect.height;
      final pos = -300 + (w + h + 300) * sh;
      const dir = Offset(1, .6);
      final from = emblemRect.topLeft + dir * ((pos - 140) / 1.36);
      final to = emblemRect.topLeft + dir * ((pos + 140) / 1.36);
      canvas.saveLayer(emblemRect, Paint()..blendMode = BlendMode.plus);
      canvas.drawImageRect(
        img.emblem,
        _src(img.emblem),
        emblemRect,
        Paint()
          ..colorFilter = const ColorFilter.mode(
            Color(0x8CFFF5DC),
            BlendMode.srcIn,
          ),
      );
      canvas.drawRect(
        emblemRect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            from,
            to,
            const [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            const [0, .5, 1],
          ),
      );
      canvas.restore();
    }

    // Brand reveal
    final wp = _phase(t, 2.9, 3.6);
    if (wp > 0) {
      final glowA = .55 * _phase(t, 3.0, 3.8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_w / 2, wordRect.bottom + 8),
          width: 720,
          height: 48,
        ),
        Paint()
          ..color = _blue.withValues(alpha: glowA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
      canvas.drawImageRect(
        img.word,
        _src(img.word),
        wordRect.shift(Offset(0, 30 * (1 - wp))),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withValues(alpha: wp),
      );
    }
    final lp = _phase(t, 3.2, 3.9);
    if (lp > 0) {
      const lw = 760.0;
      final lh = img.line.height * lw / img.line.width;
      final top = wordRect.bottom + 22;
      final cw = math.max(2.0, lw * lp);
      final srcW = img.line.width * lp;
      canvas.drawImageRect(
        img.line,
        Rect.fromLTWH(
          (img.line.width - srcW) / 2,
          0,
          srcW,
          img.line.height.toDouble(),
        ),
        Rect.fromLTWH((_w - cw) / 2, top, cw, lh),
        Paint()..color = Colors.white.withValues(alpha: _clamp01(lp * 1.4)),
      );
    }
    canvas.restore();
  }

  void _orbits(Canvas canvas, double t, double draw, {required bool front}) {
    if (draw <= 0) return;
    for (var i = 0; i < 2; i++) {
      final color = i == 0 ? _gold : _cyan;
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (front ? .47 : .24) * .5 + .1);
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: front ? .35 : .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final path = Path();
      var open = false;
      const n = 160;
      for (var s = 0; s <= n; s++) {
        final th = 2 * math.pi * s / n * draw - math.pi / 2;
        final (o, z) = _orbit(i, th);
        if ((z > 0) == front) {
          open ? path.lineTo(o.dx, o.dy) : path.moveTo(o.dx, o.dy);
          open = true;
        } else {
          open = false;
        }
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, line);
      if (draw >= 1) {
        for (var k = 0; k < 3; k++) {
          final th = 2 * math.pi * (k / 3 + t / (3 * _loop));
          final (o, z) = _orbit(i, th);
          if ((z > 0) != front) continue;
          canvas.drawCircle(
            o,
            front ? 12 : 8,
            Paint()
              ..color = color.withValues(alpha: .8)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
          canvas.drawCircle(
            o,
            front ? 5 : 3.5,
            Paint()
              ..color = const Color(0xFFFFFAE6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
      }
    }
  }

  static Rect _src(ui.Image i) =>
      Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());

  @override
  bool shouldRepaint(_LogoPainter old) => old.img != img;
}
