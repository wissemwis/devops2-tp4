#!/usr/bin/env bash
# RATTRAPAGE — crée ce que la partie 1 demande de faire à la main dans l'UI :
# npm-proxy, npm-hosted, npm-group, realm npm Bearer Token, accès anonyme, rôle deployer-role, utilisateur deployer.
# À n'utiliser qu'en cas de blocage : signalez-le dans REPONSES.md.
# Usage : scripts/rattrapage-npm.sh   (mots de passe admin et deployer demandés)
source "$(dirname "$0")/lib.sh"

require_nexus
ask_admin_password

log "Realm et accès anonyme"
ensure_realm NpmToken
if [[ $(api GET /v1/security/anonymous 200 | jq -r .enabled) == true ]]; then
  warn "accès anonyme : déjà actif, ignoré"
else
  api PUT /v1/security/anonymous 200 '{"enabled": true, "userId": "anonymous", "realmName": "NexusAuthorizingRealm"}' >/dev/null
  ok "accès anonyme activé (lecture)"
fi

log "Dépôts npm"
ensure_repo npm proxy npm-proxy "$(jq -nc --argjson s "$(storage)" --argjson p "$(proxy_attrs https://registry.npmjs.org)" \
  '{online: true, storage: $s} + $p')"
ensure_repo npm hosted npm-hosted "$(jq -nc --argjson s "$(storage ALLOW_ONCE)" '{online: true, storage: $s}')"
ensure_repo npm group npm-group "$(jq -nc --argjson s "$(storage)" \
  '{online: true, storage: $s, group: {memberNames: ["npm-hosted", "npm-proxy"]}}')"

log "Rôle et utilisateur"
if [[ $(http_code /v1/security/roles/deployer-role) == 200 ]]; then
  warn "rôle deployer-role : déjà présent, ignoré"
else
  api POST /v1/security/roles "200,201" '{"id": "deployer-role", "name": "deployer-role",
    "description": "Lecture npm, publication dans npm-hosted",
    "privileges": ["nx-repository-view-npm-*-browse", "nx-repository-view-npm-*-read",
                   "nx-repository-view-npm-npm-hosted-add", "nx-repository-view-npm-npm-hosted-edit"],
    "roles": []}' >/dev/null
  ok "rôle deployer-role créé"
fi
if api GET "/v1/security/users?userId=deployer" 200 | jq -e 'any(.[]; .userId == "deployer")' >/dev/null; then
  warn "utilisateur deployer : déjà présent, ignoré"
else
  if [[ -z ${DEPLOYER_PASSWORD:-} ]]; then
    read -rsp "Mot de passe à donner à l'utilisateur deployer (8 caractères minimum) : " DEPLOYER_PASSWORD
    echo
  fi
  api POST /v1/security/users "200,201" "$(jq -nc --arg p "$DEPLOYER_PASSWORD" \
    '{userId: "deployer", firstName: "Deployer", lastName: "TP4", emailAddress: "deployer@example.com",
      password: $p, status: "active", roles: ["deployer-role"]}')" >/dev/null
  ok "utilisateur deployer créé"
fi
