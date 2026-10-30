# TP4 — Dépôts d'artefacts avec Nexus

**Module :** DevOps 2 (ECUE733) · **Travail :** individuel, en classe (à terminer chez vous si besoin)

Vous reprenez le site des cours du TP3 (Next.js, Strapi, PostgreSQL), dans son état corrigé.
Aujourd'hui, chaque `npm ci` télécharge ses dépendances directement sur **npmjs.org** et chaque
`docker pull` va sur **Docker Hub** : si l'un d'eux est lent, indisponible ou compromis, votre
build l'est aussi. Et rien de ce que vous produisez (paquets, images) n'est stocké quelque part.

Dans ce TP, vous installez **votre propre Nexus**, vous y faites passer les dépendances du site,
vous publiez la logique des cours comme **paquet npm interne** versionné, puis vous publiez
**l'image Docker du front** et la déployez depuis Nexus.

> **La règle à retenir : on lit via le group, on écrit dans le hosted.**
>
> | Type de dépôt | Rôle                                                        | Exemple du TP |
> |---------------|-------------------------------------------------------------|---------------|
> | **proxy**     | cache d'un registre public                                  | `npm-proxy` → npmjs.org |
> | **hosted**    | artefacts produits par l'équipe (on y publie)               | `npm-hosted` |
> | **group**     | une seule adresse qui regroupe hosted + proxy (on y lit)    | `npm-group` |

| Service       | Rôle                                                   | Profil   | Port hôte |
|---------------|--------------------------------------------------------|----------|-----------|
| `frontend`    | Site Next.js des cours                                 | —        | 3000      |
| `strapi`      | CMS headless : API REST + admin                        | —        | 1337      |
| `postgres`    | Base de données de Strapi                              | —        | *aucun*   |
| `pgadmin`     | Administration de la base                              | —        | 5050      |
| `nexus`       | Gestionnaire de dépôts : UI + npm (8081), Docker push (8082), Docker pull (8083) | — | 8081, 8082, 8083 |
| `npm`         | Client npm dans un conteneur (Node.js inutile sur votre machine) | `tools` | — |
| `unit`, `integration`, `e2e` | Tests du TP3                            | `test`, `e2e` | — |

> **Le service `npm`.** Il lance npm dans un conteneur relié à Nexus. Le premier argument est le
> dossier où travailler, la suite est la commande npm :
>
> ```bash
> docker compose run --rm npm frontend ci                 # = "npm ci" dans frontend/
> docker compose run --rm npm packages/cours-utils test   # = "npm test" dans packages/cours-utils/
> ```

## Objectifs

À la fin du TP, vous saurez :

1. distinguer les dépôts **hosted**, **proxy** et **group**, pour npm et pour Docker ;
2. configurer un client (npm, Docker) pour passer par un gestionnaire de dépôts, **sans exposer
   de secret** ;
3. versionner un paquet selon **SemVer** et expliquer pourquoi une version publiée ne se
   **republie pas** ;
4. **pousser et tirer une image Docker** depuis Nexus, et distinguer **tag** et **digest**.

## Prérequis

- Docker Desktop (ou Docker Engine) avec **Docker Compose v2** : `docker compose version`.
- **Environ 4 Go de RAM disponibles pour Docker** : Nexus en consomme 2 à lui seul.
  Sous Docker Desktop : *Settings → Resources → Memory*. Arrêtez les stacks des TP précédents
  (`docker compose down` dans leurs dossiers).
- Ports libres : 8081, 8082, 8083, 3000, 1337, 5050.
- **Avant la séance**, téléchargez les images (plusieurs centaines de Mo) :
  ```bash
  docker pull sonatype/nexus3:3.96.5
  docker pull node:22
  docker pull node:22-alpine
  ```
- `curl` et **`jq`** (utilisés par les scripts) : `jq --version`. Installation : Ubuntu/Debian
  `sudo apt install jq curl` ; macOS `brew install jq` ; Windows `winget install jqlang.jq`
  (puis rouvrez Git Bash).
- Node.js n'est **pas** nécessaire : npm tourne dans le service `npm`.
- Sous Windows, lancez les commandes et les scripts `scripts/*.sh` depuis **Git Bash**.
- Sous Linux, si `id -u` n'affiche pas `1000`, mettez la sortie de `id -u` et de `id -g` dans
  `HOST_UID` et `HOST_GID` de votre `.env` (partie 0).

## Structure du dépôt

```
.
├── docker-compose.yml          # stack du TP3 + nexus + client npm
├── .env.example                # à copier en .env (jamais commité)
├── REPONSES.md                 # vos réponses (à compléter)
├── backend/                    # Strapi (inchangé depuis le TP3)
├── frontend/                   # site Next.js
│   ├── .npmrc                  # registre npm du front (partie 2)
│   └── lib/cours.ts            # logique des cours… qui va devenir un paquet (partie 3)
├── packages/
│   └── cours-utils/            # le paquet interne à publier (partie 3)
│       ├── package.json        # à compléter
│       ├── .npmrc              # à compléter
│       ├── src/index.ts        # code de frontend/lib/cours.ts, déjà déplacé
│       └── tests/index.test.ts # ses tests unitaires
└── scripts/
    ├── wait-for-nexus.sh       # attend que Nexus soit prêt
    ├── setup-docker.sh         # crée les dépôts Docker (partie 4)
    └── rattrapage-npm.sh       # en cas de blocage à la partie 1
```

> **Rendu progressif.** Répondez aux questions dans `REPONSES.md` au fil de l'eau, et faites les
> **commits demandés** au moment indiqué : ils font partie de l'évaluation.

---

## Partie 0 — Mise en route

**Forkez** ce dépôt, puis clonez votre fork :

```bash
git clone <url-de-votre-fork> tp4 && cd tp4
cp .env.example .env
docker compose up -d nexus
scripts/wait-for-nexus.sh          # premier démarrage : 1 à 3 minutes
```

Nexus génère un mot de passe administrateur aléatoire au premier démarrage :

```bash
docker compose exec nexus sh -c 'cat /nexus-data/admin.password'; echo
```

Ouvrez http://localhost:8081, cliquez sur **Sign in** et connectez-vous avec `admin` et ce mot de
passe. Un assistant s'ouvre :

1. choisissez un **nouveau mot de passe admin** — notez-le, vous en aurez besoin ;
2. *Configure Anonymous Access* : choisissez **Enable anonymous access**. Tout le monde pourra
   **lire** les dépôts (télécharger des paquets), mais seuls les comptes autorisés pourront
   **écrire** (publier) ;
3. acceptez la licence (EULA) de la Community Edition et terminez l'assistant.

> Nexus crée d'office des dépôts `maven-*` et `nuget-*` : ils ne servent pas dans ce TP, ignorez-les.

> ✅ **Vérifiez :** déconnectez-vous, puis reconnectez-vous en `admin` avec votre nouveau mot de passe.

## Partie 1 — Les dépôts npm

Tout se passe dans l'UI, menu *Settings* (roue dentée) → *Repository* → *Repositories* →
*Create repository*.

1. **`npm (proxy)`** — *Name* : `npm-proxy` ; *Remote storage* : `https://registry.npmjs.org`.
   *Create repository*.
2. **`npm (hosted)`** — *Name* : `npm-hosted` ; *Deployment policy* : **Disable redeploy**.
3. **`npm (group)`** — *Name* : `npm-group` ; *Members* : ajoutez **`npm-hosted` puis
   `npm-proxy`**, dans cet ordre.

Activez ensuite l'authentification npm : *Settings → Security → Realms*, faites passer
**npm Bearer Token Realm** dans *Active*, puis *Save*.

Créez enfin un compte dédié à la publication — on ne publie jamais avec `admin` :

4. *Security → Roles → Create role* (*Nexus role*) — *Role ID* et *Role name* : `deployer-role` ;
   privilèges :
   - `nx-repository-view-npm-*-browse`
   - `nx-repository-view-npm-*-read`
   - `nx-repository-view-npm-npm-hosted-add`
   - `nx-repository-view-npm-npm-hosted-edit`
5. *Security → Users → Create local user* — *ID* : `deployer` ; un mot de passe d'au moins
   8 caractères ; *Status* : *Active* ; rôle : `deployer-role`.

npm s'authentifiera avec `deployer` grâce à une valeur encodée en base64. Calculez-la et mettez-la
dans **`.env`** :

```bash
printf 'deployer:VOTRE_MOT_DE_PASSE' | base64
```

```
NPM_AUTH=ZGVwbG95ZXI6...
```

> **`.env` n'est jamais commité.** Vérifiez-le : `git check-ignore .env` doit afficher `.env`.

> **Bloqué ?** `scripts/rattrapage-npm.sh` crée les dépôts, le realm, le rôle et l'utilisateur
> (il demande le mot de passe admin, puis celui à donner à `deployer`). Utilisez-le seulement en
> dernier recours et **signalez-le dans `REPONSES.md`**.

> ✅ **Vérifiez :** sans aucun identifiant, le group répond… avec un paquet qu'il est allé
> chercher sur npmjs.org à travers le proxy :
> ```bash
> curl -s http://localhost:8081/repository/npm-group/lodash | head -c 200; echo
> ```

➡️ Répondez à **Q1 à Q3**.

## Partie 2 — Consommer via le group

Le client npm lit sa configuration dans le fichier `.npmrc` du projet. Remplacez le contenu de
`frontend/.npmrc` par :

```ini
registry=http://nexus:8081/repository/npm-group/
```

> **Pourquoi `nexus` et pas `localhost` ?** npm ne tourne pas sur votre machine mais dans des
> conteneurs : dans le réseau Compose, `nexus` est le nom du service. Pendant un `docker build`,
> le conteneur de build n'est pas dans ce réseau ; le `docker-compose.yml` déclare donc que
> `nexus` désigne la machine hôte, où le port 8081 est publié :
> ```yaml
>     build:
>       context: ./frontend
>       extra_hosts:
>         - "nexus:host-gateway"
> ```
> Une seule adresse, valable partout, commitée sans aucun secret.

Installez les dépendances du front, puis reconstruisez et lancez les tests (leur image fait aussi
un `npm ci`) :

```bash
docker compose run --rm npm frontend ci
docker compose build unit
docker compose run --rm unit
```

> ✅ **Vérifiez :**
> - dans l'UI, *Browse* → `npm-proxy` contient maintenant `next`, `react`, `vitest`… ;
> - `git status` : seul `frontend/.npmrc` est modifié — le `package-lock.json` n'a pas bougé.

Faites une capture de *Browse* → `npm-proxy` : `captures/npm-proxy.png`. Commitez :

```bash
git add frontend/.npmrc
git commit -m "Fait passer les dépendances du front par Nexus"
```

➡️ Répondez à **Q4 à Q6**.

## Partie 3 — Publier un paquet interne

La logique des cours (`formatDuration`, `filterCours`, `sortBySession`…) va être partagée par
d'autres applications : elle devient le paquet **`@devops2/cours-utils`**. Le code de
`frontend/lib/cours.ts` et ses tests ont déjà été déplacés dans `packages/cours-utils/`.

1. Installez ses dépendances et lancez ses tests :

   ```bash
   docker compose run --rm npm packages/cours-utils ci
   docker compose run --rm npm packages/cours-utils test
   ```

2. Complétez `packages/cours-utils/package.json` en ajoutant en tête ces quatre champs :

   ```json
     "name": "@devops2/cours-utils",
     "version": "0.1.0",
     "files": ["dist"],
     "publishConfig": {
       "registry": "http://nexus:8081/repository/npm-hosted/"
     },
   ```

   - `name` : le nom du paquet ; `@devops2` est son *scope* (l'espace de noms de l'équipe) ;
   - `version` : sa version **SemVer** (`MAJEUR.MINEUR.CORRECTIF`) ;
   - `files` : ce qui part dans l'archive publiée (le code compilé seulement, pas les tests) ;
   - `publishConfig` : où `npm publish` envoie le paquet — le **hosted**, jamais le group.

3. Remplacez le contenu de `packages/cours-utils/.npmrc` par :

   ```ini
   registry=http://nexus:8081/repository/npm-group/
   //nexus:8081/repository/npm-hosted/:_auth=${NPM_AUTH}
   ```

   > `${NPM_AUTH}` est **lu dans l'environnement** au moment où npm s'exécute (le service `npm`
   > le reçoit de votre `.env`). Le fichier commité ne contient qu'une référence, aucun secret.

4. Publiez (le script `prepublishOnly` relance les tests et compile `dist/` avant l'envoi) :

   ```bash
   docker compose run --rm npm packages/cours-utils publish
   ```

   > ✅ **Vérifiez :** *Browse* → `npm-hosted` contient `@devops2/cours-utils` en version 0.1.0.

5. Relancez **exactement la même commande**. Nexus refuse. Recopiez le message d'erreur et faites
   une capture : `captures/republication.png`.

6. Ajoutez une fonctionnalité au paquet. Dans `packages/cours-utils/src/index.ts` :

   ```ts
   export function formatLevel(level: Level): string {
     return LEVEL_LABELS[level];
   }
   ```

   et dans `packages/cours-utils/tests/index.test.ts`, à la fin du fichier :

   ```ts
   describe("formatLevel", () => {
     it("renvoie le libellé du niveau", () => {
       expect(formatLevel("avance")).toBe("Avancé");
     });
   });
   ```

   (ajoutez `formatLevel` à l'`import` en tête du fichier de tests). Quelle doit être la nouvelle
   version ? Réfléchissez à **Q9**, puis posez-la et publiez :

   ```bash
   docker compose run --rm npm packages/cours-utils version 0.2.0 --no-git-tag-version
   docker compose run --rm npm packages/cours-utils publish
   ```

   Capture de *Browse* → `npm-hosted` montrant les deux versions : `captures/npm-hosted.png`.
   Commitez :

   ```bash
   git add packages/cours-utils
   git commit -m "Publie @devops2/cours-utils"
   ```

7. Le front consomme maintenant le paquet publié au lieu de sa copie locale :

   ```bash
   docker compose run --rm npm frontend install @devops2/cours-utils@^0.2.0
   ```

   Dans les fichiers suivants, remplacez `@/lib/cours` par `@devops2/cours-utils` :
   `components/CoursList.tsx`, `components/CoursCard.tsx`, `components/CoursFilters.tsx`,
   `lib/api.ts`, `app/page.tsx`, `app/cours/[documentId]/page.tsx`,
   `tests/component/CoursCard.test.tsx`.

   Supprimez la copie locale et ses tests (ils vivent désormais avec le paquet), puis relancez les
   tests du front :

   ```bash
   git rm frontend/lib/cours.ts frontend/tests/unit/cours.test.ts
   docker compose build unit
   docker compose run --rm unit
   ```

   > ✅ **Vérifiez :**
   > - tous les tests passent ;
   > - `grep -c nexus:8081 frontend/package-lock.json` affiche au moins 1 ;
   > - `grep -rn "@/lib/cours" frontend --include=*.ts --include=*.tsx` n'affiche rien.

   Commitez :

   ```bash
   git add -A frontend
   git commit -m "Le front consomme @devops2/cours-utils"
   ```

➡️ Répondez à **Q7 à Q11**.

## Partie 4 — L'image Docker

1. Créez les dépôts Docker (le script demande votre mot de passe admin) :

   ```bash
   scripts/setup-docker.sh
   ```

   Il crée `docker-hosted` (port **8082**, *Disable redeploy*), `docker-proxy` (cache de Docker
   Hub) et `docker-group` (port **8083**, hosted + proxy), et active le realm Docker. Regardez-les
   dans l'UI.

2. Donnez à `deployer` les droits Docker : *Security → Roles → deployer-role*, ajoutez :
   - `nx-repository-view-docker-*-browse`
   - `nx-repository-view-docker-*-read`
   - `nx-repository-view-docker-docker-hosted-add`
   - `nx-repository-view-docker-docker-hosted-edit`

3. Connectez votre client Docker aux deux ports avec `deployer` :

   ```bash
   docker login localhost:8082 -u deployer
   docker login localhost:8083 -u deployer
   ```

   > Docker accepte de parler en HTTP (sans TLS) uniquement à un registre sur `localhost`.

4. Construisez le front et lancez la stack. Le `npm ci` du build passe par Nexus, paquet interne
   compris :

   ```bash
   docker compose up -d --build frontend
   ```

   Vérifiez le site sur http://localhost:3000.

5. Donnez à l'image son nom définitif — registre, dépôt, **version** — et poussez-la dans le hosted :

   ```bash
   docker tag tp4/frontend:dev localhost:8082/cours-frontend:1.0.0
   docker push localhost:8082/cours-frontend:1.0.0
   ```

   Notez le **digest** affiché sur la dernière ligne (`1.0.0: digest: sha256:…`).

6. Supprimez la copie locale, puis tirez l'image **à travers le group** :

   ```bash
   docker rmi localhost:8082/cours-frontend:1.0.0
   docker pull localhost:8083/cours-frontend:1.0.0
   docker image inspect --format '{{json .RepoDigests}}' localhost:8083/cours-frontend:1.0.0
   ```

   Comparez le `Digest:` affiché avec celui du push. Capture des deux : `captures/digests.png`.

   > `RepoDigests` peut lister plusieurs noms (dont `tp4/frontend`) avec le même `sha256` : ce sont
   > des étiquettes différentes sur **le même contenu**.

7. Les images publiques passent aussi par Nexus. Tirez l'image de la base à travers le group :

   ```bash
   docker pull localhost:8083/library/postgres:16-alpine
   ```

8. **Déployez ce qui a été publié.** Dans `docker-compose.yml` :
   - service `postgres` : `image: localhost:8083/library/postgres:16-alpine` ;
   - service `frontend` : supprimez tout le bloc `build:` (avec son `extra_hosts`) et remplacez
     l'image par `image: localhost:8083/cours-frontend:1.0.0`.

   ```bash
   docker compose up -d
   ```

   > ✅ **Vérifiez :**
   > - http://localhost:3000 affiche les 6 cours ;
   > - `docker compose images frontend postgres` montre des images `localhost:8083/…` ;
   > - *Browse* → `docker-proxy` contient `library/postgres`.

   Commitez :

   ```bash
   git add docker-compose.yml
   git commit -m "Lance le front depuis l'image publiée dans Nexus"
   ```

➡️ Répondez à **Q12 à Q15**.

## Partie 5 — Secrets et synthèse

Un secret commité reste dans l'historique Git, même s'il est supprimé ensuite. Vérifiez le vôtre :

```bash
git log --all --oneline -- .env                                # rien : .env n'a jamais été commité
git log --all -p -- '*.npmrc' | grep _auth                     # seulement la référence _auth=${NPM_AUTH}
git log --all -p | grep -c "$(sed -n 's/^NPM_AUTH=//p' .env)"   # 0 : la valeur n'apparaît nulle part
```

➡️ Répondez à **Q16**.

Pour finir, commitez vos réponses et vos captures :

```bash
git add REPONSES.md captures/
git commit -m "Ajoute les réponses et les captures du TP4"
git push
```

---

## Livrables

Sur votre fork, branche `main` :

1. les **commits demandés** (parties 2, 3, 4 et 5) ;
2. `packages/cours-utils/package.json` complété, `frontend/.npmrc` et `packages/cours-utils/.npmrc`
   **sans aucun secret** ;
3. `REPONSES.md` complété ;
4. un dossier `captures/` contenant `npm-proxy.png`, `npm-hosted.png` (0.1.0 et 0.2.0),
   `republication.png` (le refus) et `digests.png` (digest au push et au pull).

## Pièges fréquents

- **`401 Unauthorized` au `npm publish`** : realm *npm Bearer Token* non activé, `NPM_AUTH` vide,
  ou mal encodé — on encode `deployer:motdepasse`, pas le mot de passe seul. Après une
  modification de `.env`, relancez simplement la commande.
- **`ENOTFOUND nexus` ou `ECONNREFUSED` pendant un `docker compose build`** : Nexus est arrêté
  (`docker compose up -d nexus`), `extra_hosts` manque dans le service, ou un pare-feu bloque le
  port 8081 depuis les conteneurs.
- **`404 Not Found - GET …/@devops2%2fcours-utils`** : `npm-hosted` n'est pas membre de
  `npm-group`.
- **`docker push` : `unauthorized` ou `denied`** : pas de `docker login localhost:8082`, ou
  droits Docker absents du rôle `deployer-role`.
- **`Compte bloqué` / HTTP 429** : après 3 mauvais mots de passe, Nexus bloque le compte (30 s,
  puis le double à chaque essai). Attendez, ou `docker compose restart nexus`.
- **`toomanyrequests` de Docker Hub** : quota de téléchargements anonymes atteint ; réessayez plus
  tard.
- **Nexus redémarre en boucle (`OOMKilled`)** : pas assez de mémoire. `docker compose stop pgadmin`,
  fermez des applications, vérifiez la mémoire allouée à Docker Desktop.
- **`port is already allocated`** : un autre programme (une ancienne stack de TP ?) utilise déjà
  8081, 3000… ; arrêtez-le.
- **Sous Linux, `EACCES: permission denied` avec le service `npm`** : votre UID n'est pas 1000.
  Mettez la sortie de `id -u` et `id -g` dans `HOST_UID` et `HOST_GID` de votre `.env`.
- **Sous Windows, `$'\r': command not found` en lançant un script** : le dépôt a été cloné avec des
  fins de ligne Windows. Le fichier `.gitattributes` l'évite ; si besoin, re-clonez le dépôt.

## Commandes utiles

```bash
docker compose up -d nexus && scripts/wait-for-nexus.sh    # démarre Nexus
docker compose run --rm npm <dossier> <commande npm>       # npm dans un conteneur
docker compose run --rm unit                               # tests unitaires et de composant du front
docker compose up -d --build frontend                      # reconstruit et relance le front
docker compose logs -f nexus                               # suivre les logs de Nexus
docker compose down                                        # tout arrêter (données conservées, Nexus compris)
docker compose down -v                                     # tout arrêter ET effacer, y compris Nexus
```
