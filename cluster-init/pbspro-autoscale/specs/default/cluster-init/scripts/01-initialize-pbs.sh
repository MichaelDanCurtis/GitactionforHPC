#!/bin/bash
# This script runs on the PBS master node during cluster initialization
# It configures PBS server settings and creates custom resources for Azure

set -euo pipefail

echo "[cluster-init] Configuring PBS server settings..."

source /etc/profile.d/pbs.sh

/opt/pbs/bin/qmgr -c 'set server managers = root@*'
/opt/pbs/bin/qmgr -c 'set server query_other_jobs = true'
/opt/pbs/bin/qmgr -c 'set server scheduler_iteration = 15'
/opt/pbs/bin/qmgr -c 'set server flatuid = true'
/opt/pbs/bin/qmgr -c 'set server job_history_enable = true'

/opt/pbs/bin/qmgr -c "set sched only_explicit_psets=True"
/opt/pbs/bin/qmgr -c "set sched do_not_span_psets=True"

function create_resource() {
	local name=$1
	local type=$2
	local flag=${3:-}
	
	if [ -n "$flag" ]; then
		flag=", flag=$flag"
	fi
	
	/opt/pbs/bin/qmgr -c "list resource $name" >/dev/null 2>/dev/null || \
	/opt/pbs/bin/qmgr -c "create resource $name type=$type $flag"
}

echo "[cluster-init] Creating Azure-specific PBS resources..."

create_resource slot_type string h
create_resource instance_id string h
create_resource vm_size string h
create_resource nodearray string h
create_resource disk size nh
create_resource ngpus long nh
create_resource group_id string h
create_resource ungrouped string h

# Fix PBS mom limits
sed -i "s/^if /#if /g" /opt/pbs/lib/init.d/limits.pbs_mom
sed -i "s/^fi/#fi /g" /opt/pbs/lib/init.d/limits.pbs_mom

echo "[cluster-init] PBS server configuration complete."
