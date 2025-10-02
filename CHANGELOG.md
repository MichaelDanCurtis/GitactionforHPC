# Changelog

## Version 2.0 - October 2, 2025

Major reorganization with workflow consolidation and security enhancements.

### 🎯 Major Changes

#### Workflow Consolidation (3 → 2 workflows)
- **Merged workflows**: Combined "Bootstrap PBS" and "Create Cluster" into single workflow
- **Before**: 3 separate workflows requiring manual sequencing
- **After**: 2 workflows with clear progression
- **Benefit**: Reduced manual steps by 33%, eliminated user errors from missed bootstrap step

#### Renamed Workflows
- `Deploy-CycleCloud-from-MCR.yaml` → `Workflow-1-Deploy-CycleCloud.yaml`
- `bootstrap-pbspro.yaml` + `create-pbspro-cluster.yaml` → `Workflow-2-Create-PBSpro-Cluster.yaml`

#### Private Networking Enforcement
- **Removed**: All public IP deployment code paths
- **Required**: VNet configuration for all deployments
- **Security**: All components (CycleCloud, PBS master, compute nodes) use private IPs only
- **Access**: Via VPN, Azure Bastion, or Jump Box

#### Template Extraction
- **Moved**: Cluster template from embedded YAML to separate file
- **Location**: `cluster-init/cluster-templates/pbspro-cluster.txt`
- **Benefit**: Users can edit cluster configuration without modifying workflows
- **Documentation**: Added `cluster-init/cluster-templates/README.md` customization guide

#### File Organization
- **Created**: `/Legacy/` directory for deprecated files
- **Moved**: 5 old workflow files to Legacy with documentation
- **Preserved**: Legacy files for reference but removed from active use
- **Organized**: Cluster configuration files under `cluster-init/` directory

---

### 📁 New Directory Structure

```
GitactionforHPC/
├── .github/workflows/
│   ├── Workflow-1-Deploy-CycleCloud.yaml        (Deploy CycleCloud container)
│   └── Workflow-2-Create-PBSpro-Cluster.yaml    (Create cluster + autoscale)
├── cluster-init/
│   ├── cluster-templates/
│   │   ├── pbspro-cluster.txt                   (User-editable template)
│   │   └── README.md                            (Customization guide)
│   └── pbspro-autoscale/                        (User-editable PBS scripts)
├── cyclecloud-pbspro/                           (Autoscale integration)
├── Legacy/                                      (Deprecated files)
└── [documentation files]
```

---

### ⚠️ Breaking Changes

#### For Existing Users

**1. Workflow Names Changed**
- Update any automation scripts or bookmarks
- Old workflow names no longer exist in `.github/workflows/`

**2. Public Networking Removed**
- Must configure VNet before deployment
- Set GitHub repository variables:
  - `VIRTUAL_NETWORK_NAME`
  - `VIRTUAL_NETWORK_RESOURCE_GROUP_NAME`
  - `VIRTUAL_NETWORK_SUBNET_NAME`
- Set up VPN, Bastion, or Jump Box for access

**3. Workflow Sequence Changed**
- Old: Deploy → Bootstrap → Create Cluster (3 steps)
- New: Deploy → Create Cluster (2 steps, bootstrap automatic)

**4. Template Location Changed**
- Old: Embedded in workflow YAML
- New: `cluster-init/cluster-templates/pbspro-cluster.txt`
- Can now be edited directly in repository

---

### 🔄 Migration Guide

#### If Migrating from v1.0

**Step 1: Update GitHub Variables**
```bash
# Add these new REQUIRED variables
VIRTUAL_NETWORK_NAME                    = "your-vnet"
VIRTUAL_NETWORK_RESOURCE_GROUP_NAME     = "your-networking-rg"
VIRTUAL_NETWORK_SUBNET_NAME             = "cyclecloud-subnet"
```

**Step 2: Set Up Network Access**
- Configure VPN gateway, or
- Set up Azure Bastion, or
- Deploy Jump Box in same VNet

**Step 3: Update Automation Scripts**
```bash
# Old
gh workflow run bootstrap-pbspro.yaml ...
gh workflow run create-pbspro-cluster.yaml ...

# New (bootstrap is automatic)
gh workflow run Workflow-2-Create-PBSpro-Cluster.yaml ...
```

**Step 4: Customize Templates (Optional)**
- Edit `cluster-init/cluster-templates/pbspro-cluster.txt` for cluster config
- Edit `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/*.sh` for PBS config

---

### 📊 Improvements

| Metric | v1.0 | v2.0 | Change |
|--------|------|------|--------|
| Active workflows | 3 | 2 | -33% |
| Manual workflow runs | 3 | 2 | -33% |
| Template editable | No | Yes | ✅ |
| Private networking | Optional | Required | ✅ |
| User error prone | Yes | No | ✅ |
| Security | Mixed | Enforced | ✅ |

---

### 🔒 Security Enhancements

#### Private Networking Only
- **CycleCloud container**: Private IP in VNet
- **PBS master node**: Private IP in VNet
- **PBS compute nodes**: Private IP in VNet
- **Public IPs**: None assigned anywhere

#### Access Methods
- **VPN**: Connect to Azure VPN, access private IPs
- **Bastion**: Use Azure Bastion for SSH access
- **Jump Box**: SSH through jump host in same VNet

#### Network Requirements
- VNet must exist before deployment
- Subnet must have sufficient IP address space
- Service principal needs network join permissions

---

### 📚 Documentation Updates

#### New Documents
- `cluster-init/cluster-templates/README.md` - Template customization guide
- `Legacy/README.md` - Legacy file documentation
- `CHANGELOG.md` - This file

#### Updated Workflow Files
- Both workflows now require VNet configuration
- Workflow 2 includes autoscale setup automatically
- Template loaded from repository file instead of embedded

---

### 🐛 Bug Fixes
- Fixed YAML syntax in workflow headers
- Corrected network validation logic
- Improved error messages for missing VNet configuration

---

### 🎯 New Features

#### Workflow 2 Enhancements
- **Atomic deployment**: Cluster creation + autoscale in one workflow
- **Better validation**: Checks VNet, subnet, credentials upfront
- **Detailed output**: Generates comprehensive access instructions
- **Artifact upload**: Saves cluster info, autoscale config for reference
- **Summary output**: GitHub Actions summary shows deployment status

#### Template Customization
- **VM sizes**: Easy to change master, execute, HTC node sizes
- **Autoscale limits**: Adjust max cores per node array
- **Custom node arrays**: Add GPU, memory-optimized, or other node types
- **Cluster-init**: Specify custom initialization projects

#### PBS Configuration
- **Queue customization**: Edit queue definitions in cluster-init scripts
- **PBS settings**: Modify server settings, scheduler parameters
- **Resource definitions**: Add custom PBS resources

---

### 📖 Documentation Structure

**Essential Reading**:
1. `README.md` - Project overview, setup instructions
2. `QUICKSTART.md` - Step-by-step deployment guide
3. `AUTOMATION.md` - Workflow documentation
4. `ARCHITECTURE.md` - System architecture

**Specialized Topics**:
- `cluster-init/cluster-templates/README.md` - How to customize cluster templates
- `Legacy/README.md` - Why files were deprecated
- `CHANGELOG.md` - Version history and changes

---

### 🔮 Future Enhancements

Potential improvements for future versions:
- Add workflow for cluster deletion/cleanup
- Support for multiple cluster types (Slurm, LSF)
- Automated testing and validation
- Terraform/Bicep deployment options
- Enhanced monitoring and logging integration

---

### 🙏 Acknowledgments

This reorganization simplifies the user experience, improves security posture, and makes the system more maintainable. The v2.0 release represents a significant improvement over the original 3-workflow architecture.

---

## Version 1.0 - Original Release

Initial implementation with 3-workflow architecture:
1. Deploy CycleCloud container
2. Bootstrap PBS autoscale
3. Create PBS cluster

Features:
- Azure Container Instance deployment
- CycleCloud integration
- PBS Pro cluster creation
- Autoscale (azpbs) integration
- Cluster-init mechanism

Limitations addressed in v2.0:
- Required manual sequencing of 3 workflows
- Mixed public/private networking
- Embedded cluster template
- No centralized customization
