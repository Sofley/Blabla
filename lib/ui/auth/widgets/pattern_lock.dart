import 'package:flutter/material.dart';

/// 3×3 graphic pattern input. Reports the sequence of touched dots (0..8).
class PatternLock extends StatefulWidget {
  const PatternLock({
    super.key,
    required this.onCompleted,
    this.size = 280,
    this.error = false,
  });

  final ValueChanged<List<int>> onCompleted;
  final double size;

  /// Paints the last pattern in the error color.
  final bool error;

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock> {
  final List<int> _path = [];
  Offset? _finger;

  double get _cell => widget.size / 3;

  Offset _center(int i) => Offset((i % 3 + .5) * _cell, (i ~/ 3 + .5) * _cell);

  int? _hit(Offset p) {
    for (var i = 0; i < 9; i++) {
      if ((p - _center(i)).distance < _cell * .32) return i;
    }
    return null;
  }

  void _add(int i) {
    if (_path.contains(i)) return;
    // Auto-include a skipped middle dot (like Android): 0→2 passes 1, etc.
    if (_path.isNotEmpty) {
      final a = _path.last;
      final mid = _middle(a, i);
      if (mid != null && !_path.contains(mid)) _path.add(mid);
    }
    _path.add(i);
  }

  static int? _middle(int a, int b) {
    final ar = a ~/ 3, ac = a % 3, br = b ~/ 3, bc = b % 3;
    if ((ar + br).isEven && (ac + bc).isEven) {
      final m = ((ar + br) ~/ 2) * 3 + (ac + bc) ~/ 2;
      return m == a || m == b ? null : m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.error && _path.isEmpty ? scheme.error : scheme.primary;
    return GestureDetector(
      onPanStart: (d) => setState(() {
        _path.clear();
        final h = _hit(d.localPosition);
        if (h != null) _add(h);
        _finger = d.localPosition;
      }),
      onPanUpdate: (d) => setState(() {
        final h = _hit(d.localPosition);
        if (h != null) _add(h);
        _finger = d.localPosition;
      }),
      onPanEnd: (_) {
        final result = List<int>.of(_path);
        setState(() {
          _path.clear();
          _finger = null;
        });
        if (result.isNotEmpty) widget.onCompleted(result);
      },
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _PatternPainter(
          path: _path,
          finger: _finger,
          center: _center,
          dot: scheme.onSurfaceVariant.withValues(alpha: .45),
          active: color,
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.path,
    required this.finger,
    required this.center,
    required this.dot,
    required this.active,
  });

  final List<int> path;
  final Offset? finger;
  final Offset Function(int) center;
  final Color dot;
  final Color active;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = active.withValues(alpha: .6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < path.length; i++) {
      canvas.drawLine(center(path[i - 1]), center(path[i]), line);
    }
    if (path.isNotEmpty && finger != null) {
      canvas.drawLine(center(path.last), finger!, line);
    }
    for (var i = 0; i < 9; i++) {
      final on = path.contains(i);
      canvas.drawCircle(
        center(i),
        on ? 11 : 7,
        Paint()..color = on ? active : dot,
      );
      if (on) {
        canvas.drawCircle(
          center(i),
          24,
          Paint()..color = active.withValues(alpha: .12),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => true;
}

String encodePattern(List<int> p) => p.join('-');
