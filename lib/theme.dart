import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData baseTheme(BuildContext context) {
  return ThemeData(
    popupMenuTheme: PopupMenuThemeData(
      menuPadding: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: null,
      elevation: 0,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

ColorScheme customColorScheme =
    ColorScheme.fromSeed(seedColor: Colors.deepOrange);
ColorScheme customDarkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.deepOrange, brightness: Brightness.dark);

class CustomTheme {
  final ThemeData light;
  final ThemeData dark;

  CustomTheme({required this.light, required this.dark});
}

CustomTheme getTheme({
  required BuildContext context,
  required ColorScheme? lightDynamic,
  required ColorScheme? darkDynamic,
}) {
  ColorScheme colorScheme =
      lightDynamic != null ? lightDynamic.harmonized() : customColorScheme;
  ColorScheme darkColorScheme =
      darkDynamic != null ? darkDynamic.harmonized() : customDarkColorScheme;

  final lightTheme = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    textTheme: GoogleFonts.notoSansScTextTheme(),
    popupMenuTheme: baseTheme(context).popupMenuTheme,
    dropdownMenuTheme: baseTheme(context).dropdownMenuTheme,
    listTileTheme: baseTheme(context).listTileTheme,
  );

  final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
    colorScheme: darkColorScheme,
    textTheme: GoogleFonts.notoSansScTextTheme(
      ThemeData.dark(useMaterial3: true)
          .copyWith(colorScheme: darkColorScheme)
          .textTheme,
    ),
    popupMenuTheme: baseTheme(context).popupMenuTheme,
    dropdownMenuTheme: baseTheme(context).dropdownMenuTheme,
    listTileTheme: baseTheme(context).listTileTheme,
  );

  return CustomTheme(light: lightTheme, dark: darkTheme);
}
