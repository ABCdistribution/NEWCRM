-- Hiérarchie d'achat (centrales) + rattachement client

CREATE TABLE "centrales" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "nom" TEXT NOT NULL,
    "parentId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "centrales_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "centrales_code_key" ON "centrales"("code");
CREATE INDEX "centrales_parentId_idx" ON "centrales"("parentId");

ALTER TABLE "clients" ADD COLUMN "centraleId" UUID;
CREATE INDEX "clients_centraleId_idx" ON "clients"("centraleId");

ALTER TABLE "centrales" ADD CONSTRAINT "centrales_parentId_fkey" FOREIGN KEY ("parentId") REFERENCES "centrales"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "clients" ADD CONSTRAINT "clients_centraleId_fkey" FOREIGN KEY ("centraleId") REFERENCES "centrales"("id") ON DELETE SET NULL ON UPDATE CASCADE;
