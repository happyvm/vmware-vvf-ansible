# vmware-vvf-ansible

Code Ansible pour configurer VMware vSphere en **multi-site** et **multi-vCenter** :

- vCenter : comptes, rôles, hardening
- Datacenter
- Clusters : HA/DRS, règles d'affinité/anti-affinité, vDS
- Nœuds ESXi : NTP, DNS, VMkernel, multipathing, hardening
- dvPortgroups
- Logging / syslog ESXi
- Helpers d'import de configuration existante (bash + PowerShell)

## Ordre de mise en place recommandé

1. `.gitignore`
2. `.github/workflows/ci.yml`
3. `.ansible-lint`, `.yamllint`, `.pre-commit-config.yaml`
4. `requirements.txt`
5. `playbooks/preflight.yml`
6. `roles/vcenter_hardening/`
7. `roles/esxi_hardening/`
8. `roles/dvswitch/`
9. `roles/logging_syslog/`
10. `molecule/` (tests minimaux)

## Pré-requis

- Python 3.11+
- `pip install -r requirements.txt`
- Collection Ansible VMware :

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

## Structure

```text
.
├── .github/workflows/ci.yml
├── .ansible-lint
├── .yamllint
├── .pre-commit-config.yaml
├── requirements.txt
├── playbooks/
│   ├── preflight.yml
│   └── site.yml
├── roles/
│   ├── vcenter/
│   ├── datacenter/
│   ├── cluster/
│   ├── esxi_host/
│   ├── dvportgroup/
│   ├── vcenter_hardening/
│   ├── esxi_hardening/
│   ├── dvswitch/
│   └── logging_syslog/
└── molecule/default/
```

## Exécution

### 1) Préflight

```bash
ansible-playbook playbooks/preflight.yml
```

### 2) Déploiement

```bash
ansible-playbook playbooks/site.yml
```

## Import de l'existant

### Bash

```bash
export GOVC_URL='https://vcsa-paris.example.local/sdk'
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='***'

scripts/export-config.sh \
  -o inventories/production/group_vars/all.generated.yml \
  -s paris \
  -v vcsa-paris
```

### PowerShell

```powershell
pwsh ./scripts/export-config.ps1 \
  -OutputPath inventories/production/group_vars/all.generated.yml \
  -SiteName paris \
  -VCenterAlias vcsa-paris \
  -VCenterServer vcsa-paris.example.local
```
