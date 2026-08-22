/// Геометрия поверки: расстояния от нивелира до рейки A и рейки B на каждой
/// из двух станций.
///
/// ПОЧЕМУ A/B, А НЕ "БЛИЖНЯЯ/ДАЛЬНЯЯ". В способе нивелирования с разными
/// плечами (ГКИНП (ГНТА) 17-195-99, п. 4.2.5, способ 3) станции стоят за разными
/// концами створа, и одна и та же рейка на первой станции ближняя, а на
/// второй дальняя. Привязка "ближняя/дальняя" там разваливается вместе со
/// знаком превышения. Рейки A и B — неподвижные точки местности, их
/// идентичность не меняется, поэтому знак определён однозначно.
class MethodGeometry {
  /// Расстояние от станции 1 до рейки A, м.
  final double station1ToA;

  /// Расстояние от станции 1 до рейки B, м.
  final double station1ToB;

  final double station2ToA;
  final double station2ToB;

  const MethodGeometry({
    required this.station1ToA,
    required this.station1ToB,
    required this.station2ToA,
    required this.station2ToB,
  });

  /// Разность плеч на станции (A минус B). Для станции "из середины" = 0.
  double get station1DiffM => station1ToA - station1ToB;
  double get station2DiffM => station2ToA - station2ToB;

  /// Знаменатель формулы угла i. Величина ЗНАКОВАЯ: порядок станций задан
  /// методикой (сначала из середины, потом со смещением), переставлять их
  /// ради положительного знаменателя нельзя — юстировка выполняется именно
  /// на станции 2. Знак знаменателя сокращается со знаком числителя, и
  /// итоговый угол i получается правильного знака при любом порядке.
  ///
  /// Рабочий метод (50/50 и 25/75): (25-75) - 0 -> -50 м, по модулю 50.
  /// Разные плечи (4/54 и 54/4): (54-4) - (4-54) -> +100 м, то есть 2s.
  /// Вперёд (0/50 и 50/0): (50-0) - (0-50) -> +100 м, тоже 2s.
  double get distanceDiffM => station2DiffM - station1DiffM;

  bool get isValid => distanceDiffM.abs() > 0.001;

  /// На станции 2 дальняя та рейка, до которой больше расстояние — по ней и
  /// выставляется теоретический отсчёт при юстировке.
  bool get farRodAtStation2IsA => station2ToA > station2ToB;

  MethodGeometry copyWith({
    double? station1ToA,
    double? station1ToB,
    double? station2ToA,
    double? station2ToB,
  }) {
    return MethodGeometry(
      station1ToA: station1ToA ?? this.station1ToA,
      station1ToB: station1ToB ?? this.station1ToB,
      station2ToA: station2ToA ?? this.station2ToA,
      station2ToB: station2ToB ?? this.station2ToB,
    );
  }

  Map<String, dynamic> toMap() => {
        's1_a': station1ToA,
        's1_b': station1ToB,
        's2_a': station2ToA,
        's2_b': station2ToB,
      };

  factory MethodGeometry.fromMap(Map<String, dynamic> m) => MethodGeometry(
        station1ToA: (m['s1_a'] as num).toDouble(),
        station1ToB: (m['s1_b'] as num).toDouble(),
        station2ToA: (m['s2_a'] as num).toDouble(),
        station2ToB: (m['s2_b'] as num).toDouble(),
      );
}

class MethodPreset {
  /// Идентификатор, уходящий в БД (`verifications.method_preset`).
  final String id;
  final String title;
  final String description;
  final MethodGeometry defaultGeometry;
  final bool editableGeometry;

  /// В способе "вперёд" отсчёт по рейке в точке стояния заменяется высотой
  /// визирной оси над точкой, измеренной рулеткой (плечо равно нулю).
  final bool usesInstrumentHeight;

  const MethodPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.defaultGeometry,
    this.editableGeometry = false,
    this.usesInstrumentHeight = false,
  });

  static const workingId = 'working_100m';
  static const gkinpForwardId = 'gkinp_forward';
  static const gkinpMiddleForwardId = 'gkinp_middle_forward';
  static const gkinpUnequalId = 'gkinp_unequal_arms';
  static const customId = 'custom';

  static const List<MethodPreset> all = [
    MethodPreset(
      id: workingId,
      title: 'Рабочий метод (база 100 м)',
      description:
          'Рейки неподвижны, база 100 м. Станция 1 — из середины (50/50 м), '
          'станция 2 — со смещением (25/75 м). Перемещается только нивелир. '
          'Знаменатель формулы — 50 м.',
      defaultGeometry: MethodGeometry(
        station1ToA: 50,
        station1ToB: 50,
        station2ToA: 25,
        station2ToB: 75,
      ),
    ),
    MethodPreset(
      id: gkinpMiddleForwardId,
      title: 'Из середины + вперёд (ГКИНП 17-195-99, способ 2)',
      description:
          'Линия 40–60 м. Станция 1 — на равных расстояниях от реек, '
          'станция 2 — в 5–10 м за рейкой B. Плечи редактируются.',
      defaultGeometry: MethodGeometry(
        station1ToA: 25,
        station1ToB: 25,
        station2ToA: 57,
        station2ToB: 7,
      ),
      editableGeometry: true,
    ),
    MethodPreset(
      id: gkinpUnequalId,
      title: 'С разными плечами (ГКИНП 17-195-99, способ 3)',
      description:
          'Линия (50 ± 10) м. Обе станции — в 3–5 м за концами створа, '
          'фокусировка трубы между станциями не меняется. '
          'Знаменатель выходит равным удвоенной длине линии.',
      defaultGeometry: MethodGeometry(
        station1ToA: 4,
        station1ToB: 54,
        station2ToA: 54,
        station2ToB: 4,
      ),
      editableGeometry: true,
    ),
    MethodPreset(
      id: gkinpForwardId,
      title: 'Вперёд (ГКИНП 17-195-99, способ 1)',
      description:
          'Линия (50 ± 10) м. Нивелир стоит над точкой: вместо отсчёта по '
          'своей рейке вводится высота визирной оси над точкой, измеренная '
          'рулеткой с погрешностью не более 1 мм. Затем нивелир и рейка '
          'меняются местами.',
      defaultGeometry: MethodGeometry(
        station1ToA: 0,
        station1ToB: 50,
        station2ToA: 50,
        station2ToB: 0,
      ),
      editableGeometry: true,
      usesInstrumentHeight: true,
    ),
    MethodPreset(
      id: customId,
      title: 'Свои плечи',
      description: 'Произвольная геометрия: все четыре расстояния вручную.',
      defaultGeometry: MethodGeometry(
        station1ToA: 50,
        station1ToB: 50,
        station2ToA: 25,
        station2ToB: 75,
      ),
      editableGeometry: true,
    ),
  ];

  static MethodPreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}
