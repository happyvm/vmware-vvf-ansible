# vmware-vvf-ansible

Code Ansible prêt à l'emploi pour configurer VMware vSphere de manière **multi-site** et **multi-vCenter** :

- vCenter : comptes et rôles locaux
- Datacenter
- Clusters : HA, DRS, règles d'affinité / anti-affinité VM
- Nœuds ESXi : NTP, DNS, interfaces VMkernel, multipathing
- dvPortgroups
- Helpers d'import de l'existant en **bash** et **PowerShell**

## 1) Pré-requis

- Ansible >= 2.14
- Collection Ansible : `community.vmware`
- Python : `pyvmomi`
- Pour export bash : `govc`, `jq`, `yq`
- Pour export PowerShell : module `VMware.PowerCLI`

Installation des collections :

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

## 2) Structure

```text
.
├── ansible.cfg
├── collections/requirements.yml
├── inventories/production/
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml
│       └── vault.example.yml
├── playbooks/site.yml
├── roles/
│   ├── vcenter/
│   ├── datacenter/
│   ├── cluster/
│   ├── esxi_host/
│   └── dvportgroup/
└── scripts/
    ├── export-config.sh
    └── export-config.ps1
```

## 3) Variables multi-site / multi-vCenter

Le modèle principal est dans :

- `inventories/production/group_vars/all.yml`

Le principe :

- `vmware_sites[]`
  - `vcenters[]`
    - `datacenters[]`
      - `clusters[]`
        - `hosts[]`
        - `dvportgroups[]`

Vous pouvez dupliquer les blocs pour ajouter autant de sites/vCenters que nécessaire.

## 4) Secrets

Exemple de variables sensibles :

- `inventories/production/group_vars/vault.example.yml`

Recommandé : utiliser **Ansible Vault**.

```bash
ansible-vault create inventories/production/group_vars/vault.yml
```

## 5) Exécution

```bash
ansible-playbook playbooks/site.yml
```

## 6) Import de la configuration existante (helper)

### 6.1 Bash (`govc`)

Script : `scripts/export-config.sh`

Exemple :

```bash
export GOVC_URL='https://vcsa-paris.example.local/sdk'
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='***'

scripts/export-config.sh \
  -o inventories/production/group_vars/all.generated.yml \
  -s paris \
  -v vcsa-paris
```

Le script génère un YAML de base réutilisable dans les variables Ansible.

### 6.2 PowerShell (`VMware.PowerCLI`)

Script : `scripts/export-config.ps1`

Exemple :

```powershell
pwsh ./scripts/export-config.ps1 \
  -OutputPath inventories/production/group_vars/all.generated.yml \
  -SiteName paris \
  -VCenterAlias vcsa-paris \
  -VCenterServer vcsa-paris.example.local
```

## 7) Notes importantes

- Les modules `community.vmware` s'exécutent depuis la machine Ansible et se connectent aux APIs vCenter/ESXi.
- Adaptez les noms de politiques multipathing, services VMkernel et options cluster selon votre standard.
- Commencez par un environnement de test avant production.
