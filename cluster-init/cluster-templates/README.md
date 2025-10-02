# Cluster Templates Directory

This directory contains **user-editable** CycleCloud cluster templates that define the infrastructure and configuration for PBS Pro clusters.

## 📝 Template Files

### [`pbspro-cluster.txt`](pbspro-cluster.txt)
**Purpose**: Defines the PBS Pro cluster with autoscaling support and **private networking only**

**Used by**: [`Workflow-2-Create-PBSpro-Cluster.yaml`](../../.github/workflows/Workflow-2-Create-PBSpro-Cluster.yaml)

**Networking**: All nodes use **private IPs only**. Access requires:
- Azure VPN Gateway
- Azure ExpressRoute
- Azure Bastion Host
- Jump box/bastion VM in the same VNet

## 🔧 How to Customize

### 1. Edit the Template File
```bash
# Open the template in your editor
code cluster-init/cluster-templates/pbspro-cluster.txt
```

### 2. Common Customizations

#### Change Default VM Sizes
```ini
[[[parameter MasterMachineType]]]
Label = Master VM Type
Description = VM type for PBS master (scheduler and submission node)
ParameterType = Cloud.MachineType
DefaultValue = Standard_D8s_v3  # Changed from D4s_v3 for more power
```

#### Adjust Autoscale Limits
```ini
[[[parameter MaxExecuteCoreCount]]]
Label = Max Execute Cores
Description = Maximum number of execute cores to start (MPI jobs)
DefaultValue = 500  # Changed from 100
Config.Plugin = pico.form.NumberTextBox
Config.MinValue = 1
Config.IntegerOnly = true
```

#### Add a GPU Node Array
```ini
[[nodearray gpu]]
MachineType = $GPUMachineType
MaxCoreCount = $MaxGPUCoreCount
Interruptible = $UseLowPrio
AdditionalClusterInitSpecs = $GPUClusterInitSpecs

    [[[configuration]]]
    
    [[[cluster-init cyclecloud/pbspro:execute]]]
    [[[cluster-init nvidia-drivers:execute]]]  # Your custom GPU driver installer
    
    [[[network-interface eth0]]]
    AssociatePublicIpAddress = false
```

Then add the parameters:
```ini
[[[parameter GPUMachineType]]]
Label = GPU VM Type
Description = VM type for GPU compute nodes
ParameterType = Cloud.MachineType
DefaultValue = Standard_NC6s_v3

[[[parameter MaxGPUCoreCount]]]
Label = Max GPU Cores
Description = Maximum number of GPU cores
DefaultValue = 24
Config.Plugin = pico.form.NumberTextBox
Config.MinValue = 1
Config.IntegerOnly = true
```

#### Enable Spot Instances by Default
```ini
[[[parameter UseLowPrio]]]
Label = Use Spot Instances
DefaultValue = true  # Changed from false for cost savings
ParameterType = Boolean
Config.Label = Use low-priority spot instances for cost savings
```

#### Add Custom Cluster-Init Specs
```ini
[[node master]]
MachineType = $MasterMachineType
AdditionalClusterInitSpecs = $MasterClusterInitSpecs

    [[[cluster-init cyclecloud/pbspro:master]]]
    [[[cluster-init pbspro-autoscale:default]]]
    Order = 20000
    
    [[[cluster-init custom-monitoring:master]]]  # Add your custom spec
    [[[cluster-init vault-integration:master]]]  # Add another spec
```

### 3. Commit Your Changes
```bash
git add cluster-init/cluster-templates/pbspro-cluster.txt
git commit -m "Customize PBS Pro cluster: increase max cores to 500"
git push
```

### 4. Run the Workflow
The workflow automatically reads this file - no workflow changes needed!

## 🎯 Template Variables

These variables are populated by the workflow from inputs and repository variables:

| Variable | Source | Example | Description |
|----------|--------|---------|-------------|
| `$Credentials` | Workflow default | `azure` | Azure service principal name |
| `$Region` | `vars.AZURE_REGION` | `eastus` | Azure region |
| `$SubnetId` | Workflow input (REQUIRED) | `/subscriptions/.../subnets/default` | Private subnet ID |
| `$MasterMachineType` | Workflow input | `Standard_D4s_v3` | Master VM SKU |
| `$ExecuteMachineType` | Workflow input | `Standard_F4s_v2` | Execute VM SKU |
| `$HTCMachineType` | Workflow input | `Standard_F2s_v2` | HTC VM SKU |
| `$MaxExecuteCoreCount` | Calculated from input | `100` | Max execute cores |
| `$MaxHTCCoreCount` | Calculated from input | `200` | Max HTC cores |
| `$Autoscale` | Fixed | `true` | Enable autoscaling |
| `$ReturnProxy` | Fixed | `true` | Use master as SSH proxy |
| `$UseLowPrio` | Workflow input | `false` | Use spot instances |

## 🔒 Private Networking

**All nodes in this template use private IPs only:**
- `AssociatePublicIpAddress = false` on all network interfaces
- `UsePublicNetwork = false` in node defaults
- Subnet ID is **required** (cannot deploy without VNet)

### Access Methods

Since nodes are private-only, you must use one of these access methods:

1. **Azure Bastion** (Recommended for security):
   ```bash
   # Connect via Azure Portal Bastion feature
   # Or use az CLI:
   az network bastion ssh \
     --name MyBastion \
     --resource-group MyRG \
     --target-resource-id /subscriptions/.../virtualMachines/pbspro-master \
     --auth-type ssh-key \
     --username cyclecloud \
     --ssh-key ~/.ssh/id_rsa
   ```

2. **VPN Gateway**:
   ```bash
   # Connect to Azure VPN first
   # Then SSH directly to private IP
   ssh cyclecloud@10.0.1.4
   ```

3. **Jump Box / Bastion VM**:
   ```bash
   # SSH to jump box in same VNet
   ssh -J jumpbox@public-ip cyclecloud@10.0.1.4
   
   # Or use SSH ProxyJump
   ssh -o ProxyJump=jumpbox@public-ip cyclecloud@10.0.1.4
   ```

4. **ExpressRoute** (for on-premises connectivity)

## 📚 CycleCloud Template Syntax Reference

### Node Types
- `[[node master]]` - Single master/scheduler node (non-scaling)
- `[[nodearray execute]]` - Auto-scaling worker nodes for MPI/tightly-coupled jobs
- `[[nodearray htc]]` - Auto-scaling nodes for embarrassingly parallel workloads

### Cluster-Init Specs
```ini
[[[cluster-init <project>:<role>]]]
Order = <number>  # Optional: execution order (higher = later)
```

**Built-in specs**:
- `cyclecloud/pbspro:master` - PBS Pro server installation
- `cyclecloud/pbspro:execute` - PBS Pro execution node setup
- `pbspro-autoscale:default` - Custom PBS configuration (from `cluster-init/` directory)

**Custom specs**:
- Create in `cluster-init/<project-name>/specs/<role>/` directory
- Reference as `<project-name>:<role>`

### Parameter Types
- `Cloud.MachineType` - Azure VM SKU dropdown (e.g., Standard_D4s_v3)
- `Cloud.Region` - Azure region selector
- `Azure.Subnet` - Subnet resource picker
- `Cloud.Credentials` - Azure service principal selector
- `Cloud.ClusterInitSpecs` - Cluster-init project selector
- `Boolean` - Checkbox (true/false)
- `String` - Text input
- `Number` - Integer input with validation

### Network Configuration
```ini
[[[network-interface eth0]]]
AssociatePublicIpAddress = false  # Private networking only
```

## 🔍 Validation

Test your template syntax before deploying:

```bash
# If you have CycleCloud CLI installed locally
cyclecloud validate_template cluster-init/cluster-templates/pbspro-cluster.txt

# Or let the workflow validate it
# The workflow will fail early with syntax errors
```

## 💡 Best Practices

1. **Keep defaults conservative** - Users can override via workflow inputs
2. **Document all custom parameters** - Add clear descriptions
3. **Test in dev environment first** - Use `RG-BH_HPC_Cloud_Azure-NP-SUB-000005-EastUS-dev`
4. **Version control everything** - Git tracks all changes automatically
5. **Use meaningful parameter names** - Makes UI clearer
6. **Add validation** - Use `Config.MinValue`, `Config.MaxValue`, `Required = true`
7. **Group related parameters** - Use `[[parameters]]` sections for organization
8. **Provide examples in descriptions** - Help users understand what to enter

## 🚨 What NOT to Change

### Do NOT make nodes public:
```ini
# DON'T DO THIS - violates security policy
[[[network-interface eth0]]]
AssociatePublicIpAddress = true  # ❌ NOT ALLOWED
```

### Do NOT remove subnet requirement:
```ini
# DON'T DO THIS
[[[parameter SubnetId]]]
Required = false  # ❌ Must be true
```

### Do NOT edit workflow-generated files:
- ❌ `/tmp/cluster-params.json` (generated at runtime)
- ❌ Embedded templates in workflow YAML (this file overrides them)

## 📖 Additional Documentation

- **Cluster-init scripts**: [`../cluster-init/README.md`](../cluster-init/README.md)
- **Architecture overview**: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- **Customization guide**: [`../CUSTOMIZATION_GUIDE.md`](../CUSTOMIZATION_GUIDE.md)
- **CycleCloud docs**: https://learn.microsoft.com/azure/cyclecloud/
- **PBS Pro docs**: https://help.altair.com/pbspro/

## 📊 Template Structure

```
cluster-init/cluster-templates/pbspro-cluster.txt
├── [cluster pbspro]              # Cluster definition
│   ├── [[node defaults]]         # Settings applied to all nodes
│   ├── [[node master]]           # PBS master/scheduler
│   ├── [[nodearray execute]]     # MPI compute nodes
│   └── [[nodearray htc]]         # HTC compute nodes
├── [parameters About]            # UI information
├── [parameters Required Settings] # Core configuration
│   ├── [[parameters Virtual Machines]]
│   ├── [[parameters Auto-Scaling]]
│   └── [[parameters Networking]]
└── [parameters Advanced Settings] # Optional configuration
    ├── [[parameters Azure Settings]]
    ├── [[parameters Software]]
    ├── [[parameters Advanced Networking]]
    └── [[parameters Node Health Checks]]
```

## 🎓 Example: Complete Custom GPU Node Array

```ini
# Add this to the cluster definition section
[[nodearray gpu]]
MachineType = $GPUMachineType
MaxCoreCount = $MaxGPUCoreCount
Interruptible = $GPUUseLowPrio
AdditionalClusterInitSpecs = $GPUClusterInitSpecs

    [[[configuration]]]
    # GPU-specific configuration
    pbs.slot_type = gpu
    
    [[[cluster-init cyclecloud/pbspro:execute]]]
    
    [[[cluster-init nvidia-drivers:execute]]]
    # Assumes you created cluster-init/nvidia-drivers/ project
    
    [[[network-interface eth0]]]
    AssociatePublicIpAddress = false

# Add these parameters to appropriate sections
[[[parameter GPUMachineType]]]
Label = GPU VM Type
Description = Azure VM type with NVIDIA GPUs (e.g., NC, ND, NV series)
ParameterType = Cloud.MachineType
DefaultValue = Standard_NC6s_v3
Config.Filter := Model in {"Standard_NC*", "Standard_ND*", "Standard_NV*"}

[[[parameter MaxGPUCoreCount]]]
Label = Max GPU Cores
Description = Maximum CPU cores for GPU nodes (not GPU count)
DefaultValue = 24
Config.Plugin = pico.form.NumberTextBox
Config.MinValue = 1
Config.MaxValue = 1000
Config.IntegerOnly = true

[[[parameter GPUUseLowPrio]]]
Label = GPU Spot Instances
DefaultValue = false
ParameterType = Boolean
Config.Label = Use spot instances for GPU nodes (not recommended for long jobs)

[[[parameter GPUClusterInitSpecs]]]
Label = GPU Cluster-Init
DefaultValue = =undefined
Description = Additional cluster-init specs for GPU nodes
ParameterType = Cloud.ClusterInitSpecs
```

Then create the PBS queue in `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/02-initialize-queues.sh`:
```bash
# Add GPU queue
qmgr -c "create queue gpuq queue_type=execution"
qmgr -c "set queue gpuq enabled=True"
qmgr -c "set queue gpuq started=True"
qmgr -c "set queue gpuq resources_default.place=scatter:excl"
qmgr -c "set queue gpuq resources_default.slot_type=gpu"
```

---

**This template is production-ready for private networking deployments!** ✅
