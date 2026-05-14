# Paper Pro framebuffer — état et travail restant

## TL;DR

La branche `claude/optimize-remarkable-app-g8Ylc` produit désormais un binaire **aarch64** qui s'exécute sur la rMPP (plus de "Exec format error"). Mais **l'affichage ne marchera probablement pas** tant que la couche framebuffer de `libnsfb-reMarkable` n'est pas adaptée au controller d'écran de la Paper Pro. Ce document liste ce qu'il reste à faire et donne les pistes d'investigation.

## Ce que fait le binaire actuel

`libnsfb-reMarkable` (le fork pinné dans `versions.sh`) gère pour rM1 et rM2 :

- L'ouverture du framebuffer Linux à `/dev/fb0`
- Le format pixel (RGB565 ou Y8 selon le modèle)
- Les ioctl spécifiques au driver e-ink pour déclencher un refresh écran (modes A2, DU, GC16, etc., propres au controller Pearl/Carta)
- L'input via libevdev (touch + stylus Wacom)

Pour rM1/rM2 ces choix sont valides et stables depuis 2019-2020. La rMPP, sortie en 2024, utilise un **autre controller d'écran** (e-ink couleur "Canvas display", probablement avec un firmware très différent des rM précédentes). Conséquences attendues quand on lance le binaire aarch64 sur rMPP :

- Soit `/dev/fb0` ne s'ouvre pas (path différent, perm, etc.) → erreur visible dans la sortie de netsurf
- Soit le framebuffer s'ouvre mais le format pixel est différent → affichage corrompu
- Soit le format est OK mais les ioctl de refresh ne fonctionnent pas → image figée à l'écran malgré le travail de NetSurf

## Diagnostic à faire sur la rMPP

À lancer en SSH sur la tablette, **avant** d'essayer de patcher quoi que ce soit :

```bash
# Devices framebuffer présents
ls -la /dev/fb*
ls -la /dev/dri/* 2>/dev/null    # DRM/KMS path si reMarkable est passé à ça
ls -la /dev/snd 2>/dev/null      # juste pour comprendre l'ensemble

# Format du framebuffer
fbset -i 2>/dev/null
cat /sys/class/graphics/fb0/virtual_size
cat /sys/class/graphics/fb0/bits_per_pixel
cat /sys/class/graphics/fb0/stride 2>/dev/null
cat /sys/class/graphics/fb0/name 2>/dev/null
cat /sys/class/graphics/fb0/modes 2>/dev/null

# Driver e-ink — quel module noyau ?
lsmod | grep -iE 'epd|eink|mxc|imx|epdc'
dmesg | grep -iE 'epd|eink|epdc|frame.?buffer' | head -50

# Le binaire xochitl, lui, sait afficher. Voir contre quoi il est linké
ldd /usr/bin/xochitl | grep -iE 'epd|eink|fb|drm'
strings /usr/bin/xochitl | grep -iE '/dev/fb|MXCFB|EPDC|REAGL' | head -20
```

La sortie de tout ça est le point de départ. **Sans elle, impossible d'avancer sur le port framebuffer.**

## Travail à effectuer

### Étape 1 — Inventaire du framebuffer rMPP

À partir du diagnostic ci-dessus, déterminer :

- [ ] Chemin du fb : `/dev/fb0` ou autre (DRM via `/dev/dri/card0` ?)
- [ ] Format pixel attendu (bpp, ordre des canaux, e-ink couleur a probablement un format spécial)
- [ ] Stride / pitch
- [ ] Ioctl ou syscall pour forcer un refresh écran (modes partial / full update)
- [ ] Modèle de mémoire (mmap direct vs API dédiée)

Sources :
- Tracer xochitl avec `strace -f -e trace=openat,ioctl,mmap` pendant qu'il affiche quelque chose
- Reverse léger de xochitl pour repérer les constantes `MXCFB_*` ou équivalent
- Lire les commits récents du noyau reMarkable s'ils sont open : `https://github.com/remarkable/...` ou les patches OE qu'ils publient

### Étape 2 — Adapter `libnsfb-reMarkable`

Le fork live ici : `https://github.com/alex0809/libnsfb-reMarkable`. Pour porter sur rMPP, créer un nouveau backend (ou modifier le backend `surface/remarkable.c` existant) :

- [ ] Implémenter un backend `paperpro.c` qui ouvre le bon device et fait les bons ioctl
- [ ] Gérer la conversion de l'image rendue par NetSurf (RGBA32) vers le format attendu par le controller (gris 4 bits, ou couleur indexée pour Canvas display, à confirmer)
- [ ] Gérer les modes de refresh : pour de la navigation web, du `A2` ou équivalent sur le scroll, `GC16` ou `full` pour les changements de page
- [ ] Mettre à jour `versions.sh` pour pointer sur la branche/fork qui inclut ce backend

### Étape 3 — Adapter `netsurf-base-reMarkable`

Le flag `NETSURF_REMARKABLE=YES` active du code spécifique dans `frontends/framebuffer/`. Vérifier que ce code ne fait pas d'hypothèses rM1/rM2 (taille d'écran 1404×1872, etc.). Le rMPP est 1620×2160 — gérer la nouvelle géométrie.

### Étape 4 — Input

`libevdev` est portable. Mais sur rMPP les noms de devices `/dev/input/eventN` ne sont plus les mêmes (la rM2 avait des indices fixes ; rMPP probablement aussi mais différents). Le code de `libnsfb-reMarkable/surface/remarkable.c` ouvre les devices en dur — il faut soit ré-énumérer dynamiquement via udev/sysfs, soit hardcoder les nouveaux indices.

## Tester sans casser la tablette

Pendant le dev, **ne pas désinstaller xochitl**. Le pattern de test sûr :

```bash
# Sur la tablette, en SSH
systemctl stop xochitl       # libère le framebuffer
/home/root/netsurf 2>&1 | tee /tmp/netsurf.log
# Quand ça plante / fige, depuis un autre SSH :
pkill -9 nsfb
systemctl start xochitl      # restaure l'UI normale
```

Si la tablette devient totalement inutilisable, hard reboot via le bouton power (10 s).

## État actuel de la branche

- ✅ Toolchain aarch64 (Debian `gcc-aarch64-linux-gnu`)
- ✅ Libs tierces cross-compilées en aarch64 (OpenSSL 3.0.20, curl 8.20, libiconv 1.17, FreeType 2.13.3, libjpeg-turbo 3.0.4) avec flags de durcissement
- ✅ NetSurf produit un binaire ELF64 aarch64
- ⚠ Affichage rMPP : non testé / probablement non fonctionnel — voir étapes 1-3 ci-dessus
- ⚠ Input rMPP : idem — voir étape 4

## Pourquoi tout n'a pas été fait en une session

Le portage framebuffer demande :

1. Un accès interactif à la rMPP pour diagnostiquer (qu'on n'a pas dans Claude Code)
2. Du reverse / lecture du driver e-ink rMPP (non documenté publiquement)
3. Probablement plusieurs cycles de patch / test / debug device

C'est un projet de jours à semaines selon la difficulté du reverse. Cette branche pose les fondations propres (toolchain à jour, libs sécurisées, hardening) ; le travail framebuffer arrivera dans une session séparée dédiée.

Le brief Option E (`OPTION_E_BRIEF.md`) propose une **alternative complète** qui contourne le portage framebuffer en réutilisant le Qt6/QtWebEngine déjà présent dans xochitl. À explorer en parallèle.
