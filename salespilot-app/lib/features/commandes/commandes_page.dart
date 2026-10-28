import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Emplacement du module Commande (CDC §3.5) : recherche d'articles, colisage, récapitulatif. Pas encore développé.
class CommandesPage extends StatelessWidget {
  const CommandesPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shopping_cart_outlined, size: 40, color: StatusColors.muted),
            SizedBox(height: 12),
            Text('Commandes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Ce module arrive bientôt.', style: TextStyle(color: StatusColors.muted)),
          ]),
        ),
      );
}
