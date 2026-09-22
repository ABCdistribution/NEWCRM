-- Saisie de visite mobile : motif, DN gondole haute/basse, idApk unique (idempotence sync).
ALTER TABLE "visites" ADD COLUMN "motif" TEXT;
ALTER TABLE "visites" ADD COLUMN "dnGondoleHaute" INTEGER;
ALTER TABLE "visites" ADD COLUMN "dnGondoleBasse" INTEGER;
CREATE UNIQUE INDEX "visites_idApk_key" ON "visites"("idApk");
