#!/usr/bin/env bash
# Attend que Nexus accepte les écritures (premier démarrage : 1 à 3 minutes).
# Usage : scripts/wait-for-nexus.sh [timeout_en_secondes]
source "$(dirname "$0")/lib.sh"

timeout=${1:-300}
log "Attente de Nexus sur $NEXUS_URL (max ${timeout}s)"
for ((i = 0; i < timeout; i += 5)); do
  if nexus_writable; then
    ok "Nexus prêt (${i}s)"
    exit 0
  fi
  sleep 5
done
die "Nexus n'est pas prêt après ${timeout}s — voir 'docker compose logs nexus'"
