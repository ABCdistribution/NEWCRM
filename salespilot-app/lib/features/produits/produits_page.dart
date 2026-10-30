import '../prechargement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import '../tournee/tournee_page.dart' show dateCourte;
import 'produit_repository.dart';

enum _FiltreStock { tous, enStock, bas, rupture }

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

final _euro = NumberFormat('#,##0.00', 'fr');

/// Famille (à défaut gamme) servant de catégorie dans les pastilles.
String? _categorie(Produit p) {
  final f = p.famille?.trim();
  if (f != null && f.isNotEmpty) return f;
  final g = p.gamme?.trim();
  return g != null && g.isNotEmpty ? g : null;
}

/// Référentiel produits d'ABC Sales (maquette) : recherche locale, catégories, filtres, fiche d'un produit.
class ProduitsPage extends ConsumerStatefulWidget {
  const ProduitsPage({super.key});

  @override
  ConsumerState<ProduitsPage> createState() => _ProduitsPageState();
}

class _ProduitsPageState extends ConsumerState<ProduitsPage> {
  var _q = '';
  String? _categorieChoisie;
  var _stock = _FiltreStock.tous;
  var _promo = false;
  var _avant = false;

  int get _nbFiltres => (_stock == _FiltreStock.tous ? 0 : 1) + (_promo ? 1 : 0) + (_avant ? 1 : 0);

  bool _garde(Produit p, List<String> mots) {
    if (_categorieChoisie != null && _categorie(p) != _categorieChoisie) return false;
    if (_promo && !p.enPromo) return false;
    if (_avant && !p.misEnAvant) return false;
    final ok = switch (_stock) {
      _FiltreStock.tous => true,
      _FiltreStock.enStock => p.niveauStock == NiveauStock.enStock,
      _FiltreStock.bas => p.niveauStock == NiveauStock.bas,
      _FiltreStock.rupture => p.niveauStock == NiveauStock.rupture,
    };
    if (!ok) return false;
    if (mots.isEmpty) return true;
    final meule = _norm('${p.libelle} ${p.code} ${p.ean ?? ''} ${p.marque ?? ''} ${p.gamme ?? ''} ${p.famille ?? ''}');
    return mots.every(meule.contains);
  }

  Future<void> _ouvrirFiltres() async {
    var stock = _stock;
    var promo = _promo;
    var avant = _avant;
    final applique = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              const Text('Stock', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final f in _FiltreStock.values)
                  ChoiceChip(
                    label: Text(switch (f) { _FiltreStock.tous => 'Tous', _FiltreStock.enStock => 'En stock', _FiltreStock.bas => 'Stock bas', _FiltreStock.rupture => 'Rupture' }),
                    selected: stock == f,
                    onSelected: (_) => setS(() => stock = f),
                  ),
              ]),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('En promotion'), value: promo, onChanged: (v) => setS(() => promo = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Mis en avant'), value: avant, onChanged: (v) => setS(() => avant = v)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => setS(() {
                      stock = _FiltreStock.tous;
                      promo = false;
                      avant = false;
                    }),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Appliquer'))),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (applique == true) {
      setState(() {
        _stock = stock;
        _promo = promo;
        _avant = avant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(produitsProvider);
    final cached = async.value;
    final tous = cached?.value ?? const <Produit>[];
    final bleu = SpacePalette.sales.accent;

    final mots = _norm(_q.trim()).split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final liste = tous.where((p) => _garde(p, mots)).toList();

    // Catégories : les plus fournies d'abord.
    final compte = <String, int>{};
    for (final p in tous) {
      final c = _categorie(p);
      if (c != null) compte[c] = (compte[c] ?? 0) + 1;
    }
    final categories = (compte.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).map((e) => e.key).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Column(children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 16),
          decoration: BoxDecoration(color: bleu, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Référentiel produits', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    cached == null ? 'Chargement…' : '${tous.length} référence${tous.length > 1 ? 's' : ''} · données du ${dateCourte(cached.fetchedAt).split(' ').skip(1).join(' ')}${cached.fromCache ? ' (hors ligne)' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ]),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Scan du code-barres : bientôt disponible. Saisissez l\'EAN dans la recherche.'))),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Nom, marque, EAN ou code article',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            // Une mise à jour en arrière-plan ne doit pas remplacer la liste par un loader.
            skipLoadingOnReload: true,
            loading: () => const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Premier chargement du référentiel…', style: TextStyle(color: StatusColors.muted)),
              ]),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(errorMessage(e), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => ref.invalidate(produitsProvider), child: const Text('Réessayer')),
                ]),
              ),
            ),
            data: (_) => RefreshIndicator(
              onRefresh: () async {
                await ref.read(miseAJourLocaleProvider).produits();
              },
              // Liste paresseuse : seules les lignes visibles sont construites (le référentiel compte des milliers d'articles).
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: 1 + (liste.isEmpty ? 1 : liste.length),
                itemBuilder: (_, i) {
                  if (i == 0) return _entete(categories, liste.length, bleu);
                  if (liste.isEmpty) {
                    return Container(
                      decoration: _carte(haut: true, bas: true),
                      padding: const EdgeInsets.all(28),
                      child: const Center(child: Text('Aucun produit ne correspond.', style: TextStyle(color: StatusColors.muted))),
                    );
                  }
                  final n = i - 1;
                  return Container(
                    decoration: _carte(haut: n == 0, bas: n == liste.length - 1),
                    child: Column(children: [
                      if (n > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEF0F6)),
                      _Ligne(produit: liste[n], onTap: () => _fiche(liste[n])),
                    ]),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }

  /// Fond blanc bordé d'une ligne ; les coins ne sont arrondis qu'en haut de la première et en bas de la dernière.
  BoxDecoration _carte({required bool haut, required bool bas}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(haut ? 20 : 0), bottom: Radius.circular(bas ? 20 : 0)),
        border: Border(
          left: const BorderSide(color: Color(0xFFE8EAF2)),
          right: const BorderSide(color: Color(0xFFE8EAF2)),
          top: haut ? const BorderSide(color: Color(0xFFE8EAF2)) : BorderSide.none,
          bottom: bas ? const BorderSide(color: Color(0xFFE8EAF2)) : BorderSide.none,
        ),
      );

  Widget _entete(List<String> categories, int nb, Color bleu) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _Pastille(label: 'Tous', actif: _categorieChoisie == null, onTap: () => setState(() => _categorieChoisie = null)),
              for (final c in categories) _Pastille(label: c, actif: _categorieChoisie == c, onTap: () => setState(() => _categorieChoisie = c)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '$nb', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: ' produit${nb > 1 ? 's' : ''}${_categorieChoisie == null ? '' : ' · $_categorieChoisie'}'),
              ]), style: const TextStyle(color: StatusColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            OutlinedButton.icon(
              onPressed: _ouvrirFiltres,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(_nbFiltres == 0 ? 'Filtres' : 'Filtres · $_nbFiltres'),
              style: OutlinedButton.styleFrom(
                foregroundColor: bleu,
                backgroundColor: Colors.white,
                side: BorderSide(color: _nbFiltres == 0 ? const Color(0xFFD1D5DB) : bleu),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ]),
      );

  void _fiche(Produit p) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _FicheProduit(produit: p),
      );
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.label, required this.actif, required this.onTap});

  final String label;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: actif ? const Color(0xFF0B1530) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: actif ? const Color(0xFF0B1530) : const Color(0xFFE5E7EB)),
            ),
            child: Text(label, style: TextStyle(color: actif ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      );
}

(String, Color) _etatStock(Produit p) => switch (p.niveauStock) {
      NiveauStock.enStock => ('En stock', StatusColors.ok),
      NiveauStock.bas => ('Stock bas', const Color(0xFFB45309)),
      NiveauStock.rupture => ('Rupture', StatusColors.alert),
    };

class _Ligne extends StatelessWidget {
  const _Ligne({required this.produit, required this.onTap});

  final Produit produit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final (stockLabel, stockCouleur) = _etatStock(p);
    final bleu = SpacePalette.sales.accent;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(p.libelle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (p.enPromo) _Badge(label: p.promoLibelle?.isNotEmpty == true ? p.promoLibelle! : 'Promo', fond: const Color(0xFFFCE7F3), texte: const Color(0xFFBE185D)),
                if (p.misEnAvant) _Badge(label: 'Mis en avant', fond: bleu.withValues(alpha: .12), texte: bleu),
              ]),
              const SizedBox(height: 3),
              Text(
                [if (p.ean != null && p.ean!.isNotEmpty) 'EAN ${p.ean}', if (p.pcb != null) 'colis ${p.pcb}'].join(' · '),
                style: const TextStyle(color: StatusColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: stockCouleur, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(stockLabel, style: TextStyle(color: stockCouleur, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(p.prix == null ? '—' : '${_euro.format(p.prix)} € HT', style: TextStyle(color: bleu, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 3),
            Text('Réf. ${p.code}', style: const TextStyle(color: StatusColors.muted, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.fond, required this.texte});

  final String label;
  final Color fond;
  final Color texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: texte, fontWeight: FontWeight.w700, fontSize: 11)),
      );
}

class _FicheProduit extends StatelessWidget {
  const _FicheProduit({required this.produit});

  final Produit produit;

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final (stockLabel, _) = _etatStock(p);
    Widget ligne(String k, String? v) => v == null || v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(k, style: const TextStyle(color: StatusColors.muted))),
              Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.libelle, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(p.prix == null ? 'Prix non renseigné' : '${_euro.format(p.prix)} € HT (prix indicatif)', style: TextStyle(color: SpacePalette.sales.accent, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          ligne('Marque', p.marque),
          ligne('Gamme', p.gamme),
          ligne('Famille', p.famille),
          ligne('Code article', p.code),
          ligne('EAN', p.ean),
          ligne('Colisage', p.pcb == null ? null : '${p.pcb} unités par colis'),
          ligne('Stock', '${p.stock} · $stockLabel'),
          if (p.enPromo) ligne('Promotion', p.promoLibelle ?? 'En cours'),
        ]),
      ),
    );
  }
}
