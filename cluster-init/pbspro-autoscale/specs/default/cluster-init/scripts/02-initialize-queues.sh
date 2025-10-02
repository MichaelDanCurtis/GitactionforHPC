#!/bin/bash
# This script runs on the PBS master node during cluster initialization
# It creates default queues for different workload types

set -euo pipefail

echo "[cluster-init] Creating default PBS queues..."

source /etc/profile.d/pbs.sh

# Configure workq for MPI/tightly-coupled jobs
/opt/pbs/bin/qmgr -c "set queue workq resources_default.place = scatter:excl"
/opt/pbs/bin/qmgr -c "set queue workq resources_default.ungrouped = false"

# Enable node grouping for placement groups
/opt/pbs/bin/qmgr -c "set server node_group_enable = true"
/opt/pbs/bin/qmgr -c 'set server node_group_key = group_id'

# Create htcq for HTC/embarrassingly parallel jobs
/opt/pbs/bin/qmgr -c "list queue htcq" 2>/dev/null || /opt/pbs/bin/qmgr -c "create queue htcq"
/opt/pbs/bin/qmgr -c "set queue htcq queue_type = Execution"
/opt/pbs/bin/qmgr -c "set queue htcq resources_default.place = free"
/opt/pbs/bin/qmgr -c "set queue htcq resources_default.ungrouped = true"
/opt/pbs/bin/qmgr -c "set queue htcq enabled = true"
/opt/pbs/bin/qmgr -c "set queue htcq started = true"

echo "[cluster-init] PBS queue configuration complete."
