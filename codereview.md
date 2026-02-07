# Code Review - OhMyTermux

**Date** : 2026-01-29
**Branche** : `1.1.01`
**Revieweur** : Claude Code (Opus 4.5)

---

## Sommaire

| Categorie | Critique | Majeur | Mineur | Info |
|-----------|----------|--------|--------|------|
| Securite | 3 | 1 | 0 | 0 |
| Architecture | 0 | 4 | 2 | 0 |
| Fiabilite | 1 | 3 | 2 | 0 |
| Maintenabilite | 0 | 2 | 3 | 1 |
| **Total** | **4** | **10** | **7** | **1** |

---

## 1. Problemes critiques de securite

### 1.1 Injection de commande via `eval` dans `execute_command()`

**Fichiers** : `install.sh:407`, `xfce.sh:421`, `proot.sh:267`
**Severite** : CRITIQUE

La fonction `execute_command()` utilise `eval` pour executer des commandes :

```bash
if eval "$COMMAND $REDIRECT"; then
```

Toute donnee non-assainie passee a cette fonction peut entrainer une injection de commande. Bien que dans le contexte actuel les commandes sont construites en interne, ce pattern est dangereux et fragile face aux evolutions futures.

**Recommandation** : Remplacer `eval` par une execution directe via `bash -c` ou restructurer pour eviter l'evaluation dynamique de chaines.

---

### 1.2 Mot de passe expose via la ligne de commande

**Fichier** : `proot.sh:158`
**Severite** : CRITIQUE

Le mot de passe PRoot peut etre passe en argument `--password=VALUE`. Les arguments de ligne de commande sont visibles dans `/proc/*/cmdline` et dans la sortie de `ps`, exposant le mot de passe a tout utilisateur du systeme.

```bash
--password=*)
    PROOT_PASSWORD="${ARG#*=}"
```

De plus, dans `create_user_proot()` (`proot.sh:371`), le mot de passe est passe directement via `echo` et pipe :

```bash
echo '$USERNAME:$PASSWORD' | proot-distro login debian --shared-tmp -- env DISPLAY=:1.0 chpasswd
```

**Recommandation** : Utiliser `chpasswd` avec un heredoc ou un fichier temporaire avec permissions restrictives, et privilegier la saisie interactive pour les mots de passe.

---

### 1.3 `alias rm="rm -rf"` - Alias destructif par defaut

**Fichier** : `install.sh:627`
**Severite** : CRITIQUE

```bash
alias rm="rm -rf"
```

Cet alias remplace `rm` par `rm -rf` pour tous les utilisateurs, supprimant recursivement et sans confirmation. Une simple faute de frappe (`rm /` au lieu de `rm ./fichier`) peut detruire l'ensemble du systeme de fichiers.

**Recommandation** : Supprimer cet alias ou le remplacer par un alias plus sur comme `alias rm="rm -i"`.

---

### 1.4 Alias `push` avec message de commit generique

**Fichier** : `install.sh:648`
**Severite** : MAJEUR

```bash
alias push="git pull && git add . && git commit -m 'mobile push' && git push"
```

Cet alias fait `git add .` (ajout de tous les fichiers, y compris potentiellement des fichiers sensibles comme `.env`, cles privees) et commit avec un message generique sans contenu descriptif.

**Recommandation** : Supprimer cet alias ou le rendre interactif pour le message de commit. Ne jamais utiliser `git add .` dans un alias automatique.

---

## 2. Problemes d'architecture

### 2.1 Duplication massive de code entre scripts

**Fichiers** : `install.sh`, `xfce.sh`, `proot.sh`, `utils.sh`
**Severite** : MAJEUR

Les fonctions suivantes sont dupliquees de maniere quasi-identique dans chaque script :

- `info_msg()`, `success_msg()`, `error_msg()`, `title_msg()`, `subtitle_msg()`
- `execute_command()`
- `log_error()`
- `show_banner()`, `bash_banner()`
- `gum_confirm()`, `gum_choose()`, `gum_choose_multi()`
- `finish()` (trap EXIT handler)
- Bloc de chargement i18n (`download_i18n_system()` + bloc de source)
- Definition des couleurs (`COLOR_BLUE`, `COLOR_GREEN`, etc.)
- Definition de `REDIRECT`

Cela represente environ 200-300 lignes dupliquees par script. Toute correction de bug doit etre appliquee 4 fois.

**Recommandation** : Extraire ces fonctions dans un fichier `lib/common.sh` source par tous les scripts. Le repertoire `src/modules/` existe deja mais est vide - l'utiliser.

---

### 2.2 Bloc i18n duplique et incoherent

**Fichiers** : `install.sh:1-65`, `xfce.sh:1-89`, `proot.sh:1-104`, `utils.sh:1-36`
**Severite** : MAJEUR

Le code de chargement i18n est copie-colle dans chaque script avec des variations subtiles :

- `install.sh` : charge i18n puis initialise plus tard (ligne 314)
- `xfce.sh` : charge et initialise immediatement (ligne 70)
- `proot.sh` : charge et initialise immediatement (ligne 84-85)
- `utils.sh` : charge et initialise immediatement (ligne 30-32), sans `download_i18n_system()`

Cette incoherence peut causer des bugs ou les messages ne sont pas charges au bon moment.

**Recommandation** : Unifier le chargement i18n dans un seul fichier source commun.

---

### 2.3 Variable `SHELL_CHOICE` surchargee semantiquement

**Fichier** : `install.sh:90, 870, 888-892`
**Severite** : MAJEUR

`SHELL_CHOICE` est utilisee d'abord comme booleen (`false`/`true`) pour indiquer si la selection de shell est activee, puis reutilisee comme chaine (`"bash"`, `"zsh"`, `"fish"`) apres la selection :

```bash
SHELL_CHOICE=false           # ligne 90 - booleen
SHELL_CHOICE=true            # ligne 181 - booleen
SHELL_CHOICE=$(gum_choose...) # ligne 870 - chaine "zsh"
```

Plus tard (`install.sh:2101-2119`), des comparaisons melangent les deux semantiques :

```bash
if [ "$SHELL_CHOICE" = true ]; then   # booleen
    exec zsh -l
if [ "$SHELL_CHOICE" = "zsh" ]; then  # chaine
    exec zsh -l
```

**Recommandation** : Utiliser deux variables distinctes : `SHELL_ENABLED` (booleen) et `SELECTED_SHELL` (chaine).

---

### 2.4 Variables re-declarees et ecrasees

**Fichier** : `xfce.sh:136-159`
**Severite** : MAJEUR

Les variables de la section "CUSTOM VARIABLES" (lignes 136-146) sont immediatement ecrasees par la section "COMPLETE VARIABLES" (lignes 150-159) :

```bash
# CUSTOM VARIABLES
INSTALL_THEME=false           # ligne 136
SELECTED_THEME="WhiteSur"    # ligne 141

# COMPLETE VARIABLES
INSTALL_THEME=false           # ligne 153 (ecrase)
SELECTED_THEME=""             # ligne 157 (ecrase avec valeur differente!)
```

**Recommandation** : Supprimer la section "CUSTOM VARIABLES" et ne garder qu'une seule initialisation.

---

### 2.5 Repertoire `src/modules/` vide

**Fichier** : `src/modules/proot/`, `src/modules/utils/`, `src/modules/xfce/`
**Severite** : MINEUR

La structure modulaire est prevue mais jamais utilisee. Les modules sont vides.

**Recommandation** : Implementer la modularisation ou supprimer ces repertoires vides.

---

### 2.6 Fichiers `.sh` et `.fr.sh` mentionnes mais absents

**Fichier** : `CLAUDE.md`
**Severite** : MINEUR

La documentation mentionne `install.fr.sh`, `xfce.fr.sh`, `proot.fr.sh`, `utils.fr.sh` mais ces fichiers n'existent pas dans le depot. Le systeme i18n les a rendus obsoletes.

**Recommandation** : Mettre a jour la documentation pour refleter l'architecture actuelle basee sur i18n.

---

## 3. Problemes de fiabilite

### 3.1 Argument `--lang` casse dans le parseur de `install.sh`

**Fichier** : `install.sh:223-232`
**Severite** : CRITIQUE

Le parseur d'arguments utilise un `for` avec `shift`, mais `shift` dans une boucle `for ARG in "$@"` ne fonctionne pas comme attendu. Le `shift` decremente `$#` mais ne modifie pas l'iteration du `for` qui a deja capture la liste :

```bash
for ARG in "$@"; do
    case $ARG in
        --lang|-l)
            shift
            if [ -n "$1" ]; then    # $1 ne pointe plus vers le bon argument
                OVERRIDE_LANG="$1"
                shift
```

Apres `--lang`, le prochain ARG itere sera la valeur de langue (ex: `fr`), qui tombera dans le cas `*` et sera affecte a `PROOT_USERNAME`.

**Recommandation** : Utiliser une boucle `while` avec `shift` au lieu de `for ARG in "$@"` pour le parsing d'arguments, ou utiliser un index pour parcourir les arguments.

---

### 3.2 Fonction `uninstall_proot` appelee avant definition

**Fichier** : `install.sh:215`
**Severite** : MAJEUR

```bash
--uninstall)
    uninstall_proot
    exit 0
    ;;
```

La fonction `uninstall_proot` est appelee dans le parseur d'arguments mais n'est jamais definie dans `install.sh`. L'option `--uninstall` provoquera une erreur.

**Recommandation** : Implementer la fonction `uninstall_proot` ou supprimer l'option `--uninstall` du parseur.

---

### 3.3 Typo "recommanded" vs "recommandee"

**Fichiers** : `install.sh:1662,1669`, `xfce.sh:185,550`
**Severite** : MAJEUR

Des inconstances de nommage entre les scripts :

- `install.sh:1662` : `XFCE_VERSION="recommanded"` (anglais incorrect, "recommended")
- `xfce.sh:185` : `XFCE_VERSION="recommandee"` (francais)
- `xfce.sh:550` : `case "recommandee"` ne correspondra jamais a `"recommanded"` venant de `install.sh`

Le `case` de `xfce.sh` utilise `"recommandee"` et `"personnalisee"` (francais) tandis que `install.sh` passe `"recommanded"`, `"minimal"`, `"customized"` (pseudo-anglais). La version recommandee ne sera jamais selectionnee correctement quand `xfce.sh` est appele depuis `install.sh`.

**Recommandation** : Normaliser les valeurs en anglais (`minimal`, `recommended`, `customized`) dans tous les scripts.

---

### 3.4 `REDIRECT` defini comme chaine evaluee par `eval`

**Fichiers** : `install.sh:132-136`, `xfce.sh:110-114`, `proot.sh:119-123`
**Severite** : MAJEUR

```bash
REDIRECT="> /dev/null 2>&1"   # install.sh
REDIRECT=">/dev/null 2>&1"    # xfce.sh / proot.sh
```

`REDIRECT` est utilise comme chaine dans `eval "$COMMAND $REDIRECT"` et `bash -c "$COMMAND $REDIRECT"`. Mais `REDIRECT` est initialise *avant* le parsing des arguments `--verbose`. Si `--verbose` est passe, `REDIRECT` est mis a jour dans le parseur, mais dans `xfce.sh` et `proot.sh`, `REDIRECT` est defini *avant* le parseur d'arguments, donc il est correctement ecrase. Cependant, dans `install.sh`, `REDIRECT` est defini ligne 132 mais `VERBOSE` est modifie ligne 219, et `REDIRECT` n'est jamais re-evalue apres. La variable `REDIRECT` de `install.sh:133` restera `"> /dev/null 2>&1"` meme en mode verbose, car le `if` de la ligne 132 a deja ete evalue.

**Recommandation** : Deplacer l'evaluation de `REDIRECT` apres le parsing des arguments, ou utiliser une fonction.

---

### 3.5 `configure_xfce()` appelee sans argument dans `xfce.sh`

**Fichier** : `xfce.sh:1146`
**Severite** : MINEUR

```bash
configure_xfce    # appel sans argument
```

Mais `configure_xfce()` attend un argument `$1` pour `INSTALL_TYPE` (ligne 452). La variable locale `INSTALL_TYPE` sera vide, et le `case` de la ligne 549 ne correspondra a aucun cas defini.

**Recommandation** : Passer `$INSTALL_TYPE` en argument : `configure_xfce "$INSTALL_TYPE"`.

---

### 3.6 Nettoyage des fichiers temporaires non garanti

**Fichier** : `xfce.sh:686-710`
**Severite** : MINEUR

Les archives telecharges (`theme.zip`, `*.zip`) ne sont pas nettoyees en cas d'erreur dans la chaine de commandes. Si `unzip` echoue, l'archive reste sur le systeme.

**Recommandation** : Ajouter un `trap` de nettoyage ou verifier la suppression dans un `finally`.

---

## 4. Problemes de maintenabilite

### 4.1 Menus interactifs (mode texte) a maintenance lourde

**Fichiers** : `install.sh:872-892, 1156-1196, 1472-1528`, `xfce.sh:978-1112`
**Severite** : MAJEUR

Chaque menu interactif en mode texte (non-Gum) est code manuellement avec des `echo` numerotes, `read`, `tput cuu N` et des `case` correspondants. La valeur de `tput cuu` est codee en dur et doit etre modifiee a chaque ajout/suppression d'option.

Exemple (`install.sh:1177`) :

```bash
tput cuu 18   # 18 lignes codees en dur
tput ed
```

**Recommandation** : Creer une fonction generique `text_choose()` qui accepte un tableau d'options et gere automatiquement l'affichage, la saisie et le nettoyage terminal.

---

### 4.2 Hardcoded paths pour Termux

**Fichiers** : Multiples
**Severite** : MAJEUR

Chemins codes en dur partout :

- `/data/data/com.termux/files/usr/share/oh-my-posh/themes/` (`install.sh:1112`)
- `$PREFIX/var/lib/proot-distro/installed-rootfs/debian/` (multiples)
- `/data/data/com.termux/files/usr/share/backgrounds/` (`xfce.sh:581`)

**Recommandation** : Definir ces chemins comme constantes en debut de fichier (`PROOT_ROOT_DIR`, `THEMES_DIR`, etc.).

---

### 4.3 Messages non-traduits (hardcodes en anglais)

**Fichiers** : Multiples
**Severite** : MINEUR

Plusieurs messages sont encore codes en dur au lieu d'utiliser le systeme i18n :

- `install.sh:791` : `"Argonaut theme installed"` (anglais)
- `install.sh:2039` : `"Installation of the dependencies"` (anglais)
- `install.sh:2087` : `"Saving the installation scripts"` (anglais)
- `xfce.sh:835` : `"XFCE installation"` (anglais)
- `xfce.sh:837` : `"Update packages"` (anglais)
- `xfce.sh:686-689` : `"Download theme"`, `"Extraction of theme"` (anglais)
- Nombreux messages dans `proot.sh` et `xfce.sh`

**Recommandation** : Migrer tous les messages restants vers le systeme i18n.

---

### 4.4 Commentaires bilingues

**Fichiers** : `install.sh` (principal)
**Severite** : MINEUR

Les commentaires melangent francais et anglais dans le meme fichier :

```bash
# Si on est en mode FULL_INSTALL, demander les identifiants au debut
# Rechargement du shell
# Suppression of the login banner
# Checking and installing the necessary dependencies
```

**Recommandation** : Uniformiser la langue des commentaires (de preference anglais pour un projet open-source).

---

### 4.5 `SCRIPT_CHOICE` utilise mais jamais defini

**Fichier** : `install.sh:241, 310`
**Severite** : MINEUR

```bash
SCRIPT_CHOICE=true   # ligne 241 (dans --full)
SCRIPT_CHOICE=true   # ligne 310 (dans ONLY_GUM)
```

`SCRIPT_CHOICE` est assigne mais jamais utilise nulle part dans le script. Aucune condition ne teste cette variable.

**Recommandation** : Supprimer les references a `SCRIPT_CHOICE` ou implementer la fonctionnalite associee.

---

### 4.6 Fichier binaire `.deb` dans le depot Git

**Fichier** : `src/mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb` (1.9 MB)
**Severite** : INFO

Un fichier binaire de 1.9 MB est versionne dans le depot. Git n'est pas optimise pour les binaires et chaque modification augmentera la taille du depot de maniere permanente.

**Recommandation** : Heberger ce fichier sur GitHub Releases ou un CDN et le telecharger a l'installation.

---

## 5. Resume et priorites

### Actions immediates (Critique)

1. Corriger le parseur d'arguments `--lang` dans `install.sh` (boucle `for` + `shift`)
2. Supprimer l'alias `rm="rm -rf"`
3. Securiser la gestion des mots de passe PRoot (ne pas exposer via CLI)
4. Auditer les usages de `eval` dans `execute_command()`

### Actions a court terme (Majeur)

5. Normaliser les valeurs de version XFCE (`recommanded` vs `recommandee`)
6. Corriger la variable `SHELL_CHOICE` surchargee (booleen vs chaine)
7. Supprimer les variables dupliquees dans `xfce.sh`
8. Implementer ou supprimer `uninstall_proot`
9. Extraire le code commun dans `lib/common.sh`
10. Corriger l'evaluation de `REDIRECT` dans `install.sh`

### Actions a moyen terme (Mineur)

11. Uniformiser les commentaires en anglais
12. Migrer les messages hardcodes vers i18n
13. Passer `configure_xfce()` avec l'argument requis
14. Supprimer `SCRIPT_CHOICE` inutilise
15. Creer une fonction generique pour les menus texte
16. Definir les chemins Termux comme constantes
17. Nettoyer les modules vides ou les implementer

---

## 6. Points positifs

- **Systeme i18n bien concu** : La bibliotheque `i18n/i18n.sh` est propre, avec cache de traductions, lazy loading et logging des cles manquantes.
- **Double mode d'interaction** : Le support Gum + mode texte offre une bonne flexibilite.
- **Gestion d'erreurs** : Le trap EXIT et les fonctions `log_error()` sont presents dans tous les scripts.
- **Suite de tests** : Le repertoire `tests/` inclut des tests unitaires, d'integration et de performance pour le systeme i18n.
- **Fallback i18n** : Le mecanisme de telechargement et fallback si i18n est absent est robuste.
- **Structure claire** : La separation en scripts (install, xfce, proot, utils) suit une logique fonctionnelle comprehensible.
