# cluster-init Directory - CycleCloud Cluster Initialization

## 📋 Overview
This directory contains CycleCloud cluster-init projects that run scripts on cluster nodes during boot. Cluster-init is CycleCloud's native mechanism for configuring software and settings on nodes as they start up.

**Why cluster-init?** PBS Professional runs on the cluster master node (Azure VM), not on the CycleCloud orchestration container (Azure Container Instance). We need to run PBS configuration commands (`qmgr`) on the master node where PBS is installed.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions: "Create CycleCloud PBS Pro Cluster"   │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │ Upload cluster-init project   │
        │ to CycleCloud server          │
        └───────────────┬───────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │ Create cluster with template  │
        │ referencing cluster-init spec │
        │ [[[cluster-init               │
        │   pbspro-autoscale:default]]] │
        │   Order = 20000               │
        └───────────────┬───────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │ Start PBS master node         │
        └───────────────┬───────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────────────┐
│  PBS Master Node Boot Sequence                        │
├───────────────────────────────────────────────────────┤
│  1. Azure provisions VM                               │
│  2. OS boots                                          │
│  3. CycleCloud agent starts                           │
│  4. PBS Pro gets installed (via CycleCloud template)  │
│  5. Cluster-init scripts run (Order 20000):           │
│     ├─ 01-initialize-pbs.sh                           │
│     │  └─ Configure PBS server with qmgr              │
│     │     - Custom resources                          │
│     │     - Server settings                           │
│     │     - Scheduler iteration                       │
│     └─ 02-initialize-queues.sh                        │
│        └─ Create PBS queues                           │
│           - workq (MPI, placement groups)             │
│           - htcq (HTC, no placement groups)           │
│  6. Node fully configured and ready                   │
└───────────────────────────────────────────────────────┘
```

---

## 📁 Directory Structure

```
cluster-init/
└── pbspro-autoscale/                    # Cluster-init project name
    ├── project.ini                      # Project metadata
    └── specs/
        └── default/                     # Spec name (referenced in template)
            └── cluster-init/
                └── scripts/
                    ├── 01-initialize-pbs.sh        # PBS server configuration
                    └── 02-initialize-queues.sh     # Queue creation
```

---

## 📄 File Descriptions

### `pbspro-autoscale/project.ini`
**Purpose**: Defines the cluster-init project metadata  
**Format**: INI configuration file

```ini
[project]
version = 1.0.0
type = application
```

**Fields**:
- `version`: Project version (semantic versioning)
- `type`: Project type (`application` for custom software configuration)

**Used by**: CycleCloud when uploading and managing the project

---

### `specs/default/cluster-init/scripts/01-initialize-pbs.sh`
**Purpose**: Configures PBS server settings and creates custom resources  
**Execution**: Runs on PBS master node during boot, AFTER PBS Pro is installed  
**Order**: 20000 (ensures PBS is already installed)

**What it does**:
1. Waits for PBS server to be available
2. Configures PBS server settings via `qmgr` commands:
   ```bash
   # Set managers
   qmgr -c "set server managers = root@*"
   
   # Enable job queries
   qmgr -c "set server query_other_jobs = True"
   
   # Fast scheduler iteration (15 seconds)
   qmgr -c "set server scheduler_iteration = 15"
   
   # Job history
   qmgr -c "set server job_history_enable = True"
   ```

3. Creates custom PBS resources for Azure integration:
   - `slot_type` (string) - CycleCloud node array name
   - `instance_id` (string) - Azure VM instance ID
   - `vm_size` (string) - Azure VM SKU (e.g., Standard_F4s_v2)
   - `nodearray` (string) - CycleCloud node array
   - `disk` (size) - Disk size in bytes
   - `ngpus` (long) - Number of GPUs
   - `group_id` (string) - Placement group ID for MPI jobs
   - `ungrouped` (string_array) - Whether node can join any placement group

**Example custom resource**:
```bash
qmgr -c "create resource slot_type type=string,flag=h"
qmgr -c "create resource vm_size type=string,flag=h"
```

**Output**: PBS server configured with Azure-aware resources

---

### `specs/default/cluster-init/scripts/02-initialize-queues.sh`
**Purpose**: Creates and configures PBS queues for different workload types  
**Execution**: Runs on PBS master node during boot, AFTER PBS server is configured  
**Order**: 20000 (same as previous script, runs sequentially)

**What it does**:
1. Configures `workq` queue (default, for MPI workloads):
   ```bash
   qmgr -c "set queue workq queue_type = Execution"
   qmgr -c "set queue workq enabled = True"
   qmgr -c "set queue workq started = True"
   qmgr -c "set queue workq resources_default.place = scatter:excl"
   qmgr -c "set queue workq resources_default.ungrouped = false"
   ```
   - `scatter:excl` - Spread jobs across nodes, exclusive access
   - `ungrouped = false` - Enforce placement groups (for MPI low-latency networking)

2. Creates `htcq` queue (for HTC workloads):
   ```bash
   qmgr -c "create queue htcq"
   qmgr -c "set queue htcq queue_type = Execution"
   qmgr -c "set queue htcq enabled = True"
   qmgr -c "set queue htcq started = True"
   qmgr -c "set queue htcq resources_default.place = free"
   qmgr -c "set queue htcq resources_default.ungrouped = true"
   ```
   - `place = free` - Pack jobs wherever they fit
   - `ungrouped = true` - Ignore placement groups (for embarrassingly parallel work)

3. Enables node grouping:
   ```bash
   qmgr -c "set server node_group_enable = True"
   qmgr -c "set server node_group_key = group_id"
   ```

**Output**: Two queues configured for different job patterns

---

## 🔧 How Cluster-Init Works

### Upload Process
The "Create CycleCloud PBS Pro Cluster" workflow uploads the project:
```bash
cyclecloud project upload /path/to/cluster-init/pbspro-autoscale
```

This makes the project available to CycleCloud for use in cluster templates.

### Template Reference
The cluster template includes:
```ini
[[[cluster-init pbspro-autoscale:default]]]
Order = 20000
```

**Fields**:
- `pbspro-autoscale` - Project name
- `default` - Spec name within the project
- `Order = 20000` - Execution order (higher = later, after PBS installation)

### Execution Order
1. Order 0-10000: CycleCloud base configuration, networking, storage
2. Order 10000-19999: Software installation (PBS Pro installed here)
3. **Order 20000: PBS configuration scripts run** ← Our scripts
4. Order 20001+: Post-configuration tasks

By using Order 20000, we ensure PBS Pro is already installed when our scripts run.

### Script Execution
- Scripts run as `root` user
- Scripts run in **alphabetical order** (hence `01-`, `02-` prefixes)
- Scripts must be executable (`chmod +x`)
- Output logged to `/var/log/cloud-init-output.log`

---

## 🎯 Why This Architecture?

### The Problem
Originally, PBS initialization scripts were in `cyclecloud-pbspro/` and called by the bootstrap workflow. This had a critical flaw:

**PBS runs on the cluster master node (VM), not the CycleCloud container (ACI).**

Running `qmgr` commands on the CycleCloud container fails because:
- PBS Pro is not installed there
- The container is for orchestration only
- PBS server (`pbs_server`) runs on the master node

### The Solution: Cluster-Init
CycleCloud's cluster-init mechanism solves this by:
1. ✅ Running scripts **on the node where PBS is installed** (master VM)
2. ✅ Running scripts **at the right time** (after PBS installation)
3. ✅ Being the **standard CycleCloud pattern** for node configuration
4. ✅ Supporting **version control and updates** via project uploads

---

## 🔍 Verification

### Check Cluster-Init Execution
SSH to the PBS master node:
```bash
# View cluster-init logs
sudo cat /var/log/cloud-init-output.log | grep -A 50 "pbspro-autoscale"

# Check for script execution
sudo grep "01-initialize-pbs.sh" /var/log/cloud-init-output.log
sudo grep "02-initialize-queues.sh" /var/log/cloud-init-output.log
```

### Verify PBS Configuration
```bash
# Check custom resources were created
/opt/pbs/bin/qmgr -c "list resource" | grep -E "slot_type|vm_size|nodearray"

# Check server settings
/opt/pbs/bin/qmgr -c "list server" | grep -E "scheduler_iteration|node_group"

# Check queues were created
/opt/pbs/bin/qstat -Q
# Should show: workq and htcq

# Check queue settings
/opt/pbs/bin/qmgr -c "list queue workq" | grep place
/opt/pbs/bin/qmgr -c "list queue htcq" | grep place
```

### Test Job Submission
```bash
# Submit to workq (MPI, placement group enforced)
echo "sleep 60" | qsub -l select=2:ncpus=4

# Submit to htcq (HTC, no placement group)
echo "sleep 60" | qsub -q htcq -l select=4:ncpus=2
```

---

## 🔄 Updating Scripts

To modify PBS initialization:

1. **Edit the scripts** in `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/`
2. **Re-run the cluster creation workflow** to upload the updated project
3. **Terminate and restart the master node** to apply changes

Or manually:
```bash
# Upload updated project
cyclecloud project upload cluster-init/pbspro-autoscale

# Terminate master node in CycleCloud UI
# Start new master node
# New node will run updated cluster-init scripts
```

---

## 📚 References

- [CycleCloud Cluster-Init Documentation](https://learn.microsoft.com/azure/cyclecloud/how-to/cluster-init)
- [PBS Professional qmgr Command](https://help.altair.com/pbspro/qmgr.htm)
- [CycleCloud Project Management](https://learn.microsoft.com/azure/cyclecloud/how-to/projects)

---

## ✅ Summary

| Aspect | Details |
|--------|---------|
| **Purpose** | Configure PBS server and queues on master node during boot |
| **Why needed** | PBS runs on master VM, not CycleCloud container |
| **When runs** | During master node boot, after PBS installation (Order 20000) |
| **What it configures** | PBS server settings, custom resources, queues (workq, htcq) |
| **How to update** | Edit scripts, re-upload project, restart master node |
| **Verification** | Check `/var/log/cloud-init-output.log` and `qmgr -c "list resource"` |

**This is the correct, production-ready way to initialize PBS in a CycleCloud cluster running on Azure Container Instances!** ✅
