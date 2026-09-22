-- Soirée étape : lieu et adresse du découcher.
ALTER TABLE "tournee_etapes"
  ADD COLUMN "soireeLieu" TEXT,
  ADD COLUMN "soireeAdresse" TEXT;
