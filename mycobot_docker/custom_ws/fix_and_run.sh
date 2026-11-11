#!/bin/bash
# Configurações de Rede
SCRIPT_DIR_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _env_file in "${SCRIPT_DIR_ENV}/../../../future_lab_control_center/.env" "${SCRIPT_DIR_ENV}/../../../.env" "${SCRIPT_DIR_ENV}/../../.env"; do
  if [ -f "$_env_file" ]; then set -a; source "$_env_file"; set +a; break; fi
done

NANO_USER="${JETSON_NANO_SSH_USER:-er}"
NANO_IP="${JETSON_NANO_IP:-192.168.0.250}"
NANO_PASS="${JETSON_NANO_SSH_PASSWORD:?Defina JETSON_NANO_SSH_PASSWORD no .env}"
DISCOVERY_IP="${HOST_PC_IP:-192.168.0.204}"
DISCOVERY_PORT="11811"
XML_PATH="/root/custom_ws/fastdds_super_client.xml"

echo "--- INICIANDO LIMPEZA TOTAL (PC, Docker e Nano) ---"
# Limpa processos no Host
pkill -f joint_state_relay || true
pkill -f fastdds || true

# Limpa PC (Docker)
docker exec mycobot_ros2 pkill -9 -f ros2 || true
docker exec mycobot_ros2 pkill -9 -f move_group || true

# Limpa Nano via SSH (Libera a porta serial /dev/ttyTHS1)
sshpass -p "$NANO_PASS" ssh -n -o StrictHostKeyChecking=no "${NANO_USER}@${NANO_IP}" "echo \"$NANO_PASS\" | sudo -S fuser -k /dev/ttyTHS1 || true; pkill -9 -u ${NANO_USER} -f ros2; pkill -9 -u ${NANO_USER} -f python3; rm -rf ~/.ros/discovery_server/"

sleep 2

echo "--- VERIFICANDO DISCOVERY SERVER NO HOST ---"
if ! lsof -i :$DISCOVERY_PORT > /dev/null 2>&1; then
    echo "Iniciando Discovery Server (ID 0) em $DISCOVERY_IP:$DISCOVERY_PORT..."
    fastdds discovery -i 0 -l $DISCOVERY_IP -p $DISCOVERY_PORT > /tmp/discovery_cobot.log 2>&1 &
    sleep 2
fi

echo "--- INICIANDO ROBÔ (NANO) ---"
# O Nano deve apontar para o Discovery Server do PC no Domain 42
# Usamos o nohup para garantir que o processo continue rodando
sshpass -p "$NANO_PASS" ssh -n -o StrictHostKeyChecking=no "${NANO_USER}@${NANO_IP}" "export ROS_DOMAIN_ID=42 && export RMW_IMPLEMENTATION=rmw_fastrtps_cpp && export ROS_DISCOVERY_SERVER=$DISCOVERY_IP:$DISCOVERY_PORT && source /opt/ros/galactic/setup.bash && source ~/custom_ws/install/setup.bash && nohup ros2 launch mycobot_hw_interface mycobot_hw.launch.py mock:=False baud:=1000000 > /tmp/nano_bridge.log 2>&1 < /dev/null &"

echo "Robô disparado. Aguardando inicialização..."
sleep 5

echo "--- INICIANDO MOVEIT (PC DOCKER) ---"
# O Docker se conecta ao Discovery Server do Host como SUPER_CLIENT no Domain 42
docker exec mycobot_ros2 bash -c "export ROS_DOMAIN_ID=42 && export RMW_IMPLEMENTATION=rmw_fastrtps_cpp && export ROS_DISCOVERY_SERVER=$DISCOVERY_IP:$DISCOVERY_PORT && export FASTRTPS_DEFAULT_PROFILES_FILE=$XML_PATH && source /opt/ros/galactic/setup.bash && source /root/custom_ws/install/setup.bash && ros2 launch mycobot_280_jn_moveit_config galactic_demo.launch.py"
