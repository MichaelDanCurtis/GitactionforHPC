# cyclecloud-pbspro Directory - File Purpose Guide

## 📋 Overview
This directory contains scripts and dependencies for the PBS Pro autoscale integration with Azure CycleCloud. 

**Important Architecture Note**: As of the current implementation, PBS initialization (server configuration and queue creation) happens via CycleCloud's **cluster-init mechanism** on the PBS master node during boot. The files in this directory are primarily for installing the `azpbs` autoscaler on the CycleCloud container.

---

## 🏗️ Current Architecture

### Files Used by Workflows (Active)
These files are packaged and deployed to the **CycleCloud container** (Azure Container Instance):

| File | Purpose | Runs On |
|------|---------|---------|
| `install.sh` | Installs azpbs Python package and dependencies | CycleCloud container |
| `generate_autoscale_json.sh` | Generates autoscale configuration | CycleCloud container |
| `autoscale_hook.py` | PBS hook for periodic autoscale triggering | CycleCloud container |
| `server_dyn_res_wrapper.sh` | Helper for PBS dynamic resource scripts | CycleCloud container |
| `logging.conf` | Logging configuration for azpbs | CycleCloud container |
| `packages/` | Python wheel files for offline installation | CycleCloud container |

### Files Replaced by Cluster-Init (Deprecated)
These files contain the logic that now runs via cluster-init on the PBS master node:

| File | Status | Replacement |
|------|--------|-------------|
| `bootstrap_pbspro.sh` | ⚠️ Deprecated | Workflow steps in `.github/workflows/bootstrap-pbspro.yaml` |
| `initialize_pbs.sh` | ⚠️ Deprecated | `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/01-initialize-pbs.sh` |
| `initialize_default_queues.sh` | ⚠️ Deprecated | `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/02-initialize-queues.sh` |

**Why deprecated?** These scripts require PBS Pro to be installed. PBS runs on the cluster master node (VM), not the CycleCloud container (ACI). The cluster-init mechanism ensures they run in the right place at the right time.

---

## 🔧 Active Shell Scripts

### 1. `install.sh` 
**Purpose**: Installs the `azpbs` CLI tool and all Python dependencies  
**Execution location**: CycleCloud container (Azure Container Instance)
**When executed**: Called by the "Configure CycleCloud Autoscale" workflow  
**What it does**:
1. Checks for Python 3 (installs if `--install-python3` flag set)
2. Creates Python virtual environment at `/opt/cycle/pbspro/venv`
3. Installs all wheel packages from `packages/` directory:
   - `cyclecloud_pbspro-2.0.25.tar.gz` (main PBS autoscaler package)
   - `cyclecloud-scalelib-1.0.5.tar.gz` (CycleCloud autoscale library)
   - `cyclecloud_api` (CycleCloud REST API client)
   - All dependencies (requests, attrs, jsonpickle, etc.)
4. Creates `azpbs` executable symlink in `/root/bin/`
5. Copies support files:
   - `autoscale_hook.py` → `/opt/cycle/pbspro/autoscale_hook.py`
   - `logging.conf` → `/opt/cycle/pbspro/logging.conf`

**Key arguments**:
- `--install-python3`: Install Python 3 if missing
- `--install-venv`: Install virtualenv package
- `--venv /path`: Custom venv location
- `--cron-method none`: Don't set up cron (not needed on container)

**Output**: 
- `/opt/cycle/pbspro/venv/` with azpbs installed
- `/root/bin/azpbs` command available

**Used by**: `.github/workflows/bootstrap-pbspro.yaml`

---

### 2. `generate_autoscale_json.sh`
**Purpose**: Generates the `autoscale.json` configuration file that connects PBS to CycleCloud  
**Execution location**: CycleCloud container
**When executed**: Called by the "Configure CycleCloud Autoscale" workflow  
**What it does**:
1. Takes CycleCloud credentials and cluster name
2. Runs `azpbs initconfig` to generate `/opt/cycle/pbspro/autoscale.json`
3. Configures resource mappings between PBS and CycleCloud:
   - `ncpus` → `node.pcpu_count`
   - `ngpus` → `node.gpu_count`
   - `mem` → `node.memory`
   - `slot_type` → `node.nodearray`
   - `vm_size` → `node.vm_size`
   - `group_id` → `node.placement_group`
4. Sets timeouts:
   - `idle-timeout: 300` seconds (5 min before scale-down)
   - `boot-timeout: 3600` seconds (1 hour for node startup)
5. Tests CycleCloud connection with `azpbs connect`

**Key arguments**:
- `--username` / `--password`: CycleCloud credentials
- `--url`: CycleCloud API URL
- `--cluster-name`: Target cluster
- `--ignore-queues`: Queues to exclude
- `--install-dir`: Installation directory

**Output**: `/opt/cycle/pbspro/autoscale.json` (captured as workflow artifact)

**Used by**: `.github/workflows/bootstrap-pbspro.yaml`

---

### 3. `server_dyn_res_wrapper.sh`
**Purpose**: Wrapper script for PBS dynamic resources  
**Execution location**: CycleCloud container (if used)
**When executed**: Called by PBS when evaluating dynamic resources (optional)  
**What it does**:
- Caches output of dynamic resource scripts to `/opt/cycle/pbspro/server_dyn_res/<resource_name>`
- Prevents re-running expensive scripts on every scheduler iteration
- Example: `server_dyn_res: "myres !/opt/cycle/pbspro/server_dyn_res_wrapper.sh myres /path/to/script.sh"`

**Output**: Cached resource values

**Used by**: PBS server (optional, for custom dynamic resources)

---

## ⚠️ Deprecated Shell Scripts

### 4. `bootstrap_pbspro.sh` - DEPRECATED ⚠️
**Original purpose**: Master orchestrator that called all other scripts  
**Why deprecated**: The workflow now calls scripts directly. Also, this tried to run PBS initialization scripts on the CycleCloud container where PBS doesn't exist.
**Replacement**: Workflow steps in `.github/workflows/bootstrap-pbspro.yaml`
**Status**: Kept for reference only

---

### 5. `initialize_pbs.sh` - MOVED TO CLUSTER-INIT ⚠️
**Original purpose**: Configured PBS server settings and created custom resources  
**Why moved**: Requires PBS Pro to be installed. PBS runs on the master node (VM), not CycleCloud container (ACI).
**Replacement**: `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/01-initialize-pbs.sh`
**When executed**: Automatically during PBS master node boot via cluster-init
**Status**: Kept for reference only

**What it does** (now in cluster-init):
1. Configures PBS server settings via `qmgr`
2. Creates custom PBS resources for Azure attributes:
   - `slot_type`, `instance_id`, `vm_size`, `nodearray`, `disk`, `ngpus`, `group_id`, `ungrouped`

---

### 6. `initialize_default_queues.sh` - MOVED TO CLUSTER-INIT ⚠️
**Original purpose**: Created and configured default PBS queues  
**Why moved**: Requires PBS Pro to be installed (same reason as above)
**Replacement**: `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/02-initialize-queues.sh`
**When executed**: Automatically during PBS master node boot via cluster-init
**Status**: Kept for reference only

**What it does** (now in cluster-init):
1. Configures `workq` queue (MPI workloads, placement groups enforced)
2. Creates `htcq` queue (HTC workloads, placement groups ignored)
3. Enables node grouping

---

## 🐍 Python Scripts

### 7. `autoscale_hook.py`
**Purpose**: PBS hook that periodically triggers autoscaling  
**When executed**: Every 15 seconds by PBS scheduler (if using `pbs_hook` method)  
**What it does**:
1. Reads hook configuration from `/opt/cycle/pbspro/autoscale_hook_config.json`
2. Finds the `azpbs` executable (defaults to `/opt/cycle/pbspro/venv/bin/azpbs`)
3. Runs `azpbs autoscale --config /opt/cycle/pbspro/autoscale.json`
4. Logs to PBS server logs (`/var/spool/pbs/server_logs/`)

**Hook configuration** (created by `install.sh`):
```json
{
  "azpbs_path": "/opt/cycle/pbspro/venv/bin/azpbs",
  "autoscale_json": "/opt/cycle/pbspro/autoscale.json"
}
```

**Alternative**: If using `cron` method, autoscale runs 4 times per minute via crontab instead

**Output**: Node scale-up/down decisions sent to CycleCloud

**Used by**: PBS server (installed by `install.sh` line 124)

---

## 📄 Configuration Files

### 8. `logging.conf`
**Purpose**: Configures Python logging for the azpbs autoscaler  
**What it contains**:
- Log format configuration
- Log levels (DEBUG, INFO, WARNING, ERROR)
- Log file locations
- Console and file handlers

**Used by**: `azpbs` CLI and `autoscale_hook.py`

**Installed to**: `/opt/cycle/pbspro/logging.conf`

---

## 📦 packages/ Directory

### 9. `packages/*.whl` and `packages/*.tar.gz`
**Purpose**: Offline Python package dependencies for air-gapped installations  
**When used**: Installed by `install.sh` via `pip install packages/*`  

**Key packages**:

#### Core Packages:
- **`cyclecloud_pbspro-2.0.25.tar.gz`** ⭐  
  The main PBS Pro autoscaler package from Microsoft
  - Provides the `azpbs` CLI command
  - Implements PBS-to-CycleCloud translation logic
  - Handles node lifecycle management

- **`cyclecloud-scalelib-1.0.5.tar.gz`**  
  CycleCloud autoscale library
  - Common autoscale logic shared across schedulers
  - Node demand calculation
  - Bucket allocation algorithms

- **`cyclecloud_api-8.3.1-py2.py3-none-any.whl`**  
  CycleCloud REST API client
  - Communicates with CycleCloud server
  - Manages cluster state
  - Requests node allocation/deallocation

#### HTTP/Networking:
- `requests-2.24.0` - HTTP library for API calls
- `requests_cache-0.7.5` - Caches API responses
- `urllib3-1.25.11` - Low-level HTTP
- `certifi-2023.7.22` - SSL certificates
- `chardet-3.0.4` - Character encoding detection
- `idna-2.10` - Internationalized domain names

#### Utilities:
- `attrs-21.4.0` - Class attributes without boilerplate
- `jsonpickle-1.5.2` - JSON serialization
- `immutabledict-1.0.0` - Immutable dictionaries
- `six-1.17.0` - Python 2/3 compatibility
- `typing_extensions-3.7.4.3` - Type hints backport
- `argcomplete-1.12.2` - Bash tab completion
- `url_normalize-1.4.3` - URL normalization

**Why included**: Allows installation without internet access (all dependencies bundled)

---

## 📊 Execution Flow (Current Architecture)

```
GitHub Actions Workflow: "Configure CycleCloud Autoscale"
        ↓
packages: install.sh, generate_autoscale_json.sh, 
          autoscale_hook.py, logging.conf, packages/
        ↓
uploads to CycleCloud container
        ↓
executes: install.sh --install-venv --cron-method none
        ↓
    ├─ pip install packages/*
    ├─ creates /opt/cycle/pbspro/venv
    └─ copies autoscale_hook.py and logging.conf
        ↓
executes: generate_autoscale_json.sh
        ↓
    └─ creates /opt/cycle/pbspro/autoscale.json
        ↓
PBS Initialization (happens separately via cluster-init)
        ↓
    Cluster creation workflow uploads cluster-init project
        ↓
    Master node boots and runs cluster-init scripts:
        ↓
    ├─ 01-initialize-pbs.sh (qmgr commands)
    └─ 02-initialize-queues.sh (create workq, htcq)
        ↓
Complete! PBS master configured, azpbs installed on container
        ↓
azpbs monitors PBS queue and scales nodes via CycleCloud API
```

**Key Point**: PBS initialization (scripts that require `qmgr` commands) now run on the PBS master node via cluster-init, NOT on the CycleCloud container.

---

## 🎯 Summary Table

| File | Type | Purpose | Runs On | Status |
|------|------|---------|---------|--------|
| `install.sh` | Shell | Install azpbs + deps | CycleCloud container | ✅ Active |
| `generate_autoscale_json.sh` | Shell | Generate config | CycleCloud container | ✅ Active |
| `autoscale_hook.py` | Python | Periodic autoscale trigger | CycleCloud container | ✅ Active |
| `server_dyn_res_wrapper.sh` | Shell | Cache dynamic resources | CycleCloud container | ✅ Active (optional) |
| `logging.conf` | Config | Logging setup | CycleCloud container | ✅ Active |
| `packages/*` | Python | Dependencies | CycleCloud container | ✅ Active |
| `bootstrap_pbspro.sh` | Shell | Old orchestrator | N/A | ⚠️ Deprecated |
| `initialize_pbs.sh` | Shell | PBS server config | **PBS master (via cluster-init)** | ⚠️ Moved |
| `initialize_default_queues.sh` | Shell | Create queues | **PBS master (via cluster-init)** | ⚠️ Moved |

---

## 🔍 What Gets Installed Where

### On CycleCloud Container (after bootstrap workflow)

```
/opt/cycle/pbspro/
├── venv/                          # Python virtualenv
│   ├── bin/
│   │   └── azpbs                  # Main CLI command
│   └── lib/python3.x/site-packages/
│       ├── pbspro/                # azpbs package
│       ├── hpc/                   # scalelib
│       └── (all dependencies)
├── autoscale.json                 # 🎯 Main config file
├── autoscale_hook.py              # Hook script (not installed as PBS hook)
├── logging.conf                   # Logging setup
├── scalelib.lock                  # Prevents concurrent runs
└── backups/                       # autoscale.json backups

/root/bin/
└── azpbs -> /opt/cycle/pbspro/venv/bin/azpbs  # Symlink
```

### On PBS Master Node (after cluster-init)

```
/var/log/
└── cloud-init-output.log          # Cluster-init execution logs

PBS Configuration (via qmgr):
- Custom resources: slot_type, vm_size, nodearray, ngpus, group_id, etc.
- Queues: workq (MPI), htcq (HTC)
- Server settings: scheduler_iteration=15, node_group_enable=true
```

**Note**: The `autoscale_hook.py` is copied to the container but is NOT installed as an actual PBS hook because PBS runs on the master node, not the container. The autoscale logic runs via `azpbs` commands triggered by external mechanisms.

---

**Active files are used by the "Configure CycleCloud Autoscale" workflow!** ✅  
**Deprecated files are kept for reference but not used by workflows.** ⚠️

