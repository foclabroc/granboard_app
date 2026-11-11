import 'package:flutter/material.dart';

import '../players.dart';
import 'account_page.dart';
import 'dartboard.dart';
import 'theme.dart';

/// Premier lancement : création (ou connexion) du profil principal du
/// téléphone. « Plus tard » : on joue sans compte, la page ne revient pas.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))
        ..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _account(bool create) async {
    final p = await showAccountPage(context, create: create);
    if (p == null || !mounted) return;
    final store = PlayerStore.instance;
    await store.setOwner(p);
    await store.setWelcomed();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _later() async {
    await PlayerStore.instance.setWelcomed();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: TvBackground(
          child: SafeArea(
            child: Stack(children: [
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, c) => RotationTransition(
                          turns: _spin,
                          child: Dartboard(
                              size: (c.maxHeight * 0.82)
                                  .clamp(100.0, c.maxWidth * 0.9)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 12, 28, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BIENVENUE SUR', style: Tv.label(16)),
                            ShaderMask(
                              shaderCallback: (r) =>
                                  Tv.goldGradient.createShader(r),
                              child: Text('FOCLABOARD',
                                  style: Tv.title(52, color: Colors.white)
                                      .copyWith(letterSpacing: 4)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Crée ton profil principal : ta photo, ton son, ta note '
                              'et tes stats te suivent sur tous tes appareils.',
                              style: Tv.title(18, color: Tv.text),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14)),
                                onPressed: () => _account(true),
                                icon: const Icon(Icons.person_add),
                                label: Text('CRÉER MON PROFIL',
                                    style: Tv.title(20, color: Colors.black)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12)),
                                onPressed: () => _account(false),
                                icon: const Icon(Icons.login),
                                label: Text('J\'AI DÉJÀ UN COMPTE',
                                    style: Tv.title(18)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 4,
                right: 8,
                child: TextButton(
                  onPressed: _later,
                  child:
                      Text('PLUS TARD', style: Tv.label(14, color: Tv.muted)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
