import 'device_model.dart';

/// ЭКЗЕМПЛЯР — конкретный прибор в работе.
///
/// Хранит только учётные данные. Характеристики берутся из [DeviceModel]
/// и здесь не дублируются: экземпляр не может отличаться от своей модели.
///
/// Геттеры характеристик делегируют в модель, чтобы вызывающий код
/// (мастер, экспорт, расчёт) работал с экземпляром так же, как раньше
/// работал с прибором.
class DeviceInstance {
  final int? id;
  final int modelId;

  /// Серийный или инвентарный номер. Именно он различает два одинаковых
  /// прибора в списке.
  final String? serialNumber;

  /// За кем закреплён прибор.
  final String? assignedTo;

  final String? notes;

  /// Модель. Подгружается вместе с экземпляром; отдельно от неё экземпляр
  /// смысла не имеет.
  final DeviceModel model;

  const DeviceInstance({
    this.id,
    required this.modelId,
    required this.model,
    this.serialNumber,
    this.assignedTo,
    this.notes,
  });

  // --- делегирование в модель ---

  String get brand => model.brand;
  String get modelName => model.model;
  int? get magnification => model.magnification;
  double get skoMmKm => model.skoMmKm;
  String? get compensatorType => model.compensatorType;
  String get compensatorLabel => model.compensatorLabel;
  double? get minFocusM => model.minFocusM;
  String? get minFocusNote => model.minFocusNote;
  String? get adjustmentMethod => model.adjustmentMethod;
  String get adjustmentMethodLabel => model.adjustmentMethodLabel;
  bool get adjustmentInFieldForbidden => model.adjustmentInFieldForbidden;
  String get gostClass => model.gostClass;
  String get fieldToleranceLabel => model.fieldToleranceLabel;
  double get runSpreadLimitArcsec => model.runSpreadLimitArcsec;
  double get tempDriftArcsecPerC => model.tempDriftArcsecPerC;
  String get designationHint => model.designationHint;

  /// Как прибор называется в списках и в протоколе.
  String get displayName {
    final serial = serialNumber?.trim();
    if (serial == null || serial.isEmpty) return model.title;
    return '${model.title} (№ $serial)';
  }

  /// Вторая строка в списке своих приборов: за кем закреплён.
  String? get assignmentLabel {
    final who = assignedTo?.trim();
    if (who == null || who.isEmpty) return null;
    return 'Закреплён: $who';
  }

  DeviceInstance copyWith({
    int? id,
    int? modelId,
    DeviceModel? model,
    String? serialNumber,
    String? assignedTo,
    String? notes,
  }) {
    return DeviceInstance(
      id: id ?? this.id,
      modelId: modelId ?? this.modelId,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      assignedTo: assignedTo ?? this.assignedTo,
      notes: notes ?? this.notes,
    );
  }

  /// Модель в карту не пишется — она живёт в своей таблице.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'model_id': modelId,
        'serial_number': serialNumber,
        'assigned_to': assignedTo,
        'notes': notes,
      };

  /// [m] — строка device_instances, [model] — уже загруженная модель.
  factory DeviceInstance.fromMap(
    Map<String, dynamic> m, {
    required DeviceModel model,
  }) =>
      DeviceInstance(
        id: m['id'] as int?,
        modelId: (m['model_id'] as num).toInt(),
        model: model,
        serialNumber: m['serial_number'] as String?,
        assignedTo: m['assigned_to'] as String?,
        notes: m['notes'] as String?,
      );
}
