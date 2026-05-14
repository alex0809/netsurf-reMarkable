# Brief — Option E : navigateur web sur reMarkable Paper Pro via xochitl / Qt

> Document destiné à amorcer une session Claude Code dédiée à ce sujet.
> Tout ce qui est nécessaire pour démarrer sans contexte préalable est ici.

## 1. Contexte et objectif

L'utilisateur possède une **reMarkable Paper Pro (rMPP)** et veut un navigateur web utilisable directement sur la tablette. Les options déjà éliminées :

- **Toltec / opkg** : ne supporte pas l'architecture rMPP ("Unsupported device architecture").
- **NetSurf-reMarkable** (le binaire framebuffer) : a été construit pour rM1/rM2 en `armhf` 32-bit. La rMPP est en `aarch64` 64-bit. Un portage de la couche framebuffer est nécessaire (cf. autre session sur le repo `netsurf-reMarkable`, branche `claude/optimize-remarkable-app-g8Ylc`). Même rebuild en aarch64, le code de `libnsfb-reMarkable` cible le driver e-ink des rM1/rM2 qui n'est pas celui de la rMPP.

**Cible** : tirer parti du fait que **xochitl** (le launcher propriétaire reMarkable) utilise déjà **Qt 6 + QtWebEngine** en interne pour certaines vues (login OAuth Google/Microsoft notamment). Donc un moteur Chromium complet est physiquement présent sur la tablette. L'idée d'option E = exposer cette capacité à l'utilisateur pour de la navigation libre.

## 2. Spécifications matérielles / OS de la rMPP

| Élément | Valeur |
|---|---|
| Hostname | `imx8mm-ferrari` (codename interne : Ferrari) |
| SoC | NXP i.MX 8M Mini, 4× Cortex-A53 @ 1.8 GHz |
| Arch userspace | `aarch64` |
| RAM | 2 GiB |
| Écran | 11.8" e-ink couleur (Canvas display), 1620×2160, 229 DPI |
| Stockage | 64 GiB eMMC |
| Accès dev | SSH root (mot de passe dans Settings → General → About → Copyrights) |
| IP USB | `10.11.99.1` |
| Launcher | `xochitl` (binaire propriétaire, Qt 6.x) |
| Service systemd | `xochitl.service` |

## 3. Pistes techniques (du plus simple au plus lourd)

### 3.1 IPC / D-Bus

Premier réflexe : voir si `xochitl` expose déjà une méthode "ouvrir URL" via D-Bus ou socket Unix. Beaucoup d'apps Qt l'exposent involontairement.

```bash
# Sur la tablette
busctl list                                   # services D-Bus actifs
busctl introspect com.remarkable.xochitl /    # si présent
ls -la /tmp/.xochitl* /run/xochitl* 2>/dev/null
strings /usr/bin/xochitl | grep -i 'dbus\|interface\|method' | head -50
```

Si une interface de navigation existe : trivial, écrire un mini-launcher CLI.

### 3.2 `LD_PRELOAD` pour intercepter Qt

Charger une `.so` qui s'injecte au démarrage de xochitl et hook une fonction Qt (par ex. `QWebEnginePage::setUrl`) pour la rendre adressable de l'extérieur (via signal Unix, fichier surveillé, etc.).

```bash
# Activation typique
LD_PRELOAD=/home/root/.local/lib/rmweb-inject.so systemctl restart xochitl
```

Avantages : non destructif, désactivable. Inconvénient : suit le rythme des updates firmware.

### 3.3 Patch binaire de xochitl

Reverse de xochitl avec Ghidra/Cutter, identifier la table d'écrans/menus, ajouter une entrée "Web" qui pointe vers une instance `QWebEngineView` exposée librement (sans la contrainte OAuth-only).

```bash
# Récupérer le binaire
scp root@10.11.99.1:/usr/bin/xochitl ./xochitl-3.x.y
file xochitl-3.x.y
objdump -T xochitl-3.x.y | grep -i webengine
```

Coût : haut (reverse). Bénéfice : intégration native, UI cohérente.

### 3.4 Standalone Qt6 + QtWebEngine

Compiler un app Qt indépendant qui utilise `QWebEngineView`, le déployer comme alternative à xochitl (ou via un launcher type Oxide si ça arrive un jour sur rMPP).

Pré-requis : toolchain Qt 6 cross-compile pour aarch64. **C'est le morceau le plus lourd** car QtWebEngine embarque Chromium (~10-15 Go de sources, ~3-6h de build).

Une astuce sérieuse : **réutiliser les libs Qt déjà sur la tablette**. Si on construit notre app aarch64 contre les mêmes versions Qt que celles bundlées avec xochitl (`/usr/lib/aarch64-linux-gnu/libQt6*`), pas besoin de recompiler QtWebEngine. À investiguer en priorité.

```bash
# Reconnaître la version Qt utilisée par xochitl
ssh root@10.11.99.1 'ldd /usr/bin/xochitl | grep -i qt'
ssh root@10.11.99.1 'strings /usr/lib/aarch64-linux-gnu/libQt6Core.so* | grep "Qt 6\." | head -3'
ssh root@10.11.99.1 'find /usr -name "libQt6WebEngine*"'
```

Si `libQt6WebEngineCore.so` est présent sur la tablette : option **gagnante**. On compile juste le wrapper (quelques centaines de lignes de C++/QML) contre ces libs.

### 3.5 Replacer xochitl à la volée

Remplacer (ou wrapper) `/usr/bin/xochitl` par un binaire qui mux entre xochitl original et un mode browser. Risqué (brick possible si on casse le service systemd au boot), gérer via `xochitl.service` override avec ExecStart conditionnel.

## 4. Plan d'attaque proposé pour la session dédiée

```
1. Récupérer info système (étapes ci-dessous), identifier exactement Qt présent
2. Décider entre 3.4 (Qt6 standalone réutilisant libs device) ou 3.2 (LD_PRELOAD)
3. Construire un MVP minimal : afficher https://example.com plein écran
4. Itérer : input tactile + stylus, gestes, fermeture
5. Packager : .ipk ou installeur shell autonome, plus un .service systemd
```

## 5. Diagnostic device — commandes à lancer en premier

À faire EN PRIORITÉ dans la nouvelle session, avant tout code :

```bash
# Architecture & OS
ssh root@10.11.99.1 'uname -a'
ssh root@10.11.99.1 'cat /etc/os-release'
ssh root@10.11.99.1 'cat /proc/version'

# Userspace ABI
ssh root@10.11.99.1 'getconf LONG_BIT'           # 64 attendu
ssh root@10.11.99.1 'cat /proc/cpuinfo | head -30'

# Qt présent ?
ssh root@10.11.99.1 'find /usr/lib -name "libQt6*" 2>/dev/null'
ssh root@10.11.99.1 'find /usr/lib -name "*WebEngine*" 2>/dev/null'
ssh root@10.11.99.1 'ldd /usr/bin/xochitl 2>&1 | head -30'

# Xochitl
ssh root@10.11.99.1 'systemctl status xochitl'
ssh root@10.11.99.1 'cat /etc/systemd/system/xochitl.service 2>/dev/null || cat /lib/systemd/system/xochitl.service'

# Framebuffer / display
ssh root@10.11.99.1 'ls -la /dev/fb*'
ssh root@10.11.99.1 'cat /sys/class/graphics/fb0/virtual_size 2>/dev/null'
ssh root@10.11.99.1 'fbset 2>/dev/null'

# Input devices
ssh root@10.11.99.1 'ls -la /dev/input/'
ssh root@10.11.99.1 'cat /proc/bus/input/devices'

# D-Bus
ssh root@10.11.99.1 'busctl list 2>/dev/null || echo "no systemd-bus"'
ssh root@10.11.99.1 'dbus-send --list-names 2>/dev/null || true'

# Espace dispo (pour QtWebEngine si on doit installer)
ssh root@10.11.99.1 'df -h /'
ssh root@10.11.99.1 'free -m'
```

Coller la sortie complète au début de la session.

## 6. Outils côté dev

À installer sur le poste de développement :

- **Ghidra** ou **Cutter/Rizin** : reverse de xochitl si on part sur 3.3
- **Qt Creator** : si build Qt natif. Toolchain cross : `aarch64-linux-gnu-g++` (paquet Debian `g++-aarch64-linux-gnu`)
- **rmview** : pour voir l'écran de la rMPP en temps réel pendant les tests (https://github.com/bordaigorl/rmview — si fonctionne sur rMPP, sinon adapter)
- **scrcpy-like via SSH** : pas natif rM, mais socat + framebuffer mirror est faisable

## 7. Risques et limites connus

- **Updates firmware reMarkable** : chaque update OTA peut casser un patch xochitl ou un LD_PRELOAD. Prévoir un mécanisme de désactivation simple (renommer le `.so`, etc.).
- **Performances e-ink** : Chromium n'est pas conçu pour 1-5 fps. Forcer le refresh A2/DU au lieu de GC16 pour le scroll, sinon ghosting massif. La rMPP a un controller propriétaire dont les modes ne sont pas officiellement documentés.
- **Tactile + stylus** : Qt va recevoir les events evdev. La rMPP a un digitalizer Wacom plus un touchscreen capacitif. Vérifier que les deux sont vus par Qt.
- **EULA reMarkable** : modifier xochitl viole probablement les CGU. Distribution publique à éviter, usage perso OK.
- **OAuth des sites majeurs** : Cloudflare/Google peuvent rejeter une connexion depuis un UA Chromium "non-standard". Spoof UA si besoin.

## 8. Liens et ressources

- Communautés rMPP : `/r/RemarkableTablet`, `/r/RemarkablePaperPro`, Discord remarkable-hackers
- Reverse de xochitl : `https://remarkable.guide/` (rM2 mais méthodes transposables)
- Toltec source : `https://github.com/toltec-dev/toltec` (pour voir comment ils packagent, même si ils ne supportent pas rMPP)
- Reverse e-ink rMPP : recherches en cours par la communauté, voir issue tracker rmview, Oxide, et le projet `remarkable-stuff` (à confirmer s'il existe pour rMPP)

## 9. Définition de "done"

MVP acceptable :
- [ ] Une commande / un raccourci sur la tablette qui ouvre une URL
- [ ] Affichage texte + images sur l'écran e-ink (qualité de scroll acceptable)
- [ ] Input clavier (OSK ou bluetooth) pour saisir une URL
- [ ] Quitter et retourner à xochitl proprement
- [ ] Installation reproductible (un script `install.sh`)

Stretch :
- [ ] Onglets, historique, marque-pages
- [ ] Mode lecture (Reader View) — particulièrement adapté à l'e-ink
- [ ] Intégration avec le système de notes reMarkable (annotations sur page web ?)

## 10. À ne PAS faire dans cette session

- Ne pas toucher au repo `netsurf-reMarkable` : le portage NetSurf est traité ailleurs.
- Ne pas redémarrer xochitl en boucle pendant un test (peut figer la tablette) — préférer un mode dégradé via SSH.
- Ne pas modifier `/etc/systemd/system/xochitl.service` sans backup et chemin de récupération (USB de rescue via mode dev).
