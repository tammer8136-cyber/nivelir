import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/database_service.dart';
import '../../state/app_settings.dart';
import '../../state/wizard_state.dart';
import '../../theme/app_theme.dart';
import 'steps/step_adjustment.dart';
import 'steps/step_params.dart';
import 'steps/step_preflight.dart';
import 'steps/step_result.dart';
import 'steps/step_station.dart';

/// Оболочка мастера: PageView со ОТКЛЮЧЁННЫМ скроллом + PopScope.
///
/// Прокрутка отключена намеренно — переход только по кнопкам, чтобы шаг
/// нельзя было пролистнуть мимо валидации.
class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  late final WizardState _wizard;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppSettings>();
    _wizard = WizardState(
      db: context.read<DatabaseService>(),
      isMillimeters: settings.isMillimeters,
      skipPreflight: settings.skipPreflight,
    );
  }

  @override
  void dispose() {
    _wizard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Тумблер единиц может быть переключён из настроек, пока мастер открыт.
    final isMm = context.select<AppSettings, bool>((s) => s.isMillimeters);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wizard.syncUnits(isMm);
    });

    return ChangeNotifierProvider<WizardState>.value(
      value: _wizard,
      child: Consumer<WizardState>(
        builder: (context, wizard, _) {
          return PopScope(
            // Системный жест "назад" на промежуточных шагах должен
            // возвращать на предыдущий шаг, а не закрывать мастер.
            canPop: wizard.isFirst,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              wizard.previousStep();
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(_titleFor(wizard.current)),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (!wizard.previousStep()) Navigator.pop(context);
                  },
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: (wizard.index + 1) / wizard.steps.length,
                    backgroundColor: AppTheme.primaryDark,
                    color: Colors.white,
                    minHeight: 4,
                  ),
                ),
              ),
              body: PageView(
                controller: wizard.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final step in wizard.steps) _pageFor(step),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pageFor(WizardStep step) {
    switch (step) {
      case WizardStep.preflight:
        return const StepPreflight();
      case WizardStep.params:
        return const StepParams();
      case WizardStep.station1:
        return const StepStation(station: 1);
      case WizardStep.station2:
        return const StepStation(station: 2);
      case WizardStep.result:
        return const StepResult();
      case WizardStep.adjustment:
        return const StepAdjustment();
    }
  }

  String _titleFor(WizardStep step) {
    switch (step) {
      case WizardStep.preflight:
        return 'Подготовка к работе';
      case WizardStep.params:
        return 'Параметры';
      case WizardStep.station1:
        return 'Станция 1';
      case WizardStep.station2:
        return 'Станция 2';
      case WizardStep.result:
        return 'Результат';
      case WizardStep.adjustment:
        return 'Юстировка';
    }
  }
}
