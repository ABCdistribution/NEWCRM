-- Tournée personnelle Helios (encadrement) : étapes datées, prospect OU magasin existant.
CREATE TABLE "tournee_etapes" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "clientId" UUID,
    "prospectId" UUID,
    "datePassage" TIMESTAMP(3) NOT NULL,
    "fait" BOOLEAN NOT NULL DEFAULT false,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "tournee_etapes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "tournee_etapes_userId_datePassage_idx" ON "tournee_etapes"("userId", "datePassage");
CREATE INDEX "tournee_etapes_clientId_idx" ON "tournee_etapes"("clientId");
CREATE INDEX "tournee_etapes_prospectId_idx" ON "tournee_etapes"("prospectId");

ALTER TABLE "tournee_etapes" ADD CONSTRAINT "tournee_etapes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "tournee_etapes" ADD CONSTRAINT "tournee_etapes_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "tournee_etapes" ADD CONSTRAINT "tournee_etapes_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Exactement un des deux : prospect OU client.
ALTER TABLE "tournee_etapes" ADD CONSTRAINT "tournee_etapes_cible_check"
  CHECK (("clientId" IS NOT NULL AND "prospectId" IS NULL) OR ("clientId" IS NULL AND "prospectId" IS NOT NULL));
