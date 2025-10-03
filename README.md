# CycleCloud PBS Pro Automation for Azure Container Instances

Fully automated GitHub Actions workflows to deploy Azure CycleCloud with PBS Pro scheduler on Azure Container Instances using **private networking**.

## 🚀 Quick Start

**Two simple workflows** deploy a complete HPC environment in ~30 minutes:

1. **Workflow 1**: Deploy CycleCloud container (private networking)
2. **Workflow 2**: Create PBS cluster + configure autoscale (fully automated)

## Overview

**Streamlined 2-workflow deployment**:

1. **Deploy CycleCloud** - Deploys CycleCloud container in private VNet
2. **Create PBS Cluster** - Creates cluster, starts master, installs autoscale (all automatic)

### What's New in v2.0

- ✅ **Simplified**: 2 workflows instead of 3
- ✅ **Secure**: Private networking only (no public IPs)
- ✅ **Automated**: Bootstrap integrated into cluster creation
- ✅ **Editable**: Cluster templates and PBS configs in repository files

See `CHANGELOG.md` for migration details.

## Prerequisites

### Azure Resources
- Azure subscription with appropriate permissions
- Resource group for deployment
- **Virtual network and subnet** (REQUIRED for private networking)

### GitHub Repository Configuration

#### Required Secrets
- `AZURE_CREDENTIALS` - Azure service principal credentials (JSON format)
- `CYCLECLOUD_ADMIN_USERNAME` - CycleCloud admin username
- `CYCLECLOUD_ADMIN_PASSWORD` - CycleCloud admin password

#### Required Variables
- `RESOURCE_GROUP` - Azure resource group name
- `AZURE_REGION` - Azure region (e.g., eastus)
- **`VIRTUAL_NETWORK_NAME`** - VNet name (REQUIRED)
- **`VIRTUAL_NETWORK_RESOURCE_GROUP_NAME`** - VNet resource group (REQUIRED)
- **`VIRTUAL_NETWORK_SUBNET_NAME`** - Subnet name (REQUIRED)

### Network Access Setup

Since all resources use **private IPs only**, you must set up one of these access methods:

- **VPN Gateway** - Connect to Azure VPN to access private resources
- **Azure Bastion** - SSH access via Azure Portal
- **Jump Box** - VM with public IP in same VNet

See `NETWORK_SETUP.md` for detailed configuration.

### Azure Service Principal

Create a service principal with these permissions:
```bash
az ad sp create-for-rbac \
  --name "github-cyclecloud-deployment" \
  --role "Contributor" \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP" \
  --sdk-auth
```

Required permissions:
- `Microsoft.ContainerInstance/containerGroups/*`
- `Microsoft.Network/virtualNetworks/read`
- `Microsoft.Network/virtualNetworks/subnets/read`
- `Microsoft.Network/virtualNetworks/subnets/join/action`

## Workflow 1: Deploy CycleCloud

**File**: `Workflow-1-Deploy-CycleCloud.yaml`  
**Duration**: ~10-15 minutes

Deploys Azure CycleCloud as an Azure Container Instance with **private networking only**.

### Features
- Semantic version tag discovery and selection
- **Private VNet networking** (REQUIRED)
- Deployment modes: `passive`, `update`, or `forced`
- Automatic container health validation
- Artifact generation with access details

### Usage

1. Go to **Actions** → **Workflow 1 - Deploy CycleCloud**
2. Click **Run workflow**
3. Configure:
   - **Environment**: Select target resource group
   - **Image tag**: Specific version or `latest`
   - **Container name**: Azure Container Instance name
   - **CPU/Memory**: Resource allocation
   - **Deployment mode**:
     - `passive`: Skip if container is already running
     - `update`: Replace if a newer version exists
     - `forced`: Always recreate

### Outputs
- Container deployment status
- **Private IP** address (accessible via VPN/Bastion only)
- CycleCloud web interface URL: `http://<PRIVATE_IP>:8080`
- Available image tags artifact

**Security**: ❌ No public IP assigned - VPN/Bastion required for access

## Workflow 2: Create PBS Pro Cluster

**File**: `Workflow-2-Create-PBSpro-Cluster.yaml`  
**Duration**: ~20 minutes

**Combined workflow** that creates PBS cluster AND configures autoscale in one step.

### Features
- Automated cluster creation (no manual UI steps)
- Configurable VM sizes for master, execute, and HTC nodes
- Automatic master node startup
- **Private networking only** (all nodes use private IPs)
- **Integrated autoscale setup** (azpbs installed automatically)
- Node array configuration for different workload types
- Cluster template loaded from `cluster-init/cluster-templates/pbspro-cluster.txt`

### Usage

**Prerequisites**: CycleCloud container must be running (deployed via Workflow 1)

1. Go to **Actions** → **Workflow 2 - Create PBS Pro Cluster**
2. Click **Run workflow**
3. Configure:
   - **Environment**: Same as deployment workflow
   - **Container name**: CycleCloud container instance name
   - **Cluster name**: Name for your PBS Pro cluster (e.g., `pbspro-cluster`)
   - **Subnet ID**: **REQUIRED** - Azure subnet resource ID
   - **Image name**: OS image (default: `almalinux8`, or custom image ID)
   - **Master VM size**: Azure VM size for PBS master (default: `Standard_D4s_v3`)
   - **Execute VM size**: VM size for MPI workloads (default: `Standard_F4s_v2`)
   - **Max execute nodes**: Maximum execute nodes (default: 10)
   - **HTC VM size**: VM size for HTC workloads (default: `Standard_F2s_v2`)
   - **Max HTC nodes**: Maximum HTC nodes (default: 100)
   - **Auto start master**: Whether to start master automatically (default: true)
   - **Ignore queues**: Comma-separated queues to exclude from autoscale (optional)

### What It Does

This **combined workflow** performs all setup in one run:

#### Cluster Creation:
1. Validates the CycleCloud container is running
2. Initializes the CycleCloud CLI with admin credentials
3. Uploads the `pbspro-autoscale` cluster-init project
4. Loads cluster template from `cluster-init/cluster-templates/pbspro-cluster.txt`
5. Generates cluster parameters based on inputs
6. Imports the cluster into CycleCloud
7. Starts the master node automatically

#### Master Node Configuration (via cluster-init):
8. Master node runs initialization scripts during boot:
   - `01-initialize-pbs.sh` - Configures PBS server settings
   - `02-initialize-queues.sh` - Creates workq and htcq queues

#### Autoscale Integration:
9. Packages autoscale components (azpbs)
10. Uploads and installs `azpbs` on CycleCloud container
11. Generates `autoscale.json` configuration
12. Validates connection to PBS cluster

### Outputs
- Cluster creation status
- Access instructions artifact (includes cluster-info.txt, autoscale.json)
- Master node ready in ~10-15 minutes with PBS fully configured
- Autoscale active and ready to scale nodes

**Security**: ❌ No public IPs on any nodes - VPN/Bastion required for SSH access

**Fully automated - no manual steps!** 🎉

## Directory Structure

### `cluster-init/` - Cluster Configuration
All cluster configuration files grouped together:

#### `cluster-init/cluster-templates/` - User-Editable Cluster Templates
Cluster infrastructure templates:

| File | Purpose |
|------|---------|
| `pbspro-cluster.txt` | CycleCloud cluster template (VM sizes, autoscale limits, networking) |
| `README.md` | Customization guide for cluster templates |

**Users can edit these files** to customize VM sizes, add GPU nodes, modify autoscale limits, etc.

#### `cluster-init/pbspro-autoscale/` - PBS Master Node Configuration
CycleCloud cluster-init project that runs on the PBS master node during boot:

| File | Purpose | Runs On |
|------|---------|---------|
| `project.ini` | Cluster-init project definition | PBS master node |
| `specs/default/cluster-init/scripts/01-initialize-pbs.sh` | Configures PBS server settings and custom resources | PBS master node |
| `specs/default/cluster-init/scripts/02-initialize-queues.sh` | Creates `workq` (MPI) and `htcq` (HTC) queues | PBS master node |

**Users can edit these scripts** to customize PBS configuration, add custom queues, modify resources, etc.

### `cyclecloud-pbspro/` - CycleCloud Container Autoscale Files
Scripts that run on the CycleCloud container (Azure Container Instance):

| Script | Purpose | Runs On |
|--------|---------|---------|
| `install.sh` | Installs azpbs Python package and dependencies in virtualenv | CycleCloud container |
| `generate_autoscale_json.sh` | Generates autoscale configuration connecting PBS to CycleCloud | CycleCloud container |
| `autoscale_hook.py` | PBS hook that triggers azpbs autoscale periodically | CycleCloud container |
| `server_dyn_res_wrapper.sh` | Helper for PBS dynamic resource scripts | CycleCloud container |
| `logging.conf` | Logging configuration for azpbs | CycleCloud container |
| `packages/` | Python wheel files for offline installation | CycleCloud container |

**Used by Workflow 2** during autoscale integration step.

### `Legacy/` - Deprecated Files
Old workflow files and scripts that have been replaced:

| File | Status |
|------|--------|
| `bootstrap-pbspro.yaml` | Deprecated - merged into Workflow 2 |
| `create-pbspro-cluster.yaml` | Deprecated - merged into Workflow 2 |
| Other legacy files | See `Legacy/README.md` for details |

## Typical Workflow

### Step 1: Deploy CycleCloud
```bash
# Run Workflow 1 with private networking
gh workflow run Workflow-1-Deploy-CycleCloud.yaml \
  -f resource_group_name="cyclecloud-rg" \
  -f location="eastus" \
  -f vnet_name="my-hpc-vnet" \
  -f subnet_name="cyclecloud-subnet" \
  -f cyclecloud_username="admin" \
  -f cyclecloud_password="MySecurePass123!" \
  -f cyclecloud_ssh_public_key="ssh-rsa AAAAB3..."
```

**Result:**
- CycleCloud container with private IP only
- Access via VPN/Bastion to `https://10.0.1.4` (private IP)
- Takes ~5 minutes

### Step 2: Create PBS Cluster with Autoscale
```bash
# Run Workflow 2 (creates cluster AND configures autoscale)
gh workflow run Workflow-2-Create-PBSpro-Cluster.yaml \
  -f cyclecloud_url="https://10.0.1.4" \
  -f cyclecloud_username="admin" \
  -f cyclecloud_password="MySecurePass123!" \
  -f cluster_name="pbspro-cluster" \
  -f resource_group_name="cyclecloud-rg" \
  -f location="eastus" \
  -f vnet_name="my-hpc-vnet" \
  -f subnet_id="/subscriptions/.../subnets/compute-subnet" \
  -f master_vm_size="Standard_D4s_v3" \
  -f max_core_count="1000"
```

**This workflow automatically:**
1. ✅ Creates PBS Pro cluster in CycleCloud
2. ✅ Starts master node (private IP only)
3. ✅ Installs azpbs autoscale package
4. ✅ Generates autoscale configuration
5. ✅ Configures PBS server with autoscale hook

**Result:** Production-ready PBS cluster with working autoscale (~25 minutes total)

### Step 3: Submit Jobs
```bash
# SSH to PBS master node (via VPN/Bastion)
ssh cyclecloud@10.0.2.4

# Submit a job
qsub -l select=10:ncpus=4:slot_type=execute my_script.sh

# Watch nodes scale automatically
watch qstat -a
```

Nodes will scale up automatically based on job requirements, and scale down after 5 minutes of idle time.

---

## Custom Images

### Using Marketplace Images (Default)

The workflow defaults to `almalinux8` but supports multiple marketplace images:

**Available options:**
- `almalinux8` - AlmaLinux 8 (default, CentOS replacement)
- `cycle.image.ubuntu22` - Ubuntu 22.04 LTS
- `cycle.image.ubuntu20` - Ubuntu 20.04 LTS  
- `cycle.image.centos7` - CentOS 7

**Usage:**
```bash
gh workflow run Workflow-2-Create-PBSpro-Cluster.yaml \
  -f image_name="cycle.image.ubuntu22" \
  ...
```

### Using Custom Azure Images

For pre-baked images with PBS Pro or custom software:

**1. Create Custom Image in Azure:**
```bash
# Example: Create image from existing VM
az image create \
  --resource-group my-images-rg \
  --name pbs-pro-custom-v1 \
  --source /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/my-vm
```

**2. Use in Workflow:**
```bash
gh workflow run Workflow-2-Create-PBSpro-Cluster.yaml \
  -f image_name="/subscriptions/{sub-id}/resourceGroups/my-images-rg/providers/Microsoft.Compute/images/pbs-pro-custom-v1" \
  ...
```

**3. Or Set as GitHub Variable:**
```bash
# Set once, use always
gh variable set CUSTOM_IMAGE_ID \
  --body "/subscriptions/{sub-id}/resourceGroups/my-images-rg/providers/Microsoft.Compute/images/pbs-pro-custom-v1"
```

Then reference in workflow:
```yaml
image_name: ${{ vars.CUSTOM_IMAGE_ID }}
```

**Benefits of Custom Images:**
- ✅ Faster node startup (PBS Pro pre-installed)
- ✅ Consistent environment across clusters
- ✅ Pre-configured libraries and tools
- ✅ Reduced cluster-init complexity

---

## Autoscale Behavior

Once configured, the PBS Pro autoscale integration:
- Monitors PBS job queue every 15 seconds (via hook) or minute (via cron)
- Requests nodes from CycleCloud based on job requirements
- Scales down idle nodes after 5 minutes (default)
- Respects placement groups for MPI jobs
- Maps PBS resources to Azure VM sizes

### Custom Resources

The integration maps these custom PBS resources:

| PBS Resource | CycleCloud Node Property |
|--------------|--------------------------|
| `slot_type` | Node array name |
| `vm_size` | Azure VM size |
| `ncpus` | CPU count |
| `ngpus` | GPU count |
| `mem` | Memory |
| `group_id` | Placement group |
| `ungrouped` | Whether node can be in any group |

## Troubleshooting

### Cannot access CycleCloud web UI
**Problem**: CycleCloud uses private IP only  
**Solution**: Set up VPN or Azure Bastion to access the VNet. See [NETWORK_SETUP.md](NETWORK_SETUP.md) for detailed instructions.

### Container not found
```
Error: Azure Container Instance 'cyclecloud-mcr' not found
```
**Solution**: Run Workflow 1 (Deploy CycleCloud) first

### Workflow 2 fails with VNet error
```
Error: VNet 'my-hpc-vnet' not found in resource group 'cyclecloud-rg'
```
**Solution**: 
- VNet must exist BEFORE running Workflow 1
- Create VNet in Azure Portal or use ARM/Bicep template
- Verify VNet name and resource group match exactly

### Authentication failed
```
Error: Both CYCLECLOUD_ADMIN_USERNAME and CYCLECLOUD_ADMIN_PASSWORD secrets are required
```
**Solution**: Add secrets to GitHub repository settings (Settings → Secrets and variables → Actions)

### Subnet ID format
**Problem**: Workflow 2 requires `subnet_id` parameter  
**Solution**: Use full Azure resource ID format:
```
/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/virtualNetworks/{vnet-name}/subnets/{subnet-name}
```

Get it from Azure Portal (VNet → Subnets → Properties) or Azure CLI:
```bash
az network vnet subnet show \
  --resource-group cyclecloud-rg \
  --vnet-name my-hpc-vnet \
  --name compute-subnet \
  --query id -o tsv
```

### PBS commands not found on CycleCloud container
**Problem**: PBS qmgr commands fail when running on CycleCloud container  
**Solution**: This is expected! PBS runs on the cluster **master node** (VM), not the CycleCloud container (ACI). PBS initialization happens automatically via cluster-init during master node boot.

### Autoscale not working
1. **Verify cluster-init ran on master**: SSH to master and check `/var/log/cloud-init-output.log`
2. **Check azpbs installation**: On CycleCloud container, check `/opt/cycle/pbspro/venv/bin/azpbs`
3. **Verify autoscale.json**: On master node, check `/opt/cycle/jetpack/config/autoscale.json`
4. **Check PBS hook**: `qmgr -c "print hook autoscale"`
5. **Review logs**: Check `/var/spool/pbs/server_logs/` on master node

### Jobs not scaling nodes
**Problem**: Jobs stay queued but no nodes start  
**Solution**: 
- Check resource requests match available VM sizes: `qstat -f <job-id>`
- Verify `slot_type` matches node array name in cluster template
- Check Azure quota limits in subscription
- Review CycleCloud logs: Settings → Health Checks

---
---

## Architecture: Private Networking Flow

### Component Layout (Private VNet)
```
┌─────────────────────────────────────────────────────────────┐
│  Azure VNet (10.0.0.0/16)                                   │
│                                                              │
│  ┌─────────────────────┐         ┌─────────────────────┐  │
│  │ CycleCloud Subnet   │         │ Compute Subnet      │  │
│  │ (10.0.1.0/24)       │         │ (10.0.2.0/24)       │  │
│  │                     │         │                     │  │
│  │ ┌─────────────────┐ │         │ ┌─────────────────┐ │  │
│  │ │  CycleCloud     │ │         │ │  PBS Master     │ │  │
│  │ │  Container      │◀┼─────────┼▶│  Node (VM)      │ │  │
│  │ │  (ACI)          │ │   API   │ │  10.0.2.4       │ │  │
│  │ │  10.0.1.4       │ │         │ │                 │ │  │
│  │ │                 │ │         │ │  - pbs_server   │ │  │
│  │ │  - Web UI       │ │         │ │  - Job queue    │ │  │
│  │ │  - azpbs        │ │         │ │  - Cluster-init │ │  │
│  │ │  - Autoscaler   │ │         │ └─────────────────┘ │  │
│  │ └─────────────────┘ │         │                     │  │
│  │                     │         │ ┌─────────────────┐ │  │
│  │                     │         │ │  Compute Nodes  │ │  │
│  │                     │         │ │  (Auto-scaled)  │ │  │
│  │                     │         │ │  10.0.2.5+      │ │  │
│  │                     │         │ └─────────────────┘ │  │
│  └─────────────────────┘         └─────────────────────┘  │
│                                                              │
│  Access via: VPN Gateway or Azure Bastion                   │
└─────────────────────────────────────────────────────────────┘
```

### How Components Communicate
1. **CycleCloud Container** (ACI):
   - Orchestrates cluster lifecycle via CycleCloud API
   - Hosts autoscale configuration and azpbs package
   - Web UI accessible at `https://10.0.1.4` (private IP)

2. **PBS Master Node** (VM):
   - Runs PBS Professional scheduler
   - Executes cluster-init scripts at boot (configure PBS, create queues)
   - Communicates with CycleCloud API to request/release nodes

3. **Compute Nodes** (VMs):
   - Auto-scaled by PBS based on job queue
   - Started/stopped by CycleCloud orchestrator
   - Join PBS cluster automatically via cluster-init

### Workflow Execution Flow
```
Workflow 1              Workflow 2
    │                       │
    ▼                       ▼
┌─────────┐           ┌─────────┐
│ Deploy  │           │ Create  │
│ ACI     │──────────▶│ Cluster │
│         │  outputs  │         │
│ 10.0.1.4│  URL      │ 10.0.2.4│
└─────────┘           └─────────┘
                            │
                            ├─ Upload cluster-init
                            ├─ Create cluster
                            ├─ Start master
                            ├─ Install azpbs
                            └─ Generate autoscale config
                                    │
                                    ▼
                              ┌──────────┐
                              │ Ready to │
                              │ Submit   │
                              │ Jobs!    │
                              └──────────┘
```

### Why This Architecture?
- **Security**: No public IPs, all communication via private VNet
- **Simplicity**: 2 workflows instead of 3 (consolidated autoscale setup)
- **Flexibility**: Edit cluster templates and cluster-init without modifying workflows
- **Production-ready**: Private networking is Azure best practice

---

## Azure Container Instance Considerations

### Persistence
- Container state is **not persistent** across restarts
- Autoscale configuration stored in container filesystem (regenerate if container recreated)
- CycleCloud database persisted if using Azure storage backend

### Networking
- **Private VNet**: REQUIRED in v2.0+ (recommended for production)
- **Public IP**: No longer supported (removed for security)
- **Firewall**: CycleCloud container needs outbound access to Azure APIs

### Resource Limits
- CPU: 2-4 cores recommended for CycleCloud container
- Memory: 8 GB recommended
- Scales vertically only (no autoscaling for ACI)

---

## Architecture: Container vs VM

### CycleCloud Container (Azure Container Instance)
**What runs here:**
- ✅ CycleCloud orchestration service (web UI + API)
- ✅ `azpbs` autoscaler Python package
- ✅ Autoscale configuration generation
- ❌ **NOT** PBS Pro scheduler (PBS runs on cluster VMs)

### PBS Master Node (Azure Virtual Machine)
**What runs here:**
- ✅ PBS Professional scheduler (`pbs_server`)
- ✅ PBS queue configuration (via cluster-init)
- ✅ PBS custom resources (via cluster-init)
- ✅ Job submission and management
- ✅ Communication with CycleCloud API for autoscaling

### How They Work Together
```
┌─────────────────┐         ┌─────────────────┐
│  CycleCloud     │         │  PBS Master     │
│  Container      │◀───────▶│  Node (VM)      │
│                 │  API    │                 │
│  - Web UI       │         │  - pbs_server   │
│  - azpbs        │         │  - Job queue    │
│  - Autoscaler   │         │  - Cluster-init │
└─────────────────┘         └─────────────────┘
        │                           │
        │                           │
        ▼                           ▼
   Orchestrates                Requests nodes
   cluster nodes               based on jobs
```

This separation is why:
- PBS initialization scripts run via **cluster-init** on the master node
- Autoscale installation runs on the **CycleCloud container**
- The two communicate via CycleCloud REST API

## Azure Container Instance Considerations

### Persistence
- Container state is **not persistent**
- Autoscale configuration stored in container filesystem
- CycleCloud database persisted if using Azure storage backend

### Networking
- Private VNet: Recommended for production
- Public IP: Convenient for development/testing
- Firewall: CycleCloud needs outbound access to Azure APIs

### Resource Limits
- CPU: 2-4 cores recommended for CycleCloud container
- Memory: 8 GB recommended
- Scales vertically only (no autoscaling for ACI)

---

## Related Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute quick start guide
- **[AUTOMATION.md](AUTOMATION.md)** - Detailed workflow documentation
- **[NETWORK_SETUP.md](NETWORK_SETUP.md)** - VPN and network access setup
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture deep dive
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and migration notes
- **[DOCS.md](DOCS.md)** - Documentation guide and navigation

## License

Scripts in `cyclecloud-pbspro/` are copyright Microsoft Corporation, licensed under the MIT License.

## Support

For issues with:
- **Workflows**: Open issue in this repository
- **Azure CycleCloud**: https://github.com/Azure/cyclecloud-pbspro
- **PBS Professional**: Contact PBS support or visit https://github.com/pbspro/pbspro
