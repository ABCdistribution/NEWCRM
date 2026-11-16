import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import 'state/filtres_clients.dart';
import 'widgets/carte_client.dart';

/// Onglet « Clients » (tous les rôles). Maquette : pageMagasins l.689-695 (encadrement) et salesMagasins l.1227-1235
/// (promoteur), liste filtrée `magasinsListe` l.1222-1226.
///
/// Recherche dans le nom et l'adresse, feuille de filtres (portée, enseigne, tri) avec compteur de filtres actifs,
/// une carte par client avec sa classe ; le promoteur bascule entre son portefeuille et tout le secteur.
class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  late final TextEditingController _recherche;

  @override
  void initState() {
    super.initState();
    // La recherche survit au changement d'onglet (`S.mf.q`) : le champ repart de sa dernière valeur.
    _recherche = TextEditingController(
      text: ref.read(filtresClientsProvider).q,
    );
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleActifProvider);
    final promoteur = role == Role.promoteur;
    final filtres = ref.watch(filtresClientsProvider);
    final liste = ref.watch(clientsAffichesProvider);
    final etat = ref.watch(crmProvider);
    final notifier = ref.read(filtresClientsProvider.notifier);
    final mes = filtres.portee == PorteeClients.mes;

    return PageUnivers(
      entete: AppEntete(
        titre: 'Clients',
        sous: sousTitreClients(role, filtres, liste.length),
        extra: BarreRecherche(
          hint: promoteur ? 'Enseigne, ville, code…' : 'Rechercher un client…',
          controller: _recherche,
          onChanged: notifier.rechercher,
          nbFiltres: nbFiltresClients(role, filtres),
          onFiltres: () => AppRoutes.filtresClients(context),
        ),
      ),
      enfants: [
        if (promoteur)
          LienPortee(
            libelle: mes
                ? 'Voir tous les clients du secteur (${etat.tousMagasins.length})'
                : 'Revenir à mon portefeuille (${etat.magasins.length})',
            onTap: () => notifier.choisirPortee(
              mes ? PorteeClients.tous : PorteeClients.mes,
            ),
          ),
        if (liste.isEmpty)
          const Vide('Aucun client.')
        else
          // Pagination : des milliers de clients construits d'un coup bloqueraient l'application.
          ListePaginee<Magasin>(
            elements: liste,
            constructeur: (m) => CarteClient(
              magasin: m,
              onTap: () => AppRoutes.ficheMagasin(context, m.id),
            ),
          ),
      ],
    );
  }
}
