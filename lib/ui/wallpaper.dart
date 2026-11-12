import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thème « Fond d'écran » : une image derrière toutes les pages.
///
/// Choix (pref `wallpaper_v1`) : `random` (une image au hasard à chaque
/// lancement, parmi celles de l'appli et les tiennes), `asset:<n>` (image
/// de l'appli 1 à [assetCount]) ou `file:<nom>` (photo du téléphone, copiée
/// dans `wallpapers/` du dossier de l'appli).
class Wallpaper extends ChangeNotifier {
  Wallpaper._();
  static final instance = Wallpaper._();

  static const assetCount = 9;
  static const _pref = 'wallpaper_v1';

  static String assetPath(int n) => 'assets/wallpapers/w$n.jpg';
  static String thumbPath(int n) => 'assets/wallpapers/t$n.jpg';

  String choice = 'random';

  /// Photos du téléphone ajoutées (noms de fichiers).
  final files = <String>[];

  /// Image affichée en ce moment (tirée au lancement si [choice] = random).
  String _shown = 'asset:1';
  String get shown => _shown;

  Directory? _dir;
  final _rnd = Random();

  /// Pas de lecture du disque en test.
  @visibleForTesting
  static bool storage = true;

  Future<Directory?> _folder() async {
    if (!storage) return null;
    if (_dir != null) return _dir;
    try {
      final d = Directory('${(await getApplicationDocumentsDirectory()).path}'
          '/wallpapers');
      if (!d.existsSync()) d.createSync(recursive: true);
      _dir = d;
    } catch (_) {}
    return _dir;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      choice = p.getString(_pref) ?? 'random';
      files
        ..clear()
        ..addAll(p.getStringList('${_pref}_files') ?? const []);
      final d = await _folder();
      if (d != null) {
        files.removeWhere((f) => !File('${d.path}/$f').existsSync());
      }
    } catch (_) {}
    _pickShown();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_pref, choice);
      await p.setStringList('${_pref}_files', files);
    } catch (_) {}
  }

  /// Toutes les images possibles (« asset:1 »…, « file:… »).
  List<String> get all => [
        for (var i = 1; i <= assetCount; i++) 'asset:$i',
        for (final f in files) 'file:$f',
      ];

  void _pickShown() {
    if (choice == 'random') {
      final list = all;
      _shown = list[_rnd.nextInt(list.length)];
    } else if (choice.startsWith('file:') &&
        !files.contains(choice.substring(5))) {
      choice = 'random';
      _pickShown();
    } else {
      _shown = choice;
    }
  }

  Future<void> choose(String c) async {
    choice = c;
    _pickShown();
    notifyListeners();
    await _save();
  }

  /// Ajoute une photo du téléphone et la choisit. Faux si rien n'a été pris.
  Future<bool> addFromGallery() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85);
    if (x == null) return false;
    final d = await _folder();
    if (d == null) return false;
    final name = 'w${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy('${d.path}/$name');
    files.add(name);
    await choose('file:$name');
    return true;
  }

  Future<void> remove(String name) async {
    files.remove(name);
    final d = await _folder();
    try {
      if (d != null) File('${d.path}/$name').deleteSync();
    } catch (_) {}
    if (choice == 'file:$name') choice = 'random';
    if (_shown == 'file:$name') _pickShown();
    notifyListeners();
    await _save();
  }

  /// Image d'un choix (miniature pour les images de l'appli si [thumb]).
  ImageProvider? imageOf(String c, {bool thumb = false}) {
    if (c.startsWith('asset:')) {
      final n = int.tryParse(c.substring(6)) ?? 1;
      return AssetImage(thumb ? thumbPath(n) : assetPath(n));
    }
    if (c.startsWith('file:') && _dir != null) {
      final f = File('${_dir!.path}/${c.substring(5)}');
      if (!f.existsSync()) return null;
      final ImageProvider img = FileImage(f);
      return thumb ? ResizeImage(img, width: 240) : img;
    }
    return null;
  }

  ImageProvider get current => imageOf(_shown) ?? AssetImage(assetPath(1));

  /// Écran TV : ce que le téléphone affiche (une photo du téléphone n'est
  /// pas envoyée : la TV prend alors une image au hasard).
  String get forTv => _shown.startsWith('asset:') ? _shown : 'random';

  /// Écran TV : applique le choix reçu du téléphone.
  void applyFromPhone(String c) {
    if (c == 'random') {
      if (_shown.startsWith('asset:') && choice == 'tv-random') return;
      choice = 'tv-random';
      _shown = 'asset:${1 + _rnd.nextInt(assetCount)}';
    } else {
      if (_shown == c) return;
      choice = c;
      _shown = c;
    }
    notifyListeners();
  }
}
