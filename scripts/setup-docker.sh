#!/usr/bin/env bash
# Crée les dépôts Docker de la partie 4 : docker-hosted (push, port 8082), docker-proxy (Docker Hub)
# et docker-group (pull, port 8083), et active le realm Docker Bearer Token. Relançable sans risque.
# Usage : scripts/setup-docker.sh   (le mot de passe admin est demandé)
source "$(dirname "$0")/lib.sh"

require_nexus
ask_admin_password

log "Realm"
ensure_realm DockerToken

log "Dépôts Docker"
ensure_repo docker hosted docker-hosted "$(jq -nc --argjson s "$(storage ALLOW_ONCE)" \
  '{online: true, storage: $s, docker: {v1Enabled: false, forceBasicAuth: true, httpPort: 8082}}')"
ensure_repo docker proxy docker-proxy "$(jq -nc --argjson s "$(storage)" --argjson p "$(proxy_attrs https://registry-1.docker.io)" \
  '{online: true, storage: $s, docker: {v1Enabled: false, forceBasicAuth: true}, dockerProxy: {indexType: "HUB"}} + $p')"
ensure_repo docker group docker-group "$(jq -nc --argjson s "$(storage)" \
  '{online: true, storage: $s, group: {memberNames: ["docker-hosted", "docker-proxy"]}, docker: {v1Enabled: false, forceBasicAuth: true, httpPort: 8083}}')"

cat <<FIN

Dépôts Docker prêts.
  Push : localhost:8082   (docker-hosted)
  Pull : localhost:8083   (docker-group = docker-hosted + docker-proxy)
Pensez à donner au rôle deployer-role les droits Docker (énoncé, partie 4).
FIN
