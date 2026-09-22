-- Photo utilisateur issue de l'AD (thumbnailPhoto, JPEG), synchronisée au login.
ALTER TABLE "users" ADD COLUMN "photo" BYTEA;
