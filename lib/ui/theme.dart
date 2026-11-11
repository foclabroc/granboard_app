import 'package:flutter/material.dart';

/// Palette « retransmission TV » : noir profond, or, rouge et vert de cible.
class Tv {
  static const bg = Color(0xFF07070A);
  static const panel = Color(0xFF121218);
  static const panel2 = Color(0xFF1B1B23);
  static const line = Color(0xFF2A2A35);
  static const gold = Color(0xFFE8B63C);
  static const goldLight = Color(0xFFFFD877);
  static const goldDark = Color(0xFF8C6716);
  static const red = Color(0xFFD7262F);
  static const green = Color(0xFF1AA155);
  static const cream = Color(0xFFEEE2C4);
  static const text = Color(0xFFF4F4F6);
  static const muted = Color(0xFF8D8D9C);
  static const ice = Color(0xFF7FD3FF);

  static const font = 'Barlow';

  static const goldGradient = LinearGradient(
    colors: [goldLight, gold, goldDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const panelGradient = LinearGradient(
    colors: [Color(0xFF1D1D26), Color(0xFF0E0E13)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static TextStyle title(double size, {Color color = text}) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.0,
        letterSpacing: 0.5,
      );

  static TextStyle label(double size, {Color color = muted}) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1.2,
      );

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      primary: gold,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF3A2C0A),
      onPrimaryContainer: goldLight,
      secondary: green,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF0E3A22),
      onSecondaryContainer: Colors.white,
      error: red,
      errorContainer: Color(0xFF4A0E12),
      surface: panel,
      onSurface: text,
      surfaceContainer: panel,
      surfaceContainerHigh: panel2,
      surfaceContainerHighest: line,
      outline: muted,
      outlineVariant: line,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: font,
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: title(24, color: gold).copyWith(letterSpacing: 1.5),
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          textStyle: title(18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: line, width: 1.5),
          textStyle: title(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: panel2,
        selectedColor: gold,
        side: const BorderSide(color: line),
        labelStyle: title(16),
        secondaryLabelStyle: title(16, color: Colors.black),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(title(15)),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? gold : panel2),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Colors.black : text),
          side: const WidgetStatePropertyAll(BorderSide(color: line)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.black : muted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? gold : panel2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel2,
        contentTextStyle: title(16),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: line,
    );
  }
}

/// Titre de section façon bandeau TV (barre or à gauche).
class TvSection extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const TvSection(this.text,
      {super.key, this.padding = const EdgeInsets.fromLTRB(16, 22, 16, 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(width: 4, height: 18, color: Tv.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tv.label(15, color: Tv.gold)),
          ),
        ],
      ),
    );
  }
}

/// Fond sombre avec léger dégradé et halo or en haut.
class TvBackground extends StatelessWidget {
  final Widget child;
  const TvBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.3,
          colors: [Color(0xFF2A210C), Tv.bg],
          stops: [0, 0.7],
        ),
      ),
      child: child,
    );
  }
}
