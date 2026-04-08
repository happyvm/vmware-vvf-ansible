# vmware-vvf-ansible

Documentation opératoire pour déployer et maintenir une configuration VMware vSphere (multi-site / multi-vCenter) avec Ansible.

---

## 1) Objectif

Ce repository permet de gérer de façon déclarative :

- vCenter (comptes locaux, rôles, permissions, paramètres de hardening)
- Datacenters
- Clusters (HA/DRS + règles d'affinité / anti-affinité)
- dvSwitch et dvPortgroups
- Hôtes ESXi (join cluster, DNS, NTP, VMkernel, multipathing, hardening)
- Paramètres syslog ESXi

La structure est pensée pour être **multi-site** et **multi-vCenter** via une variable racine `vmware_sites`.

---

## 2) Prérequis

### 2.1 Outils

- Python 3.11+
- `pip`
- Ansible (via `requirements.txt`)
- Accès réseau API vers les vCenter/ESXi ciblés

### 2.2 Dépendances Python

```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 2.3 Collections Ansible

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

### 2.4 Outils optionnels pour import d'existant

- Bash helper (`scripts/export-config.sh`) : `govc`, `jq`, `yq`
- PowerShell helper (`scripts/export-config.ps1`) : `VMware.PowerCLI`

---

## 3) Bootstrap (mise en route rapide)

1. Cloner le repo.
2. Créer l'environnement Python + installer les dépendances.
3. Installer les collections Ansible.
4. Copier l'inventaire exemple et renseigner vos cibles.
5. Créer le fichier de secrets chiffré (Ansible Vault).
6. Exécuter le preflight.
7. Exécuter le playbook principal.

Exemple rapide :

```bash
cp inventories/production/group_vars/vault.example.yml inventories/production/group_vars/vault.yml
ansible-vault encrypt inventories/production/group_vars/vault.yml
ansible-playbook playbooks/preflight.yml
ansible-playbook playbooks/site.yml
```

---

## 4) Inventaire minimal

Fichier : `inventories/production/group_vars/all.yml`

Exemple minimal (1 site / 1 vCenter / 1 datacenter / 1 cluster) :

```yaml
vmware_sites:
  - name: paris
    vcenters:
      - name: vcsa-paris
        hostname: vcsa-paris.example.local
        username: "{{ vault_vcenter_paris_username }}"
        password: "{{ vault_vcenter_paris_password }}"
        validate_certs: false
        local_roles: []
        local_accounts: []
        datacenters:
          - name: dc-paris-01
            clusters:
              - name: cl-paris-prod
                drs_enabled: true
                ha_enabled: true
                host_rules:
                  affinity: []
                  anti_affinity: []
                dvswitches: []
                hosts: []
                dvportgroups: []
```

---

## 5) Gestion des secrets

### 5.1 Recommandation

Utiliser **Ansible Vault** pour tous les identifiants :

- comptes vCenter
- mots de passe comptes locaux
- credentials ESXi root (ou compte d'intégration dédié)

### 5.2 Bonnes pratiques

- Ne jamais committer `vault.yml` en clair.
- Activer des mots de passe robustes et rotation régulière.
- Préférer des comptes de service dédiés, périmètre minimum.
- Isoler les secrets par environnement (dev / qualif / prod).

---

## 6) Exécution opératoire

### 6.1 Preflight

Valide la structure minimale `vmware_sites` et quelques prérequis locaux.

```bash
ansible-playbook playbooks/preflight.yml
```

### 6.2 Déploiement principal

```bash
ansible-playbook playbooks/site.yml
```

### 6.3 Ciblage d'un site (optionnel)

Si vous ajoutez un filtrage dans vos variables/groupes, lancez en limitant l'inventaire.

```bash
ansible-playbook -i inventories/production/hosts.yml playbooks/site.yml
```

---

## 7) Ordre des rôles (logique d'exécution)

Le flux actuel est :

1. `vcenter`
   - comptes/rôles/permissions locaux
   - `vcenter_hardening`
2. `datacenter`
3. `cluster`
   - paramètres cluster
   - règles affinité / anti-affinité
   - `dvswitch`
4. `esxi_host`
   - join cluster
   - DNS / NTP / VMkernel / multipathing
   - `esxi_hardening`
   - `logging_syslog`
5. `dvportgroup`

Ce séquencement évite de créer des objets dépendants avant leurs prérequis.

---

## 8) Exemple multi-site / multi-vCenter

Exemple conceptuel :

```yaml
vmware_sites:
  - name: paris
    vcenters:
      - name: vcsa-paris
        hostname: vcsa-paris.example.local
        datacenters: [...]

  - name: montreal
    vcenters:
      - name: vcsa-montreal
        hostname: vcsa-montreal.example.local
        datacenters: [...]
```

Le playbook parcourt automatiquement `vmware_sites[*].vcenters[*]`.

---

## 9) Import de configuration existante

### 9.1 Bash helper

```bash
export GOVC_URL='https://vcsa-paris.example.local/sdk'
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='***'

scripts/export-config.sh \
  -o inventories/production/group_vars/all.generated.yml \
  -s paris \
  -v vcsa-paris
```

### 9.2 PowerShell helper

```powershell
pwsh ./scripts/export-config.ps1 \
  -OutputPath inventories/production/group_vars/all.generated.yml \
  -SiteName paris \
  -VCenterAlias vcsa-paris \
  -VCenterServer vcsa-paris.example.local
```

> Les helpers génèrent une **base** d'inventaire. Un enrichissement manuel reste nécessaire (règles, hardening détaillé, conventions réseau, etc.).

---

## 10) Limites connues

- Certains paramètres des modules `community.vmware` peuvent varier selon la version de collection et la version vSphere.
- Les rôles de hardening fournis sont un **socle initial**, pas un benchmark de conformité complet (CIS/ANSSI/etc.).
- Le scénario Molecule est minimal et ne simule pas un vrai backend vSphere.
- Sans `ansible-playbook`/collections installés localement, seuls des checks de syntaxe basiques sont possibles.

---

## 11) Recommandations de sécurité

- Utiliser `validate_certs: true` en production avec une PKI maîtrisée.
- Appliquer le principe du moindre privilège sur les comptes d'automatisation.
- Journaliser toutes les exécutions Ansible (CI + artefacts de logs).
- Segmenter réseau/API (jump host, ACL, bastion).
- Tester d'abord en environnement de pré-production.
- Mettre en place une revue de changements + approbation avant exécution en prod.

---

## 12) Qualité et CI

- Lint local recommandé :

```bash
yamllint .
ansible-lint
```

- CI GitHub Actions :
  - installe dépendances
  - installe collections
  - lance `yamllint`, `ansible-lint`
  - lance les `--syntax-check` des playbooks
  - valide la structure d'inventaire sur deux fixtures :
    - `tests/inventory/simple.yml`
    - `tests/inventory/multisite.yml`

Validation locale des fixtures :

```bash
ansible-playbook tests/playbooks/validate_inventory.yml -e inventory_fixture=tests/inventory/simple.yml
ansible-playbook tests/playbooks/validate_inventory.yml -e inventory_fixture=tests/inventory/multisite.yml
```
