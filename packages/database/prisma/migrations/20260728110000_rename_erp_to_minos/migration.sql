-- Renommage table erp_import_logs -> minos_import_logs (l'ERP est "Minos")
ALTER TABLE "erp_import_logs" RENAME TO "minos_import_logs";
ALTER TABLE "minos_import_logs" RENAME CONSTRAINT "erp_import_logs_pkey" TO "minos_import_logs_pkey";
ALTER INDEX "erp_import_logs_status_idx" RENAME TO "minos_import_logs_status_idx";

-- Renommage de la valeur d'enum MIOS -> MINOS (conserve les données, pas de suppression)
ALTER TYPE "ImportSource" RENAME VALUE 'MIOS' TO 'MINOS';
