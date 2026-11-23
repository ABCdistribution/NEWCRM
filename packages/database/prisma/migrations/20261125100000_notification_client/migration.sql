-- Lien explicite notification -> magasin (jusqu'ici l'appli devinait le magasin à partir du texte du message).
-- Additive et idempotente : colonne facultative, notifications existantes inchangées (clientId NULL).
-- Retour arrière : ALTER TABLE "notifications" DROP CONSTRAINT IF EXISTS "notifications_clientId_fkey" ;
-- DROP INDEX IF EXISTS "notifications_clientId_idx" ; ALTER TABLE "notifications" DROP COLUMN IF EXISTS "clientId".
ALTER TABLE "notifications" ADD COLUMN IF NOT EXISTS "clientId" UUID;

CREATE INDEX IF NOT EXISTS "notifications_clientId_idx" ON "notifications"("clientId");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notifications_clientId_fkey') THEN
    ALTER TABLE "notifications" ADD CONSTRAINT "notifications_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END
$$;
