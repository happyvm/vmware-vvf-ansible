"""Non-regression tests for critical VMware Ansible roles.

These tests validate the presence of key modules and parameters in role tasks
without requiring a live vCenter/ESXi environment.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]


def _load_tasks(relative_path: str) -> list[dict[str, Any]]:
    """Load an Ansible task file as a list of task dictionaries."""
    raw = yaml.safe_load((REPO_ROOT / relative_path).read_text(encoding="utf-8"))
    assert isinstance(raw, list), f"{relative_path} must contain a YAML list of tasks"
    return raw


def _find_task(tasks: list[dict[str, Any]], task_name: str) -> dict[str, Any]:
    for task in tasks:
        if task.get("name") == task_name:
            return task
    available = [task.get("name", "<without name>") for task in tasks]
    raise AssertionError(f"Task '{task_name}' not found. Available: {available}")


def test_vcenter_hardening_and_observability_settings_are_enforced() -> None:
    tasks = _load_tasks("roles/vcenter_hardening/tasks/main.yml")

    map_task = _find_task(tasks, "Build vCenter hardening settings map")
    generated_map = map_task["ansible.builtin.set_fact"]["vcenter_hardening_settings"]

    for expected_setting in (
        "config.vpxd.security.hostValidation",
        "config.vpxd.sso.strictCertValidation",
        "VirtualCenter.InstanceName",
    ):
        assert expected_setting in generated_map

    hardening_task = _find_task(tasks, "Apply vCenter hardening advanced settings")
    module_args = hardening_task["community.vmware.vmware_vcenter_settings"]
    assert module_args["settings"] == "{{ vcenter_hardening_settings }}"

    observability_task = _find_task(tasks, "Apply vCenter observability settings")
    obs_args = observability_task["community.vmware.vmware_vcenter_settings"]
    obs_settings = obs_args["settings"]

    assert obs_settings["config.log.level"] == "{{ vmware_observability.vcenter.log_level | default('info') }}"
    assert obs_settings["config.vpxd.event.maxAge"] == "{{ vmware_observability.vcenter.event_retention_days | default(30) }}"


def test_esxi_hardening_baseline_contains_lockdown_shell_ssh_and_ntp() -> None:
    tasks = _load_tasks("roles/esxi_hardening/tasks/main.yml")

    lockdown_task = _find_task(tasks, "Enable ESXi lockdown mode when requested")
    lockdown_args = lockdown_task["community.vmware.vmware_host_lockdown"]
    assert "lockdown_mode" in lockdown_args

    hardening_task = _find_task(tasks, "Apply ESXi hardening advanced options")
    options = hardening_task["community.vmware.vmware_host_config_manager"]["options"]

    for required_option in (
        "UserVars.SuppressShellWarning",
        "DCUI.Access",
        "Annotations.WelcomeMessage",
        "NTP.ConfiguredServer",
        "UserVars.ESXiShellInteractiveTimeOut",
        "UserVars.ESXiShellTimeOut",
        "UserVars.SSHEnabled",
    ):
        assert required_option in options


def test_esxi_hardening_uses_guarded_nested_access_for_hardening_values() -> None:
    tasks = _load_tasks("roles/esxi_hardening/tasks/main.yml")

    map_task = _find_task(tasks, "Build safe ESXi hardening config map")
    assert map_task["ansible.builtin.set_fact"]["esxi_hardening_cfg"] == "{{ esxi.hardening | default({}) }}"

    lockdown_task = _find_task(tasks, "Enable ESXi lockdown mode when requested")
    lockdown_mode = lockdown_task["community.vmware.vmware_host_lockdown"]["lockdown_mode"]
    assert "esxi_hardening_cfg.lockdown_mode" in lockdown_mode
    assert "esxi.hardening." not in lockdown_mode

    hardening_task = _find_task(tasks, "Apply ESXi hardening advanced options")
    options = hardening_task["community.vmware.vmware_host_config_manager"]["options"]

    for option_value in options.values():
        if isinstance(option_value, str):
            assert "esxi.hardening." not in option_value

    assert "esxi_hardening_cfg.suppress_shell_warning" in options["UserVars.SuppressShellWarning"]
    assert "esxi_hardening_cfg.admin_group" in options["Config.HostAgent.plugins.hostsvc.esxAdminsGroup"]
    assert "esxi_hardening_cfg.dcui_access" in options["DCUI.Access"]
    assert "esxi_hardening_cfg.banner" in options["Annotations.WelcomeMessage"]
    assert "esxi_hardening_cfg.esxi_shell_timeout" in options["UserVars.ESXiShellInteractiveTimeOut"]
    assert "esxi_hardening_cfg.esxi_shell_timeout" in options["UserVars.ESXiShellTimeOut"]
    assert "esxi_hardening_cfg.ssh_enabled" in options["UserVars.SSHEnabled"]


def test_cluster_ha_parameters_and_drs_rules_are_present() -> None:
    tasks = _load_tasks("roles/cluster/tasks/main.yml")

    cluster_task = _find_task(tasks, "Créer / mettre à jour le cluster")
    cluster_args = cluster_task["vmware.vmware.cluster"]

    for required_ha_key in (
        "enable_ha",
        "ha_admission_control_enabled",
        "ha_host_monitoring",
        "ha_isolation_response",
        "ha_vm_restart_priority",
    ):
        assert required_ha_key in cluster_args

    affinity_task = _find_task(tasks, "Créer les règles d'affinité VM/VM")
    anti_affinity_task = _find_task(tasks, "Créer les règles d'anti-affinité VM/VM")

    assert affinity_task["community.vmware.vmware_vm_vm_drs_rule"]["affinity_rule"] is True
    assert anti_affinity_task["community.vmware.vmware_vm_vm_drs_rule"]["affinity_rule"] is False


def test_dvswitch_baseline_includes_network_and_health_check_controls() -> None:
    tasks = _load_tasks("roles/dvswitch/tasks/main.yml")

    dvs_task = _find_task(tasks, "Create or update distributed switches")
    dvs_args = dvs_task["community.vmware.vmware_dvswitch"]

    for required_key in (
        "version",
        "mtu",
        "uplink_quantity",
        "discovery_protocol",
        "discovery_operation",
        "health_check",
    ):
        assert required_key in dvs_args

    health_check = dvs_args["health_check"]
    assert "vlan_mtu" in health_check
    assert "teaming_failover" in health_check


def test_observability_syslog_role_targets_esxi_host_options() -> None:
    tasks = _load_tasks("roles/logging_syslog/tasks/main.yml")

    syslog_task = _find_task(tasks, "Configure ESXi syslog destination")
    options = syslog_task["community.vmware.vmware_host_config_manager"]["options"]

    assert "Syslog.global.logHost" in options
    assert "Syslog.global.logDirUnique" in options
