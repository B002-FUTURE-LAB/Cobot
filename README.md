# MyCobot 280 JN — MoveIt 2 + Distributed DDS

Distributed setup for controlling a **MyCobot 280 Jetson Nano (JN)** with **MoveIt 2** running in Docker on the host PC and the hardware bridge running natively on the **Jetson Nano**.

```text
┌─────────────────────────────┐         ┌─────────────────────────────┐
│  PC (Linux + Docker)        │         │  Jetson Nano                │
│  ────────────────           │ DDS     │  ────────────               │
│  • MoveIt 2 + RViz          │ ◄────►  │  • mycobot_bridge           │
│  • joint_state_relay        │ Cyclone │  • pymycobot ↔ /dev/ttyTHS1 │
│  • robot_state_publisher    │ peer    │  • MJPEG Camera (:8080)     │
│                             │ static  │  • HTTP Micro-Bridge (:8088)│
│  192.168.0.204              │         │  192.168.0.62               │
└─────────────────────────────┘         └─────────────────────────────┘
                                                       │
                                                       ▼
                                            ┌──────────────────┐
                                            │  MyCobot 280 JN  │
                                            │ (physical robot) │
                                            └──────────────────┘
```

---

## How to Run

### Prerequisites
- Docker and Docker Compose on the PC
- `sshpass` installed on the PC: `sudo apt install sshpass`
- Jetson Nano reachable on the LAN with credentials configured in `future_lab_control_center/.env` (`JETSON_NANO_SSH_USER` / `JETSON_NANO_SSH_PASSWORD`)
- Bridge installed on the Nano in `~/custom_ws` (see "Initial Nano Setup" below)

### Standard Usage — Single Command

```bash
./mycobot_docker/RUN_PLANNING_PC.sh
```

This script handles everything:
1. **Ensures the `mycobot_ros2` Docker container is running**
2. **Restarts the bridge and MJPEG camera server on the Jetson Nano** with a clean DDS state (via SSH + `setsid`)
3. **Cleans up stale ROS 2 processes** inside the Docker container
4. **Launches MoveIt 2 + RViz** on the PC

In RViz:
- Drag the **interactive marker** (ball/rings) around the end-effector to set a target pose
- Click **"Plan"** to preview the planned trajectory
- Click **"Plan & Execute"** to move the physical arm

### Updating Bridge Code

If you edit `mycobot_bridge.py`, `joint_state_relay.py`, or other files in `mycobot_docker/custom_ws/src/mycobot_hw_interface/`, sync them to the Nano:

```bash
./mycobot_docker/DEPLOY_TO_NANO.sh
```

This runs `rsync`, rebuilds the workspace on the Nano, and restarts the bridge.

### Building the Docker Container (First Time)

```bash
cd mycobot_docker
docker compose build
docker compose up -d
docker exec mycobot_ros2 bash -c "source /opt/ros/galactic/setup.bash && cd /root/custom_ws && colcon build --symlink-install"
```

---

## Architecture

### Data Flow

```text
[Physical] MyCobot 280 JN
   ↑↓ 1 Mbps serial via /dev/ttyTHS1
[Jetson Nano] mycobot_bridge (pymycobot)
   • publishes /joint_states_raw at 10 Hz (current joint angles)
   • action server /mycobot_arm_controller/follow_joint_trajectory
   ↑↓ DDS (CycloneDDS / FastDDS discovery)
[Docker PC] joint_state_relay
   • re-stamps messages with the PC clock (prevents MoveIt "stale state" rejections)
   • publishes /joint_states
[Docker PC] robot_state_publisher
   • reads /joint_states → publishes TF for all arm links
[Docker PC] move_group (MoveIt 2)
   • reads /joint_states + URDF/SRDF
   • dispatches planned trajectories → bridge action server
[Docker PC] RViz
   • 3D visualization + interactive planning
```

### Why `joint_state_relay`?

The Jetson Nano and the PC may have slightly unsynchronized system clocks. When the Nano stamps a message with its local clock and MoveIt on the PC compares it against the PC clock, MoveIt can reject the state as "stale". `joint_state_relay` re-stamps incoming joint states with the PC clock before republishing them on `/joint_states`.

---

## Key Bug Fixes Documented in This Repository

1. **Corrected XACRO Joint Origins (`8326dce`)**: Restored the 6 joint origins and limits from the official `mycobot_280_jn.urdf`.
2. **CycloneDDS Discovery (`8326dce`)**: Enabled default multicast for local discovery alongside static unicast peer configuration for cross-machine communication.
3. **Standardized Joint Names (`8326dce`)**: Unified all joint names across the bridge, controllers, `joint_limits.yaml`, SRDF, and RViz config (`joint2_to_joint1` ... `joint6output_to_joint6`).
4. **Visible MoveIt Interactive Marker (`aab1f7f`)**: Set `Interactive Marker Size: 0.15` in `moveit.rviz`.
5. **Targeted Bridge Process Management (`8effc7e`)**: Replaced broad `pkill python3` with targeted `pkill -9 -f mycobot_bridge` and `setsid` backgrounding.
6. **Full Hardware Execution in Bridge (`a70021b`)**: Added `DEPLOY_TO_NANO.sh` so the Nano runs the real `send_angles()` trajectory execution callback.
7. **Fresh DDS State on Launch**: `RUN_PLANNING_PC.sh` restarts the Nano bridge before each launch to clear stale DDS subscriber references.

---

## Initial Nano Setup (One-Time)

If the bridge is not yet installed on the Jetson Nano:

```bash
./mycobot_docker/DEPLOY_TO_NANO.sh
```

Requirements on the Jetson Nano:
- ROS 2 Galactic installed
- `~/custom_ws/src/` directory created (`mkdir -p ~/custom_ws/src`)
- `pymycobot`: `pip3 install pymycobot --upgrade`
- CycloneDDS: `sudo apt install ros-galactic-rmw-cyclonedds-cpp`

---

## Repository Structure

```text
mycobot_docker/
├── docker-compose.yml          # Container with host networking + X11
├── Dockerfile                  # ROS 2 Galactic + MoveIt 2 + pymycobot
├── RUN_PLANNING_PC.sh          # Main launch script (Nano bridge + MoveIt 2)
├── RUN_ROBOT_NANO.sh           # SSH + start_bridge on the Nano
├── DEPLOY_TO_NANO.sh           # Syncs and builds bridge code on the Nano
└── custom_ws/                  # ROS 2 workspace (volume-mounted)
    ├── cyclonedds_pc.xml       # PC DDS configuration
    └── src/
        ├── mycobot_description/          # URDF/XACRO + meshes
        ├── mycobot_280_jn_moveit_config/ # SRDF, controllers, RViz
        └── mycobot_hw_interface/         # mycobot_bridge + joint_state_relay + YOLO vision
```
