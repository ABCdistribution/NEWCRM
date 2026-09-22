-- Région commerciale de l'utilisateur, synchronisée depuis l'AD (attribut `st`) au login.
ALTER TABLE "users" ADD COLUMN "regionId" UUID;

ALTER TABLE "users" ADD CONSTRAINT "users_regionId_fkey"
  FOREIGN KEY ("regionId") REFERENCES "regions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "users_regionId_idx" ON "users"("regionId");
