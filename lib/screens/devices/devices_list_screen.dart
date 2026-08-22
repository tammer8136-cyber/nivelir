import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/units.dart';
import 'device_detail_screen.dart';
import 'device_form_screen.dart';

class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({super.key});

  @override
  State<DevicesListScreen> createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen> {
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
      appBar: AppBar(title: const Text('Приборы')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceFormScreen()),
          );
          if (mounted) setState(_load);
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Поиск по каталогу и своим приборам',
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
                        d.isCatalog
                            ? Icons.inventory_2_outlined
                            : Icons.edit_note,
                        color: AppTheme.primary,
                      ),
                      title: Text(d.displayName),
                      subtitle: Text(
                        '${d.gostClass} · СКО ${d.skoMmKm} мм/км · '
                        'допуск ${Units.arcsec(d.toleranceArcsec)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceDetailScreen(device: d),
                          ),
                        );
                        if (mounted) setState(_load);
                      },
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
