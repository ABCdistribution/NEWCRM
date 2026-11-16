import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';

/// Champ « Heure » (`<input type="time">`) : « 09:30 » ou « --:-- » quand il est vide ; un appui ouvre le choix de
/// l'heure du téléphone. Même cadre que `.champ input` (étiquette grise, bord arrondi à 12).
class ChampHeure extends StatelessWidget {
  const ChampHeure({
    super.key,
    required this.valeur,
    required this.onChanged,
    this.label = 'Heure',
  });

  /// Heure saisie au format « HH:MM », vide si aucune.
  final String valeur;
  final ValueChanged<String> onChanged;
  final String label;

  Future<void> _choisir(BuildContext context) async {
    final morceaux = valeur.split(':');
    final depart = morceaux.length == 2
        ? TimeOfDay(
            hour: int.tryParse(morceaux[0]) ?? 0,
            minute: int.tryParse(morceaux[1]) ?? 0,
          )
        : const TimeOfDay(hour: 14, minute: 23);
    final heure = await showTimePicker(
      context: context,
      initialTime: depart,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (heure != null) {
      onChanged('${deuxChiffres(heure.hour)}:${deuxChiffres(heure.minute)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: AppText.etiquetteChamp),
          ),
          Semantics(
            button: true,
            label: label,
            value: valeur,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _choisir(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bordureChamp),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        valeur.isEmpty ? '--:--' : valeur,
                        style: AppText.champ,
                      ),
                    ),
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
