# 📚 Documentation Guide

## Essential Documentation (Read in This Order)

### 1. **README.md** - Start Here
- Project overview
- What this does
- Prerequisites
- Quick links

### 2. **QUICKSTART.md** - How to Deploy
- Step-by-step deployment guide
- GitHub setup
- Running workflows
- First cluster deployment

### 3. **NETWORK_SETUP.md** - Private Network Access
- VNet configuration requirements
- Access methods (VPN, Bastion, Jump Box)
- Troubleshooting network issues
- Security best practices

### 4. **AUTOMATION.md** - Workflow Details
- Detailed workflow documentation
- Input parameters
- Output artifacts
- Advanced usage

### 5. **ARCHITECTURE.md** - System Design
- Component architecture
- How everything fits together
- Design decisions
- Technical details

---

## Specialized Topics

### **CHANGELOG.md** - Version History
- What changed in v2.0
- Breaking changes
- Migration guide
- Future roadmap

### **cluster-templates/README.md** - Customization
- How to edit cluster templates
- Add GPU nodes
- Change VM sizes
- Custom node arrays

### **Legacy/README.md** - Deprecated Files
- Why old files were removed
- Old vs new architecture
- Reference only

---

## Quick Reference

**Want to...** | **Read this**
--- | ---
Deploy your first cluster | QUICKSTART.md
Set up VPN/network access | NETWORK_SETUP.md
Understand workflows | AUTOMATION.md
Customize cluster config | cluster-templates/README.md
See what changed | CHANGELOG.md
Understand architecture | ARCHITECTURE.md
Troubleshoot issues | NETWORK_SETUP.md (Troubleshooting section)

---

## Documentation Structure

```
GitactionforHPC/
├── README.md                    # Project overview
├── QUICKSTART.md                # Deployment guide
├── NETWORK_SETUP.md             # Private networking & access
├── AUTOMATION.md                # Workflow documentation
├── ARCHITECTURE.md              # System architecture
├── CHANGELOG.md                 # Version history
│
├── cluster-templates/
│   └── README.md                # Template customization
│
└── Legacy/
    └── README.md                # Deprecated files
```

---

## Getting Started

**New users**: Read in this order:
1. README.md → QUICKSTART.md → NETWORK_SETUP.md

**Existing users migrating from v1.0**: 
1. CHANGELOG.md → NETWORK_SETUP.md

**Customizing clusters**:
1. cluster-templates/README.md

**Understanding the system**:
1. ARCHITECTURE.md → AUTOMATION.md
