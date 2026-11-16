import { BadRequestException } from '@nestjs/common';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional } from 'class-validator';

/**
 * Synchro incrémentale (app mobile) : paramètre de requête `modifieDepuis` partagé par les routes de liste.
 * Les DTO de requête étendent cette classe ; les services appellent `lireModifieDepuis` puis les fonctions
 * ci-dessous. Sans le paramètre, rien ne change (mêmes lignes, même ordre, même format).
 */
export class ModifieDepuisQuery {
  @ApiPropertyOptional({
    description:
      "Synchro incrémentale : date-heure ISO 8601 avec fuseau (ex. 2026-11-13T08:30:00Z). Ne renvoie que les lignes modifiées depuis cet instant (updatedAt >= valeur), triées par updatedAt puis id croissants, " +
      "y compris les lignes supprimées logiquement (deletedAt non nul) quand le modèle en a une ; chaque ligne expose alors updatedAt (et deletedAt). Le filtre s'ajoute au périmètre du rôle, jamais à la place.",
    example: '2026-11-13T08:30:00Z',
  })
  @IsOptional()
  @IsDateString({ strict: true, strictSeparator: true })
  modifieDepuis?: string;
}

/** Convertit `modifieDepuis` en Date ; undefined si absent. Lève une 400 si la valeur n'est pas une date valide. */
export function lireModifieDepuis(valeur?: string | null): Date | undefined {
  if (valeur === undefined || valeur === null || valeur === '') return undefined;
  const date = new Date(valeur);
  if (Number.isNaN(date.getTime())) {
    throw new BadRequestException('modifieDepuis doit être une date-heure ISO 8601 valide');
  }
  return date;
}

/** Condition `updatedAt >= depuis` (>= : le client dédoublonne par id, rien n'est perdu à la frontière d'une page). */
export function filtreModifieDepuis(depuis: Date | undefined): { updatedAt?: { gte: Date } } {
  return depuis ? { updatedAt: { gte: depuis } } : {};
}

/** Suppression logique : lignes supprimées exclues, sauf en synchro (l'app doit pouvoir les effacer). */
export function filtreSupprimes(depuis: Date | undefined): { deletedAt?: null } {
  return depuis ? {} : { deletedAt: null };
}

/** Tri stable de la synchro : updatedAt puis id croissants (pagination sans trou ni doublon). */
export const TRI_MODIFIE_DEPUIS = [{ updatedAt: 'asc' as const }, { id: 'asc' as const }];

/** Champs d'horodatage exposés en synchro, pour un `select` Prisma (modèle avec suppression logique). */
export function selectHorodatage(depuis: Date | undefined): { updatedAt?: true; deletedAt?: true } {
  return depuis ? { updatedAt: true, deletedAt: true } : {};
}

/** Idem pour un modèle sans suppression logique (Commande, CommandeApk). */
export function selectHorodatageSansSuppression(depuis: Date | undefined): { updatedAt?: true } {
  return depuis ? { updatedAt: true } : {};
}
