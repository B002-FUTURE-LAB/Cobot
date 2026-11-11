#!/bin/bash
# ============================================================
# RUN_ROBOT_NANO.sh — Inicia Discovery Server + Bridge no Nano
# Delega ao start_bridge.sh que já existe e está configurado.
# O Nano é o servidor de descoberta (porta 11811).
# ============================================================

SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _env_file in "${SCRIPT_DIR_ENV}/../../future_lab_control_center/.env" "${SCRIPT_DIR_ENV}/../../.env" "${SCRIPT_DIR_ENV}/../.env"; do
  if [ -f "$_env_file" ]; then set -a; source "$_env_file"; set +a; break; fi
done

NANO_USER="${JETSON_NANO_SSH_USER:-er}"
NANO_IP="${JETSON_NANO_IP:-192.168.0.250}"
NANO_PASS="${JETSON_NANO_SSH_PASSWORD:?Defina JETSON_NANO_SSH_PASSWORD no .env}"

echo "========================================"
echo "  Ligando DS + Bridge no Nano"
echo "  SSH: ${NANO_USER}@${NANO_IP}"
echo "========================================"

sshpass -p "$NANO_PASS" ssh -o StrictHostKeyChecking=no -t ${NANO_USER}@${NANO_IP} "~/start_bridge.sh"
