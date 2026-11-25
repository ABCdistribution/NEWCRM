-- Types « appel » et « remplacement » d'une étape de tournée (formulaire de RDV de l'app mobile).
-- Additive et idempotente : deux booléens avec défaut false, lignes existantes inchangées. Aucun DROP, aucun SET NOT NULL.
-- Retour arrière : ALTER TABLE "tournee_etapes" DROP COLUMN IF EXISTS "appel", DROP COLUMN IF EXISTS "remplacement".
ALTER TABLE "tournee_etapes" ADD COLUMN IF NOT EXISTS "appel" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "tournee_etapes" ADD COLUMN IF NOT EXISTS "remplacement" BOOLEAN NOT NULL DEFAULT false;
