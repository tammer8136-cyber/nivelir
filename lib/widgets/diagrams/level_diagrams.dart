import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Схемы поверок круглых уровней.
///
/// Нарисованы кодом, а не картинками, по одной причине: здесь всё держится
/// на числах. Уход пузырька после поворота на 180° РОВНО вдвое больше
/// ошибки установки, и половина, которую выбирают винтами уровня, — ровно
/// половина. На растровой картинке это «примерно», здесь — посчитано.
///
/// Источник процедуры: ГКИНП (ГНТА) 03-010-03, поверки круглого уровня
/// нивелира и круглого уровня рейки.
class _Geom {
  /// Радиус ампулы принят за единицу; всё остальное — доли от него.
  static const double tolerance = 0.52; // окружность допуска
  static const double bubble = 0.26; // радиус пузырька
  static const double offset = 0.40; // уход пузырька после поворота

  // Проверка соразмерности: при максимальном уходе пузырёк обязан
  // оставаться внутри ампулы — offset + bubble = 0.66 < 1.0. Иначе схема
  // показывала бы физически невозможное.
}

const _line = AppTheme.primary;
const _bubbleFill = Color(0xFF8BC98B);
const _muted = AppTheme.textSecondary;

void _drawAmpoule(Canvas canvas, Offset c, double r) {
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = _line;
  canvas.drawCircle(c, r, stroke);

  // Окружность допуска — пунктиром.
  final dashed = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..color = _line.withValues(alpha: 0.65);
  _dashedCircle(canvas, c, r * _Geom.tolerance, dashed);
}

void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
  const segments = 44;
  const step = 2 * math.pi / segments;
  for (var i = 0; i < segments; i += 2) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      i * step,
      step,
      false,
      paint,
    );
  }
}

void _drawBubble(Canvas canvas, Offset center, double r) {
  // Пузырёк в СФЕРИЧЕСКОЙ ампуле круглый, а не овальный: овал получился бы
  // только у цилиндрического (трубчатого) уровня.
  canvas.drawCircle(
    center,
    r,
    Paint()..color = _bubbleFill,
  );
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _line,
  );
}

void _drawCross(Canvas canvas, Offset c, double size) {
  final p = Paint()
    ..strokeWidth = 1.0
    ..color = _line.withValues(alpha: 0.55);
  canvas.drawLine(c - Offset(size, 0), c + Offset(size, 0), p);
  canvas.drawLine(c - Offset(0, size), c + Offset(0, size), p);
}

void _label(Canvas canvas, String s, Offset center, double size,
    {double maxWidth = 200, Color color = _muted, bool bold = false}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        height: 1.25,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  tp.layout(maxWidth: maxWidth);
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
}

/// Стрелка с засечками на концах: показывает величину ухода.
void _dimension(Canvas canvas, Offset from, Offset to, {Color? color}) {
  final paint = Paint()
    ..strokeWidth = 1.3
    ..color = color ?? _line;
  canvas.drawLine(from, to, paint);

  const tick = 4.0;
  for (final p in [from, to]) {
    canvas.drawLine(p + const Offset(0, -tick), p + const Offset(0, tick), paint);
  }
}

// ===========================================================================
// 1. ПОВЕРКА КРУГЛОГО УРОВНЯ НИВЕЛИРА
// ===========================================================================

/// Три состояния: пузырёк выведен в нуль-пункт, после поворота на 180°
/// ушёл на удвоенную ошибку, половина ухода выбрана винтами уровня.
class RoundLevelCheckDiagram extends StatelessWidget {
  const RoundLevelCheckDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.15,
      child: CustomPaint(painter: _RoundLevelCheckPainter()),
    );
  }
}

class _RoundLevelCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 8.2, size.height / 3.6);
    final cy = size.height * 0.40;
    final step = size.width / 3;
    final centers = [
      Offset(step * 0.5, cy),
      Offset(step * 1.5, cy),
      Offset(step * 2.5, cy),
    ];

    final offset = r * _Geom.offset;
    final bubbleR = r * _Geom.bubble;

    for (final c in centers) {
      _drawAmpoule(canvas, c, r);
      _drawCross(canvas, c, r * 0.16);
    }

    // 1 — в нуль-пункте.
    _drawBubble(canvas, centers[0], bubbleR);

    // 2 — после поворота на 180°: уход ВДВОЕ больше ошибки установки.
    _drawBubble(canvas, centers[1] + Offset(offset, 0), bubbleR);
    _dimension(canvas, centers[1], centers[1] + Offset(offset, 0));

    // 3 — половина ухода выбрана винтами уровня. Ровно половина: offset / 2.
    final half = offset / 2;
    _drawBubble(canvas, centers[2] + Offset(half, 0), bubbleR);
    // Пунктиром — где пузырёк был до исправления.
    canvas.drawCircle(
      centers[2] + Offset(offset, 0),
      bubbleR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = _line.withValues(alpha: 0.30),
    );
    _dimension(canvas, centers[2], centers[2] + Offset(half, 0));

    // Дуга поворота между 1 и 2.
    final arcTop = cy - r * 1.55;
    final path = Path()
      ..moveTo(centers[0].dx, cy - r - 6)
      ..quadraticBezierTo(
        (centers[0].dx + centers[1].dx) / 2,
        arcTop,
        centers[1].dx,
        cy - r - 6,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = _line,
    );
    _arrowHead(canvas, centers[1] + Offset(0, -r - 6), math.pi * 0.30);
    _label(canvas, '180°', Offset((centers[0].dx + centers[1].dx) / 2, arcTop - 14),
        11, color: _line, bold: true);

    final capY = cy + r + 10;
    _label(canvas, '1\nв нуль-пункте', centers[0].translate(0, 0) + Offset(0, capY - cy),
        10, maxWidth: step * 0.92);
    _label(canvas, '2\nуход вдвое больше ошибки',
        centers[1] + Offset(0, capY - cy), 10, maxWidth: step * 0.92);
    _label(canvas, '3\nполовина — винтами уровня',
        centers[2] + Offset(0, capY - cy), 10, maxWidth: step * 0.92);
  }

  void _arrowHead(Canvas canvas, Offset tip, double angle) {
    const len = 7.0;
    final p = Paint()
      ..strokeWidth = 1.3
      ..color = _line;
    canvas.drawLine(
        tip, tip + Offset(-len * math.cos(angle), -len * math.sin(angle)), p);
    canvas.drawLine(
        tip, tip + Offset(-len * math.cos(-angle + 0.9), -len * math.sin(-angle + 0.9)), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===========================================================================
// 2. ПРАВИЛО ПОЛОВИНЫ
// ===========================================================================

/// Ход пузырька к нуль-пункту делится ровно пополам: половина — юстировочными
/// винтами уровня, половина — подъёмными винтами.
class HalfRuleDiagram extends StatelessWidget {
  const HalfRuleDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.55,
      child: CustomPaint(painter: _HalfRulePainter()),
    );
  }
}

class _HalfRulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 3.4, size.height / 3.0);
    final c = Offset(size.width * 0.34, size.height * 0.36);

    _drawAmpoule(canvas, c, r);
    _drawCross(canvas, c, r * 0.16);

    final offset = r * _Geom.offset;
    final bubbleR = r * _Geom.bubble;
    final from = c + Offset(offset, 0);
    final mid = c + Offset(offset / 2, 0);

    _drawBubble(canvas, from, bubbleR);

    // Пунктирные метки: где пузырёк сейчас, где будет после первой половины,
    // и куда должен прийти.
    for (final p in [mid, c]) {
      canvas.drawCircle(
        p,
        bubbleR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = _line.withValues(alpha: 0.28),
      );
    }

    // Две стрелки одна за другой по одной линии — так видно, что это
    // последовательные половины ОДНОГО хода, а не два разных движения.
    final y = c.dy + r * 0.74;
    _dimension(canvas, from.translate(0, y - c.dy), mid.translate(0, y - c.dy));
    _dimension(canvas, mid.translate(0, y - c.dy), c.translate(0, y - c.dy));

    _label(canvas, '½', Offset((from.dx + mid.dx) / 2, y + 4), 12,
        color: _line, bold: true);
    _label(canvas, '½', Offset((mid.dx + c.dx) / 2, y + 4), 12,
        color: _line, bold: true);

    // Подставка: РОВНО три подъёмных винта.
    final tribrachC = Offset(size.width * 0.78, size.height * 0.34);
    final tr = r * 0.62;
    canvas.drawCircle(
      tribrachC,
      tr * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _line,
    );
    for (var i = 0; i < 3; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 3;
      final p = tribrachC + Offset(tr * math.cos(a), tr * math.sin(a));
      canvas.drawCircle(
        p,
        tr * 0.26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _line,
      );
    }

    _label(canvas, 'подъёмные винты\n(три)',
        Offset(tribrachC.dx, tribrachC.dy + tr + 10), 10, maxWidth: size.width * 0.4);

    _label(
      canvas,
      'Половину ухода выбирают юстировочными винтами уровня,\n'
      'вторую половину — подъёмными винтами',
      Offset(size.width / 2, size.height * 0.84),
      10.5,
      maxWidth: size.width * 0.92,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===========================================================================
// 3. ПОВЕРКА КРУГЛОГО УРОВНЯ РЕЙКИ
// ===========================================================================

/// Слева — вид в трубу: РЕБРО рейки совмещено с вертикальной нитью сетки.
/// Справа — круглый уровень рейки, пузырёк в допуске.
class RodLevelDiagram extends StatelessWidget {
  const RodLevelDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.9,
      child: CustomPaint(painter: _RodLevelPainter()),
    );
  }
}

class _RodLevelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    _paintTelescope(canvas, Rect.fromLTWH(0, 0, half, size.height));
    _paintRodLevel(canvas, Rect.fromLTWH(half, 0, half, size.height));
  }

  void _paintTelescope(Canvas canvas, Rect area) {
    final r = math.min(area.width / 2.6, area.height / 2.9);
    final c = Offset(area.center.dx, area.top + area.height * 0.42);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    // Рейка: её ЛЕВОЕ РЕБРО должно лечь на вертикальную нить сетки,
    // поэтому полотно уходит вправо от центра, а не стоит симметрично.
    final rodW = r * 0.62;
    final rodRect = Rect.fromLTWH(c.dx, c.dy - r, rodW, r * 2);
    canvas.drawRect(
      rodRect,
      Paint()..color = const Color(0xFFF2F2F2),
    );
    // Шашки сантиметровых делений.
    final blockH = r * 0.30;
    for (var i = 0; i < 8; i++) {
      final top = c.dy - r + i * blockH;
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(c.dx + rodW * 0.18, top, rodW * 0.44, blockH * 0.62),
          Paint()..color = _line,
        );
      }
    }
    canvas.drawRect(
      rodRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _line,
    );
    canvas.restore();

    // Поле зрения.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _line,
    );

    // Сетка нитей. Вертикальная нить проходит ровно по ребру рейки.
    final wire = Paint()
      ..strokeWidth = 1.3
      ..color = _line;
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), wire);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), wire);

    _label(
      canvas,
      'Ребро рейки — точно\nпо вертикальной нити',
      Offset(area.center.dx, c.dy + r + 8),
      10,
      maxWidth: area.width * 0.92,
    );
  }

  void _paintRodLevel(Canvas canvas, Rect area) {
    final r = math.min(area.width / 3.4, area.height / 3.4);
    final c = Offset(area.center.dx, area.top + area.height * 0.42);

    // Фрагмент рейки за уровнем.
    final rodW = r * 1.5;
    canvas.drawRect(
      Rect.fromLTWH(c.dx - rodW / 2, area.top + 4, rodW, area.height * 0.72),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _line.withValues(alpha: 0.45),
    );

    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    _drawAmpoule(canvas, c, r);
    // Пузырёк в нуль-пункте и заведомо внутри окружности допуска:
    // bubble (0.26) < tolerance (0.52).
    _drawBubble(canvas, c, r * _Geom.bubble);

    _label(
      canvas,
      'Пузырёк — в нуль-пункте,\nвнутри окружности допуска',
      Offset(area.center.dx, c.dy + r + 8),
      10,
      maxWidth: area.width * 0.92,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
