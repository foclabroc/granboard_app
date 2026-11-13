// Éléments de la page de réglages « retransmission TV » : bandeau, colonnes,
// lignes de choix, favoris. Couleurs = thème en cours (`Tv`).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/cricket.dart';
import '../game/practice.dart';
import 'theme.dart';

/// Bandeau doré en biseau en haut de page : retour, titre, actions.
class SetupBand extends StatelessWidget {
  final String title;
  final String sub;
  final List<Widget> actions;
  const SetupBand(
      {super.key, required this.title, this.sub = '', this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: ClipPath(
              clipper: _Bevel(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Tv.gold, Tv.goldDark]),
                ),
                padding: const EdgeInsets.only(right: 40),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Retour',
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                              text: title.toUpperCase(),
                              style: Tv.title(24, color: Colors.black)),
                          if (sub.isNotEmpty)
                            TextSpan(
                                text: '  ·  ${sub.toUpperCase()}',
                                style: Tv.title(16, color: Colors.black87)),
                        ])),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...actions,
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _Bevel extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width, 0)
    ..lineTo(s.width - 28, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

/// Une colonne : panneau du thème avec un titre et un contenu qui défile.
class SetupColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? header;
  const SetupColumn(
      {super.key, required this.title, required this.children, this.header});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Tv.skin.value.panelColors,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tv.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvSection(title, padding: const EdgeInsets.fromLTRB(10, 8, 10, 4)),
          if (header != null) header!,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de choix : icône, nom, valeur à droite ; surlignée si choisie.
class SetupItem extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  const SetupItem(
      {super.key,
      required this.label,
      this.value,
      this.icon,
      this.selected = false,
      this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = selected ? Tv.gold : Tv.text;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: selected ? Color.lerp(Tv.panel2, Tv.gold, 0.16) : Tv.panel2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: Tv.gold, width: 3)))
                : null,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: selected ? Tv.gold : Tv.muted),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(16, color: c)),
                ),
                if (value != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Tv.title(15, color: selected ? c : Tv.muted)),
                    ),
                  ),
                if (trailing != null) trailing!,
                if (selected && value == null && trailing == null)
                  Icon(Icons.circle, size: 8, color: Tv.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Réglage à plusieurs valeurs : la ligne montre la valeur, un toucher
/// ouvre la liste.
class SetupPick<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) text;
  final ValueChanged<T> onChanged;
  final IconData? icon;
  const SetupPick(
      {super.key,
      required this.label,
      required this.value,
      required this.values,
      required this.text,
      required this.onChanged,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (i) => onChanged(values[i]),
      itemBuilder: (_) => [
        for (var i = 0; i < values.length; i++)
          CheckedPopupMenuItem(
              value: i,
              checked: values[i] == value,
              child: Text(text(values[i]))),
      ],
      child: IgnorePointer(
        child: SetupItem(
            label: label,
            value: text(value),
            icon: icon,
            trailing: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(Icons.arrow_drop_down, size: 18, color: Tv.muted),
            ),
            onTap: () {}),
      ),
    );
  }
}

/// Réglage oui / non.
class SetupSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  const SetupSwitch(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.icon});

  @override
  Widget build(BuildContext context) => SetupItem(
        label: label,
        icon: icon,
        selected: value,
        onTap: () => onChanged(!value),
        trailing: Text(value ? 'OUI' : 'NON',
            style: Tv.title(15, color: value ? Tv.gold : Tv.muted)),
      );
}

/// Petit texte d'aide sous les réglages.
class SetupNote extends StatelessWidget {
  final String text;
  const SetupNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Text(text, style: Tv.label(11.5, color: Tv.muted)),
      );
}

// ─── Icônes des variantes ───

IconData cricketIcon(CricketVariant v) => switch (v) {
      CricketVariant.standard => Icons.close,
      CricketVariant.cutThroat => Icons.content_cut,
      CricketVariant.hidden => Icons.visibility_off,
      CricketVariant.hiddenCutThroat => Icons.visibility_off_outlined,
      CricketVariant.wildcard => Icons.shuffle,
      CricketVariant.noScore => Icons.block,
      CricketVariant.tripleOnly => Icons.filter_3,
      CricketVariant.mickeyMouse => Icons.pets,
    };

IconData practiceIcon(PracticeKind k) => switch (k) {
      PracticeKind.countUp => Icons.trending_up,
      PracticeKind.target20 => Icons.gps_fixed,
      PracticeKind.targetBull => Icons.adjust,
      PracticeKind.targetChoice => Icons.my_location,
      PracticeKind.targetHat => Icons.workspace_premium,
      PracticeKind.targetHorse => Icons.bedroom_baby_outlined,
      PracticeKind.halfIt => Icons.vertical_split,
      PracticeKind.deltaShoot => Icons.change_history,
      PracticeKind.rotation => Icons.rotate_right,
      PracticeKind.shootForce => Icons.bolt,
      PracticeKind.oniren => Icons.repeat,
      PracticeKind.crCountUp => Icons.close,
      PracticeKind.crMultiple => Icons.functions,
      PracticeKind.bobs27 => Icons.looks_two,
      PracticeKind.checkout121 => Icons.flag,
      PracticeKind.spider => Icons.bug_report,
      PracticeKind.pirates => Icons.sailing,
      PracticeKind.funMission => Icons.assignment_turned_in,
      PracticeKind.allFives => Icons.filter_5,
      PracticeKind.beyondTop => Icons.arrow_upward,
      PracticeKind.kickDown => Icons.arrow_downward,
      PracticeKind.twoLine => Icons.grid_on,
      PracticeKind.shanghai => Icons.looks_3,
      PracticeKind.hyperBull => Icons.radio_button_checked,
      PracticeKind.hideAndSeek => Icons.search,
      PracticeKind.killer => Icons.dangerous,
      PracticeKind.treasureHunt => Icons.diamond,
      PracticeKind.ticTacToe => Icons.tag,
      PracticeKind.baseball => Icons.sports_baseball,
      PracticeKind.golf => Icons.golf_course,
      PracticeKind.scram => Icons.swap_horiz,
      PracticeKind.football => Icons.sports_soccer,
      PracticeKind.hotPotato => Icons.local_fire_department,
      PracticeKind.catMouse => Icons.pets,
      PracticeKind.timeAttack => Icons.timer,
    };

IconData x01Icon(int start) => switch (start) {
      301 => Icons.bolt,
      501 => Icons.star,
      701 => Icons.timer,
      _ => Icons.hourglass_bottom,
    };

// ─── Favoris ───

/// Un favori : nom affiché + réglages (jeu et règles, sans les joueurs).
class SetupFavorite {
  final String label;
  final Map<String, dynamic> settings;
  const SetupFavorite(this.label, this.settings);

  Map<String, dynamic> toJson() => {'label': label, 'settings': settings};
  factory SetupFavorite.fromJson(Map<String, dynamic> j) => SetupFavorite(
      '${j['label']}', (j['settings'] as Map).cast<String, dynamic>());
}

/// Favoris de chaque tuile (01, cricket, match, practice, party, tournoi),
/// pref `setup_favs_v1` ; 8 au plus par tuile.
class SetupFavorites {
  static const _pref = 'setup_favs_v1';
  static const max = 8;

  static Future<Map<String, List<SetupFavorite>>> _all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_pref);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', [
            for (final f in v as List)
              SetupFavorite.fromJson((f as Map).cast<String, dynamic>())
          ]));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(Map<String, List<SetupFavorite>> all) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _pref,
          jsonEncode(
              all.map((k, v) => MapEntry(k, [for (final f in v) f.toJson()]))));
    } catch (_) {}
  }

  static Future<List<SetupFavorite>> of(String tile) async =>
      (await _all())[tile] ?? [];

  /// Ajoute (faux si déjà présent ou plein).
  static Future<bool> add(String tile, SetupFavorite f) async {
    final all = await _all();
    final list = all[tile] ?? [];
    final key = jsonEncode(f.settings);
    if (list.any((x) => jsonEncode(x.settings) == key) || list.length >= max) {
      return false;
    }
    all[tile] = [...list, f];
    await _write(all);
    return true;
  }

  static Future<void> remove(String tile, int index) async {
    final all = await _all();
    final list = [...?all[tile]];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    all[tile] = list;
    await _write(all);
  }
}
