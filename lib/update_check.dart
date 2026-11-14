import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Mise à jour dans l'appli (GitHub Releases de foclabroc/granboard_app)
// À chaque nouvelle version : changer kAppVersion ET « version: » du
// pubspec.yaml, ajouter la section « ## vX.Y.Z » au CHANGELOG.md, puis lancer
// le workflow APK avec « publier » coché (release vX.Y.Z + granboard.VX.Y.Z.apk).
// ═══════════════════════════════════════════════════════════════════════════

/// Version de l'application (identique au pubspec.yaml, sans le « +N »).
const kAppVersion = '0.6.13';

const _apiLatest =
    'https://api.github.com/repos/foclabroc/granboard_app/releases/latest';

/// Lien direct de la dernière version (copie à nom fixe faite par le
/// workflow) : QR code de « Partager l'appli ».
const kApkLink =
    'https://github.com/foclabroc/granboard_app/releases/latest/download/Foclaboard.apk';

const _releasesPage =
    'https://github.com/foclabroc/granboard_app/releases/latest';

class AppUpdate {
  final String latest; // ex. « 0.2.0 »
  final String pageUrl; // page de la release
  final String? apkUrl; // lien direct de l'APK
  const AppUpdate(this.latest, this.pageUrl, this.apkUrl);
}

/// Renvoie la mise à jour disponible, ou null (à jour, hors ligne, erreur…).
/// La version est lue dans le nom de l'APK : « granboard.V0.2.0.apk ».
Future<AppUpdate?> checkAppUpdate({bool throwOnError = false}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client.getUrl(Uri.parse(_apiLatest));
    req.headers.add('Accept', 'application/vnd.github+json');
    req.headers.add('User-Agent', 'granboard-update-check');
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode == 404) return null; // pas encore de release
    if (res.statusCode != 200) {
      if (throwOnError) throw HttpException('HTTP ${res.statusCode}');
      return null;
    }
    final data = jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    final pattern = RegExp(r'V(\d+(?:\.\d+){1,3})\.apk$', caseSensitive: false);
    String? best, apk;
    for (final a in (data['assets'] as List? ?? const [])) {
      final m = a as Map<String, dynamic>;
      final match = pattern.firstMatch(m['name'] as String? ?? '');
      if (match == null) continue;
      final v = match.group(1)!;
      if (best == null || _compare(v, best) > 0) {
        best = v;
        apk = m['browser_download_url'] as String?;
      }
    }
    if (best == null || _compare(best, kAppVersion) <= 0) return null;
    return AppUpdate(best, data['html_url'] as String? ?? _releasesPage, apk);
  } catch (_) {
    if (throwOnError) rethrow;
    return null;
  } finally {
    client.close();
  }
}

/// Compare « 1.10.0 » et « 1.9.2 » segment par segment (> 0 si a > b).
int _compare(String a, String b) {
  final pa =
      a.split(RegExp(r'[.+-]')).map((p) => int.tryParse(p) ?? 0).toList();
  final pb =
      b.split(RegExp(r'[.+-]')).map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Accès à la vérification manuelle (bouton dans l'appli).
final updateGateKey = GlobalKey<UpdateGateState>();

/// Enveloppe l'écran d'accueil : vérifie une fois au lancement.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => UpdateGateState();
}

class UpdateGateState extends State<UpdateGate> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      Future.delayed(const Duration(seconds: 2), check);
    }
  }

  /// 0 : à jour, 1 : mise à jour proposée, 2 : hors ligne (seulement si manual).
  Future<int> check({bool manual = false}) async {
    AppUpdate? u;
    try {
      u = await checkAppUpdate(throwOnError: manual);
    } catch (_) {
      return 2;
    }
    if (u == null || !mounted) return 0;
    final upd = u;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(update: upd),
    );
    return 1;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── Fenêtre : téléchargement dans l'appli + installateur Android ───
class _UpdateDialog extends StatefulWidget {
  final AppUpdate update;
  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  // 0 : question, 1 : téléchargement, 2 : prêt à installer, 3 : erreur
  int _step = 0;
  double _progress = 0; // 0 à 1 (−1 = taille inconnue)
  String? _apkPath;
  String _info = '';
  HttpClient? _client;
  bool _cancelled = false;

  @override
  void dispose() {
    _cancelled = true;
    _client?.close(force: true);
    super.dispose();
  }

  Future<void> _download() async {
    final url = widget.update.apkUrl;
    if (url == null) {
      _openPage();
      return;
    }
    setState(() {
      _step = 1;
      _progress = 0;
      _info = '';
    });
    final client =
        _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/granboard_update.apk');
      final req = await client.getUrl(Uri.parse(url)); // redirection suivie
      req.headers.add('User-Agent', 'granboard-updater');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res) {
        if (_cancelled) break;
        sink.add(chunk);
        got += chunk.length;
        if (mounted) setState(() => _progress = total > 0 ? got / total : -1);
      }
      await sink.close();
      if (_cancelled) return;
      if (total > 0 && got < total) {
        throw const FileSystemException('incomplet');
      }
      _apkPath = file.path;
      if (!mounted) return;
      setState(() => _step = 2);
      await _install();
    } catch (_) {
      if (!mounted || _cancelled) return;
      setState(() {
        _step = 3;
        _info = 'Téléchargement impossible. Essaie depuis la page GitHub.';
      });
    } finally {
      client.close(force: true);
      _client = null;
    }
  }

  /// Ouvre l'installateur Android (confirmation avec « Installer »).
  Future<void> _install() async {
    final path = _apkPath;
    if (path == null) return;
    final r = await OpenFilex.open(path,
        type: 'application/vnd.android.package-archive');
    if (!mounted) return;
    setState(() => _info = r.type == ResultType.done
        ? ''
        : 'Autorise « Installer des applis inconnues » pour Foclaboard, '
            'puis appuie sur Installer.');
  }

  void _openPage() {
    Navigator.of(context).pop();
    launchUrl(Uri.parse(widget.update.pageUrl),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _progress < 0 ? null : _progress;
    return PopScope(
      canPop: _step != 1,
      child: AlertDialog(
        title: const Text('Nouvelle version disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version installée : $kAppVersion'),
            Text('Nouvelle version : ${widget.update.latest}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_step == 1) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: pct),
              const SizedBox(height: 4),
              Text(pct == null
                  ? 'Téléchargement…'
                  : 'Téléchargement : ${(pct * 100).round()} %'),
            ],
            if (_step == 2) ...[
              const SizedBox(height: 8),
              const Text(
                  'Téléchargé ! Confirme avec « Installer » dans la fenêtre d\'Android.',
                  style: TextStyle(color: Colors.greenAccent)),
            ],
            if (_info.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_info, style: const TextStyle(color: Colors.amberAccent)),
            ],
          ],
        ),
        actions: [
          if (_step == 0) ...[
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Plus tard')),
            FilledButton.icon(
              autofocus: true, // télécommande TV : OK direct
              onPressed: _download,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Installer'),
            ),
          ],
          if (_step == 1)
            TextButton(
              onPressed: () {
                _cancelled = true;
                _client?.close(force: true);
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
          if (_step == 2) ...[
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer')),
            FilledButton.icon(
              autofocus: true, // télécommande TV : OK direct
              onPressed: _install,
              icon: const Icon(Icons.install_mobile_rounded, size: 18),
              label: const Text('Installer'),
            ),
          ],
          if (_step == 3) ...[
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer')),
            FilledButton.icon(
              autofocus: true, // télécommande TV : OK direct
              onPressed: _openPage,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('GitHub'),
            ),
          ],
        ],
      ),
    );
  }
}
