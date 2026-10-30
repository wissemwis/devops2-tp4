#!/usr/bin/env bash
# Fonctions communes aux scripts du TP4 (à sourcer, pas à exécuter).
set -euo pipefail

for outil in curl jq; do
  command -v "$outil" >/dev/null || die_tool=$outil
done
if [[ -n ${die_tool:-} ]]; then
  printf '\033[1;31mERR\033[0m %s\n' "La commande '$die_tool' est introuvable : installez-la (voir les prérequis de l'énoncé)." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEXUS_URL="http://localhost:8081"
API="$NEXUS_URL/service/rest"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m OK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

compose() { docker compose -f "$ROOT_DIR/docker-compose.yml" "$@"; }

# Nexus bloque un compte après 3 échecs d'authentification (délai doublé à chaque essai, jusqu'à 15 min).
LOCKED_MSG="Compte bloqué temporairement par Nexus (HTTP 429) après plusieurs échecs d'authentification. Attendez, ou débloquez tout de suite avec : docker compose restart nexus"

# api METHOD PATH EXPECTED_CODES [BODY] [CONTENT_TYPE]
# Appelle l'API REST de Nexus en admin. Affiche le corps ; quitte si le code HTTP est inattendu.
api() {
  local method=$1 path=$2 expected=$3 body=${4:-} ctype=${5:-application/json}
  local out code
  out=$(mktemp)
  local args=(-s -o "$out" -w '%{http_code}' -u "$NEXUS_AUTH" -X "$method")
  if [[ -n $body ]]; then args+=(-H "Content-Type: $ctype" --data "$body"); fi
  code=$(curl "${args[@]}" "$API$path") || code=000
  if [[ ",$expected," != *",$code,"* ]]; then
    [[ $code == 429 ]] && printf '\033[1;31mERR\033[0m %s\n' "$LOCKED_MSG" >&2
    printf '\033[1;31mERR\033[0m %s %s -> HTTP %s (attendu : %s)\n' "$method" "$path" "$code" "$expected" >&2
    cat "$out" >&2; echo >&2
    rm -f "$out"
    exit 1
  fi
  cat "$out"
  rm -f "$out"
}

# http_code PATH : code HTTP d'un GET authentifié (ne quitte jamais)
http_code() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -u "$NEXUS_AUTH" "$API$1") || code=000
  echo "$code"
}

nexus_writable() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' "$API/v1/status/writable") || code=000
  [[ $code == 200 ]]
}

require_nexus() {
  nexus_writable || die "Nexus ne répond pas sur $NEXUS_URL — lancez 'docker compose up -d nexus' puis scripts/wait-for-nexus.sh"
}

# Lit le mot de passe admin (variable NEXUS_ADMIN_PASSWORD ou saisie masquée) et le vérifie une seule fois :
# pas de nouvel essai automatique, pour ne pas faire bloquer le compte.
ask_admin_password() {
  if [[ -z ${NEXUS_ADMIN_PASSWORD:-} ]]; then
    read -rsp "Mot de passe admin de votre Nexus : " NEXUS_ADMIN_PASSWORD
    echo
  fi
  NEXUS_AUTH="admin:$NEXUS_ADMIN_PASSWORD"
  case $(http_code /v1/security/realms/active) in
    200) ;;
    429) die "$LOCKED_MSG" ;;
    401|403) die "Mot de passe admin refusé. Relancez le script avec le mot de passe choisi au premier login." ;;
    *) die "Réponse inattendue de Nexus : vérifiez 'docker compose ps nexus'." ;;
  esac
}

# ensure_repo FORMAT TYPE NAME JSON : crée le dépôt s'il n'existe pas (idempotent)
ensure_repo() {
  local format=$1 type=$2 name=$3 body=$4
  if [[ $(http_code "/v1/repositories/$name") == 200 ]]; then
    warn "$name : déjà présent, ignoré"
    return
  fi
  api POST "/v1/repositories/$format/$type" 201 "$(jq -c --arg n "$name" '.name = $n' <<<"$body")" >/dev/null
  ok "$name ($format $type) créé"
}

# storage [WRITE_POLICY] : bloc de stockage (ALLOW_ONCE = Disable redeploy)
storage() { jq -nc --arg wp "${1:-}" '{blobStoreName: "default", strictContentTypeValidation: true}
  + (if $wp == "" then {} else {writePolicy: $wp} end)'; }

# proxy_attrs URL : attributs communs d'un dépôt proxy
proxy_attrs() { jq -nc --arg url "$1" '{
  proxy: {remoteUrl: $url, contentMaxAge: 1440, metadataMaxAge: 1440},
  negativeCache: {enabled: true, timeToLive: 1440},
  httpClient: {blocked: false, autoBlock: true}}'; }

# ensure_realm REALM_ID : active un realm sans toucher aux autres
ensure_realm() {
  local active wanted
  active=$(api GET /v1/security/realms/active 200 | jq -c .)
  wanted=$(jq -c --arg r "$1" 'if index($r) then . else . + [$r] end' <<<"$active")
  if [[ $active == "$wanted" ]]; then
    warn "realm $1 : déjà actif, ignoré"
    return
  fi
  api PUT /v1/security/realms/active 204 "$wanted" >/dev/null
  ok "realm $1 activé"
}
