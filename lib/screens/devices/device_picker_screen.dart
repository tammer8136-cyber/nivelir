import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';
import 'device_form_screen.dart';

/// Выбор прибора для мастера. Возвращает Device через Navigator.pop.
class DevicePickerScreen extends StatefulWidget {
  const DevicePickerScreen({super.key});

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  final _searchCtrl = TextEditingController();
  late Future<List<Device>> _devices;

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
    _devices = context.read<DatabaseService>().getDevices(
          search: _searchCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор прибора')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<Device>(
            context,
            MaterialPageRoute(builder: (_) => const DeviceFormScreen()),
          );
          if (created != null && context.mounted) {
            Navigator.pop(context, created);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Свой прибор'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Марка, модель или номер',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(_load),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Device>>(
              future: _devices,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final devices = snapshot.data!;
                if (devices.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }
                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, i) {
                    final d = devices[i];
                    return ListTile(
                      leading: Icon(
                        d.isCatalog ? Icons.inventory_2_outlined : Icons.edit_note,
                        color: AppTheme.primary,
                      ),
                      title: Text(d.displayName),
                      subtitle: Text(
                        '${d.gostClass} · СКО ${d.skoMmKm} мм/км · '
                        'допуск ${Units.arcsec(d.toleranceArcsec)}',
                      ),
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
