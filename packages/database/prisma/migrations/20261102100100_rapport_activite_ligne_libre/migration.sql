-- Rapport d'activité : une ligne peut porter un client ou un lieu saisi en texte libre (sans magasin ni prospect de la
-- liste). La contrainte « cible » accepte désormais, hors ADM, soit un magasin, soit un prospect, soit un libellé libre.
ALTER TABLE "tournee_etapes" DROP CONSTRAINT "tournee_etapes_cible_check";
ALTER TABLE "tournee_etapes" ADD CONSTRAINT "tournee_etapes_cible_check"
  CHECK (
    ("adm" AND "clientId" IS NULL AND "prospectId" IS NULL)
    OR (
      NOT "adm" AND (
        ("clientId" IS NOT NULL AND "prospectId" IS NULL)
        OR ("clientId" IS NULL AND "prospectId" IS NOT NULL)
        OR ("clientId" IS NULL AND "prospectId" IS NULL AND "libelle" IS NOT NULL)
      )
    )
  );
