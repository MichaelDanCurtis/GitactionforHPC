# Architecture Documentation

## 🏗️ System Architecture Overview

This document explains the **correct architecture** for running CycleCloud on Azure Container Instances (ACI) with PBS Pro autoscaling.

---

## Critical Architectural Distinction

### CycleCloud Container (Azure Container Instance)
**What it is**: Azure Container Instance running the CycleCloud orchestration service  
**What runs here**:
- ✅ CycleCloud web UI (port 8080)
- ✅ CycleCloud REST API
- ✅ `azpbs` Python autoscaler package
- ✅ Autoscale configuration (`autoscale.json`)
- ❌ **NOT** PBS Professional scheduler

**Why no PBS?**
- Container is for **orchestration only**
- PBS requires persistent state and complex dependencies
- PBS runs on **dedicated VM nodes** in the cluster

### PBS Master Node (Azure Virtual Machine)
**What it is**: Azure VM that serves as the PBS scheduler and job submission node  
**What runs here**:
- ✅ PBS Professional server (`pbs_server`)
- ✅ PBS scheduler daemon
- ✅ PBS job queue management
- ✅ PBS custom resources and queue configuration
- ❌ **NOT** the azpbs autoscaler (that's on the container)

**Why a separate VM?**
- PBS needs persistent disk for job history
- PBS requires full OS capabilities
- PBS master coordinates all cluster compute nodes

---

## Communication Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Architecture Diagram                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐                    ┌──────────────────────┐
│  CycleCloud         │                    │  PBS Master Node     │
│  Container (ACI)    │                    │  (Azure VM)          │
│                     │                    │                      │
│  ┌──────────────┐   │                    │  ┌───────────────┐   │
│  │ CycleCloud   │   │                    │  │ PBS Server    │   │
│  │ Web UI       │   │                    │  │ (pbs_server)  │   │
│  └──────────────┘   │                    │  └───────┬───────┘   │
│                     │                    │          │           │
│  ┌──────────────┐   │                    │          │           │
│  │ CycleCloud   │   │  REST API          │          │           │
│  │ REST API     │◀──┼────────────────────┼──────────┘           │
│  └──────┬───────┘   │  (cluster status,  │                      │
│         │           │   node requests)   │  ┌───────────────┐   │
│         │           │                    │  │ PBS Queues    │   │
│         │           │                    │  │ - workq (MPI) │   │
│  ┌──────▼───────┐   │                    │  │ - htcq (HTC)  │   │
│  │ azpbs        │   │  Monitors queue    │  └───────────────┘   │
│  │ Autoscaler   │───┼────────────────────▶                      │
│  └──────┬───────┘   │  via PBS API       │  ┌───────────────┐   │
│         │           │                    │  │ Custom        │   │
│         │           │                    │  │ Resources     │   │
│         │           │                    │  │ - slot_type   │   │
│         │           │                    │  │ - vm_size     │   │
│         └───────────┼────────────────────┼──│ - group_id    │   │
│    Requests nodes   │                    │  └───────────────┘   │
│    based on jobs    │                    │                      │
└─────────┬───────────┘                    └──────────────────────┘
          │
          │ Provisions VMs
          ▼
┌─────────────────────────────────────────┐
│  Azure Resource Manager                 │
│  - Creates compute VMs                  │
│  - Configures networking                │
│  - Manages node lifecycle               │
└─────────────────────────────────────────┘
          │
          │ Starts nodes
          ▼
┌─────────────────────────────────────────┐
│  PBS Compute Nodes (Azure VMs)          │
│  - Execute array nodes                  │
│  - HTC array nodes                      │
│  - Auto-join PBS cluster                │
│  - Report to PBS master                 │
└─────────────────────────────────────────┘
```

---

## Deployment Flow

### Step 1: Deploy CycleCloud Container
**Workflow**: `Deploy-CycleCloud-from-MCR.yaml`

```
GitHub Actions
     │
     ▼
Azure Container Instance created
     │
     ├─ CycleCloud service starts
     ├─ Web UI available on port 8080
     └─ Ready to accept API calls
```

### Step 2: Create PBS Cluster
**Workflow**: `create-pbspro-cluster.yaml`

```
GitHub Actions
     │
     ├─ Upload cluster-init project (pbspro-autoscale)
     │  └─ Contains PBS initialization scripts
     │
     ├─ Initialize CycleCloud CLI
     │
     ├─ Generate cluster template
     │  └─ References: [[[cluster-init pbspro-autoscale:default]]]
     │
     ├─ Import cluster to CycleCloud
     │
     └─ Start master node
         │
         ▼
    PBS Master Node boots
         │
         ├─ Azure provisions VM
         ├─ CycleCloud agent starts
         ├─ PBS Pro gets installed
         └─ Cluster-init scripts run:
             ├─ 01-initialize-pbs.sh
             │   └─ Configure PBS server, custom resources
             └─ 02-initialize-queues.sh
                 └─ Create workq and htcq queues
```

**Key Point**: PBS initialization happens **on the master node** via cluster-init, NOT on the CycleCloud container.

### Step 3: Configure Autoscale
**Workflow**: `bootstrap-pbspro.yaml`

```
GitHub Actions
     │
     ├─ Package container-appropriate files:
     │  ├─ install.sh
     │  ├─ generate_autoscale_json.sh
     │  ├─ autoscale_hook.py
     │  ├─ logging.conf
     │  └─ packages/
     │
     ├─ Upload to CycleCloud container
     │
     ├─ Install azpbs in virtualenv
     │  └─ /opt/cycle/pbspro/venv/
     │
     └─ Generate autoscale.json
         └─ Configures mapping between PBS and CycleCloud
```

**Key Point**: Only autoscaler installation happens on the container. PBS is already configured on the master.

---

## Why This Architecture?

**On CycleCloud Container (ACI)**:
```bash
bootstrap workflow
    ├─ install.sh                    ✅ Install azpbs
    └─ generate_autoscale_json.sh   ✅ Generate config
```

**On PBS Master Node (VM, via cluster-init)**:
```bash
cluster-init: pbspro-autoscale:default
    ├─ 01-initialize-pbs.sh         ✅ Configure PBS server
    └─ 02-initialize-queues.sh      ✅ Create queues
```
## File Organization

### Repository Structure
```
GitactionforHPC/
├── .github/workflows/
│   ├── Workflow-1-Deploy-CycleCloud.yaml       # Deploy CycleCloud (private VNet)
│   └── Workflow-2-Create-PBSpro-Cluster.yaml   # Create cluster + autoscale
│
├── cluster-init/                               # All cluster configuration
│   ├── cluster-templates/                      # User-editable templates
│   │   ├── pbspro-cluster.txt                  # ✅ Cluster definition
│   │   └── README.md                           # ✅ Customization guide
│   └── pbspro-autoscale/                       # Master node configuration
│       ├── project.ini                         # ✅ Cluster-init definition
│       └── specs/default/cluster-init/scripts/
│           ├── 01-initialize-pbs.sh            # ✅ PBS server setup
│           └── 02-initialize-queues.sh         # ✅ Queue creation
│
├── cyclecloud-pbspro/                          # Container-side files
│   ├── install.sh                              # ✅ Install azpbs
│   ├── generate_autoscale_json.sh              # ✅ Generate autoscale config
│   ├── autoscale_hook.py                       # ✅ PBS autoscale hook
│   ├── logging.conf                            # ✅ Logging config
│   ├── server_dyn_res_wrapper.sh               # ✅ Dynamic resources helper
│   └── packages/                               # ✅ Python wheels
│
└── Legacy/                                     # Deprecated files
    ├── bootstrap-pbspro.yaml                   # ⚠️  Merged into Workflow 2
    ├── create-pbspro-cluster.yaml              # ⚠️  Replaced by Workflow 2
    └── README.md                               # Migration notes
```

### Execution Locations

| File | Runs On | Triggered By |
|------|---------|--------------|
| `install.sh` | CycleCloud container | Workflow 2 (autoscale step) |
| `generate_autoscale_json.sh` | CycleCloud container | Workflow 2 (autoscale step) |
| `autoscale_hook.py` | PBS master node | Generated during autoscale setup |
| `01-initialize-pbs.sh` | PBS master node | CycleCloud cluster-init |
| `02-initialize-queues.sh` | PBS master node | CycleCloud cluster-init |

---

## Data Flow: Job Submission to Node Scaling

```
1. User submits job to PBS
   └─> SSH to PBS master node
       └─> qsub -l select=4:ncpus=8

2. PBS queues the job
   └─> Job sits in queue (insufficient resources)

3. azpbs monitors PBS queue (via API)
   └─> Runs on CycleCloud container
       └─> Polls PBS master API for queue status

4. azpbs calculates node demand
   └─> Determines: Need 4 nodes, 8 CPUs each
       └─> Maps to Azure VM size (e.g., Standard_F8s_v2)

5. azpbs requests nodes from CycleCloud
   └─> REST API call: "Create 4 execute nodes"

6. CycleCloud provisions Azure VMs
   └─> Creates VMs via Azure Resource Manager
       └─> VMs join PBS cluster automatically

7. PBS scheduler assigns job to nodes
   └─> Job starts running

8. Job completes, nodes idle
   └─> azpbs detects idle nodes after 5 minutes
       └─> Requests CycleCloud to terminate nodes

9. CycleCloud terminates VMs
   └─> Cluster scales back to master only
```

---

## Configuration Files

### autoscale.json (on CycleCloud container)
**Location**: `/opt/cycle/pbspro/autoscale.json`  
**Purpose**: Maps PBS resources to CycleCloud node properties

```json
{
  "cluster_name": "pbspro-cluster",
  "url": "http://127.0.0.1:8080",
  "username": "admin",
  "default_resources": {
    "ncpus": {"select": "node.pcpu_count"},
    "ngpus": {"select": "node.gpu_count"},
    "mem": {"select": "node.memory"},
    "slot_type": {"select": "node.nodearray"},
    "vm_size": {"select": "node.vm_size"},
    "group_id": {"select": "node.placement_group"}
  },
  "idle_timeout": 300,
  "boot_timeout": 3600
}
```

### PBS Custom Resources (on PBS master)
**Configuration method**: `qmgr` commands in cluster-init  
**Purpose**: Allow jobs to request Azure-specific attributes

```bash
# Created by 01-initialize-pbs.sh
qmgr -c "create resource slot_type type=string,flag=h"
qmgr -c "create resource vm_size type=string,flag=h"
qmgr -c "create resource group_id type=string,flag=h"
qmgr -c "create resource ngpus type=long,flag=h"
```

**Usage in jobs**:
```bash
# Request specific node array
qsub -l select=2:slot_type=execute:ncpus=4

# Request specific VM size
qsub -l select=1:vm_size=Standard_F16s_v2

# Request GPUs
qsub -l select=1:ngpus=2
```

---

## Troubleshooting Guide

### Issue: "qmgr: command not found" on container
**Diagnosis**: Trying to run PBS commands on CycleCloud container  
**Root Cause**: PBS is not installed on the container (by design)  
**Solution**: PBS commands must run on the master node via cluster-init

### Issue: PBS queues not created
**Diagnosis**: Cluster-init scripts didn't run  
**Check**: `sudo cat /var/log/cloud-init-output.log | grep pbspro-autoscale` on master  
**Solution**: Verify cluster-init project was uploaded and referenced in template

### Issue: Autoscale not working
**Diagnosis**: azpbs can't connect to PBS master  
**Check**: 
1. On container: `azpbs connect`
2. On master: PBS server is running (`systemctl status pbs`)
**Solution**: Verify network connectivity between container and master

### Issue: Jobs stay queued, nodes don't start
**Diagnosis**: azpbs not monitoring or CycleCloud not provisioning  
**Check**:
1. autoscale.json exists on container: `/opt/cycle/pbspro/autoscale.json`
2. Manual trigger: `azpbs autoscale --config /opt/cycle/pbspro/autoscale.json`
3. CycleCloud cluster exists and is started
**Solution**: Run bootstrap workflow to install azpbs, verify cluster creation

---

## Best Practices

### ✅ DO
- Use cluster-init for PBS configuration (runs on master node)
- Use bootstrap workflow for azpbs installation (runs on container)
- Keep PBS initialization scripts in `cluster-init/` directory
- Upload cluster-init project before creating cluster
- Verify cluster-init execution via `/var/log/cloud-init-output.log`

### ❌ DON'T
- Don't try to run qmgr commands on the CycleCloud container
- Don't install PBS on the container (not needed, not supported)
- Don't skip cluster-init project upload (PBS won't be configured)
- Don't mix container tasks and node tasks in the same script

---

## Summary

| Component | Location | Purpose |
|-----------|----------|---------|
| **CycleCloud Container** | Azure Container Instance | Orchestration, autoscaler |
| **PBS Master Node** | Azure VM | PBS scheduler, job queue |
| **PBS Compute Nodes** | Azure VMs | Job execution |
| **Cluster-Init** | Runs on master during boot | PBS configuration |
| **Bootstrap Workflow** | Runs on container | azpbs installation |
| **azpbs** | Container, monitors master | Autoscale logic |

**Key Insight**: CycleCloud container orchestrates; PBS master schedules; compute nodes execute. Each component runs in the right place with the right capabilities.

---

**This architecture is production-ready and follows CycleCloud best practices!** ✅
