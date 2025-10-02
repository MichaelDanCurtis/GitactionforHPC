# Private Network Setup Guide

## Overview

All deployments use **private networking only** for security and compliance. This means:
- ✅ CycleCloud container has private IP only
- ✅ PBS master node has private IP only
- ✅ PBS compute nodes have private IP only
- ❌ No public IPs assigned anywhere

---

## Prerequisites

### 1. Azure Virtual Network

You must have a VNet and subnet configured before deployment.

**Create VNet (if needed):**
```bash
az network vnet create \
  --resource-group MyNetworkingRG \
  --name hpc-vnet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name cyclecloud-subnet \
  --subnet-prefix 10.0.1.0/24
```

### 2. GitHub Repository Variables

Set these in **Settings → Secrets and variables → Actions → Variables**:

| Variable | Example | Description |
|----------|---------|-------------|
| `VIRTUAL_NETWORK_NAME` | `hpc-vnet` | VNet name |
| `VIRTUAL_NETWORK_RESOURCE_GROUP_NAME` | `RG-Networking` | VNet resource group |
| `VIRTUAL_NETWORK_SUBNET_NAME` | `cyclecloud-subnet` | Subnet name |

### 3. Service Principal Permissions

Your Azure service principal needs:
- `Microsoft.Network/virtualNetworks/read`
- `Microsoft.Network/virtualNetworks/subnets/read`
- `Microsoft.Network/virtualNetworks/subnets/join/action`

---

## Access Methods

Since all resources use private IPs, you need one of these access methods:

### Option 1: VPN Gateway (Recommended)

**Setup:**
```bash
# Create VPN gateway (one-time setup)
az network vnet-gateway create \
  --name MyVPNGateway \
  --resource-group RG-Networking \
  --vnet hpc-vnet \
  --gateway-type Vpn \
  --vpn-type RouteBased \
  --sku VpnGw1
```

**Access:**
1. Connect to Azure VPN
2. Access CycleCloud UI: `http://10.0.1.4:8080`
3. SSH to master: `ssh cyclecloud@10.0.1.5`

### Option 2: Azure Bastion

**Setup:**
```bash
# Create Bastion (one-time setup)
az network bastion create \
  --name MyBastion \
  --resource-group RG-Networking \
  --vnet-name hpc-vnet \
  --public-ip MyBastionIP
```

**Access PBS Master:**
```bash
az network bastion ssh \
  --name MyBastion \
  --resource-group RG-Networking \
  --target-resource-id <MASTER_VM_ID> \
  --auth-type ssh-key \
  --username cyclecloud \
  --ssh-key ~/.ssh/id_rsa
```

### Option 3: Jump Box

**Setup:**
```bash
# Create jump box in same VNet with public IP
az vm create \
  --resource-group RG-HPC \
  --name jumpbox \
  --image Ubuntu2204 \
  --vnet-name hpc-vnet \
  --subnet cyclecloud-subnet \
  --public-ip-address jumpbox-ip \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub
```

**Access:**
```bash
# SSH to master via jump box
ssh -J azureuser@jumpbox-ip cyclecloud@10.0.1.5

# SSH tunnel for CycleCloud UI
ssh -L 8080:10.0.1.4:8080 azureuser@jumpbox-ip
# Then browse to: http://localhost:8080
```

### Option 4: ExpressRoute

For enterprise environments with ExpressRoute already configured, private resources will be accessible directly from on-premises network.

---

## Workflow Configuration

### Required Inputs

Both workflows now require VNet configuration:

**Workflow 1: Deploy CycleCloud**
- VNet variables must be set (see Prerequisites)
- Workflow will fail if VNet not found

**Workflow 2: Create PBS Cluster**
- `subnet_id` input is **required**
- Format: `/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/{subnet}`

### Get Subnet ID

```bash
az network vnet subnet show \
  --resource-group RG-Networking \
  --vnet-name hpc-vnet \
  --name cyclecloud-subnet \
  --query id -o tsv
```

---

## Troubleshooting

### Error: "Virtual network configuration is REQUIRED"

**Cause**: Missing VNet repository variables  
**Fix**: Set `VIRTUAL_NETWORK_NAME`, `VIRTUAL_NETWORK_RESOURCE_GROUP_NAME`, `VIRTUAL_NETWORK_SUBNET_NAME`

### Error: "Subnet ID is required"

**Cause**: `subnet_id` workflow input is empty  
**Fix**: Provide subnet resource ID when running Workflow 2

### Error: "Virtual network 'X' not found"

**Cause**: VNet doesn't exist or wrong resource group  
**Fix**: 
```bash
# Verify VNet exists
az network vnet show \
  --resource-group RG-Networking \
  --name hpc-vnet
```

### Error: "Insufficient permissions on virtual network"

**Cause**: Service principal can't access VNet  
**Fix**: Grant network permissions:
```bash
az role assignment create \
  --assignee <service-principal-id> \
  --role "Network Contributor" \
  --scope /subscriptions/{sub}/resourceGroups/RG-Networking
```

### Can't access CycleCloud UI

**Symptoms**: Container deployed but can't browse to UI  
**Cause**: Not connected to VNet  
**Fix**: 
- Connect to VPN, or
- Use SSH tunnel via jump box, or
- Use Azure Portal to view container logs

### Can't SSH to master node

**Symptoms**: SSH connection timeout  
**Cause**: Not on same network or NSG blocking traffic  
**Fix**:
1. Verify you're connected to VPN/using bastion
2. Check NSG rules on subnet:
   ```bash
   az network nsg rule list \
     --resource-group RG-Networking \
     --nsg-name cyclecloud-nsg \
     --query "[?direction=='Inbound']" -o table
   ```
3. Ensure SSH (port 22) is allowed from your source

### Autoscale not working

**Symptoms**: Jobs queue but nodes don't scale  
**Diagnostic**:
```bash
# SSH to master node
ssh cyclecloud@<MASTER_PRIVATE_IP>

# Check PBS status
qstat -B

# Check autoscale logs
tail -f /opt/cycle/pbspro/azpbs.log

# Verify PBS hook
qmgr -c "list hook azpbs"
```

**Common issues**:
- Master node can't reach CycleCloud (check network routes)
- Autoscale hook not installed (re-run Workflow 2)
- CycleCloud credentials incorrect (check secrets)

---

## Security Best Practices

### Network Security Groups

Create NSG rules that only allow necessary traffic:

```bash
# Allow SSH from VPN subnet only
az network nsg rule create \
  --resource-group RG-Networking \
  --nsg-name cyclecloud-nsg \
  --name AllowSSHFromVPN \
  --priority 100 \
  --source-address-prefixes 10.0.0.0/24 \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp

# Allow CycleCloud UI from VPN subnet only
az network nsg rule create \
  --resource-group RG-Networking \
  --nsg-name cyclecloud-nsg \
  --name AllowCycleCloudFromVPN \
  --priority 110 \
  --source-address-prefixes 10.0.0.0/24 \
  --destination-port-ranges 8080 \
  --access Allow \
  --protocol Tcp
```

### Service Endpoints

Enable service endpoints for Azure services:

```bash
az network vnet subnet update \
  --resource-group RG-Networking \
  --vnet-name hpc-vnet \
  --name cyclecloud-subnet \
  --service-endpoints Microsoft.Storage Microsoft.KeyVault
```

### Private Endpoints

For production, consider private endpoints for:
- Azure Storage (cluster-init files, logs)
- Azure Key Vault (secrets management)
- Azure Container Registry (if using custom images)

---

## Migration from Public IPs

If you previously deployed with public IPs:

### 1. Clean Up Old Deployment
```bash
# Delete old cluster and container
az container delete --resource-group RG-HPC --name cyclecloud-mcr
```

### 2. Set Up VNet (if not exists)
Follow Prerequisites section above

### 3. Configure Access Method
Choose VPN, Bastion, or Jump Box (see Access Methods)

### 4. Deploy with Private Networking
Run workflows normally - they now enforce private networking

### 5. Update Firewall Rules
- Remove public IP allowances
- Configure NSG for VPN/Bastion source only

---

## Network Diagram

```
Internet
   |
   v
[VPN Gateway] ──────────────┐
   |                        |
   v                        v
[Azure VNet: 10.0.0.0/16]   [On-premises via ExpressRoute]
   |
   ├─ [Subnet: 10.0.1.0/24]
   |    ├─ CycleCloud Container (10.0.1.4:8080)
   |    ├─ PBS Master (10.0.1.5)
   |    └─ PBS Compute Nodes (10.0.1.6+)
   |
   └─ [Bastion Subnet: 10.0.255.0/24]
        └─ Azure Bastion
```

---

## Summary

✅ **All deployments are private by default**  
✅ **VNet configuration is required**  
✅ **Choose access method that fits your security policy**  
✅ **No public IPs = better security posture**  

For more information, see:
- `CHANGELOG.md` - What changed in v2.0
- `cluster-templates/README.md` - How to customize clusters
- `QUICKSTART.md` - Deployment walkthrough
