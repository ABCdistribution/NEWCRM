-- « Ne pas livrer avant » sur la commande mobile (jour + motif) et exposition dans les vues d'export Minos.
-- Additive : colonnes nullables ; les vues sont recréées avec les nouvelles colonnes ajoutées à la fin.
-- Retour arrière : recréer les vues sans les deux dernières colonnes (migration 20261118120100), puis
-- ALTER TABLE "commandes_apk" DROP COLUMN "nePasLivrerAvant", DROP COLUMN "motifNePasLivrerAvant".
ALTER TABLE "commandes_apk" ADD COLUMN "nePasLivrerAvant" DATE;
ALTER TABLE "commandes_apk" ADD COLUMN "motifNePasLivrerAvant" TEXT;

CREATE OR REPLACE VIEW "v_commandes_apk_a_exporter" AS
SELECT c."id", c."idCommandeApk", c."promoteurId", c."clientId", c."commentaire", c."dateCommande",
       c."valideeLe", COALESCE(c."valideeLe", c."createdAt") AS "dateValidation", c."createdAt", c."updatedAt",
       c."nePasLivrerAvant", c."motifNePasLivrerAvant"
FROM "commandes_apk" c
WHERE c."statut" = 'VALIDEE'
  AND NOT EXISTS (SELECT 1 FROM "commandes" x WHERE x."idCommandeApk" = c."idCommandeApk");

CREATE OR REPLACE VIEW "v_commande_apk_lignes_a_exporter" AS
SELECT l."id", l."commandeApkId", l."ordre", l."articleId", l."quantite", l."prixIndicatif",
       v."nePasLivrerAvant", v."motifNePasLivrerAvant"
FROM "commande_apk_lignes" l
JOIN "v_commandes_apk_a_exporter" v ON v."id" = l."commandeApkId";
