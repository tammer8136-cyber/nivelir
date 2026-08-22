import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_instance.dart';
import '../../models/device_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'instance_detail_screen.dart';
import 'instance_form_screen.dart';
import 'model_detail_screen.dart';
import 'model_form_screen.dart';

/// Раздел «Приборы»: две вкладки.
///
/// Справочник моделей — типы приборов и их характеристики.
/// Свои приборы — конкретные экземпляры с номерами и закреплением.
class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({super.key});

  @override
  State<DevicesListScreen> createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Приборы'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Свои приборы'),
              Tab(text: 'Справочник'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _InstancesTab(),
            _ModelsTab(),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// СВОИ ПРИБОРЫ
// ===========================================================================

class _InstancesTab extends StatefulWidget {
  const _InstancesTab();

  @override
  State<_InstancesTab> createState() => _InstancesTabState();
}

class _InstancesTabState extends State<_InstancesTab> {
  final _searchCtrl = TextEditingController();
  late Future<List<DeviceInstance>> _future;

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
    _future = context
        .read<DatabaseService>()
        .getInstances(search: _searchCtrl.text.trim());
  }

  Future<void> _add() async {
    final created = await Navigator.push<DeviceInstance>(
      context,
      MaterialPageRoute(builder: (_) => const InstanceFormScreen()),
    );
    if (created != null && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
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
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const _Empty(
                    icon: Icons.straighten,
                    title: 'Своих приборов пока нет',
                    text: 'Добавьте прибор: выберите модель из справочника '
                        'и укажите его номер.',
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
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InstanceDetailScreen(instance: d),
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

// ===========================================================================
// СПРАВОЧНИК МОДЕЛЕЙ
// ===========================================================================

class _ModelsTab extends StatefulWidget {
  const _ModelsTab();

  @override
  State<_ModelsTab> createState() => _ModelsTabState();
}

class _ModelsTabState extends State<_ModelsTab> {
  final _searchCtrl = TextEditingController();
  late Future<List<DeviceModel>> _future;

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
    _future = context
        .read<DatabaseService>()
        .getModels(search: _searchCtrl.text.trim());
  }

  Future<void> _add() async {
    final created = await Navigator.push<DeviceModel>(
      context,
      MaterialPageRoute(builder: (_) => const ModelFormScreen()),
    );
    if (created != null && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Добавить модель'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Марка или модель',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(_load),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DeviceModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const _Empty(
                    icon: Icons.menu_book_outlined,
                    title: 'Справочник пуст',
                    text: 'Добавьте модель со своими характеристиками.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = items[index];
                    return ListTile(
                      title: Text(m.title),
                      subtitle: Text(
                        '${m.skoMmKm} мм/км · ${m.gostClass}'
                        '${m.magnification != null ? ' · ${m.magnification}×' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: m.isCatalog
                          ? const Icon(Icons.chevron_right)
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline,
                                    size: 16, color: AppTheme.textSecondary),
                                Icon(Icons.chevron_right),
                              ],
                            ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ModelDetailScreen(model: m),
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

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _Empty({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
