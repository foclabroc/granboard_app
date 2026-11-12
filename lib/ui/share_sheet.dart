import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../update_check.dart';
import 'theme.dart';

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
