# TP4 — Réponses

**Nom Prénom :**

> Répondez sous chaque question. Si vous avez utilisé `scripts/rattrapage-npm.sh`, indiquez-le ici :

## Partie 1 — Les dépôts npm

**Q1.** En une phrase chacun : à quoi servent `npm-proxy`, `npm-hosted` et `npm-group` ? Lequel des trois les clients (npm, le build Docker) connaissent-ils ?

**Q2.** Pourquoi l'ordre des membres de `npm-group` compte-t-il ? Que se passerait-il si un paquet `@devops2/cours-utils` était aussi publié sur npmjs.org ?

**Q3.** Pourquoi publier avec l'utilisateur `deployer` plutôt qu'avec `admin` ? Pourquoi active-t-on la lecture anonyme ?

## Partie 2 — Consommer via le group

**Q4.** Après le `npm ci`, que contient `npm-proxy` ? Pourquoi le `package-lock.json` n'a-t-il pas changé alors que les paquets viennent désormais de Nexus ?

**Q5.** Demain, npmjs.org est indisponible. Que se passe-t-il au prochain `npm ci` du front ? Et pour un paquet que personne n'a encore téléchargé via votre Nexus ?

**Q6.** Pourquoi `frontend/.npmrc` est-il commité ? Pourquoi le build Docker du front n'a-t-il besoin d'aucun secret ?

## Partie 3 — Publier un paquet interne

**Q7.** À quoi servent les champs `files` et `publishConfig` ? Que se passerait-il au `npm publish` sans `publishConfig` ?

**Q8.** Recopiez le message obtenu à la seconde publication de 0.1.0. Pourquoi Nexus refuse-t-il ? Quel problème cela évite-t-il pour ceux qui ont déjà installé 0.1.0 (pensez au lockfile) ?

**Q9.** Pourquoi la version 0.2.0, et pas 0.1.1 ni 1.0.0 ?

**Q10.** Quelles versions la plage `^0.2.0` accepte-t-elle ? Si vous publiez 0.2.1 puis 0.3.0, lesquelles le front prendra-t-il au prochain `npm install` ? Et au prochain `npm ci` ?

**Q11.** Où se trouve `NPM_AUTH` et pourquoi n'apparaît-il jamais dans Git ? Que faut-il faire si un jeton a été commité par erreur ?

## Partie 4 — L'image Docker

**Q12.** Décomposez `localhost:8082/cours-frontend:1.0.0` (registre, dépôt, tag). Pourquoi pousse-t-on sur le port 8082 et tire-t-on sur le port 8083 ?

**Q13.** Recopiez le digest obtenu au push et celui obtenu au pull. Sont-ils identiques ? Que garantit le digest que le tag ne garantit pas ?

**Q14.** Pourquoi ne publie-t-on jamais une image sous le seul tag `latest` pour la déployer ?

**Q15.** Pourquoi Docker accepte-t-il ici de parler à Nexus en HTTP ? Que faudrait-il pour un Nexus partagé par toute une équipe ?

## Partie 5 — Synthèse

**Q16.** « Build once, deploy many » : pour l'image du front, qu'est-ce qui est construit une seule fois, où est-ce stocké, et comment le `docker-compose.yml` le déploie-t-il ? Citez deux étapes de ce TP qu'un serveur d'intégration continue (séance 6) devrait automatiser.
