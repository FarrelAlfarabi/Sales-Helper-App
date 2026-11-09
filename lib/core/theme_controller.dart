import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pilihan tema aplikasi (terang, gelap, ikuti sistem), diingat antar kunjungan.
class ThemeController {
  ThemeController._();
  static const _key = 'zonein_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode.value = switch (p.getString(_key)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    } catch (_) {}
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, m.name);
    } catch (_) {}
  }

  static String label(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Terang',
        ThemeMode.dark => 'Gelap',
        ThemeMode.system => 'Ikuti perangkat',
      };
}

/// Tombol ikon dengan menu pilihan tema.
class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, m, _) => PopupMenuButton<ThemeMode>(
        tooltip: 'Tema',
        icon: Icon(switch (m) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.brightness_auto_outlined,
        }),
        initialValue: m,
        onSelected: ThemeController.set,
        itemBuilder: (_) => [
          for (final v in ThemeMode.values)
            CheckedPopupMenuItem(value: v, checked: v == m, child: Text(ThemeController.label(v))),
        ],
      ),
    );
  }
}
