# Workflow Automation Guide

## 🚀 Automated Deployment - 2 Simple Steps

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflows                              │
└─────────────────────────────────────────────────────────────────────────┘

         STEP 1                              STEP 2
┌──────────────────────┐         ┌──────────────────────────────┐
│   Deploy CycleCloud  │         │  Create PBS Cluster +        │
│   (Private Network)  │────────▶│  Configure Autoscale         │
│                      │         │  (Combined Workflow)         │
└──────────────────────┘         └──────────────────────────────┘
           │                                    │
           │                                    │
           ▼                                    ▼
┌──────────────────────┐         ┌──────────────────────────────┐
│ Azure Container      │         │ Single workflow does:        │
│ Instance with        │         │ 1. Upload cluster-init       │
│ CycleCloud           │         │ 2. Create PBS cluster        │
│                      │         │ 3. Start master node         │
│ - Private IP only    │         │ 4. Install azpbs autoscaler  │
│ - Deployed in VNet   │         │ 5. Generate autoscale config │
│ - Accessible via VPN │         │                              │
└──────────────────────┘         └──────────┬───────────────────┘
     ~10-15 min                              │
                                             │
                                             ▼
                              ┌──────────────────────────────┐
                              │ PBS Master Node              │
                              │ - Private IP only            │
                              │ - Runs cluster-init scripts: │
                              │   • 01-initialize-pbs.sh     │
                              │   • 02-initialize-queues.sh  │
                              │ - PBS fully configured       │
                              │ - Autoscale integrated       │
                              └──────────────────────────────┘
                                        ~20 min
```

## Workflow Details

### Workflow 1: Deploy CycleCloud
**File**: `Workflow-1-Deploy-CycleCloud.yaml`  
**Duration**: ~10-15 minutes  

**What it does**:
- ✅ Validates VNet configuration (REQUIRED - fails if not set)
- ✅ Discovers latest CycleCloud image from Microsoft Container Registry
- ✅ Deploys Azure Container Instance with **private networking only**
- ✅ Validates container health and CycleCloud initialization
- ✅ Generates access credentials artifact

**Required GitHub Variables**:
- `VIRTUAL_NETWORK_NAME` - VNet name
- `VIRTUAL_NETWORK_RESOURCE_GROUP_NAME` - VNet resource group
- `VIRTUAL_NETWORK_SUBNET_NAME` - Subnet name
- `RESOURCE_GROUP` - Deployment target resource group
- `AZURE_REGION` - Azure region

**Required GitHub Secrets**:
- `AZURE_CREDENTIALS` - Service principal credentials
- `CYCLECLOUD_ADMIN_USERNAME` - CycleCloud admin user
- `CYCLECLOUD_ADMIN_PASSWORD` - CycleCloud admin password

**Outputs**:
- CycleCloud web UI: `http://<PRIVATE_IP>:8080` (accessible via VPN/Bastion only)
- Container running and ready for cluster creation
- Access instructions artifact

**Security Note**: 
- ❌ No public IP assigned to container
- ✅ Container deployed in private subnet
- ✅ Access requires VPN, Azure Bastion, or Jump Box

---

### Workflow 2: Create PBS Pro Cluster
**File**: `Workflow-2-Create-PBSpro-Cluster.yaml`  
**Duration**: ~20 minutes (includes autoscale setup)  

**What it does** (combined workflow):

#### Cluster Creation:
- ✅ Initializes CycleCloud CLI with admin credentials
- ✅ Uploads `cluster-init/pbspro-autoscale` project to CycleCloud
- ✅ Loads cluster template from `cluster-init/cluster-templates/pbspro-cluster.txt`
- ✅ Generates cluster parameters with your VM sizes and limits
- ✅ Creates PBS Pro cluster with 3 node arrays:
  - **Master**: Scheduler and submission node
  - **Execute**: MPI/tightly-coupled workloads
  - **HTC**: Embarrassingly parallel workloads
- ✅ Starts master node automatically (optional)
- ✅ Master node runs cluster-init scripts during boot:
  - `01-initialize-pbs.sh` - PBS server configuration
  - `02-initialize-queues.sh` - Queue creation (workq, htcq)

#### Autoscale Configuration:
- ✅ Packages CycleCloud autoscale components:
  - `install.sh` - Installs azpbs Python package
  - `generate_autoscale_json.sh` - Creates autoscale config
  - `autoscale_hook.py` - PBS hook script
  - `server_dyn_res_wrapper.sh` - Dynamic resources
  - `logging.conf` - Logging configuration
  - `packages/` - Python dependencies
- ✅ Uploads package to CycleCloud container
- ✅ Installs `azpbs` CLI and Python dependencies in virtualenv
- ✅ Generates `autoscale.json` configuration file
- ✅ Validates connection to CycleCloud and PBS cluster

**Required Inputs**:
- `subnet_id` - **REQUIRED** - Azure subnet resource ID
- `cluster_name` - Name for PBS cluster
- `master_vm_size` - VM size for master node (default: Standard_D4s_v3)
- `execute_vm_size` - VM size for execute nodes (default: Standard_F4s_v2)
- `max_execute_nodes` - Max execute nodes (default: 10)
- `htc_vm_size` - VM size for HTC nodes (default: Standard_F2s_v2)
- `max_htc_nodes` - Max HTC nodes (default: 100)
- `auto_start_master` - Auto-start master (default: true)
- `ignore_queues` - Comma-separated queues to ignore (optional)

**Outputs**:
- PBS cluster visible in CycleCloud UI
- Master node with PBS fully configured
- `azpbs` autoscaler installed and configured
- Cluster access instructions artifact (includes cluster-info.txt, autoscale.json)

**Security Note**:
- ❌ No public IPs on any nodes (master, execute, HTC)
- ✅ All nodes deployed in private subnet
- ✅ SSH access requires VPN, Bastion, or Jump Box

**No manual steps required!** 🎉

---

## Total Time: ~30 minutes

From zero to production HPC cluster, fully automated with private networking!

## What You Get

```
┌─────────────────────────────────────────────────────────────────┐
│              Your Private HPC Environment                        │
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │ CycleCloud   │         │  PBS Master  │                     │
│  │  Web UI      │◀───────▶│    Node      │                     │
│  │ (Container)  │   API   │ (Private IP) │                     │
│  │ Private IP   │         │              │                     │
│  │              │         │ - PBS Server │                     │
│  │ - azpbs      │         │ - Queues     │                     │
│  │   autoscaler │         │   (workq,    │                     │
│  │              │         │    htcq)     │                     │
│  └──────────────┘         └──────┬───────┘                     │
│         │                         │                             │
│         │                         │                             │
│         │                         │ Jobs trigger                │
│         │                         │ autoscale via               │
│         │                         │ azpbs hook                  │
│         │                         │                             │
│         │              ┌──────────▼──────────┐                 │
│         └─────────────▶│  Azure CycleCloud   │                 │
│                        │   Orchestration     │                 │
│                        └──────────┬──────────┘                 │
│                                   │                             │
│                                   ▼                             │
│                        ┌─────────────────────┐                 │
│                        │   Compute Nodes     │                 │
│                        │  (Auto-scaling)     │                 │
│                        │   Private IPs       │                 │
│                        │                     │                 │
│                        │  [Execute] [HTC]    │                 │
│                        │   Scale 0-100       │                 │
│                        └─────────────────────┘                 │
│                                                                 │
│  Access via: VPN Gateway | Azure Bastion | Jump Box            │
└─────────────────────────────────────────────────────────────────┘

Key Architecture Points:
- ✅ All components use private networking (no public IPs)
- ✅ CycleCloud Container (ACI): Orchestration + azpbs autoscaler
- ✅ PBS Master (VM): PBS scheduler + queues (configured via cluster-init)
- ✅ azpbs: Monitors PBS queue, requests nodes from CycleCloud API
- ✅ Cluster-init: Auto-configures PBS during master node boot
- ✅ Access: Requires VPN, Bastion, or Jump Box
```

## Usage Comparison

### ❌ Old Way (v1.0 - 3 workflows)
1. Deploy CycleCloud container (Workflow 1)
2. Wait ~10 minutes
3. Run Bootstrap workflow (Workflow 2)
4. Wait ~5 minutes
5. Run Create Cluster workflow (Workflow 3)
6. Wait ~20 minutes
7. Master node configures itself via cluster-init
8. Done!

**Time**: ~35 minutes + 3 manual workflow runs  
**Error prone**: Easy to forget bootstrap step

### ✅ New Way (v2.0 - 2 workflows)
1. Run "Workflow 1: Deploy CycleCloud"
2. Wait ~10-15 minutes
3. Run "Workflow 2: Create PBS Pro Cluster"
   - Uploads cluster-init project
   - Creates cluster
   - Starts master (auto-configures PBS)
   - Installs autoscale on container
4. Done!

**Time**: ~30 minutes, 2 manual workflow runs  
**Reliable**: Bootstrap happens automatically, can't be missed

## Configuration Options

### Workflow 1: Deploy CycleCloud
**Customizable parameters**:
- `environment` - Target resource group environment
- `container_instance_name` - Container name (default: cyclecloud-mcr)
- `cyclecloud_version` - CycleCloud version (default: latest)
- `deployment_mode` - Deployment mode (passive/update/forced)
- `container_cpu_cores` - CPU allocation (default: 2)
- `container_memory_gb` - Memory allocation (default: 4)

**Note**: VNet configuration is set via repository variables (not workflow inputs)

### Workflow 2: Create PBS Pro Cluster
**Customizable parameters**:
- `cluster_name` - PBS cluster name
- `master_vm_size` - Master VM size (default: Standard_D4s_v3)
- `execute_vm_size` - Execute VM size (default: Standard_F4s_v2)
- `max_execute_nodes` - Max execute nodes (default: 10)
- `htc_vm_size` - HTC VM size (default: Standard_F2s_v2)
- `max_htc_nodes` - Max HTC nodes (default: 100)
- `subnet_id` - **REQUIRED** - Subnet resource ID
- `auto_start_master` - Auto-start master (default: true)
- `ignore_queues` - Queues to ignore in autoscale (optional)
- `cyclecloud_url` - CycleCloud URL (default: http://127.0.0.1:8080)

### Template Customization
For advanced customization, edit:
- `cluster-init/cluster-templates/pbspro-cluster.txt` - Cluster infrastructure
- `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/*.sh` - PBS config

See `cluster-init/cluster-templates/README.md` for detailed customization guide.

## Artifacts Generated

Each workflow produces downloadable artifacts:

### Workflow 1: Deploy CycleCloud
**Artifact**: `cyclecloud-mcr-<environment>-<run_number>`  
**Contents**:
- Access details
- Private IP address
- Connection information
- VNet configuration used

### Workflow 2: Create PBS Pro Cluster
**Artifact**: `pbspro-cluster-<cluster_name>-<run_number>`  
**Contents**:
- `cluster-access.md` - Detailed access instructions
- `cluster-info.txt` - Cluster configuration details
- `autoscale.json` - Autoscale configuration (if captured)

All artifacts retained for 30 days.

## Idempotency and Re-running

### Workflow 1: Deploy CycleCloud
**Idempotency**: Uses deployment modes
- `passive` - Skip if exists
- `update` - Update if exists
- `forced` - Replace existing

**Can be re-run**: Yes, choose appropriate deployment mode

### Workflow 2: Create PBS Pro Cluster
**Idempotency**: Partial
- Cluster creation: Fails if cluster name already exists
- Autoscale installation: Can be re-run to update configuration

**To re-run**: Delete cluster first via CycleCloud CLI or UI:
```bash
# Via Azure CLI (from CycleCloud container)
az container exec \
  --resource-group <RG> \
  --name cyclecloud-mcr \
  --exec-command "/bin/bash -c 'cyclecloud delete_cluster <CLUSTER_NAME>'"
```

Then run Workflow 2 again.

## Advanced: Workflow Automation

### Sequential Workflow Execution

You can automate running both workflows sequentially using GitHub CLI:

```bash
#!/bin/bash
set -euo pipefail

# Step 1: Deploy CycleCloud
echo "Deploying CycleCloud container..."
gh workflow run Workflow-1-Deploy-CycleCloud.yaml \
  -f environment="RG-BH_HPC_Cloud_Azure-NP-SUB-000005-EastUS-dev" \
  -f deployment_mode="passive" \
  -f container_instance_name="cyclecloud-mcr"

# Wait for completion (~15 minutes)
echo "Waiting for CycleCloud deployment..."
sleep 900

# Step 2: Create PBS cluster with autoscale
echo "Creating PBS Pro cluster..."
SUBNET_ID="/subscriptions/YOUR_SUB/resourceGroups/RG-Networking/providers/Microsoft.Network/virtualNetworks/hpc-vnet/subnets/cyclecloud-subnet"

gh workflow run Workflow-2-Create-PBSpro-Cluster.yaml \
  -f environment="RG-BH_HPC_Cloud_Azure-NP-SUB-000005-EastUS-dev" \
  -f container_instance_name="cyclecloud-mcr" \
  -f cluster_name="pbspro-cluster" \
  -f subnet_id="$SUBNET_ID" \
  -f master_vm_size="Standard_D4s_v3" \
  -f execute_vm_size="Standard_F4s_v2" \
  -f max_execute_nodes="10" \
  -f auto_start_master="true"

echo "Cluster creation started. Monitor in GitHub Actions."
echo "Cluster will be ready in ~20 minutes."
```

### Workflow Chaining (GitHub Actions)

You can also chain workflows using `workflow_run` triggers:

```yaml
# .github/workflows/auto-create-cluster.yaml
name: Auto Create Cluster After CycleCloud Deployment

on:
  workflow_run:
    workflows: ["Workflow 1 - Deploy CycleCloud"]
    types: [completed]
    
jobs:
  create-cluster:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Trigger cluster creation
        uses: actions/github-script@v6
        with:
          script: |
            await github.rest.actions.createWorkflowDispatch({
              owner: context.repo.owner,
              repo: context.repo.repo,
              workflow_id: 'Workflow-2-Create-PBSpro-Cluster.yaml',
              ref: 'main',
              inputs: {
                environment: 'RG-BH_HPC_Cloud_Azure-NP-SUB-000005-EastUS-dev',
                cluster_name: 'pbspro-cluster',
                subnet_id: 'YOUR_SUBNET_ID',
                auto_start_master: 'true'
              }
            })
```

## Monitoring

### GitHub Actions
- Real-time workflow logs
- Step-by-step progress
- Error messages and diagnostics
- Downloadable artifacts

### CycleCloud UI
Access via VPN/Bastion at `http://<PRIVATE_IP>:8080`:
- Cluster status and health
- Node provisioning progress
- Master node logs
- Autoscale activity

### Azure Portal
- Container instance health and logs
- VM provisioning status
- Network configuration
- Resource utilization

### Command Line
Check cluster status from CycleCloud container:
```bash
# Show cluster details
az container exec \
  --resource-group <RG> \
  --name cyclecloud-mcr \
  --exec-command "/bin/bash -c 'cyclecloud show_cluster pbspro-cluster'"

# Show cluster nodes
az container exec \
  --resource-group <RG> \
  --name cyclecloud-mcr \
  --exec-command "/bin/bash -c 'cyclecloud show_nodes -c pbspro-cluster'"
```

---

## Troubleshooting

### Workflow 1 Fails

**Error**: "Virtual network configuration is REQUIRED"  
**Fix**: Set GitHub repository variables:
- `VIRTUAL_NETWORK_NAME`
- `VIRTUAL_NETWORK_RESOURCE_GROUP_NAME`
- `VIRTUAL_NETWORK_SUBNET_NAME`

**Error**: "Virtual network 'X' not found"  
**Fix**: Verify VNet exists:
```bash
az network vnet show \
  --resource-group <VNet RG> \
  --name <VNet Name>
```

**Error**: "Insufficient permissions"  
**Fix**: Grant service principal network permissions:
```bash
az role assignment create \
  --assignee <SERVICE_PRINCIPAL_ID> \
  --role "Network Contributor" \
  --scope /subscriptions/<SUB>/resourceGroups/<VNet RG>
```

### Workflow 2 Fails

**Error**: "Subnet ID is required"  
**Fix**: Provide subnet ID in workflow inputs:
```bash
az network vnet subnet show \
  --resource-group <VNet RG> \
  --vnet-name <VNet Name> \
  --name <Subnet Name> \
  --query id -o tsv
```

**Error**: "CycleCloud container is not running"  
**Fix**: Verify Workflow 1 completed successfully and container is running

**Error**: "Cluster already exists"  
**Fix**: Delete existing cluster first:
```bash
az container exec \
  --resource-group <RG> \
  --name cyclecloud-mcr \
  --exec-command "/bin/bash -c 'cyclecloud delete_cluster <CLUSTER_NAME>'"
```

### Can't Access Resources

**Symptom**: Can't browse to CycleCloud UI or SSH to master  
**Cause**: Not connected to VNet  
**Fix**: 
- Connect to VPN gateway
- Use Azure Bastion
- SSH via Jump Box

See `NETWORK_SETUP.md` for detailed access configuration.

---

**You now have a streamlined, 2-workflow automated HPC deployment system with enterprise-grade security!** 🎉
