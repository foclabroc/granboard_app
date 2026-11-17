import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../update_check.dart';
import 'theme.dart';

/// Texte du SMS de partage (lien direct vers l'APK).
String shareSmsText() =>
    'Viens jouer aux fléchettes avec Foclaboard ! Télécharge l\'appli '
    '(Android) : $kApkLink';

/// Ouvre l'appli SMS avec le message pré-rempli (destinataire à choisir).
Future<bool> shareBySms() async {
  final uri = Uri(
      scheme: 'sms',
      path: '',
      query: 'body=${Uri.encodeComponent(shareSmsText())}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// QR code à faire scanner : il télécharge directement la dernière version
/// de l'APK (nom fixe « Foclaboard.apk » dans la dernière release).
Future<void> showShareSheet(BuildContext context) => showAppSheet(
      context,
      builder: (ctx) => LayoutBuilder(
        builder: (ctx, c) {
          final side = (c.maxHeight - 40).clamp(160.0, 300.0);
          final qr = Container(
            key: const ValueKey('share-qr'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: QrImageView(
              data: kApkLink,
              size: side - 24,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          );
          final text = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PARTAGER FOCLABOARD', style: Tv.title(24, color: Tv.gold)),
              const SizedBox(height: 8),
              Text(
                  'Fais scanner ce QR code : le téléphone télécharge '
                  'directement la dernière version de l\'appli.',
                  style: Tv.title(16)),
              const SizedBox(height: 12),
              Text(
                  'Puis ouvrir le fichier Foclaboard.apk et accepter '
                  '« installer des applis inconnues » si Android le demande. '
                  'Android seulement.',
                  style: Tv.label(12)),
              const SizedBox(height: 12),
              SelectableText(kApkLink, style: Tv.label(11)),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('share-sms'),
                style: FilledButton.styleFrom(
                    backgroundColor: Tv.gold, foregroundColor: Colors.black),
                onPressed: () async {
                  final ok = await shareBySms();
                  if (!ok && ctx.mounted) {
                    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(const SnackBar(
                        content: Text('Impossible d\'ouvrir les SMS')));
                  }
                },
                icon: const Icon(Icons.sms),
                label: Text('ENVOYER PAR SMS', style: Tv.title(16, color: Colors.black)),
              ),
            ],
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                qr,
                const SizedBox(width: 20),
                Expanded(child: SingleChildScrollView(child: text)),
              ],
            ),
          );
        },
      ),
    );
