-- Tarifs : base tarifaire + prix à 4 décimales (format Minos)
ALTER TABLE "tarifs" ADD COLUMN "codeTarif" TEXT;
ALTER TABLE "tarifs" ALTER COLUMN "montant" TYPE DECIMAL(14,4);
CREATE UNIQUE INDEX "tarifs_articleId_codeTarif_key" ON "tarifs"("articleId", "codeTarif");
