-- Alignement du modèle User sur l'AD on-premise (LDAP)

-- azureAdObjectId -> username (sAMAccountName)
ALTER TABLE "users" RENAME COLUMN "azureAdObjectId" TO "username";
ALTER INDEX "users_azureAdObjectId_key" RENAME TO "users_username_key";

-- email devient optionnel (certains comptes AD n'ont pas de mail)
ALTER TABLE "users" ALTER COLUMN "email" DROP NOT NULL;
