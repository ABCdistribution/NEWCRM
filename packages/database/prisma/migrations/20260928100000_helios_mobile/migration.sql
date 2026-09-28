-- Helios Mobile : idempotence des étapes de tournée créées hors ligne
-- et photos de rayon des visites commerciales stockées en base.
ALTER TABLE "tournee_etapes" ADD COLUMN "idApk" TEXT;
CREATE UNIQUE INDEX "tournee_etapes_idApk_key" ON "tournee_etapes"("idApk");

ALTER TABLE "visite_photos" ADD COLUMN "mime" TEXT;
ALTER TABLE "visite_photos" ADD COLUMN "donnees" BYTEA;
ALTER TABLE "visite_photos" ADD COLUMN "idApk" TEXT;
CREATE UNIQUE INDEX "visite_photos_idApk_key" ON "visite_photos"("idApk");
