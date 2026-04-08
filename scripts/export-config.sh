#!/usr/bin/env bash
set -euo pipefail

# Exporte une base de configuration VMware vers inventories/<env>/group_vars/all.generated.yml
# Dépendances: govc, jq, yq (Mike Farah)

usage() {
  cat <<USAGE
Usage: $0 -o <output.yml> -s <site_name> -v <vcenter_name>

Variables d'environnement requises (govc):
  GOVC_URL, GOVC_USERNAME, GOVC_PASSWORD

Exemple:
  GOVC_URL=https://vcsa-paris/sdk GOVC_USERNAME=administrator@vsphere.local GOVC_PASSWORD='***' \
  $0 -o inventories/production/group_vars/all.generated.yml -s paris -v vcsa-paris
USAGE
}

OUTPUT=""
SITE=""
VCENTER_ALIAS=""

while getopts ":o:s:v:h" opt; do
  case "${opt}" in
    o) OUTPUT="${OPTARG}" ;;
    s) SITE="${OPTARG}" ;;
    v) VCENTER_ALIAS="${OPTARG}" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [[ -z "${OUTPUT}" || -z "${SITE}" || -z "${VCENTER_ALIAS}" ]]; then
  usage
  exit 1
fi

for bin in govc jq yq; do
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "Erreur: ${bin} n'est pas installé." >&2
    exit 1
  fi
done

TMP_JSON="$(mktemp)"
trap 'rm -f "${TMP_JSON}"' EXIT

DC_LIST="$(govc find / -type d 2>/dev/null | awk -F/ 'NF>1{print $NF}' | sort -u)"

echo '{"site":{},"datacenters":[]}' > "${TMP_JSON}"

while IFS= read -r dc; do
  [[ -z "${dc}" ]] && continue

  CLUSTERS_JSON="[]"
  while IFS= read -r cluster_path; do
    [[ -z "${cluster_path}" ]] && continue
    cluster_name="$(basename "${cluster_path}")"

    HOSTS_JSON="[]"
    while IFS= read -r host_path; do
      [[ -z "${host_path}" ]] && continue
      host_name="$(basename "${host_path}")"
      HOSTS_JSON="$(jq --arg hn "${host_name}" '. + [{"hostname":$hn,"username":"root","password":"{{ vault_esxi_root_password }}"}]' <<<"${HOSTS_JSON}")"
    done < <(govc find "${cluster_path}" -type h 2>/dev/null)

    CLUSTERS_JSON="$(jq \
      --arg cn "${cluster_name}" \
      --argjson hosts "${HOSTS_JSON}" \
      '. + [{"name":$cn,"drs_enabled":true,"ha_enabled":true,"hosts":$hosts,"host_rules":{"affinity":[],"anti_affinity":[]},"dvswitches":[],"dvportgroups":[]}]' <<<"${CLUSTERS_JSON}")"
  done < <(govc find "/${dc}" -type c 2>/dev/null)

  jq --arg dc "${dc}" --argjson clusters "${CLUSTERS_JSON}" \
    '.datacenters += [{"name":$dc,"clusters":$clusters}]' "${TMP_JSON}" > "${TMP_JSON}.new"
  mv "${TMP_JSON}.new" "${TMP_JSON}"
done <<< "${DC_LIST}"

jq --arg site "${SITE}" --arg vcalias "${VCENTER_ALIAS}" --arg url "${GOVC_URL:-}" '
  {
    vmware_sites: [
      {
        name: $site,
        vcenters: [
          {
            name: $vcalias,
            hostname: ($url | gsub("^https?://"; "") | gsub("/sdk$"; "")),
            username: "{{ vault_vcenter_username }}",
            password: "{{ vault_vcenter_password }}",
            validate_certs: false,
            local_roles: [],
            local_accounts: [],
            datacenters: .datacenters
          }
        ]
      }
    ]
  }
' "${TMP_JSON}" | yq -P > "${OUTPUT}"

echo "Export terminé: ${OUTPUT}"
