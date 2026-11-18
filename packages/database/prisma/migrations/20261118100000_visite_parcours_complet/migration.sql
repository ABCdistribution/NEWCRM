-- Parcours de visite complet (app mobile) : commande à mettre en rayon + colis, kits DN, étape des photos, pointage OP.
-- Additive : colonnes nullables et nouvelles tables uniquement.
-- Retour arrière : DROP TABLE "visite_colis", "visite_kits" ; ALTER TABLE "visite_promos" DROP COLUMN "promoId", DROP COLUMN "presente" ;
-- ALTER TABLE "visite_photos" DROP COLUMN "etape" ; ALTER TABLE "visites" DROP COLUMN "commandeEnRayon".
ALTER TABLE "visites" ADD COLUMN "commandeEnRayon" BOOLEAN;

ALTER TABLE "visite_photos" ADD COLUMN "etape" VARCHAR(20);

ALTER TABLE "visite_promos" ADD COLUMN "promoId" UUID;
ALTER TABLE "visite_promos" ADD COLUMN "presente" BOOLEAN;
CREATE INDEX "visite_promos_promoId_idx" ON "visite_promos"("promoId");
CREATE UNIQUE INDEX "visite_promos_visiteId_promoId_key" ON "visite_promos"("visiteId", "promoId");
ALTER TABLE "visite_promos" ADD CONSTRAINT "visite_promos_promoId_fkey"
  FOREIGN KEY ("promoId") REFERENCES "promos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "visite_kits" (
  "id" UUID NOT NULL,
  "visiteId" UUID NOT NULL,
  "code" VARCHAR(64) NOT NULL,
  "nbReferences" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "visite_kits_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "visite_kits_visiteId_idx" ON "visite_kits"("visiteId");
CREATE UNIQUE INDEX "visite_kits_visiteId_code_key" ON "visite_kits"("visiteId", "code");
ALTER TABLE "visite_kits" ADD CONSTRAINT "visite_kits_visiteId_fkey"
  FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "visite_colis" (
  "id" UUID NOT NULL,
  "visiteId" UUID NOT NULL,
  "code" VARCHAR(64) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "visite_colis_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "visite_colis_visiteId_idx" ON "visite_colis"("visiteId");
CREATE UNIQUE INDEX "visite_colis_visiteId_code_key" ON "visite_colis"("visiteId", "code");
ALTER TABLE "visite_colis" ADD CONSTRAINT "visite_colis_visiteId_fkey"
  FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
