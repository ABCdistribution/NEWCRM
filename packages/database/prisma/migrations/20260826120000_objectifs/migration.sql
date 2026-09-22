-- Objectifs mensuels de CA par représentant (ex-`objectifs` legacy)
CREATE TABLE "objectifs" (
    "id" UUID NOT NULL,
    "idRepr" TEXT NOT NULL,
    "annee" INTEGER NOT NULL,
    "mois" INTEGER NOT NULL,
    "cibleCa" DECIMAL(14,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "objectifs_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "objectifs_idRepr_annee_mois_key" ON "objectifs"("idRepr", "annee", "mois");
