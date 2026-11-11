#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _env_file in "${SCRIPT_DIR}/../future_lab_control_center/.env" "${SCRIPT_DIR}/../.env" "${SCRIPT_DIR}/.env"; do
  if [ -f "$_env_file" ]; then set -a; source "$_env_file"; set +a; break; fi
done
NANO_USER="${JETSON_NANO_SSH_USER:-er}"
NANO_PASS="${JETSON_NANO_SSH_PASSWORD:?Defina JETSON_NANO_SSH_PASSWORD no .env}"

echo "=========================================="
echo " Atualizando a dança no MyCobot..."
echo "=========================================="

# 1. Envia o arquivo editado para o Nano
sshpass -p "$NANO_PASS" scp -o StrictHostKeyChecking=no "${SCRIPT_DIR}/listen_keyboard_service.py" "${NANO_USER}@192.168.0.250:/home/${NANO_USER}/"

# 2. Move para a pasta do sistema e reinicia o serviço invisível
sshpass -p "$NANO_PASS" ssh -o StrictHostKeyChecking=no "${NANO_USER}@192.168.0.250" "echo \"$NANO_PASS\" | sudo -S mv /home/${NANO_USER}/listen_keyboard_service.py /usr/local/bin/ && sudo chmod +x /usr/local/bin/listen_keyboard_service.py && sudo systemctl restart cobot_dance.service"

echo ""
echo "✅ Sucesso! O serviço foi reiniciado."
echo "👉 Vá até o robô e aperte a tecla ESPAÇO para ver a nova dancinha!"
