import 'package:crm_app/core/ui/ui.dart';

/// Lanceur d'applications externes pour les tests : garde les adresses demandées au lieu de les ouvrir.
/// `reussit` faux simule un téléphone sans application pour gérer l'adresse.
class LanceurFactice implements LanceurExterne {
  LanceurFactice({this.reussit = true});

  final bool reussit;
  final List<Uri> ouverts = [];

  @override
  Future<bool> ouvrir(Uri uri) async {
    ouverts.add(uri);
    return reussit;
  }
}
