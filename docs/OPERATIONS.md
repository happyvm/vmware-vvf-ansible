# Exploitation / Observabilité

## Variables globales

La variable `vmware_observability` centralise les paramètres d'observabilité communs:

- `vmware_observability.syslog.esxi_target`: cible syslog ESXi globale.
- `vmware_observability.syslog.per_host_dir`: activation d'un répertoire de logs par hôte.
- `vmware_observability.vcenter.log_level`: niveau de log vCenter.
- `vmware_observability.vcenter.event_retention_days`: rétention des événements vCenter.
- `vmware_observability.ntp_servers`: serveurs NTP communs.

## Recommandations d'exploitation

1. Pointez ESXi et vCenter vers une plateforme syslog/SIEM centralisée.
2. Activez TLS strict (`validate_certs: true`) en production.
3. Conservez des règles de rétention adaptées aux besoins audit/compliance.
4. Supervisez les échecs d'authentification et changements de configuration.
5. Exécutez `playbooks/preflight.yml` avant toute exécution `playbooks/site.yml`.
