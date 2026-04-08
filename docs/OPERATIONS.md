# Exploitation / Observabilité

## Variables globales

La variable `vmware_observability` centralise les paramètres d'observabilité communs:

- `vmware_observability.syslog.esxi_target`: cible syslog ESXi globale.
- `vmware_observability.syslog.per_host_dir`: activation d'un répertoire de logs par hôte.
- `vmware_observability.vcenter.log_level`: niveau de log vCenter.
- `vmware_observability.vcenter.event_retention_days`: rétention des événements vCenter.
- `vmware_observability.ntp_servers`: serveurs NTP communs.

## Source de vérité Syslog ESXi

La configuration Syslog ESXi est portée **uniquement** par le rôle `logging_syslog`.

- Le rôle `esxi_hardening` ne configure plus les options `Syslog.global.*`.
- Les variables supportées restent:
  - `esxi.syslog_target` (niveau hôte, prioritaire)
  - `vmware_observability.syslog.esxi_target` (niveau global)
  - `vmware_observability.syslog.per_host_dir` (répertoire dédié par hôte)

Cette séparation évite les doubles écritures de configuration et clarifie la responsabilité des rôles.

## Recommandations d'exploitation

1. Pointez ESXi et vCenter vers une plateforme syslog/SIEM centralisée.
2. Activez TLS strict (`validate_certs: true`) en production.
3. Conservez des règles de rétention adaptées aux besoins audit/compliance.
4. Supervisez les échecs d'authentification et changements de configuration.
5. Exécutez `playbooks/preflight.yml` avant toute exécution `playbooks/site.yml`.


## Compliance: mode check vs remediation

- `playbooks/compliance_checks.yml`: mode **check** (lecture seule). Produit un rapport consolidé exploitable en CI (`compliance_checks_report_path`) et peut échouer volontairement avec `compliance_checks_fail_on_non_compliant=true`.
- `playbooks/site.yml`: mode **remediation** (applique la configuration cible via les rôles de provisioning/hardening).

Le mode check permet d'identifier les hôtes non conformes sans action destructive.
