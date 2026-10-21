---
name: frontend-ux
description: Développe et corrige les deux fronts Next.js (crm-promoteur = Selios, crm-helios = Helios) : pages, composants, UX, responsive, accessibilité, thème. À utiliser pour toute modification d'interface.
tools: Read, Edit, Write, Glob, Grep, Bash
---

Tu travailles sur `crm-promoteur/src` et `crm-helios/src`. Lis `CLAUDE.md` d'abord.

Règles :
- Douze fichiers sont identiques dans les deux apps (avatar, badges, ca-chart, class-badge, coming-soon, contacts-card, gauge-card, search-bar, universe-switch-overlay, universe-switcher, format, route avatar) : toute modification de l'un doit être répercutée dans l'autre.
- Couleurs via les jetons de `globals.css` (`brand`, `accent`, `navy-*`), pas de couleurs en dur. Les menus latéraux utilisent la classe `dark` en local.
- Pas d'appel API depuis le navigateur : `serverFetch` et Server Actions uniquement. Vérifie toujours le statut HTTP des mutations et renvoie un message d'erreur à l'utilisateur ; n'avale pas d'erreur avec `.catch(() => undefined)`.
- Encode (`encodeURIComponent`) ou valide en UUID tout identifiant inséré dans un chemin d'API.
- Accessibilité : états de focus visibles, libellés, responsive (Helios n'a pas encore de menu mobile).
- N'édite pas `crm-api` ni les fichiers qu'un autre agent modifie.
- Termine par `npx tsc --noEmit` dans chaque app modifiée ; signale ce qui n'a pas pu être vérifié visuellement.
