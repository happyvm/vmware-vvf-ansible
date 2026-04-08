#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [Parameter(Mandatory = $true)]
    [string]$SiteName,
    [Parameter(Mandatory = $true)]
    [string]$VCenterAlias,
    [Parameter(Mandatory = $true)]
    [string]$VCenterServer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    throw "Le module VMware.PowerCLI est requis. Installez-le avec: Install-Module VMware.PowerCLI"
}

Import-Module VMware.PowerCLI
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

$credential = Get-Credential -Message "Identifiants vCenter pour export"
Connect-VIServer -Server $VCenterServer -Credential $credential | Out-Null

try {
    $datacenters = foreach ($dc in Get-Datacenter) {
        $clusters = foreach ($cluster in (Get-Cluster -Location $dc)) {
            $hosts = foreach ($vmhost in (Get-VMHost -Location $cluster)) {
                [ordered]@{
                    hostname = $vmhost.Name
                    username = 'root'
                    password = '{{ vault_esxi_root_password }}'
                    dns_servers = @()
                    search_domains = @()
                    ntp_servers = @()
                    vmkernel_interfaces = @()
                }
            }

            [ordered]@{
                name = $cluster.Name
                drs_enabled = [bool]$cluster.DrsEnabled
                ha_enabled = [bool]$cluster.HAEnabled
                host_rules = [ordered]@{
                    affinity = @()
                    anti_affinity = @()
                }
                dvswitches = @()
                hosts = @($hosts)
                dvportgroups = @()
            }
        }

        [ordered]@{
            name = $dc.Name
            clusters = @($clusters)
        }
    }

    $output = [ordered]@{
        vmware_sites = @(
            [ordered]@{
                name = $SiteName
                vcenters = @(
                    [ordered]@{
                        name = $VCenterAlias
                        hostname = $VCenterServer
                        username = '{{ vault_vcenter_username }}'
                        password = '{{ vault_vcenter_password }}'
                        validate_certs = $false
                        local_roles = @()
                        local_accounts = @()
                        datacenters = @($datacenters)
                    }
                )
            }
        )
    }

    $yaml = $output | ConvertTo-Yaml
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    Set-Content -Path $OutputPath -Value $yaml -Encoding UTF8
    Write-Host "Export terminé: $OutputPath"
}
finally {
    Disconnect-VIServer -Server $VCenterServer -Confirm:$false | Out-Null
}
