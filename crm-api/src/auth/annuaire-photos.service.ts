import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { idReprVariants } from '../common/id-repr.util';

/** Annuaire intranet de l'entreprise (adresse interne) ; surchargeable par la variable d'environnement ANNUAIRE_URL. */
const BASE_PAR_DEFAUT = 'http://intranet.abcosmetique.com';
const DELAI_LISTE_MS = 15_000;
const DELAI_PHOTO_MS = 10_000;
const TAILLE_MAX = 2 * 1024 * 1024;
const PARALLELE = 4;
/** Fichier photo d'une fiche : « Photos/prenomnom.jpg » (aucun chemin remontant, aucun schéma, aucun espace). */
const FICHIER_PHOTO = /^Photos\/[A-Za-z0-9][A-Za-z0-9._-]{0,100}\.jpe?g$/i;

/** Type d'une image d'après ses premiers octets (jamais d'après son nom ni l'en-tête HTTP), ou null. */
export function typeImage(buf: Buffer): 'image/jpeg' | 'image/png' | null {
  if (buf.length < 100) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return 'image/png';
  return null;
}

interface FicheAnnuaire {
  email?: unknown;
  /** Dans l'annuaire, le champ « fax » porte le code représentant (même donnée que l'AD). */
  fax?: unknown;
  photo?: unknown;
}

export interface PhotosAnnuaire {
  /** Photos reprises de l'annuaire et enregistrées. */
  reprises: number;
  /** Fiches avec photo dont aucun compte sans photo ne correspond (compte inconnu ou déjà doté d'une photo). */
  ignorees: number;
  /** Photos introuvables, trop lourdes ou qui ne sont ni des JPEG ni des PNG. */
  echecs: number;
  /** L'annuaire n'a pas répondu ou a renvoyé une liste illisible : rien n'a été fait. */
  indisponible: boolean;
}

/**
 * Complète les photos manquantes avec celles de l'annuaire intranet.
 *
 * L'AD (attribut thumbnailPhoto) ne renseigne presque aucune photo ; l'annuaire, lui, tient sa propre bibliothèque
 * (`/annuaire/Photos/<fichier>.jpg`, gérée dans son interface d'administration) et la publie avec la liste des
 * collaborateurs (`/api/employees.php`). On ne remplit QUE les comptes sans photo : une photo venue de l'AD n'est
 * jamais écrasée. Rapprochement par e-mail, à défaut par code représentant.
 *
 * Jamais bloquant : toute erreur (réseau, JSON illisible, fichier absent) est journalisée et comptée, la synchro AD
 * qui l'appelle réussit quand même. Seule l'adresse de l'annuaire (configuration, jamais une saisie) est jointe, et
 * seuls des noms de fichiers conformes à `FICHIER_PHOTO` sont demandés ; le contenu doit être une vraie image JPEG ou
 * PNG (reconnue à ses premiers octets, quelle que soit l'extension : l'annuaire a des PNG nommés .jpg) de moins de 2 Mo.
 */
@Injectable()
export class AnnuairePhotosService {
  private readonly logger = new Logger(AnnuairePhotosService.name);

  constructor(private readonly prisma: PrismaService) {}

  async completerPhotos(): Promise<PhotosAnnuaire> {
    const bilan: PhotosAnnuaire = { reprises: 0, ignorees: 0, echecs: 0, indisponible: false };
    const base = (process.env.ANNUAIRE_URL?.trim() || BASE_PAR_DEFAUT).replace(/\/+$/, '');

    let fiches: FicheAnnuaire[];
    try {
      const res = await fetch(`${base}/api/employees.php`, {
        cache: 'no-store',
        signal: AbortSignal.timeout(DELAI_LISTE_MS),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json: unknown = await res.json();
      if (!Array.isArray(json)) throw new Error('liste attendue');
      fiches = json as FicheAnnuaire[];
    } catch (err) {
      this.logger.warn(`Photos de l'annuaire : liste indisponible (${(err as Error)?.message ?? err}) — photos inchangées`);
      return { ...bilan, indisponible: true };
    }

    // Comptes sans photo, indexés par e-mail et par code représentant (variantes « 68 » ↔ « 068 »).
    const sansPhoto = await this.prisma.user.findMany({
      where: { photo: null },
      select: { id: true, email: true, idRepr: true },
    });
    const parEmail = new Map<string, string>();
    const parCode = new Map<string, string>();
    for (const u of sansPhoto) {
      if (u.email) parEmail.set(u.email.trim().toLowerCase(), u.id);
      if (u.idRepr) for (const v of idReprVariants(u.idRepr.trim())) parCode.set(v, u.id);
    }

    const aTelecharger: { userId: string; fichier: string }[] = [];
    const pris = new Set<string>();
    for (const f of fiches) {
      const fichier = typeof f?.photo === 'string' ? f.photo.trim() : '';
      if (!FICHIER_PHOTO.test(fichier) || /(^|\/)default\./i.test(fichier)) continue;
      const email = typeof f.email === 'string' ? f.email.trim().toLowerCase() : '';
      const code = typeof f.fax === 'string' ? f.fax.trim() : '';
      const userId = (email && parEmail.get(email)) || (code && parCode.get(code)) || null;
      if (!userId || pris.has(userId)) {
        bilan.ignorees += 1;
        continue;
      }
      pris.add(userId);
      aTelecharger.push({ userId, fichier });
    }

    for (let i = 0; i < aTelecharger.length; i += PARALLELE) {
      await Promise.all(
        aTelecharger.slice(i, i + PARALLELE).map(async ({ userId, fichier }) => {
          try {
            const res = await fetch(`${base}/annuaire/${fichier}`, { signal: AbortSignal.timeout(DELAI_PHOTO_MS) });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const buf = Buffer.from(await res.arrayBuffer());
            if (!typeImage(buf) || buf.length > TAILLE_MAX) throw new Error('fichier non conforme (JPEG ou PNG de moins de 2 Mo attendu)');
            await this.prisma.user.update({ where: { id: userId }, data: { photo: Uint8Array.from(buf) } });
            bilan.reprises += 1;
          } catch (err) {
            bilan.echecs += 1;
            this.logger.warn(`Photo de l'annuaire ${fichier} non reprise (${(err as Error)?.message ?? err})`);
          }
        }),
      );
    }

    this.logger.log(
      `Photos de l'annuaire : ${bilan.reprises} reprises, ${bilan.ignorees} fiches ignorées, ${bilan.echecs} échecs`,
    );
    return bilan;
  }
}
