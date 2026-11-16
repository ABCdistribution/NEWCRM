-- Raisons d'absence de commande (liste administrable) et fin de visite : commande liée ou raison choisie.
CREATE TABLE "raisons_absence_commande" (
  "id" UUID NOT NULL,
  "libelle" TEXT NOT NULL,
  "ordre" INTEGER NOT NULL,
  "actif" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "deletedAt" TIMESTAMP(3),
  CONSTRAINT "raisons_absence_commande_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "raisons_absence_commande_ordre_idx" ON "raisons_absence_commande"("ordre");

ALTER TABLE "visites" ADD COLUMN "idCommandeApk" VARCHAR(10);
ALTER TABLE "visites" ADD COLUMN "raisonAbsenceCommandeId" UUID;
CREATE INDEX "visites_idCommandeApk_idx" ON "visites"("idCommandeApk");
CREATE INDEX "visites_raisonAbsenceCommandeId_idx" ON "visites"("raisonAbsenceCommandeId");
ALTER TABLE "visites" ADD CONSTRAINT "visites_raisonAbsenceCommandeId_fkey"
  FOREIGN KEY ("raisonAbsenceCommandeId") REFERENCES "raisons_absence_commande"("id") ON DELETE SET NULL ON UPDATE CASCADE;
