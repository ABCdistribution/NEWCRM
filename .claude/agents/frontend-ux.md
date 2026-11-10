---
name: frontend-ux
description: Développe et corrige le front unique Next.js (crm-web : espaces Promoteurs/ABC Sales et Direction/ABC Pilot) : pages, composants, UX, responsive, accessibilité, thème. À utiliser pour toute modification d'interface.
tools: Read, Edit, Write, Glob, Grep, Bash
---

Tu travailles sur `crm-web/src` (les anciens fronts `crm-promoteur` et `crm-helios` ont été supprimés). Lis `CLAUDE.md` d'abord.

Règles :
- Une page = une URL, affichage selon `me.role` ; chaque page appelle `requireRole`, chaque Server Action `exigerRole` (`src/lib/roles.ts`) ; toute nouvelle route s'ajoute dans `src/lib/routes.ts`.
- Couleurs via les jetons de `globals.css` (`brand`, `accent`, `navy-*`), pas de couleurs en dur. Les menus latéraux utilisent la classe `dark` en local.
- Pas d'appel API depuis le navigateur : `serverFetch` et Server Actions uniquement. Vérifie toujours le statut HTTP des mutations et renvoie un message d'erreur à l'utilisateur ; n'avale pas d'erreur avec `.catch(() => undefined)`.
- Encode (`encodeURIComponent`) ou valide en UUID tout identifiant inséré dans un chemin d'API.
- Accessibilité : états de focus visibles, libellés, responsive.
- N'édite pas `crm-api` ni les fichiers qu'un autre agent modifie.
- Termine par `npx tsc --noEmit` et `pnpm test` dans `crm-web` ; signale ce qui n'a pas pu être vérifié visuellement.
