#!/bin/bash
set -euo pipefail

# ─── Setup paths ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${SCRIPT_DIR}/backups"
LOG_ROOT="${SCRIPT_DIR}/logs"
mkdir -p "$BACKUP_ROOT" "$LOG_ROOT"

SUBS_FILE="subscriptions.txt"
MODE=""

# ─── Parse arguments ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode) MODE="$2"; shift 2 ;;
    *) echo "Usage: $0 --mode [block|revert]"; exit 1 ;;
  esac
done
if [[ "$MODE" != "block" && "$MODE" != "revert" ]]; then
  echo "Invalid mode: $MODE" >&2
  echo "Usage: $0 --mode [block|revert]" >&2
  exit 1
fi

TAILSCALE_CIDR="100.64.0.0/10"

# ─── Main loop per subscription ──────────────────────────────────────────────────
while read -r SUBSCRIPTION_ID; do
  [[ -z "${SUBSCRIPTION_ID//[[:space:]]/}" ]] && continue

  echo "=== Processing subscription $SUBSCRIPTION_ID (mode=$MODE) ==="
  BACKUP_DIR="${BACKUP_ROOT}/${SUBSCRIPTION_ID}"
  LOG_DIR="${LOG_ROOT}/${SUBSCRIPTION_ID}"
  mkdir -p "$BACKUP_DIR" "$LOG_DIR"

  NSG_LOG="${LOG_DIR}/nsg-${MODE}.log"
  AKS_LOG="${LOG_DIR}/aks-${MODE}.log"
  PUBIP_LOG="${LOG_DIR}/pubip-${MODE}.log"
  :> "$NSG_LOG" :> "$AKS_LOG" :> "$PUBIP_LOG"

  run_nsg(){
    desc="$1"; shift
    ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "$ts START: $desc" | tee -a "$NSG_LOG"
    if "$@"; then
      echo "$ts SUCCESS: $desc" | tee -a "$NSG_LOG"
    else
      echo "$ts FAILURE: $desc" | tee -a "$NSG_LOG"
    fi
  }

  run_aks(){
    desc="$1"; shift
    ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "$ts START: $desc" | tee -a "$AKS_LOG"
    if "$@"; then
      echo "$ts SUCCESS: $desc" | tee -a "$AKS_LOG"
    else
      echo "$ts FAILURE: $desc" | tee -a "$AKS_LOG"
    fi
  }

  run_pub(){
    desc="$1"; shift
    ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "$ts START: $desc" | tee -a "$PUBIP_LOG"
    if "$@"; then
      echo "$ts SUCCESS: $desc" | tee -a "$PUBIP_LOG"
    else
      echo "$ts FAILURE: $desc" | tee -a "$PUBIP_LOG"
    fi
  }

  az account set --subscription "$SUBSCRIPTION_ID"

  # ── 1) NSG block/revert ───────────────────────────────────────────────────────
  for NSG_ID in $(az network nsg list --query "[].id" -o tsv); do
    NSG_NAME=$(basename "$NSG_ID")
    RG=$(echo "$NSG_ID" | cut -d'/' -f5)
    NSG_BAK="${BACKUP_DIR}/${NSG_NAME}_backup.json"

    if [[ "$MODE" == "block" ]]; then
      run_nsg "Backup NSG rules for $NSG_NAME" \
        sh -c "az network nsg rule list -g '$RG' --nsg-name '$NSG_NAME' \
               | jq 'map({name,priority,direction,access,protocol,sourceAddressPrefix,sourceAddressPrefixes,destinationAddressPrefix,destinationAddressPrefixes,sourcePortRange,sourcePortRanges,destinationPortRange,destinationPortRanges})' \
               > '$NSG_BAK'"

      run_nsg "Delete all NSG rules on $NSG_NAME" \
        sh -c "az network nsg rule list -g '$RG' --nsg-name '$NSG_NAME' --query '[].name' -o tsv \
               | xargs -r -n1 az network nsg rule delete -g '$RG' --nsg-name '$NSG_NAME' --name"

      run_nsg "Add Tailscale-Inbound to $NSG_NAME" \
        az network nsg rule create -g "$RG" --nsg-name "$NSG_NAME" \
          --name Allow-Tailscale-Inbound --priority 100 --direction Inbound --access Allow \
          --protocol '*' --source-address-prefixes "$TAILSCALE_CIDR" --destination-address-prefixes '*' \
          --source-port-ranges '*' --destination-port-ranges '*'

      run_nsg "Add Tailscale-Outbound to $NSG_NAME" \
        az network nsg rule create -g "$RG" --nsg-name "$NSG_NAME" \
          --name Allow-Tailscale-Outbound --priority 100 --direction Outbound --access Allow \
          --protocol '*' --source-address-prefixes '*' --destination-address-prefixes "$TAILSCALE_CIDR" \
          --source-port-ranges '*' --destination-port-ranges '*'

      run_nsg "Add Deny-Public-Inbound to $NSG_NAME" \
        az network nsg rule create -g "$RG" --nsg-name "$NSG_NAME" \
          --name Deny-Public-Inbound --priority 4096 --direction Inbound --access Deny \
          --protocol '*' --source-address-prefixes Internet --destination-address-prefixes '*' \
          --source-port-ranges '*' --destination-port-ranges '*'

    else
      run_nsg "Delete current NSG rules on $NSG_NAME" \
        sh -c "az network nsg rule list -g '$RG' --nsg-name '$NSG_NAME' --query '[].name' -o tsv \
               | xargs -r -n1 az network nsg rule delete -g '$RG' --nsg-name '$NSG_NAME' --name"

      if [[ -f "$NSG_BAK" ]]; then
        jq -c '.[]' "$NSG_BAK" | while read -r rule; do
          NAME=$(jq -r .name <<<"$rule")
          PRIORITY=$(jq -r .priority <<<"$rule")
          DIRECTION=$(jq -r .direction <<<"$rule")
          ACCESS=$(jq -r .access <<<"$rule")
          PROTOCOL=$(jq -r .protocol <<<"$rule")
          SRC=$(jq -r 'if (.sourceAddressPrefixes|length>0) then (.sourceAddressPrefixes|join(",")) else .sourceAddressPrefix end' <<<"$rule")
          DST=$(jq -r 'if (.destinationAddressPrefixes|length>0) then (.destinationAddressPrefixes|join(",")) else .destinationAddressPrefix end' <<<"$rule")
          SR=$(jq -r 'if (.sourcePortRanges|length>0) then (.sourcePortRanges|join(",")) else .sourcePortRange end' <<<"$rule")
          DR=$(jq -r 'if (.destinationPortRanges|length>0) then (.destinationPortRanges|join(",")) else .destinationPortRange end' <<<"$rule")

          run_nsg "Restore NSG rule $NAME on $NSG_NAME" \
            az network nsg rule create -g "$RG" --nsg-name "$NSG_NAME" \
              --name "$NAME" --priority "$PRIORITY" --direction "$DIRECTION" \
              --access "$ACCESS" --protocol "$PROTOCOL" \
              --source-address-prefixes "$SRC" --destination-address-prefixes "$DST" \
              --source-port-ranges "$SR" --destination-port-ranges "$DR"
        done
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No NSG backup for $NSG_NAME; skipping" | tee -a "$NSG_LOG"
      fi
    fi
  done

  # ── 2) AKS rotate certs + update ────────────────────────────────────────────────
  if [[ "$MODE" == "block" ]]; then
    run_aks "Begin AKS certificate rotation" true
    readarray -t CLUSTERS < <(az aks list -o json --query "[].{n:name,rg:resourceGroup}" | jq -c '.[]')
    for c in "${CLUSTERS[@]}"; do
      CN=$(jq -r .n <<<"$c"); CRG=$(jq -r .rg <<<"$c")
      run_aks "Rotate certs on $CN" \
        az aks rotate-certs -g "$CRG" -n "$CN" --yes --only-show-errors
    done
  fi

  run_aks "Begin AKS IP-range update ($MODE)" true
  readarray -t CLUSTERS < <(az aks list -o json --query "[].{n:name,rg:resourceGroup}" | jq -c '.[]')
  for c in "${CLUSTERS[@]}"; do
    CN=$(jq -r .n <<<"$c"); CRG=$(jq -r .rg <<<"$c")
    if [[ "$MODE" == "block" ]]; then
      run_aks "Lock $CN to 0.0.0.0/32" \
        az aks update -g "$CRG" -n "$CN" \
          --api-server-authorized-ip-ranges "0.0.0.0/32" --no-wait --only-show-errors
    else
      RANGES=$(az aks show -g "$CRG" -n "$CN" -o json \
        | jq -r '[.apiServerAccessProfile.authorizedIpRanges // [] | .[] | select(.!="0.0.0.0/32")] | join(",")')
      run_aks "Unlock $CN" \
        az aks update -g "$CRG" -n "$CN" \
          --api-server-authorized-ip-ranges "$RANGES" --no-wait --only-show-errors
    fi
  done

  if [[ "$MODE" == "revert" ]]; then
    for c in "${CLUSTERS[@]}"; do
      CN=$(jq -r .n <<<"$c"); CRG=$(jq -r .rg <<<"$c")
      run_aks "Refresh kubeconfig for $CN" \
        az aks get-credentials -g "$CRG" -n "$CN" --overwrite-existing --only-show-errors
    done
  fi

  # ── 3) Public‑IP block/revert ───────────────────────────────────────────────────
  if [[ "$MODE" == "block" ]]; then
    PUB_BAK="${BACKUP_DIR}/public_ip_backup.json"
    echo '[]' > "$PUB_BAK"
    run_pub "Begin public-IP replace" true

    az network public-ip list --query "[?ipConfiguration!=null]" -o json \
      | jq -c '.[]' | while read -r p; do
        ID=$(jq -r .id <<<"$p")
        NAME=$(jq -r .name <<<"$p")
        IPC=$(jq -r .ipConfiguration.id <<<"$p")
        [[ "$IPC" != *"/networkInterfaces/"* ]] && continue
        NRG=$(echo "$IPC" | cut -d'/' -f5)
        NN=$(echo "$IPC" | cut -d'/' -f9)
        IC=$(echo "$IPC" | cut -d'/' -f11)

        ENTRY=$(jq -n --arg rg "$NRG" --arg nic "$NN" --arg ipc "$IC" --arg id "$ID" --arg nm "$NAME" \
                  '{nic_rg:$rg,nic_name:$nic,ipconfig_name:$ipc,original_public_ip_id:$id,original_public_ip_name:$nm}')
        TMP=$(mktemp); jq ". + [ $ENTRY ]" "$PUB_BAK" >"$TMP" && mv "$TMP" "$PUB_BAK"

        run_pub "Detach $NAME from $NN/$IC" \
          az network nic ip-config update -g "$NRG" --nic-name "$NN" --name "$IC" --remove publicIpAddress

        LOC=$(jq -r .location <<<"$p")
        TNAME="temp-${NN}-$(date +%s)"
        run_pub "Create temp IP $TNAME" \
          az network public-ip create -g "$NRG" -n "$TNAME" -l "$LOC" --allocation-method Static

        TID=$(az network public-ip show -g "$NRG" -n "$TNAME" -o tsv --query id)
        run_pub "Attach temp IP $TNAME to $NN/$IC" \
          az network nic ip-config update -g "$NRG" --nic-name "$NN" --name "$IC" --public-ip-address "$TID"
    done

  else
    run_pub "Begin public-IP restore" true
    PUB_BAK="${BACKUP_DIR}/public_ip_backup.json"
    if [[ -f "$PUB_BAK" ]]; then
      jq -c '.[]' "$PUB_BAK" | while read -r e; do
        NRG=$(jq -r .nic_rg <<<"$e")
        NN=$(jq -r .nic_name <<<"$e")
        IC=$(jq -r .ipconfig_name <<<"$e")
        OID=$(jq -r .original_public_ip_id <<<"$e")
        ONM=$(jq -r .original_public_ip_name <<<"$e")

        run_pub "Restore $ONM to $NN/$IC" \
          az network nic ip-config update -g "$NRG" --nic-name "$NN" --name "$IC" --public-ip-address "$OID"
      done
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] No pub-IP backup; skipping" | tee -a "$PUBIP_LOG"
    fi
  fi

  echo
  echo "Logs for subscription $SUBSCRIPTION_ID:"
  echo "  NSG  → $NSG_LOG"
  echo "  AKS  → $AKS_LOG"
  echo "  PubIP→ $PUBIP_LOG"
  echo

done < "$SUBS_FILE"
