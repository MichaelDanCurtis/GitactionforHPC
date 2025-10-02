#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
# Convenience orchestrator that installs and configures the CycleCloud PBS Pro integration.
# This script is intended to be executed on the CycleCloud server as root.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bootstrap_pbspro.sh --username <cyclecloud_admin> --password <cyclecloud_password> --cluster-name <cyclecloud_cluster>
                          [--url http://127.0.0.1:8080] [--install-python3] [--install-venv]
                          [--venv /opt/cycle/pbspro/venv] [--install-dir /opt/cycle/pbspro]
                          [--cron-method pbs_hook|cron] [--ignore-queues queue1,queue2]

Mandatory arguments:
  --username           CycleCloud administrative username with rights to manage the target cluster.
  --password           Password for the CycleCloud administrative user.
  --cluster-name       CycleCloud cluster name that should be managed by azpbs.

Optional arguments:
  --url                Base URL for the CycleCloud instance (default: http://127.0.0.1:8080).
  --install-python3    Delegate python3 installation to install.sh if it is not already present.
  --install-venv       Install virtualenv before creating the azpbs environment.
  --venv               Target virtual environment path for azpbs (default: /opt/cycle/pbspro/venv).
  --install-dir        Override the installation directory for autoscale assets (defaults to dirname of --venv or /opt/cycle/pbspro).
  --cron-method        Choose between 'pbs_hook' (default) or 'cron' invocation for azpbs autoscale.
  --ignore-queues      Comma separated queue names excluded from autoscaling (passed to generate_autoscale_json.sh).

The script must be executed as root on the CycleCloud server.
USAGE
}

if [[ $(id -u) -ne 0 ]]; then
  echo "bootstrap_pbspro.sh must be executed with root privileges." >&2
  exit 1
else
  # ensure we can find utilities installed via /root/bin
  if [[ -d /root/bin ]] && [[ ":$PATH:" != *":/root/bin:"* ]]; then
    export PATH="$PATH:/root/bin"
  fi
fi

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)

CC_USERNAME=""
CC_PASSWORD=""
CC_CLUSTER=""
CC_URL="http://127.0.0.1:8080"
IGNORE_QUEUES=""
INSTALL_ARGS=()
REQUESTED_INSTALL_DIR=""
REQUESTED_VENV=""

while (($#)); do
  case "$1" in
    --username)
      [[ $# -ge 2 ]] || { echo "--username requires a value" >&2; exit 2; }
      CC_USERNAME="$2"
      shift 2
      ;;
    --password)
      [[ $# -ge 2 ]] || { echo "--password requires a value" >&2; exit 2; }
      CC_PASSWORD="$2"
      shift 2
      ;;
    --cluster-name)
      [[ $# -ge 2 ]] || { echo "--cluster-name requires a value" >&2; exit 2; }
      CC_CLUSTER="$2"
      shift 2
      ;;
    --url)
      [[ $# -ge 2 ]] || { echo "--url requires a value" >&2; exit 2; }
      CC_URL="$2"
      shift 2
      ;;
    --install-python3)
      INSTALL_ARGS+=("--install-python3")
      shift
      ;;
    --install-venv)
      INSTALL_ARGS+=("--install-venv")
      shift
      ;;
    --venv)
      [[ $# -ge 2 ]] || { echo "--venv requires a value" >&2; exit 2; }
      REQUESTED_VENV="$2"
      INSTALL_ARGS+=("--venv" "$2")
      shift 2
      ;;
    --install-dir)
      [[ $# -ge 2 ]] || { echo "--install-dir requires a value" >&2; exit 2; }
      REQUESTED_INSTALL_DIR="$2"
      shift 2
      ;;
    --cron-method)
      [[ $# -ge 2 ]] || { echo "--cron-method requires a value" >&2; exit 2; }
      INSTALL_ARGS+=("--cron-method" "$2")
      shift 2
      ;;
    --ignore-queues)
      [[ $# -ge 2 ]] || { echo "--ignore-queues requires a value" >&2; exit 2; }
      IGNORE_QUEUES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$CC_USERNAME" || -z "$CC_PASSWORD" || -z "$CC_CLUSTER" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 2
fi

if [[ -z "$REQUESTED_INSTALL_DIR" ]]; then
  if [[ -n "$REQUESTED_VENV" ]]; then
    REQUESTED_INSTALL_DIR=$(dirname "$REQUESTED_VENV")
  else
    REQUESTED_INSTALL_DIR="/opt/cycle/pbspro"
  fi
fi

if [[ ! -d "$SCRIPT_DIR" ]]; then
  echo "Unable to resolve script directory." >&2
  exit 1
fi

echo "[bootstrap_pbspro] Installing azpbs runtime (args: ${INSTALL_ARGS[*]:-<default>})"
"$SCRIPT_DIR/install.sh" "${INSTALL_ARGS[@]}"

echo "[bootstrap_pbspro] Applying PBS server defaults"
"$SCRIPT_DIR/initialize_pbs.sh"

echo "[bootstrap_pbspro] Creating default queues"
"$SCRIPT_DIR/initialize_default_queues.sh"

GENERATOR_ARGS=(
  --username "$CC_USERNAME"
  --password "$CC_PASSWORD"
  --url "$CC_URL"
  --cluster-name "$CC_CLUSTER"
  --install-dir "$REQUESTED_INSTALL_DIR"
)

if [[ -n "$IGNORE_QUEUES" ]]; then
  GENERATOR_ARGS+=(--ignore-queues "$IGNORE_QUEUES")
fi

echo "[bootstrap_pbspro] Generating autoscale configuration"
"$SCRIPT_DIR/generate_autoscale_json.sh" "${GENERATOR_ARGS[@]}"

echo "[bootstrap_pbspro] PBS Pro integration completed successfully"
