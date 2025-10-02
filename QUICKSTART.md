# Quick Start Guide

## Step 1: Configure GitHub Repository

### Add Secrets
Go to **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

1. **AZURE_CREDENTIALS**
   ```json
   {
     "clientId": "...",
     "clientSecret": "...",
     "subscriptionId": "...",
     "tenantId": "..."
   }
   ```

2. **CYCLECLOUD_ADMIN_USERNAME**: Your chosen CycleCloud admin username

3. **CYCLECLOUD_ADMIN_PASSWORD**: Your chosen CycleCloud admin password

### Add Variables
Go to **Settings** → **Secrets and variables** → **Actions** → **Variables** tab

1. **RESOURCE_GROUP**: Your Azure resource group name
2. **AZURE_REGION**: Azure region (e.g., `eastus`)

### Optional: Private Networking Variables
3. **VIRTUAL_NETWORK_NAME**: VNet name
4. **VIRTUAL_NETWORK_RESOURCE_GROUP_NAME**: VNet resource group  
5. **VIRTUAL_NETWORK_SUBNET_NAME**: Subnet name

## Step 2: Deploy CycleCloud Container

1. Go to **Actions** tab
2. Select **Deploy CycleCloud from Microsoft Container Registry**
3. Click **Run workflow**
4. Fill in:
   - Environment: `RG-BH_HPC_Cloud_Azure-NP-SUB-000005-EastUS-dev`
   - Image tag: `latest` (or specific version like `8.3.0`)
   - Container instance name: `cyclecloud-mcr`
   - CPU cores: `4`
   - Memory: `8`
   - Deployment mode: `passive` (for first deployment)
5. Click **Run workflow**
6. Wait for completion (~5-10 minutes)
7. Download the artifact `cyclecloud-mcr-*` to get access details

## Step 3: Create PBS Pro Cluster (Automated!)

1. Go to **Actions** tab
2. Select **Create CycleCloud PBS Pro Cluster**
3. Click **Run workflow**
4. Fill in:
   - Environment: Same as Step 2
   - Container instance name: `cyclecloud-mcr` (same as Step 2)
   - Cluster name: `pbspro-cluster` (you choose this!)
   - Master VM size: `Standard_D4s_v3` (or your preference)
   - Execute VM size: `Standard_F4s_v2`
   - Max execute nodes: `10`
   - HTC VM size: `Standard_F2s_v2`
   - Max HTC nodes: `100`
   - Subnet ID: (leave empty for public, or provide Azure subnet resource ID)
   - Auto start master: ✓ (checked)
5. Click **Run workflow**
6. Wait for completion (~2-3 minutes for cluster creation, then 10-15 minutes for master node)
7. Download artifact to see access instructions

## Step 4: Configure Autoscale Integration

1. Go to **Actions** tab
2. Select **Configure CycleCloud Autoscale**
3. Click **Run workflow**
4. Fill in:
   - Environment: Same as Step 2
   - Container instance name: `cyclecloud-mcr` (same as Step 2)
   - Cluster name: `pbspro-cluster` (from Step 3)
   - CycleCloud URL: `http://127.0.0.1:8080`
   - Ignore queues: (leave empty unless you have custom queues to exclude)
5. Click **Run workflow**
6. Wait for completion (~3-5 minutes)
7. Download the artifact `cyclecloud-autoscale-*` to see configuration

**Note**: PBS server configuration and queues were already created automatically during Step 3 via cluster-init scripts that ran on the master node during boot.

## Step 5: Test Autoscale

1. SSH to the PBS master node:
   ```bash
   # Get master node IP from CycleCloud UI or workflow artifact
   ssh cyclecloud@<PBS_MASTER_IP>
   ```

2. Verify PBS is configured:
   ```bash
   # Check queues were created by cluster-init
   /opt/pbs/bin/qstat -Q
   # Should show: workq and htcq
   
   # Check custom resources
   /opt/pbs/bin/qmgr -c "list resource slot_type"
   /opt/pbs/bin/qmgr -c "list resource vm_size"
   ```

3. Submit a test job:
   ```bash
   # Simple job requesting 2 nodes with 4 CPUs each
   echo "hostname && sleep 300" | qsub -l select=2:ncpus=4
   
   # Check job status
   qstat -a
   ```

4. Monitor autoscaling (from CycleCloud container):
   ```bash
   az container exec \
     --resource-group <RESOURCE_GROUP> \
     --name cyclecloud-mcr \
     --exec-command "/bin/bash -c 'azpbs nodes'"
   ```

5. Monitor in CycleCloud:
   - Go to your PBS cluster in the web UI
   - Click **Nodes** tab
   - Watch nodes being created
   - After job completes, nodes will scale down after ~5 minutes

## Verification Commands

### On the CycleCloud Container
```bash
# Check azpbs installation
az container exec \
  --resource-group <RESOURCE_GROUP> \
  --name cyclecloud-mcr \
  --exec-command "/bin/bash -c 'azpbs --version'"

# Test CycleCloud connection
az container exec \
  --resource-group <RESOURCE_GROUP> \
  --name cyclecloud-mcr \
  --exec-command "/bin/bash -c 'azpbs connect'"
```

### On the PBS Master Node
```bash
# Verify cluster-init ran successfully
sudo cat /var/log/cloud-init-output.log | grep -A 20 "pbspro-autoscale"

# Check PBS queues created by cluster-init
/opt/pbs/bin/qstat -Q

# Check PBS server configuration
/opt/pbs/bin/qmgr -c "list server" | grep -E "scheduler_iteration|managers"

# Check custom resources created by cluster-init
/opt/pbs/bin/qmgr -c "list resource" | grep -E "slot_type|vm_size|nodearray"

# Submit a test job
echo "sleep 60" | qsub -l select=1:ncpus=2
```

## Common Issues

### "Container not found"
**Problem**: Bootstrap workflow can't find the CycleCloud container  
**Solution**: Ensure Step 2 completed successfully and container name matches

### "Connection refused" when testing azpbs connect
**Problem**: CycleCloud isn't accessible from the master node  
**Solution**: Check networking between master node and CycleCloud container

### Jobs stay queued, no nodes appear
**Problem**: Autoscale not working  
**Solution**: 
```bash
# On master node, verify cluster-init completed
sudo cat /var/log/cloud-init-output.log | grep "pbspro-autoscale"

# Check PBS logs for errors
sudo tail -f /var/spool/pbs/server_logs/$(date +%Y%m%d)

# On CycleCloud container, test autoscale manually
az container exec \
  --resource-group <RG> \
  --name cyclecloud-mcr \
  --exec-command "/bin/bash -c 'azpbs autoscale --config /opt/cycle/pbspro/autoscale.json'"
```

### "Insufficient quota" when scaling
**Problem**: Azure subscription doesn't have enough quota  
**Solution**: Request quota increase in Azure portal for the VM family

## Next Steps

- Configure additional node arrays in CycleCloud
- Customize queue settings in PBS
- Set up monitoring and logging
- Configure backups for CycleCloud database
- Set up SSL/TLS for CycleCloud web interface
- Configure cost management policies

## Updating

### Update CycleCloud Container
Run **Deploy CycleCloud from MCR** workflow with:
- Image tag: New version
- Deployment mode: `update` (replaces only if version changed)

**Note**: This will restart the container and lose non-persistent data

### Update PBS Pro Integration
Re-run **Configure CycleCloud Autoscale** workflow to update autoscale configuration

### Update Cluster-Init Scripts
Modify scripts in `cluster-init/pbspro-autoscale/specs/default/cluster-init/scripts/`, then:
1. Re-run **Create CycleCloud PBS Pro Cluster** workflow to upload updated project
2. Terminate and restart the master node to apply changes

## Cleanup

To delete everything:
```bash
# Delete the container instance
az container delete \
  --resource-group <RESOURCE_GROUP> \
  --name cyclecloud-mcr \
  --yes

# Delete the CycleCloud cluster (from CycleCloud UI or CLI)
# This will terminate all cluster nodes
```

## Support

- GitHub Issues: For workflow problems
- Azure CycleCloud docs: https://learn.microsoft.com/azure/cyclecloud/
- PBS Professional docs: https://help.altair.com/pbspro/
