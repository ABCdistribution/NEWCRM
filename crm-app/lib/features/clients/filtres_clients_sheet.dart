import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'state/filtres_clients.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `mfiltres` l.1369-1377.
/// Appelée par `AppRoutes.filtresClients(context)`.
Future<void> ouvrirFiltresClients(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const FiltresClientsSheet());

/// Valeur de la liste d'enseignes pour « Toutes les enseignes » (`<option value="toutes">`).
const String _toutesEnseignes = 'toutes';

/// Feuille « Filtres » : afficher (mon portefeuille / tous, sauf pour le chef de secteur), enseigne, tri (nom,
/// classification), « Réinitialiser » et « Voir N clients ». Chaque choix s'applique tout de suite à la liste.
class FiltresClientsSheet extends ConsumerWidget {
  const FiltresClientsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final etat = ref.watch(crmProvider);
    final filtres = ref.watch(filtresClientsProvider);
    final notifier = ref.read(filtresClientsProvider.notifier);
    final nb = ref.watch(clientsAffichesProvider).length;
    final dir = role == Role.dir;
    final enseignes = enseignesDe(baseClients(etat, filtres.portee));

    return FeuilleBase(
      titre: 'Filtres',
      children: [
        if (role != Role.cs) ...[
          const TitreFiltre('Afficher'),
          OptionRadio(
            label: dir ? 'Tous les clients' : 'Mon portefeuille',
            detail: '(${nbClientsMes(etat)})',
            selectionne: filtres.portee == PorteeClients.mes,
            onTap: () => notifier.choisirPortee(PorteeClients.mes),
          ),
          OptionRadio(
            label: dir ? 'Clients de ma région' : 'Tous les clients du secteur',
            detail: '(${etat.tousMagasins.length})',
            selectionne: filtres.portee == PorteeClients.tous,
            onTap: () => notifier.choisirPortee(PorteeClients.tous),
          ),
        ],
        const TitreFiltre('Enseigne'),
        _ListeEnseignes(
          // Comme le `<select>` de la maquette : une enseigne absente de la base courante laisse « Toutes les
          // enseignes » affiché, alors que le filtre reste appliqué.
          valeur: enseignes.contains(filtres.ens)
              ? filtres.ens!
              : _toutesEnseignes,
          enseignes: enseignes,
          onChanged: (e) =>
              notifier.choisirEnseigne(e == _toutesEnseignes ? null : e),
        ),
        const TitreFiltre('Trier par'),
        OptionRadio(
          label: 'Nom (A → Z)',
          selectionne: filtres.tri == TriClients.nom,
          onTap: () => notifier.choisirTri(TriClients.nom),
        ),
        OptionRadio(
          label: 'Classification (A → G)',
          selectionne: filtres.tri == TriClients.classe,
          onTap: () => notifier.choisirTri(TriClients.classe),
        ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: notifier.reinitialiser,
            ),
            AppBouton(
              'Voir ${pluriel(nb, 'client')}',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Liste déroulante des enseignes (`.champ select`, sans étiquette), marge basse de 6.
class _ListeEnseignes extends StatelessWidget {
  const _ListeEnseignes({
    required this.valeur,
    required this.enseignes,
    required this.onChanged,
  });

  final String valeur;
  final List<String> enseignes;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cadre = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordureChamp),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: cadre,
          enabledBorder: cadre,
          focusedBorder: cadre,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: valeur,
            isDense: true,
            isExpanded: true,
            style: AppText.champ,
            dropdownColor: Colors.white,
            icon: const AppIcon(
              AppIcons.chevronBas,
              size: 16,
              color: AppColors.texte,
            ),
            items: [
              const DropdownMenuItem(
                value: _toutesEnseignes,
                child: Text('Toutes les enseignes'),
              ),
              for (final e in enseignes)
                DropdownMenuItem(
                  value: e,
                  child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}
