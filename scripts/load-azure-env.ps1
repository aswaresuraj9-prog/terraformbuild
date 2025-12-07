<#
.SYNOPSIS
  Loads Azure credentials and Terraform variables from a .env file.

.DESCRIPTION
  Reads KEY=VALUE pairs from a .env file and sets them as environment
  variables for the current PowerShell process (or persistently for the user
  when -Persist is specified). Comments (# ...) and blank lines are ignored.

.PARAMETER EnvFile
  Path to the .env file. Defaults to ".\.env" relative to the current directory.

.PARAMETER Persist
  If set, also writes variables to the User scope so new shells inherit them.

.EXAMPLE
  .\scripts\load-azure-env.ps1 -EnvFile .\.env
  .\scripts\load-azure-env.ps1 -EnvFile .\.env -Persist

.NOTES
  Required AzureRM provider env vars:
    - ARM_SUBSCRIPTION_ID
    - ARM_TENANT_ID
    - ARM_CLIENT_ID
    - ARM_CLIENT_SECRET

  Optional common Terraform vars (prefixed with TF_VAR_):
    - TF_VAR_temp_vm_admin_password
#>

[CmdletBinding()]
param(
  [Parameter(Position=0)]
  [string]$EnvFile = ".\.env",

  [switch]$Persist
)

function Write-Masked {
  param(
    [string]$Name,
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    Write-Host ("{0} = (empty)" -f $Name) -ForegroundColor Yellow
    return
  }

  $len = $Value.Length
  if ($len -le 5) {
    $masked = "*" * $len
  } else {
    $masked = $Value.Substring(0,3) + ("*" * ($len-5)) + $Value.Substring($len-2,2)
  }
  Write-Host ("{0} = {1}" -f $Name, $masked) -ForegroundColor Cyan
}

function Set-EnvVar {
  param(
    [string]$Name,
    [string]$Value,
    [bool]$PersistUser
  )

  # Set for current PowerShell process
  [Environment]::SetEnvironmentVariable($Name, $Value, "Process")

  # Optionally persist for User scope (new shells)
  if ($PersistUser) {
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
  }
}

function Get-EnvVar {
  param([string]$Name)
  $v = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($v)) {
    $v = [Environment]::GetEnvironmentVariable($Name, "User")
  }
  if ([string]::IsNullOrWhiteSpace($v)) {
    $v = [Environment]::GetEnvironmentVariable($Name, "Machine")
  }
  return $v
}

if (!(Test-Path -Path $EnvFile)) {
  throw "Env file not found: $EnvFile"
}

$lines = Get-Content -Path $EnvFile -ErrorAction Stop
$setCount = 0

foreach ($line in $lines) {
  $trim = $line.Trim()
  if ($trim -eq "" -or $trim.StartsWith("#")) { continue }

  $eqIdx = $trim.IndexOf("=")
  if ($eqIdx -lt 1) { continue }

  $key = $trim.Substring(0, $eqIdx).Trim()
  $val = $trim.Substring($eqIdx+1).Trim()

  # Strip surrounding quotes if present
  if ((($val.StartsWith('"')) -and ($val.EndsWith('"'))) -or (($val.StartsWith("'")) -and ($val.EndsWith("'")))) {
    $val = $val.Substring(1, $val.Length-2)
  }

  Set-EnvVar -Name $key -Value $val -PersistUser:$Persist.IsPresent
  Write-Masked -Name $key -Value $val
  $setCount++
}

Write-Host ("`nLoaded {0} variable(s) from {1}`n" -f $setCount, (Resolve-Path $EnvFile)) -ForegroundColor Green

# Validate required Azure vars
$required = @("ARM_SUBSCRIPTION_ID","ARM_TENANT_ID","ARM_CLIENT_ID","ARM_CLIENT_SECRET")
$missing = @()
foreach ($r in $required) {
  $val = Get-EnvVar -Name $r
  if ([string]::IsNullOrWhiteSpace($val)) {
    $missing += $r
  }
}

if ($missing.Count -gt 0) {
  Write-Warning ("Missing required Azure environment variables: {0}" -f ($missing -join ", "))
  Write-Host "Set them in your .env and re-run this script." -ForegroundColor Yellow
} else {
  Write-Host "All required Azure variables are present." -ForegroundColor Green
}
