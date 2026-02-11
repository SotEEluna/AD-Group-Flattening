# Create a log file to document the script execution as well as the terminal output.

$config = Get-Content "$(Split-Path $PSScriptRoot -Parent)\config\config.json" | ConvertFrom-Json
$logFile = "$(Split-Path $PSscriptRoot -Parent)$($config.Paths.logFile)"

function Write-Log {
    param (
        $message,
        [ValidateSet('INFO','INPUT','ERROR','SUCCESS')][string]$level = 'INFO'
    )

    "[$(Get-Date -Format "HH:mm:ss")][$level]: $($message)" | out-File -FilePath $logFile -Append

    switch ($level) {
        "INFO" {
            Write-Host -ForegroundColor White "[$($level)]: $($message)"
          }

        "ERROR" {
            Write-Host -ForegroundColor Red "[$($level)]: $($message)"
          }

        "INPUT" {
            Write-Host -ForegroundColor Cyan "[$($level)]: $($message)"
        }

        "SUCCESS" {
            Write-Host -ForegroundColor Green "[$($level)]: $($message)"
        }
        Default {"INFO"}
    }
}


function Rename-Logfile {
    param (
        [Parameter(Mandatory)][string]$groupName
    )

    if (-not (Test-Path $logFile)) {
        throw "Log file doesnt exist: $($logFile)"
    }

    $path = "$(Split-Path $PSscriptRoot -Parent)$($config.Paths.log)"
    $newName = "$($groupName)_log_$(Get-Date -format 'dd-MM-yyyy').txt"
    $targetPath = Join-Path $path $newName

    try {
        if (Test-Path $targetPath) {
            Remove-Item -Path "$($targetPath)" -Force
            Write-Log "A duplicate log file was found. It will be removed and replaced with the new one."
            Rename-Item -Path $logFile -NewName $newName -Force -ErrorAction Stop

        }
        else {
            Rename-Item -Path $logFile -NewName $newName -Force -ErrorAction Stop
        }
        
        
        $logFile = Join-Path $path $newName

        Write-Host "[SUCCESS]: Log file renamed in $newName" -ForegroundColor Green
        "[$(Get-Date -Format "HH:mm:ss")][SUCCESS]: Log successfully renamed in $($newName)" | out-File -FilePath $logFile -Append
    }
    catch {
        
    }
}


if (-not (Test-Path $logFile)) {
    
    New-Item -ItemType File -Path $logFile -Force | Out-Null
    Write-Log "Log file created: $($logFile)" INFO
    Write-Log "Script started by user: $($Env:USERNAME)"
}
else {
    Clear-Content -Path $logFile -Force
    Write-Log "Log file cleared: $($logFile)" INFO
    Write-Log "Script started by user: $($Env:USERNAME)"
}



Export-ModuleMember -Function Write-Log, Rename-Logfile
