import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Message éphémère en bas d'écran (`.toast`) : fond sombre, 2,6 s, un seul à la fois.
///
/// ```dart
/// AppToast.show(context, 'Prospect créé. Envoi dès que le réseau le permet.');
/// ```
/// Il s'affiche au-dessus des feuilles et dialogues et ne bloque aucun appui.
class AppToast {
  const AppToast._();

  static OverlayEntry? _courant;

  /// Affiche `message` ; remplace le message précédent. Sans effet si aucun `Overlay` n'est disponible.
  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _retirer();
    late final OverlayEntry entree;
    entree = OverlayEntry(
      builder: (_) => _ToastVue(
        message: message,
        onFin: () {
          if (identical(_courant, entree)) _retirer();
        },
      ),
    );
    _courant = entree;
    overlay.insert(entree);
  }

  static void _retirer() {
    final e = _courant;
    _courant = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _ToastVue extends StatefulWidget {
  const _ToastVue({required this.message, required this.onFin});
  final String message;
  final VoidCallback onFin;

  @override
  State<_ToastVue> createState() => _ToastVueState();
}

class _ToastVueState extends State<_ToastVue> {
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
    _minuterie = Timer(const Duration(milliseconds: 2600), widget.onFin);
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bas = MediaQuery.viewPaddingOf(context).bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 84 + bas,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  offset: Offset(0, 6),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: AppText.t(13.5, c: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
