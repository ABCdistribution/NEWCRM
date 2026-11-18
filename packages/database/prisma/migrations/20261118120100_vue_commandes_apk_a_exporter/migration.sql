-- Vues de lecture pour l'export des commandes mobiles vers l'ERP (Minos) : seules les commandes VALIDEES, pas encore
-- intégrées (aucune commande ERP ne porte leur IDCRM), sont exportables. Une commande EN_ATTENTE n'apparaît jamais.
-- "dateValidation" = date de référence de l'export : valideeLe si renseignée, sinon createdAt (commandes antérieures
-- au statut) ; une commande validée tard devient donc exportable à sa validation, pas à sa création.
-- Additive. Retour arrière : DROP VIEW "v_commande_apk_lignes_a_exporter" ; DROP VIEW "v_commandes_apk_a_exporter".
CREATE VIEW "v_commandes_apk_a_exporter" AS
SELECT c."id", c."idCommandeApk", c."promoteurId", c."clientId", c."commentaire", c."dateCommande",
       c."valideeLe", COALESCE(c."valideeLe", c."createdAt") AS "dateValidation", c."createdAt", c."updatedAt"
FROM "commandes_apk" c
WHERE c."statut" = 'VALIDEE'
  AND NOT EXISTS (SELECT 1 FROM "commandes" x WHERE x."idCommandeApk" = c."idCommandeApk");

CREATE VIEW "v_commande_apk_lignes_a_exporter" AS
SELECT l."id", l."commandeApkId", l."ordre", l."articleId", l."quantite", l."prixIndicatif"
FROM "commande_apk_lignes" l
JOIN "v_commandes_apk_a_exporter" v ON v."id" = l."commandeApkId";
