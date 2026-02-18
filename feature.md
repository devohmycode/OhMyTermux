# OhMyTermux - Propositions d'améliorations et nouvelles fonctionnalités

> Rapport généré le 2026-02-04 - Version 1.1.02

---

## Table des matières

1. [Corrections critiques (sécurité)](#1-corrections-critiques-sécurité)
2. [Améliorations de l'architecture](#2-améliorations-de-larchitecture)
3. [Nouvelles fonctionnalités](#3-nouvelles-fonctionnalités)
4. [Expérience utilisateur](#4-expérience-utilisateur)
5. [Écosystème et intégrations](#5-écosystème-et-intégrations)
6. [Internationalisation](#6-internationalisation)
7. [Environnement graphique](#7-environnement-graphique)
8. [PRoot et développement](#8-proot-et-développement)
9. [Maintenance et DevOps](#9-maintenance-et-devops)
10. [Roadmap suggérée](#10-roadmap-suggérée)

---

## 1. Corrections critiques (sécurité)

### 1.1 Suppression de `alias rm="rm -rf"`
- **Problème** : L'alias actuel supprime récursivement sans confirmation. Un `rm fichier` accidentel dans le mauvais répertoire peut être catastrophique.
- **Proposition** : Remplacer par `alias rm="rm -i"` ou supprimer complètement l'alias.

### 1.2 Exposition du mot de passe PRoot
- **Problème** : Le flag `--password=VALUE` est visible dans la liste des processus (`ps aux`).
- **Proposition** : Lire le mot de passe via `read -s` ou un fichier temporaire avec permissions restrictives (600), supprimé immédiatement après usage.

### 1.3 Usage de `eval` dans `execute_command()`
- **Problème** : `eval` permet l'injection de commandes si des entrées utilisateur ne sont pas sanitisées.
- **Proposition** : Remplacer par des tableaux bash (`"${cmd[@]}"`) ou `bash -c` avec arguments séparés.

### 1.4 Alias git `push` dangereux
- **Problème** : `alias push="git add . && git commit && git push"` peut committer des secrets (.env, credentials).
- **Proposition** : Supprimer l'alias ou le remplacer par un wrapper qui vérifie un `.gitignore` avant de `git add`.

### 1.5 Validation des entrées utilisateur
- **Problème** : Les noms d'utilisateur et mots de passe PRoot ne sont pas validés contre l'injection.
- **Proposition** : Ajouter une validation stricte dans `lib/constants.sh` (regex alphanumérique, longueur min/max).

---

## 2. Améliorations de l'architecture

### 2.1 Système de configuration déclaratif
- **État actuel** : Configuration via arguments CLI uniquement.
- **Proposition** : Supporter un fichier `~/.config/OhMyTermux/config.yml` permettant de décrire une installation complète de manière déclarative.
```yaml
shell: zsh
prompt: powerlevel10k
plugins:
  - zsh-autosuggestions
  - zsh-syntax-highlighting
packages:
  - neovim
  - nodejs-lts
  - python
xfce:
  mode: recommended
  browser: firefox
  theme: WhiteSur
proot:
  enabled: true
  username: dev
```
- **Avantage** : Installations reproductibles, partageables, et versionnables.

### 2.2 Système de plugins
- **Proposition** : Créer une architecture de plugins dans `plugins/` permettant à des tiers d'ajouter des modules sans modifier le code principal.
- **Structure** :
```
plugins/
  plugin-name/
    manifest.sh      # Nom, version, dépendances
    install.sh       # Script d'installation
    messages/en.sh   # Traductions
    messages/fr.sh
```
- **API** : `register_plugin()`, `plugin_hook()` pour s'insérer dans le flux d'installation.

### 2.3 Idempotence de l'installation
- **Problème** : Relancer `install.sh` peut provoquer des doublons ou des conflits.
- **Proposition** : Détecter l'état existant avant chaque étape (vérifier si un package est déjà installé, si un fichier de config existe déjà) et ne réexécuter que ce qui est nécessaire.

### 2.4 Fichier de verrouillage / état
- **Proposition** : Maintenir un fichier `~/.config/OhMyTermux/state.json` qui enregistre ce qui est installé, quand, et dans quelle version. Permet la reprise après échec et les mises à jour différentielles.

### 2.5 Codes de sortie standardisés
- **Proposition** : Définir des codes de sortie cohérents dans `lib/constants.sh` :
  - `0` : Succès
  - `1` : Erreur générale
  - `2` : Dépendance manquante
  - `3` : Espace disque insuffisant
  - `4` : Erreur réseau
  - `5` : Annulation utilisateur

---

## 3. Nouvelles fonctionnalités

### 3.1 Mécanisme de mise à jour
- **Problème** : Aucun moyen de mettre à jour sans tout réinstaller.
- **Proposition** : Commande `ohmytermux update` qui :
  - Vérifie la version distante sur GitHub
  - Compare avec la version locale (via `state.json`)
  - Applique les mises à jour différentielles
  - Préserve les personnalisations utilisateur

### 3.2 Commande de désinstallation complète
- **Problème** : Seul le PRoot peut être désinstallé.
- **Proposition** : `ohmytermux uninstall [--all|--xfce|--proot|--shell]` qui restaure l'état précédent proprement.

### 3.3 Sauvegarde et restauration
- **Proposition** : `ohmytermux backup` / `ohmytermux restore`
  - Sauvegarde les configurations (shell, XFCE, aliases, thèmes)
  - Export en archive compressée
  - Restauration sur un nouveau device ou après un reset Termux
  - Sync optionnel vers un dépôt Git personnel

### 3.4 Mode hors-ligne
- **Problème** : L'installation nécessite une connexion internet permanente.
- **Proposition** : Commande `ohmytermux bundle` qui pré-télécharge tous les assets dans une archive portable. L'installation peut ensuite se faire offline avec `install.sh --offline bundle.tar.gz`.

### 3.5 Profils d'installation
- **Proposition** : Profils prédéfinis pour différents cas d'usage :
  - **Développeur** : ZSH + Neovim + NodeJS + Python + Git
  - **SysAdmin** : ZSH + tmux + SSH + nala
  - **Minimal** : Bash + packages de base uniquement
  - **Graphique complet** : ZSH + XFCE Customized + PRoot + tous les thèmes
- **Commande** : `install.sh --profile developer`

### 3.6 Gestionnaire de thèmes dynamique
- **Proposition** : Commande `ohmytermux theme [list|apply|preview]` pour changer de thème XFCE/terminal après l'installation sans tout reconfigurer.

### 3.7 Dotfiles manager
- **Proposition** : Intégrer un gestionnaire de dotfiles léger :
  - Symlinks vers un répertoire centralisé
  - Versioning Git optionnel
  - Import/export de configurations complètes
  - Compatible avec les standards (stow, chezmoi-like)

### 3.8 Vérification de l'espace disque
- **Proposition** : Avant chaque étape majeure (XFCE, PRoot), vérifier l'espace disponible et avertir l'utilisateur si insuffisant, avec estimation de l'espace requis.

### 3.9 Health check post-installation
- **Proposition** : Commande `ohmytermux doctor` qui vérifie :
  - Intégrité des fichiers installés
  - Services fonctionnels (PulseAudio, VirGL, dbus)
  - Permissions correctes
  - Packages manquants ou cassés
  - Rapport avec suggestions de correction

---

## 4. Expérience utilisateur

### 4.1 Barre de progression globale
- **Problème** : L'utilisateur ne voit pas la progression globale de l'installation.
- **Proposition** : Afficher une barre de progression avec étapes numérotées : `[3/8] Installation des packages...`

### 4.2 Résumé de pré-installation
- **Proposition** : Après la sélection de toutes les options, afficher un récapitulatif complet avant de lancer l'installation :
```
╔══════════════════════════════════════╗
║   Résumé de l'installation           ║
╠══════════════════════════════════════╣
║ Shell    : ZSH + PowerLevel10k      ║
║ Packages : neovim, nodejs, python    ║
║ XFCE     : Recommended + WhiteSur   ║
║ PRoot    : Oui (user: dev)           ║
║ Espace   : ~3.5 GB requis           ║
╚══════════════════════════════════════╝
Continuer ? [O/n]
```

### 4.3 Mode interactif guidé (wizard)
- **Proposition** : Pour les nouveaux utilisateurs, un mode wizard pas-à-pas avec explications pour chaque choix (au lieu de la sélection multiple d'un coup).

### 4.4 Messages d'erreur contextuels
- **Proposition** : En cas d'erreur, afficher non seulement le message mais aussi :
  - La cause probable
  - Les actions correctives suggérées
  - Un lien vers la documentation ou les issues GitHub

### 4.5 Logs structurés
- **Proposition** : Passer du fichier `install.log` texte à un format structuré (JSON lines) pour faciliter le debug :
```json
{"ts":"2026-02-04T10:30:00","level":"ERROR","step":"xfce","msg":"Failed to download theme","url":"...","code":404}
```

### 4.6 Notifications de fin d'installation
- **Proposition** : Notification Android via `termux-notification` quand l'installation (longue) est terminée, surtout en mode `--full`.

---

## 5. Écosystème et intégrations

### 5.1 Intégration OhMyTermuxScript
- **Selon le README** : Prévu mais non implémenté.
- **Proposition** : Permettre l'exécution de scripts utilisateur personnalisés à des hooks définis du processus d'installation (pre-install, post-shell, post-xfce, post-proot, post-install).

### 5.2 Intégration OhMyObsidian
- **Selon le README** : Prévu mais non implémenté.
- **Proposition** : Option pour installer et configurer Obsidian dans le PRoot, avec sync Termux storage.

### 5.3 Support VS Code Server
- **Proposition** : Option pour installer `code-server` dans le PRoot Debian, accessible via navigateur, avec configuration XFCE desktop shortcut.

### 5.4 Support Docker dans PRoot
- **Proposition** : Détecter si le kernel supporte les namespaces et proposer l'installation de `podman` ou `docker` (via PRoot-distro) pour le développement conteneurisé.

### 5.5 Intégration Termux:API
- **Proposition** : Exploiter davantage les API Termux :
  - `termux-battery-status` pour alerter si batterie faible pendant l'install
  - `termux-wifi-connectioninfo` pour vérifier la connexion
  - `termux-storage-get` pour l'import de fichiers
  - `termux-fingerprint` pour le déverrouillage PRoot

### 5.6 Marketplace de thèmes communautaires
- **Proposition** : Répertoire GitHub (ou branche dédiée) où les utilisateurs peuvent soumettre leurs thèmes/configs. Installables via `ohmytermux theme install <nom>`.

---

## 6. Internationalisation

### 6.1 Nouvelles langues
- **État actuel** : Anglais et Français uniquement.
- **Proposition** : Ajouter les langues les plus demandées :
  - Espagnol (es)
  - Portugais-Brésil (pt-BR)
  - Allemand (de)
  - Arabe (ar) - avec support RTL dans Gum
  - Chinois simplifié (zh-CN)
  - Russe (ru)
- **Méthode** : Utiliser le `template.sh` existant et solliciter la communauté via des issues GitHub dédiées par langue.

### 6.2 Outil de traduction communautaire
- **Proposition** : Script `i18n/translate_helper.sh` qui :
  - Liste les clés non traduites pour une langue donnée
  - Génère un fichier pré-rempli avec les clés manquantes
  - Valide la complétude et la syntaxe d'un fichier de traduction

### 6.3 Suppression des fichiers `.fr.sh` dupliqués
- **Problème** : `install.fr.sh`, `xfce.fr.sh`, `proot.fr.sh`, `utils.fr.sh` dupliquent le code des versions anglaises.
- **Proposition** : Supprimer ces doublons et s'appuyer entièrement sur le système i18n pour le multilingue. Réduirait significativement la maintenance.

---

## 7. Environnement graphique

### 7.1 Nouveaux thèmes
- **Proposition** : Ajouter des thèmes populaires :
  - **Catppuccin** (Mocha, Latte, Frappe, Macchiato)
  - **Dracula**
  - **Nord**
  - **Gruvbox**
  - **Tokyo Night** (déjà dans le terminal, l'étendre au thème GTK)

### 7.2 Support Wayland natif
- **Proposition** : Préparer le support de Wayland comme alternative à X11 quand Termux le supportera pleinement (via `termux-wayland`).

### 7.3 Lanceur d'applications alternatif
- **Proposition** : Option pour installer **Rofi** ou **dmenu** comme lanceur d'applications alternatif au WhiskerMenu.

### 7.4 Gestionnaire de fenêtres alternatif
- **Proposition** : Proposer des alternatives à XFCE pour les utilisateurs avancés :
  - **i3** (tiling window manager)
  - **Openbox** (léger)
  - **Sway** (Wayland, futur)
- Permettrait de réduire l'empreinte mémoire pour les appareils limités.

### 7.5 Panel presets
- **Proposition** : Plusieurs dispositions de panel XFCE prédéfinies :
  - **macOS-like** : Panel en haut + dock en bas
  - **Windows-like** : Taskbar en bas
  - **Minimal** : Panel auto-hide

### 7.6 Fond d'écran dynamique
- **Proposition** : Script de rotation automatique des wallpapers (toutes les X minutes), configurable via la commande `ohmytermux`.

---

## 8. PRoot et développement

### 8.1 Distributions additionnelles
- **État actuel** : Debian uniquement.
- **Proposition** : Supporter d'autres distributions via `proot-distro` :
  - **Ubuntu** (plus de packages, PPAs)
  - **Alpine** (ultra-léger, ~100 MB)
  - **Arch Linux** (AUR, bleeding edge)
  - **Fedora** (alternative RPM)

### 8.2 Environnements de développement préconfigurés
- **Proposition** : Commande `ohmytermux devenv <stack>` qui installe dans le PRoot :
  - **web** : Node.js + npm + yarn + TypeScript
  - **python** : Python 3 + pip + venv + jupyter
  - **rust** : Rustup + cargo
  - **go** : Go + outils standard
  - **java** : JDK + Maven/Gradle
  - **c-cpp** : GCC + CMake + GDB

### 8.3 Snapshots PRoot
- **Proposition** : Système de snapshots pour le PRoot :
  - `ohmytermux proot snapshot create <nom>` : Crée un snapshot
  - `ohmytermux proot snapshot restore <nom>` : Restaure
  - `ohmytermux proot snapshot list` : Liste les snapshots
- Permet d'expérimenter sans risque.

### 8.4 Partage de fichiers amélioré
- **Proposition** : Montages bidirectionnels configurables entre Termux et PRoot, au-delà du répertoire par défaut. Configuration dans `config.yml`.

### 8.5 Support GPU amélioré
- **Proposition** : Détection automatique du GPU (Adreno, Mali, PowerVR) et installation du driver mesa-vulkan approprié au lieu du package hardcodé pour Adreno.

---

## 9. Maintenance et DevOps

### 9.1 CI/CD avec GitHub Actions
- **Proposition** : Pipeline d'intégration continue :
  - Linting avec `shellcheck` sur tous les scripts
  - Exécution des tests i18n
  - Validation de la complétude des traductions
  - Tests d'installation dans un conteneur Termux (via `termux-docker`)
  - Release automatique avec changelog

### 9.2 Versioning sémantique
- **Proposition** : Adopter le semver strict avec fichier `VERSION` à la racine, utilisé par le mécanisme de mise à jour.

### 9.3 Changelog automatique
- **Proposition** : Générer un `CHANGELOG.md` à partir des commits conventionnels (`feat:`, `fix:`, `docs:`, etc.).

### 9.4 Métriques d'installation (opt-in)
- **Proposition** : Télémétrie anonyme optionnelle pour comprendre :
  - Quels shells/thèmes/packages sont les plus populaires
  - Quelles étapes échouent le plus souvent
  - Quels appareils Android sont utilisés
- **Important** : Strictement opt-in, transparent, et désactivable.

### 9.5 Documentation développeur
- **Proposition** : Guide de contribution détaillé (`CONTRIBUTING.md`) avec :
  - Architecture du code
  - Comment ajouter un plugin/thème/langue
  - Standards de code (shellcheck clean, i18n obligatoire)
  - Processus de review

---

## 10. Roadmap suggérée

### Phase 1 - Stabilisation (priorité haute)
| # | Tâche | Impact |
|---|-------|--------|
| 1 | Corriger les 5 problèmes de sécurité (section 1) | Critique |
| 2 | Supprimer les fichiers `.fr.sh` dupliqués | Dette technique |
| 3 | Standardiser les codes de sortie | Fiabilité |
| 4 | Ajouter la vérification d'espace disque | UX |
| 5 | CI/CD avec shellcheck + tests | Qualité |

### Phase 2 - Fonctionnalités essentielles
| # | Tâche | Impact |
|---|-------|--------|
| 6 | Mécanisme de mise à jour (`ohmytermux update`) | Majeur |
| 7 | Commande de désinstallation | Attendu |
| 8 | Sauvegarde/restauration | Fiabilité |
| 9 | Fichier de configuration déclaratif | UX |
| 10 | Résumé pré-installation + barre de progression | UX |

### Phase 3 - Enrichissement
| # | Tâche | Impact |
|---|-------|--------|
| 11 | Profils d'installation prédéfinis | UX |
| 12 | Distributions PRoot additionnelles | Fonctionnel |
| 13 | Nouveaux thèmes (Catppuccin, Dracula, Nord) | Cosmétique |
| 14 | Commande `ohmytermux doctor` | Support |
| 15 | 3-4 nouvelles langues (es, pt-BR, de, zh-CN) | Accessibilité |

### Phase 4 - Écosystème
| # | Tâche | Impact |
|---|-------|--------|
| 16 | Système de plugins | Extensibilité |
| 17 | Environnements de dev préconfigurés | DX |
| 18 | VS Code Server / code-server | DX |
| 19 | Gestionnaire de thèmes dynamique | UX |
| 20 | Snapshots PRoot | Fiabilité |

---

*Ce rapport est basé sur l'analyse complète du code source, de l'architecture, et de la documentation du projet OhMyTermux en version 1.1.02.*
