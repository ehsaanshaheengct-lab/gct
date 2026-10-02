import 'package:flutter/material.dart';
import 'package:wasa_core/wasa_core.dart';

/// Government style: WASA blue/teal on white, big text and touch targets,
/// and the same green / orange / red for status everywhere.
class WasaColors {
  const WasaColors._();

  static const blue = Color(0xFF0B5FA5);
  static const blueDark = Color(0xFF08467A);
  static const teal = Color(0xFF0E8C99);
  static const tealLight = Color(0xFFDDF3F5);
  static const background = Color(0xFFF4F7FA);
  static const border = Color(0xFFD9E1E8);
  static const text = Color(0xFF1B2733);
  static const textMuted = Color(0xFF5B6B7A);

  static const green = Color(0xFF2E7D32);
  static const orange = Color(0xFFEF6C00);
  static const red = Color(0xFFC62828);
  static const grey = Color(0xFF78858F);
  static const slate = Color(0xFF455A64);

  static Color vehicleStatus(VehicleStatus s) => switch (s) {
        VehicleStatus.available => green,
        VehicleStatus.onJob => orange,
        VehicleStatus.maintenance => red,
      };

  static Color displayStatus(DisplayStatus s) => switch (s) {
        DisplayStatus.generated => blue,
        DisplayStatus.assigned || DisplayStatus.started || DisplayStatus.reached => orange,
        DisplayStatus.done => teal,
        DisplayStatus.paid => green,
        DisplayStatus.expired => red,
        DisplayStatus.cancelled => grey,
      };

  static Color paymentStatus(PaymentStatus s) => switch (s) {
        PaymentStatus.paid => green,
        PaymentStatus.unpaid => orange,
        PaymentStatus.expired => red,
      };
}

class WasaTheme {
  const WasaTheme._();

  /// Urdu glyphs come from Noto Naskh Arabic; Latin text uses the platform font.
  static const urduFont = 'packages/wasa_ui/NotoNaskhArabic';

  /// [touch] = true gives the larger sizes used by the driver app on phones.
  static ThemeData light({bool touch = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: WasaColors.blue,
      primary: WasaColors.blue,
      secondary: WasaColors.teal,
      surface: Colors.white,
      error: WasaColors.red,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamilyFallback: const [urduFont]);
    final scale = touch ? 1.12 : 1.0;
    // englishLike carries the font sizes, so the touch scale can be applied
    final text = base.typography.englishLike
        .merge(base.textTheme)
        .apply(bodyColor: WasaColors.text, displayColor: WasaColors.text, fontSizeFactor: scale)
        .copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15 * scale, color: WasaColors.text),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17 * scale, color: WasaColors.text),
        );
    final buttonHeight = touch ? 60.0 : 48.0;
    final buttonText = TextStyle(fontSize: touch ? 19 : 16, fontWeight: FontWeight.w600);

    return base.copyWith(
      scaffoldBackgroundColor: WasaColors.background,
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: WasaColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: WasaColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(64, buttonHeight),
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(64, buttonHeight),
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: WasaColors.border),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: touch ? 18 : 14),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: IconThemeData(color: WasaColors.blue),
        indicatorColor: WasaColors.tealLight,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
