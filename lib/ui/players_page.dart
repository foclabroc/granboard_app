import 'package:flutter/material.dart';

import '../players.dart';
import 'widgets.dart';

class PlayersPage extends StatelessWidget {
  const PlayersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PlayerStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Joueurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await askName(context);
          if (name != null) await store.add(name);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.players.isEmpty) {
            return const Center(child: Text('Aucun joueur pour l\'instant'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final p in store.players)
                ListTile(
                  leading: PlayerAvatar.of(p),
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(p.games == 0
                      ? 'Aucune partie'
                      : '${p.games} partie${p.games > 1 ? 's' : ''} · '
                          '${p.winRate} % de victoires · '
                          'moy ${p.average.toStringAsFixed(1)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlayerDetailPage(player: p)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PlayerDetailPage extends StatelessWidget {
  final PlayerProfile player;
  const PlayerDetailPage({super.key, required this.player});

  Future<bool> _confirm(BuildContext context, String title, String text) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final store = PlayerStore.instance;
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = player;
        Widget stat(String label, String value) => Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(value,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(label,
                          style: TextStyle(fontSize: 12, color: cs.outline)),
                    ],
                  ),
                ),
              ),
            );

        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'rename') {
                    final name = await askName(context,
                        title: 'Renommer', initial: p.name);
                    if (name != null) {
                      p.name = name;
                      await store.update(p);
                    }
                  } else if (v == 'color') {
                    p.colorIndex = (p.colorIndex + 1) % kPlayerColors.length;
                    await store.update(p);
                  } else if (v == 'reset') {
                    if (context.mounted &&
                        await _confirm(context, 'Remettre à zéro ?',
                            'Toutes les statistiques de ${p.name} seront effacées.')) {
                      await store.resetStats(p);
                    }
                  } else if (v == 'delete') {
                    if (context.mounted &&
                        await _confirm(context, 'Supprimer ${p.name} ?',
                            'Le joueur et ses statistiques seront supprimés.')) {
                      await store.remove(p);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renommer')),
                  PopupMenuItem(
                      value: 'color', child: Text('Changer de couleur')),
                  PopupMenuItem(
                      value: 'reset', child: Text('Remettre les stats à zéro')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Center(child: PlayerAvatar.of(p, size: 72)),
              const SizedBox(height: 12),
              Row(children: [
                stat('Parties', '${p.games}'),
                stat('Victoires', '${p.wins}'),
                stat('% victoires', '${p.winRate}'),
              ]),
              Row(children: [
                stat('Moyenne', p.average.toStringAsFixed(1)),
                stat('Meilleure fin',
                    p.bestCheckout == 0 ? '–' : '${p.bestCheckout}'),
                stat('Meilleure manche', '${p.highestTurn}'),
              ]),
              Row(children: [
                stat('Manches 100+', '${p.count100}'),
                stat('180', '${p.count180}'),
                stat('Fléchettes', '${p.darts}'),
              ]),
              const SizedBox(height: 16),
              Text('Dernières parties',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.bold)),
              if (p.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucune partie enregistrée'),
                ),
              for (final h in p.history)
                ListTile(
                  dense: true,
                  leading: Icon(h.won ? Icons.emoji_events : Icons.close,
                      color: h.won ? Colors.amber : cs.outline),
                  title: Text(h.mode),
                  subtitle: Text(_date(h.date)),
                  trailing: Text('moy ${h.average.toStringAsFixed(1)}'
                      '${h.checkout == null ? '' : '  ·  fin ${h.checkout}'}'),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
