import '../services/nivelir/algorithms/classification.dart';

/// МОДЕЛЬ прибора — тип, а не конкретный нивелир.
///
/// Здесь живут характеристики и справочная информация. Всё, что относится
/// к конкретному прибору в работе (номер, закрепление, примечание), лежит
/// в [DeviceInstance].
///
/// Характеристики экземпляра отличаться от модели не могут: нужны другие —
/// правится модель либо заводится своя.
class DeviceModel {
  final int? id;
  final String brand;
  final String model;

  final int? magnification;
  final double skoMmKm;
  final String? compensatorType;
  final double? minFocusM;
  final String? minFocusNote;

  /// Способ исправления угла i:
  /// 'reticle'   — перемещением сетки нитей;
  /// 'wedge'     — поворотом защитного стекла (оптический клин перед
  ///               объективом), например Н-05;
  /// 'workshop'  — в полевых условиях исправить нельзя, только мастерская
  ///               (например Ni-002);
  /// 'manual'    — по инструкции по эксплуатации (цифровые нивелиры);
  /// null        — не указан.
  ///
  /// Свойство МОДЕЛИ: по ГКИНП 03-010-03, приложение 9, способ указан
  /// в описании нивелира, то есть привязан к типу прибора.
  final String? adjustmentMethod;

  /// Справочная информация: особенности, замечания по эксплуатации.
  final String? referenceInfo;

  /// 'catalog' — засеяна из assets, характеристики не редактируются;
  /// 'custom'  — модель, добавленная пользователем.
  final String source;

  const DeviceModel({
    this.id,
    required this.brand,
    required this.model,
    this.magnification,
    required this.skoMmKm,
    this.compensatorType,
    this.minFocusM,
    this.minFocusNote,
    this.adjustmentMethod,
    this.referenceInfo,
    this.source = 'custom',
  });

  bool get isCatalog => source == 'catalog';

  String get title => '$brand $model';

  /// true — юстировать в поле нельзя, шаг юстировки должен это сказать
  /// вместо инструкции по сетке нитей.
  bool get adjustmentInFieldForbidden => adjustmentMethod == 'workshop';

  String get adjustmentMethodLabel {
    switch (adjustmentMethod) {
      case 'reticle':
        return 'перемещением сетки нитей';
      case 'wedge':
        return 'поворотом защитного стекла (оптический клин)';
      case 'workshop':
        return 'только в мастерской';
      case 'manual':
        return 'по инструкции по эксплуатации';
      default:
        return 'не указан';
    }
  }

  /// Класс выводится из СКО по компенсаторной колонке ГОСТ 10528-90.
  String get gostClass => DeviceClassification.gostClass(skoMmKm);

  /// Допуск угла i — ГОСТ 10528-90, п. 2.3: 10" для всех групп.
  double get toleranceArcsec => DeviceClassification.toleranceArcsec;

  /// Предел расхождения приёмов по ГКИНП — справочный показатель.
  double get runSpreadLimitArcsec =>
      DeviceClassification.runSpreadLimitArcsec(skoMmKm);

  /// Дрейф угла i на 1 °С (ГОСТ 10528-90, п. 2.4).
  double get tempDriftArcsecPerC =>
      DeviceClassification.tempDriftArcsecPerC(skoMmKm);

  String get designationHint => DeviceClassification.designationHint(skoMmKm);

  String get compensatorLabel {
    switch (compensatorType) {
      case 'air':
        return 'воздушное демпфирование';
      case 'magnetic':
        return 'магнитное демпфирование';
      case 'pendulum':
        return 'маятниковый';
      case null:
        return '—';
      default:
        return compensatorType!;
    }
  }

  DeviceModel copyWith({
    int? id,
    String? brand,
    String? model,
    int? magnification,
    double? skoMmKm,
    String? compensatorType,
    double? minFocusM,
    String? minFocusNote,
    String? adjustmentMethod,
    String? referenceInfo,
    String? source,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      magnification: magnification ?? this.magnification,
      skoMmKm: skoMmKm ?? this.skoMmKm,
      compensatorType: compensatorType ?? this.compensatorType,
      minFocusM: minFocusM ?? this.minFocusM,
      minFocusNote: minFocusNote ?? this.minFocusNote,
      adjustmentMethod: adjustmentMethod ?? this.adjustmentMethod,
      referenceInfo: referenceInfo ?? this.referenceInfo,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'brand': brand,
        'model': model,
        'magnification': magnification,
        'sko_mm_km': skoMmKm,
        'compensator_type': compensatorType,
        'min_focus_m': minFocusM,
        'min_focus_note': minFocusNote,
        'adjustment_method': adjustmentMethod,
        'reference_info': referenceInfo,
        'gost_class': gostClass,
        'source': source,
      };

  factory DeviceModel.fromMap(Map<String, dynamic> m) => DeviceModel(
        id: m['id'] as int?,
        brand: m['brand'] as String,
        model: m['model'] as String,
        magnification: (m['magnification'] as num?)?.toInt(),
        skoMmKm: (m['sko_mm_km'] as num).toDouble(),
        compensatorType: m['compensator_type'] as String?,
        minFocusM: (m['min_focus_m'] as num?)?.toDouble(),
        minFocusNote: m['min_focus_note'] as String?,
        adjustmentMethod: m['adjustment_method'] as String?,
        referenceInfo: m['reference_info'] as String?,
        source: (m['source'] as String?) ?? 'custom',
      );
}
