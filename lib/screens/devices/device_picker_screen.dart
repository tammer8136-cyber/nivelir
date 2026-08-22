import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_instance.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'instance_form_screen.dart';

/// Выбор прибора для мастера. Возвращает DeviceInstance через Navigator.pop.
///
/// Выбирается именно ЭКЗЕМПЛЯР: поверяется конкретный прибор с номером,
/// на него же выписывается протокол и вешаются напоминания. Справочник
/// моделей в этом списке не участвует.
class DevicePickerScreen extends StatefulWidget {
  const DevicePickerScreen({super.key});

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  final _searchCtrl = TextEditingController();
  late Future<List<DeviceInstance>> _instances;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _instances = context.read<DatabaseService>().getInstances(
          search: _searchCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор прибора')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<DeviceInstance>(
            context,
            MaterialPageRoute(builder: (_) => const InstanceFormScreen()),
          );
          if (created != null && context.mounted) {
            Navigator.pop(context, created);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить прибор'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Модель, номер, за кем закреплён',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(_load),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DeviceInstance>>(
              future: _instances,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.straighten,
                              size: 48, color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text('Своих приборов пока нет',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text(
                            'Добавьте прибор: выберите модель из справочника '
                            'и укажите его номер.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = items[index];
                    return ListTile(
                      title: Text(d.displayName),
                      subtitle: Text(
                        [
                          '${d.skoMmKm} мм/км · ${d.gostClass}',
                          if (d.assignmentLabel != null) d.assignmentLabel!,
                        ].join('\n'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: d.assignmentLabel != null,
                      onTap: () => Navigator.pop(context, d),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
