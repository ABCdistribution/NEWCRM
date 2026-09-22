-- Qualification d'une étape du planning d'activité (visite simple, accompagnement
-- promoteur, RDV, soirée étape) — l'heure vit dans datePassage, les observations dans note.
ALTER TABLE "tournee_etapes"
  ADD COLUMN "visiteSimple" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "accompagnement" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "rdv" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "soireeEtape" BOOLEAN NOT NULL DEFAULT false;
