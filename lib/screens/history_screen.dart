import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verification.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../state/app_settings.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import 'verification_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Verification>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = context.read<DatabaseService>().getVerifications();
  }

  Future<void> _exportExcel() async {
    final db = context.read<DatabaseService>();
    final isMm = context.read<AppSettings>().isMillimeters;
    final all = await db.getVerifications(withRuns: true);

    if (all.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История пуста')),
      );
      return;
    }

    await ExcelExportService.shareJournal(
      verifications: all,
      isMillimeters: isMm,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История поверок'),
        actions: [
          IconButton(
            tooltip: 'Журнал в Excel',
            icon: const Icon(Icons.table_view_outlined),
            onPressed: _exportExcel,
          ),
        ],
      ),
      body: FutureBuilder<List<Verification>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Поверок пока нет', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final v = items[i];
              return Card(
                child: ListTile(
                  leading: Icon(
                    v.isPass ? Icons.check_circle : Icons.error,
                    color: v.isPass ? AppTheme.success : AppTheme.error,
                  ),
                  title: Text(v.deviceLabel),
                  subtitle: Text(
                    '${Units.dateTime.format(v.createdAt)}\n'
                    'i = ${Units.signedArcsec(v.iAngleArcsec)} · '
                    'допуск ${Units.arcsec(v.toleranceArcsecSnapshot)}'
                    '${v.adjusted ? " · юстирован" : ""}',
                  ),
                  isThreeLine: true,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VerificationDetailScreen(verification: v),
                      ),
                    );
                    if (mounted) setState(_load);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
