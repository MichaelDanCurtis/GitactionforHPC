# Legacy Files

This directory contains files that are no longer actively used in the current workflow architecture but are preserved for reference or potential future use.

## 📁 Contents

### Workflows (Replaced)

#### `bootstrap-pbspro.yaml`
- **Status**: ❌ Deprecated - Merged into `Workflow-2-Create-PBSpro-Cluster.yaml`
- **Original Purpose**: Configure CycleCloud autoscale (azpbs) on CycleCloud container
- **Why Deprecated**: Workflow 2 and 3 were merged into a single workflow for simplicity
- **What Replaced It**: The autoscale configuration is now part of Workflow 2

#### `create-pbspro-cluster.yaml`
- **Status**: ❌ Deprecated - Merged into `Workflow-2-Create-PBSpro-Cluster.yaml`
- **Original Purpose**: Create PBS Pro cluster in CycleCloud
- **Why Deprecated**: Merged with bootstrap workflow to reduce manual steps
- **What Replaced It**: New unified Workflow 2 creates cluster AND configures autoscale

#### `upload-cloud-init.yml`
- **Status**: ❌ Deprecated - No longer needed
- **Original Purpose**: Upload cloud-init scripts to Azure storage
- **Why Deprecated**: Cluster-init mechanism uses GitHub repository directly, no storage upload needed
- **What Replaced It**: `cluster-init/` directory structure with CycleCloud cluster-init projects

#### `delete-azure-resource.yml`
- **Status**: ⚠️ May still be useful
- **Original Purpose**: Delete Azure resources (container instances, resource groups)
- **Why Moved Here**: Not part of main deployment workflow
- **Note**: Can be moved back to `.github/workflows/` if cleanup automation is needed

## 🔄 Migration Notes

### Old Architecture (3 Workflows)
1. **Deploy CycleCloud** - Deploy ACI container
2. **Bootstrap PBS** - Install azpbs on container
3. **Create Cluster** - Create PBS cluster

### New Architecture (2 Workflows)
1. **Workflow 1: Deploy CycleCloud** - Deploy ACI container with CycleCloud
2. **Workflow 2: Create PBS Pro Cluster** - Create cluster + configure autoscale (merged 2 & 3)

### Why We Merged Workflows 2 & 3

**Before:**
- User had to run Bootstrap workflow first
- Wait for it to complete
- Then manually run Create Cluster workflow
- Two separate workflows for sequential tasks

**After:**
- User runs Workflow 2 once
- It handles:
  1. CycleCloud CLI initialization
  2. Cluster-init project upload
  3. Cluster creation
  4. Master node startup
  5. Autoscale (azpbs) installation and configuration
- Fully automated end-to-end cluster deployment

**Benefits:**
- ✅ Fewer manual steps
- ✅ Reduced chance of user error (forgetting bootstrap step)
- ✅ Easier to understand workflow sequence
- ✅ Better error handling (single workflow sees all context)
- ✅ Clearer documentation

## 🗂️ Current Workflow Structure

```
.github/workflows/
├── Workflow-1-Deploy-CycleCloud.yaml        # Deploy CycleCloud ACI container
└── Workflow-2-Create-PBSpro-Cluster.yaml    # Create cluster + configure autoscale (merged)

cluster-init/
└── pbspro-autoscale/                        # User-editable PBS initialization scripts
    └── specs/default/cluster-init/scripts/
        ├── 01-initialize-pbs.sh
        └── 02-initialize-queues.sh

cluster-templates/
├── pbspro-cluster.txt                       # User-editable cluster template
└── README.md                                # Customization guide

cyclecloud-pbspro/
├── install.sh                               # Still used for azpbs installation
├── generate_autoscale_json.sh               # Still used for autoscale config
├── autoscale_hook.py                        # PBS hook script
├── server_dyn_res_wrapper.sh                # PBS dynamic resources
└── packages/                                # Python wheels for azpbs
```

## ⚠️ Important Notes

- **Do not delete** `cyclecloud-pbspro/` directory - it's still actively used by Workflow 2 for autoscale installation
- The workflows in this Legacy folder will **not** appear in GitHub Actions UI
- These files are preserved for reference only
- If you need to restore a legacy workflow, move it back to `.github/workflows/`

## 📚 Related Documentation

- [cluster-init/cluster-templates/README.md](../cluster-init/cluster-templates/README.md) - How to customize cluster templates
- [AUTOMATION.md](../AUTOMATION.md) - Current workflow documentation
- [CHANGELOG.md](../CHANGELOG.md) - Version history and migration guide

---

**Last Updated**: October 2, 2025  
**Migration Version**: v2.0 (Private Networking + Merged Workflows)
