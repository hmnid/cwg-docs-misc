#Requires -RunAsAdministrator
#Requires -Modules NetSecurity, NetTCPIP, ScheduledTasks

<#
.SYNOPSIS
Temporarily blocks observed Warcraft III TCP connections to remote port 443.
.DESCRIPTION
Arms a SYSTEM cleanup task immediately, before scanning or creating rules.
The deadline is three minutes from script startup, not from the last rule.
The task removes this run's rules even if the terminal closes. Startup and
missed-task handling cover reboot/sleep, but cleanup can be delayed while
Windows or Task Scheduler is unavailable. Windows Firewall has no native TTL.
Each run is independent. Battle.net, Agent, localhost and other ports are
excluded. This is a one-time snapshot; new addresses and UDP are not covered.
To undo all rules created by this script (including older versions):
    Get-NetFirewallRule | Where-Object Group -Like 'Pi WC3 HTTPS blocks*' |
        Remove-NetFirewallRule
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Invoke-Wc3HttpsBlock {
    $expires = (Get-Date).AddMinutes(3)
    $runId = [guid]::NewGuid().ToString('N')
    $group = "Pi WC3 HTTPS blocks-$runId"
    $taskName = "Pi-WC3-HTTPS-Cleanup-$runId"

    Register-Wc3Cleanup -Group $group -TaskName $taskName -Expires $expires
    try {
        $targets = @(Get-Wc3HttpsTarget)
        if ($targets.Count -eq 0) {
            Write-Host 'No WC3 TCP connections to remote port 443 found. No rules changed.'
            return
        }

        Add-Wc3HttpsBlock -Targets $targets -Group $group -Expires $expires
        $remaining = [Math]::Ceiling(($expires - (Get-Date)).TotalSeconds)
        if ($remaining -gt 0) {
            Start-Sleep -Seconds $remaining
        }
    } finally {
        # Keep the scheduled fallback if foreground cleanup fails.
        Get-NetFirewallRule | Where-Object Group -EQ $group | Remove-NetFirewallRule
        # The task deletes itself, avoiding a race with its execution.
        Write-Host 'Temporary WC3 HTTPS rules removed. Scheduled cleanup remains as a fallback.'
    }
}

function Register-Wc3Cleanup {
    param([string]$Group, [string]$TaskName, [datetime]$Expires)

    if ((Get-Service -Name Schedule).Status -ne 'Running') {
        throw 'Task Scheduler is not running. No rules created.'
    }

    # Only generated identifiers are interpolated into this SYSTEM command.
    $cleanup = @"
`$ErrorActionPreference = 'Stop'
Get-NetFirewallRule | Where-Object Group -EQ '$Group' | Remove-NetFirewallRule
Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false
"@
    $encodedCleanup = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cleanup))
    $action = New-ScheduledTaskAction `
        -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Argument "-NoProfile -NonInteractive -EncodedCommand $encodedCleanup"
    $triggers = @(
        New-ScheduledTaskTrigger -Once -At $Expires
        New-ScheduledTaskTrigger -AtStartup
    )
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    # No firewall changes are permitted unless registration and verification succeed.
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers `
        -Settings $settings -User 'SYSTEM' -RunLevel Highest | Out-Null
    $task = Get-ScheduledTask -TaskName $TaskName
    if ($task.State -eq 'Disabled' -or -not $task.Settings.Enabled) {
        throw 'Cleanup task is disabled. No rules created.'
    }
    Write-Host "Cleanup armed for $($Expires.ToString('HH:mm:ss')): $TaskName"
}

function Get-Wc3HttpsTarget {
    $processes = @(Get-Process -Name 'Warcraft III' -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        return
    }

    # Read the table once so all PIDs use the same snapshot.
    $connections = @(Get-NetTCPConnection | Where-Object {
        $_.OwningProcess -in $processes.Id -and
        $_.RemotePort -eq 443 -and
        $_.RemoteAddress -notin @('0.0.0.0', '::') -and
        -not [System.Net.IPAddress]::IsLoopback([System.Net.IPAddress]::Parse($_.RemoteAddress))
    })
    $targets = foreach ($process in $processes) {
        $addresses = @($connections |
            Where-Object OwningProcess -eq $process.Id |
            Select-Object -ExpandProperty RemoteAddress -Unique)
        foreach ($address in $addresses) {
            if (-not $process.Path) {
                throw "Cannot read executable path for WC3 PID $($process.Id)."
            }
            [pscustomobject]@{ Program = $process.Path; Address = $address }
        }
    }
    $targets | Sort-Object Program, Address -Unique
}

function Add-Wc3HttpsBlock {
    param([object[]]$Targets, [string]$Group, [datetime]$Expires)

    foreach ($target in $Targets) {
        if ((Get-Date) -ge $Expires) {
            throw 'Cleanup deadline reached before all rules could be created.'
        }
        New-NetFirewallRule -Name "Pi-WC3-HTTPS-$([guid]::NewGuid().ToString('N'))" `
            -Group $Group -DisplayName "WC3 HTTPS block: $($target.Address)" `
            -Direction Outbound -Action Block -Enabled True -Profile Any `
            -Program $target.Program -Protocol TCP `
            -RemoteAddress $target.Address -RemotePort 443 | Out-Null
        Write-Host "Blocked $($target.Program) -> $($target.Address):443"
    }
}

Invoke-Wc3HttpsBlock
