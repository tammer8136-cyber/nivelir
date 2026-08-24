import 'package:flutter/material.dart';

import '../../data/help_articles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/diagrams/level_diagrams.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Справка')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: HelpArticles.all.length,
        itemBuilder: (context, i) {
          final article = HelpArticles.all[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined,
                  color: AppTheme.primary),
              title: Text(article.title),
              subtitle: Text(article.summary),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HelpArticleScreen(article: article),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HelpArticleScreen extends StatelessWidget {
  final HelpArticle article;
  const HelpArticleScreen({super.key, required this.article});

  /// Схемы к статьям. Держатся здесь, а не в тексте статьи: статьи —
  /// это данные, схемы — виджеты.
  List<Widget> _diagramsFor(String id) {
    switch (id) {
      case 'round-level':
        return const [RoundLevelCheckDiagram(), HalfRuleDiagram()];
      case 'rod-level':
        return const [RodLevelDiagram()];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            article.body.trim(),
            style: const TextStyle(fontSize: 15, height: 1.55),
          ),
          for (final d in _diagramsFor(article.id)) ...[
            const SizedBox(height: 20),
            d,
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
