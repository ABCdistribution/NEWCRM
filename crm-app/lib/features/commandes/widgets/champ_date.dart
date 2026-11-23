import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/regles_commande.dart';

/// Champ date (`.champ input[type=date]`) : étiquette, cadre arrondi, date au format « 16/11/2026 » et calendrier
/// à droite. Un appui ouvre le sélecteur de date. La valeur est une date ISO `aaaa-mm-jj`, vide tant qu'aucune
/// date n'est choisie ; aucune date antérieure à `min` (aujourd'hui par défaut, `min="2026-11-04"`) ni postérieure à
/// `max` (deux ans plus tard par défaut) n'est proposée.
class ChampDate extends StatelessWidget {
  const ChampDate({
    super.key,
    required this.label,
    required this.valeur,
    required this.onChanged,
    this.margeHaut = 0,
    this.min,
    this.max,
  });

  final String label;
  final String valeur;
  final ValueChanged<String> onChanged;
  final double margeHaut;

  /// Première et dernière dates proposées (jours, à minuit) ; par défaut aujourd'hui et fin de la deuxième année suivante.
  final DateTime? min;
  final DateTime? max;

  Future<void> _choisir(BuildContext context) async {
    final premier = min ?? DemoTemps.aujourdhui;
    final dernier = max ?? DateTime(premier.year + 2, 12, 31);
    final actuelle = valeur.isEmpty ? null : DateTime.tryParse(valeur);
    final initiale =
        actuelle != null &&
            !actuelle.isBefore(premier) &&
            !actuelle.isAfter(dernier)
        ? actuelle
        : premier;
    final choix = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: premier,
      lastDate: dernier,
    );
    if (choix == null) return;
    onChanged(
      '${choix.year}-${deuxChiffres(choix.month)}-${deuxChiffres(choix.day)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: margeHaut, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: AppText.etiquetteChamp),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _choisir(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bordureChamp),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valeur.isEmpty ? 'jj/mm/aaaa' : dateJourMoisAnnee(valeur),
                      style: AppText.t(
                        14,
                        c: valeur.isEmpty ? AppColors.muted : AppColors.texte,
                      ),
                    ),
                  ),
                  const AppIcon(AppIcons.cal, size: 16, color: AppColors.texte),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
