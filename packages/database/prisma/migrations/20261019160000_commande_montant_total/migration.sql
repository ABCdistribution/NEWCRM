-- Total stocké par commande : évite de re-sommer des millions de lignes (commande_lignes) à chaque
-- affichage de dashboard / fiche client / performances. Tenu à jour automatiquement par un déclencheur
-- sur commande_lignes, donc valable quel que soit le chemin d'écriture (import ERP, migration, SQL).

ALTER TABLE "commandes" ADD COLUMN "montantTotal" DECIMAL(16,4) NOT NULL DEFAULT 0;

-- Reprise de l'existant.
UPDATE "commandes" c
SET "montantTotal" = s.total
FROM (SELECT "commandeId", SUM("montant") AS total FROM "commande_lignes" GROUP BY "commandeId") s
WHERE s."commandeId" = c."id";

CREATE FUNCTION "commande_lignes_maj_total"() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE "commandes" SET "montantTotal" = "montantTotal" + NEW."montant" WHERE "id" = NEW."commandeId";
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE "commandes" SET "montantTotal" = "montantTotal" - OLD."montant" WHERE "id" = OLD."commandeId";
  ELSE
    IF NEW."commandeId" = OLD."commandeId" THEN
      UPDATE "commandes" SET "montantTotal" = "montantTotal" + (NEW."montant" - OLD."montant") WHERE "id" = NEW."commandeId";
    ELSE
      UPDATE "commandes" SET "montantTotal" = "montantTotal" - OLD."montant" WHERE "id" = OLD."commandeId";
      UPDATE "commandes" SET "montantTotal" = "montantTotal" + NEW."montant" WHERE "id" = NEW."commandeId";
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "commande_lignes_total"
AFTER INSERT OR DELETE OR UPDATE OF "montant", "commandeId" ON "commande_lignes"
FOR EACH ROW EXECUTE FUNCTION "commande_lignes_maj_total"();
