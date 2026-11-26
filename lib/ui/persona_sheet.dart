import 'package:flutter/material.dart';

import '../audio.dart';
import '../format.dart';
import '../game/bot.dart';
import '../game/personas.dart';
import '../rank.dart';
import 'theme.dart';

/// Galerie des adversaires virtuels (« Ajouter des joueurs ›
/// ADVERSAIRES ») : cartes à gauche, fiche du personnage à droite. Renvoie
/// le personnage choisi (null = fermé). [taken] = déjà dans la partie.
Future<Persona?> showPersonaSheet(BuildContext context,
    {Set<String> taken = const {}}) {
  return showAppSheet<Persona>(
    context,
    builder: (ctx) => _PersonaGallery(taken: taken),
  );
}

class _PersonaGallery extends StatefulWidget {
  final Set<String> taken;
  const _PersonaGallery({required this.taken});

  @override
  State<_PersonaGallery> createState() => _PersonaGalleryState();
}

class _PersonaGalleryState extends State<_PersonaGallery> {
  final rec = PersonaRecords.instance;
  late Persona _sel = kPersonas.lastWhere(rec.unlocked);
  int _quote = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rec,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ADVERSAIRES VIRTUELS',
                style: Tv.title(22, color: Tv.goldLight)),
            Text('Bats un adversaire pour débloquer le suivant',
                style: Tv.label(13)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, box) {
              final side = box.maxWidth < 560;
              final grid = _grid(side ? box.maxWidth : box.maxWidth * .58);
              final card = _detail();
              return side
                  ? Column(children: [grid, const SizedBox(height: 10), card])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 58, child: grid),
                        const SizedBox(width: 12),
                        Expanded(flex: 42, child: card),
                      ],
                    );
            }),
          ],
        ),
      ),
    );
  }

  Widget _grid(double _) => LayoutBuilder(builder: (context, box) {
        const cols = 5;
        final w = ((box.maxWidth - (cols - 1) * 8) / cols).floorToDouble();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final p in kPersonas) _card(p, w)],
        );
      });

  Widget _card(Persona p, double w) {
    final open = rec.unlocked(p);
    final (wins, losses) = rec.of(p.id);
    final sel = p == _sel;
    final rank = rankOf(p.note);
    return GestureDetector(
      key: ValueKey('persona-${p.id}'),
      onTap: () => setState(() {
        _sel = p;
        _quote = 0;
      }),
      child: Container(
        width: w,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1020),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? Colors.white : p.color, width: 2),
          boxShadow: [
            BoxShadow(
                color: p.color.withValues(alpha: sel ? .8 : .45),
                blurRadius: sel ? 16 : 8)
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              ColorFiltered(
                colorFilter: open
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : const ColorFilter.matrix([
                        .07, .07, .07, 0, 0, //
                        .07, .07, .07, 0, 0,
                        .07, .07, .07, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: Image.asset(p.asset, fit: BoxFit.cover),
              ),
              if (!open)
                const Center(
                    child: Icon(Icons.lock, color: Colors.white70, size: 26)),
              if (wins + losses > 0)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text('$wins V · $losses D',
                        style: Tv.title(10,
                            color: wins >= losses ? Tv.green : Tv.red)),
                  ),
                ),
              if (widget.taken.contains(p.playerId))
                Positioned(
                  left: 3,
                  top: 3,
                  child: Icon(Icons.check_circle, color: p.color, size: 18),
                ),
            ]),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(p.name, style: Tv.title(15, color: Colors.white)),
          ),
          Text('${rank.label} · NOTE ${p.note.round()}',
              style: Tv.title(10, color: p.color)),
          const SizedBox(height: 3),
        ]),
      ),
    );
  }

  Widget _detail() {
    final p = _sel;
    final open = rec.unlocked(p);
    final (wins, losses) = rec.of(p.id);
    final rank = rankOf(p.note);
    final i = kPersonas.indexOf(p);
    final ppr = bandValue(p.note, kPprBounds),
        mpr = bandValue(p.note, kMprBounds);
    final taken = widget.taken.contains(p.playerId);
    return Container(
      key: const ValueKey('persona-detail'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0B0D16), p.color, .3)!,
            const Color(0xFF0B0D16)
          ],
        ),
        border: Border.all(color: p.color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.color, width: 2),
                boxShadow: [BoxShadow(color: p.color, blurRadius: 14)],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(p.asset, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(p.name,
                          style: Tv.title(32, color: Colors.white))),
                  Text(p.title, style: Tv.label(14)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: rank.color, width: 1.5),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${rank.label} · ${p.note.fr(2)}',
                        style: Tv.title(15, color: rank.color)),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _stat(ppr.fr(1), 'MOYENNE 01'),
            const SizedBox(width: 6),
            _stat(mpr.fr(2), 'MPR CRICKET'),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
                border: Border(left: BorderSide(color: p.color, width: 3))),
            child: Text('« ${p.quotes[_quote]} »',
                style: Tv.label(15)
                    .copyWith(fontStyle: FontStyle.italic, color: Tv.cream)),
          ),
          const SizedBox(height: 6),
          Text(
            !open
                ? 'Bats d\'abord ${kPersonas[i - 1].name} pour le débloquer.'
                : wins + losses == 0
                    ? 'Jamais affronté.'
                    : 'Contre toi : ${plural(wins, 'victoire')} · ${plural(losses, 'défaite')}',
            style: Tv.label(13),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('persona-listen'),
                onPressed: () {
                  AudioService.instance.say(p.quotes[_quote]);
                  setState(() => _quote = (_quote + 1) % p.quotes.length);
                },
                child: Text('ÉCOUTER', style: Tv.title(15)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton(
                key: const ValueKey('persona-add'),
                style: FilledButton.styleFrom(
                    backgroundColor: p.color, foregroundColor: Colors.black),
                onPressed:
                    open && !taken ? () => Navigator.pop(context, p) : null,
                child: Text(taken ? 'DÉJÀ DANS LA PARTIE' : 'AJOUTER',
                    style: Tv.title(16)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String v, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(v, style: Tv.title(20, color: Colors.white)),
            Text(label, style: Tv.label(10)),
          ]),
        ),
      );
}
