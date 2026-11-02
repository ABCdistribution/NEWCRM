-- Rapport d'activité hebdomadaire (CS / DR) : tournée prévue (photographie), tournée réalisée, rapport validé.
-- Colonnes ajoutées uniquement (aucune suppression, aucune réécriture de données).
ALTER TABLE "tournee_etapes"
  ADD COLUMN "libelle" TEXT,
  ADD COLUMN "adresse" TEXT;

ALTER TABLE "planning_semaines"
  ADD COLUMN "previsionEtapes" JSONB,
  ADD COLUMN "valideAuto" BOOLEAN NOT NULL DEFAULT false;
