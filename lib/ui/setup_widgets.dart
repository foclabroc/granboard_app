// Éléments de la page de réglages « retransmission TV » : bandeau, colonnes,
// lignes de choix, favoris. Couleurs = thème en cours (`Tv`).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/cricket.dart';
import '../game/practice.dart';
import 'theme.dart';
import 'tile_fx.dart';

/// Bandeau doré en biseau en haut de page : retour, titre, actions.
class SetupBand extends StatelessWidget {
  final String title;
  final String sub;
  final List<Widget> actions;
  const SetupBand(
      {super.key, required this.title, this.sub = '', this.actions = const []});

  @override
  Widget build(BuildContext context) {
    // Le dégradé va jusqu'au bord gauche, derrière une éventuelle encoche
    final side = Edge.side(context);
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
                padding: EdgeInsets.only(left: side, right: 40),
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
          SizedBox(width: 6 + side),
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

/// Panneau compact du tableau, avec un contenu éventuellement défilant.
class TableauPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const TableauPanel(
      {super.key, required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tv.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Tv.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tv.title(16, color: Tv.text)),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Expanded(
              child: Material(type: MaterialType.transparency, child: child)),
        ],
      ),
    );
  }
}

/// Une colonne du tableau de configuration.
class SetupColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? header;
  const SetupColumn(
      {super.key, required this.title, required this.children, this.header});

  @override
  Widget build(BuildContext context) => TableauPanel(
        title: title,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          children: [if (header != null) header!, ...children],
        ),
      );
}

/// Ligne de choix : icône, nom, valeur à droite ; surlignée si choisie.
class SetupItem extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;

  /// Icône illustrée (`assets/icons/<x>.jpg`), prioritaire sur [icon].
  final String? image;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool simple;

  /// Couleur de la bande (`Band`) ; null = ligne classique.
  final Color? tint;
  const SetupItem(
      {super.key,
      required this.label,
      this.value,
      this.icon,
      this.image,
      this.selected = false,
      this.onTap,
      this.trailing,
      this.simple = false,
      this.tint});

  Widget _band(Color t) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TileFx(
          seed: label,
          radius: 8,
          shine: .16,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: Band.deco(t, selected: selected, r: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  child: Row(
                    children: [
                      if (image != null) ...[
                        gameArt(image!, 30),
                        const SizedBox(width: 8),
                      ] else if (icon != null) ...[
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Band.text(Tv.title(16))),
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
                                style: Band.text(Tv.title(15)).copyWith(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70)),
                          ),
                        ),
                      if (trailing != null) trailing!,
                      if (selected && value == null && trailing == null)
                        const Icon(Icons.check, size: 17, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (tint != null && !simple) return _band(tint!);
    final c = selected ? Tv.gold : Tv.text;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: simple
            ? Colors.transparent
            : selected
                ? Color.lerp(Tv.panel2, Tv.gold, 0.16)
                : Tv.panel2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: selected && !simple
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Tv.gold))
                : simple
                    ? BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Tv.line.withValues(alpha: 0.6))))
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
                  Icon(Icons.check, size: 17, color: Tv.gold),
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
            simple: true,
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
  final String? image;

  /// Couleur de la bande (`Band`) ; null = ligne classique.
  final Color? tint;
  const SetupSwitch(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.icon,
      this.image,
      this.tint});

  @override
  Widget build(BuildContext context) => SetupItem(
        label: label,
        icon: icon,
        image: image,
        selected: value,
        tint: tint,
        onTap: () => onChanged(!value),
        trailing: Text(value ? 'OUI' : 'NON',
            style: tint != null
                ? Band.text(Tv.title(15))
                    .copyWith(color: value ? Colors.white : Colors.white70)
                : Tv.title(15, color: value ? Tv.gold : Tv.muted)),
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

/// Icône illustrée d'un jeu (images Gemini de foclabroc, 128 px).
Widget gameArt(String asset, double size) => ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => SizedBox(width: size, height: size)),
    );

String x01Art(int start) => 'assets/icons/x01_$start.jpg';
const kFreezeArt = 'assets/icons/x01_freeze.jpg';
String cricketArt(CricketVariant v) => 'assets/icons/cr_${v.name}.jpg';
String practiceArt(PracticeKind k) => 'assets/icons/pr_${k.name}.jpg';

/// Couleur de la bande d'un jeu, choisie d'après son icône.
const kGameTints = <String, Color>{
  'x01_301': Color(0xFF2A93CC),
  'x01_501': Color(0xFFC79A1A),
  'x01_701': Color(0xFF5A6880),
  'x01_901': Color(0xFF94602F),
  'x01_freeze': Color(0xFF4A9CD6),
  'cr_standard': Color(0xFF5A6880),
  'cr_cutThroat': Color(0xFF8048C0),
  'cr_hidden': Color(0xFF3A5CC4),
  'cr_hiddenCutThroat': Color(0xFFB83C92),
  'cr_wildcard': Color(0xFF8048C0),
  'cr_noScore': Color(0xFFC0393B),
  'cr_tripleOnly': Color(0xFF1F9D96),
  'cr_mickeyMouse': Color(0xFFB83C92),
  'pr_countUp': Color(0xFFC79A1A),
  'pr_target20': Color(0xFF3F9E44),
  'pr_targetBull': Color(0xFFC0393B),
  'pr_targetChoice': Color(0xFF1F9D96),
  'pr_targetHat': Color(0xFF5A6880),
  'pr_targetHorse': Color(0xFF94602F),
  'pr_halfIt': Color(0xFF3F9E44),
  'pr_deltaShoot': Color(0xFFD2691E),
  'pr_rotation': Color(0xFF1F9D96),
  'pr_shootForce': Color(0xFFC79A1A),
  'pr_oniren': Color(0xFF5A6880),
  'pr_crCountUp': Color(0xFF3A5CC4),
  'pr_crMultiple': Color(0xFFC79A1A),
  'pr_bobs27': Color(0xFFC0393B),
  'pr_checkout121': Color(0xFF5A6880),
  'pr_spider': Color(0xFF8048C0),
  'pr_pirates': Color(0xFF94602F),
  'pr_funMission': Color(0xFF3F9E44),
  'pr_allFives': Color(0xFF94602F),
  'pr_beyondTop': Color(0xFFD2691E),
  'pr_kickDown': Color(0xFF3A5CC4),
  'pr_twoLine': Color(0xFF3A5CC4),
  'pr_shanghai': Color(0xFFC0393B),
  'pr_hyperBull': Color(0xFFB83C92),
  'pr_hideAndSeek': Color(0xFF1F9D96),
  'pr_killer': Color(0xFF8048C0),
  'pr_treasureHunt': Color(0xFF3F9E44),
  'pr_ticTacToe': Color(0xFF3A5CC4),
  'pr_baseball': Color(0xFF94602F),
  'pr_golf': Color(0xFF3F9E44),
  'pr_scram': Color(0xFFD2691E),
  'pr_football': Color(0xFF3F9E44),
  'pr_hotPotato': Color(0xFFD2691E),
  'pr_catMouse': Color(0xFFC79A1A),
  'pr_paint': Color(0xFFB83C92),
  'pr_bowling': Color(0xFF8048C0),
  'pr_grandPrix': Color(0xFFC0393B),
  'pr_timeAttack': Color(0xFF94602F),
  'pr_tugOfWar': Color(0xFFD2691E),
  'pr_vault': Color(0xFF5A6880),
  'pr_fightClub': Color(0xFFC0393B),
  'pr_connect4': Color(0xFF3A5CC4),
  'pr_snakesLadders': Color(0xFF3F9E44),
  'pr_bowls': Color(0xFF5A6880),
  'pr_conqueror': Color(0xFFD2691E),
  'pr_testMatch': Color(0xFF94602F),
  'pr_snooker': Color(0xFFC0393B),
  'pr_pool': Color(0xFF8048C0),
  'pr_zombies': Color(0xFF3F9E44),
};

/// Couleur de la bande pour l'icône [asset] (null = rampe par défaut).
Color? artTint(String asset) =>
    kGameTints[asset.split('/').last.split('.').first];

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
      PracticeKind.paint => Icons.format_paint,
      PracticeKind.bowling => Icons.sports_baseball,
      PracticeKind.grandPrix => Icons.sports_motorsports,
      PracticeKind.timeAttack => Icons.timer,
      PracticeKind.tugOfWar => Icons.compare_arrows,
      PracticeKind.vault => Icons.lock_open,
      PracticeKind.fightClub => Icons.sports_mma,
      PracticeKind.connect4 => Icons.view_column,
      PracticeKind.snakesLadders => Icons.stairs,
      PracticeKind.bowls => Icons.circle_outlined,
      PracticeKind.conqueror => Icons.flag_circle,
      PracticeKind.testMatch => Icons.sports_cricket,
      PracticeKind.snooker => Icons.workspaces,
      PracticeKind.pool => Icons.sports_baseball_outlined,
      PracticeKind.zombies => Icons.coronavirus,
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
