-- Création d'une visite planifiée depuis l'app mobile (POST /plannings) : clé d'idempotence + consigne pour le promoteur.
-- Additive et idempotente : deux colonnes facultatives, lignes existantes inchangées (NULL). Aucun DROP, aucun SET NOT NULL.
-- Retour arrière : DROP INDEX IF EXISTS "plannings_idApk_key" ;
-- ALTER TABLE "plannings" DROP COLUMN IF EXISTS "idApk", DROP COLUMN IF EXISTS "note".
ALTER TABLE "plannings" ADD COLUMN IF NOT EXISTS "idApk" TEXT;
ALTER TABLE "plannings" ADD COLUMN IF NOT EXISTS "note" TEXT;

-- Même forme que l'index généré par Prisma pour `@unique` (les NULL ne se heurtent pas dans Postgres).
CREATE UNIQUE INDEX IF NOT EXISTS "plannings_idApk_key" ON "plannings"("idApk");
