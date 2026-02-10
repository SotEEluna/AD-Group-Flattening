Clear-Host

#region "Lade Config"
    $config = Get-Content "$($PSScriptRoot)\config\config.json" | ConvertFrom-Json
#endregion

#region "Import Modules"

    Import-Module "$($PSScriptRoot)$($config.Paths.modules.log)" -Force -ErrorAction Stop
    Import-Module "$($PSScriptRoot)$($config.Paths.modules.backup)" -Force -ErrorAction Stop
    Import-Module "$($PSScriptRoot)$($config.Paths.modules.evaluation)" -Force -ErrorAction Stop
    Import-Module "$($PSScriptRoot)$($config.Paths.modules.comparison)" -Force -ErrorAction Stop

#endregion

#region "Globale Variablen"

    # Variablen für das Backup und die Auswertungen
    $Global:currentGroup = ""
    $Global:maxDepth = 10
    $Global:currentDepth = 0

#endregion

#region "Abfrage der "AD" Gruppe"

    Write-Log "Bitte den Gruppennamen eingeben: " INFO
    Write-Host -ForegroundColor Cyan "[INPUT]: Gruppenname: " -NoNewline
    $Global:mainGroupName = Read-Host 
    Clear-Host
    Write-Log "Gruppenname: $($Global:mainGroupName)" INPUT

#endregion

#region "Backup erstellen"

try {
    Write-Log "Beginne mit dem erstellen des Backups der Gruppe: $($Global:mainGroupName)"
    $outputDir = "$($PSScriptRoot)$($config.Paths.backup)"
    $backupFile = New-GroupBackup -groupIdentity $Global:mainGroupName -outputDirectory $outputDir -maxDepth $Global:maxDepth

    Write-Log "Backup erfolgreich: $($backupFile)" SUCCESS
}
catch {
    Write-Log "Skriptfehler" Error
    Write-Log "Fehler: $($_.Exception.Message)" Error
    Rename-Logfile -groupName $Global:mainGroupName
    throw 
}

#endregion

#region "Userauswertung der Gruppe"

    $evaluationOutput = "$($PSScriptRoot)$($config.Paths.evaluation)"

    $evaluationFile = Get-GroupUserEvaluation `
    -groupName $Global:mainGroupName `
    -outputPath $evaluationOutput `
    -maxDepth $Global:maxDepth

#endregion

#region "Vergleiche die User welche direkt und indirekt berechtigt sind"

    $resultOutput = "$($PSScriptRoot)$($config.Paths.result)"

    Write-Log "--------------------------------------------------------------------" INFO
    Write-Log ""
    Write-Log "Starte User-Vergleich der Gruppe: $($Global:mainGroupName)" INFO
    Compare-AndFlattenGroupUsers `
        -mainGroup $Global:mainGroupName `
        -evaluationFile $evaluationFile `
        -outPutPath $resultOutput


#endregion

#region "Entferne die Sub-Gruppen aus der Hauptgruppe"

    Write-Log "--------------------------------------------------------------------" INFO
    Write-Log ""
    Write-Log "Starte das entfernen der Sub-Gruppen aus $($Global:mainGroupName)" INFO
    Compare-AndRemoveSubGroups `
        -mainGroup $Global:mainGroupName `
        -outPutPath $resultOutput


#endregion

Rename-Logfile -groupName $Global:mainGroupName
# Read-Host "Enter um das Skript zu beenden...."
