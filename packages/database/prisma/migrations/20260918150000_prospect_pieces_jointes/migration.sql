-- Pièces jointes des fiches prospects (fichiers stockés en base).
CREATE TABLE "prospect_pieces_jointes" (
    "id" UUID NOT NULL,
    "prospectId" UUID NOT NULL,
    "auteurId" UUID,
    "nom" TEXT NOT NULL,
    "mime" TEXT NOT NULL,
    "taille" INTEGER NOT NULL,
    "donnees" BYTEA NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "prospect_pieces_jointes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "prospect_pieces_jointes_prospectId_idx" ON "prospect_pieces_jointes"("prospectId");
ALTER TABLE "prospect_pieces_jointes" ADD CONSTRAINT "prospect_pieces_jointes_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "prospect_pieces_jointes" ADD CONSTRAINT "prospect_pieces_jointes_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
