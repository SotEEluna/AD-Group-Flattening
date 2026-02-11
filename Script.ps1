Clear-Host

#region "Load config"
    $config = Get-Content "$($PSScriptRoot)\config\config.json" | ConvertFrom-Json
#endregion

#region "Import Modules"

    Import-Module "$($PSScriptRoot)$($config.Paths.modules.log)" -Force -ErrorAction Stop
    Import-Module "$($PSScriptRoot)$($config.Paths.modules.backup)" -Force -ErrorAction Stop
    Import-Module "$($PSScriptRoot)$($config.Paths.modules.evaluation)" -Force -ErrorAction Stop
    Import-Module "$($PSScriptRoot)$($config.Paths.modules.comparison)" -Force -ErrorAction Stop

#endregion

#region "Global variables"

    # Global variables for the backup and evaluation
    $Global:currentGroup = ""
    $Global:maxDepth = 10
    $Global:currentDepth = 0

#endregion

#region "Userinput Maingroup"

    Write-Log "Enter a group name" INFO
    Write-Host -ForegroundColor Cyan "[INPUT]: Group name: " -NoNewline
    $Global:mainGroupName = Read-Host 
    Clear-Host
    Write-Log "Selected group name: $($Global:mainGroupName)" INPUT

#endregion

#region "Create Backup"

try {
    Write-Log "Start by creating a backup of the group: $($Global:mainGroupName)"
    $outputDir = "$($PSScriptRoot)$($config.Paths.backup)"
    $backupFile = New-GroupBackup -groupIdentity $Global:mainGroupName -outputDirectory $outputDir -maxDepth $Global:maxDepth

    Write-Log "Backup successfully created: $($backupFile)" SUCCESS
}
catch {
    Write-Log "Script error:" Error
    Write-Log "Error: $($_.Exception.Message)" Error
    Rename-Logfile -groupName $Global:mainGroupName
    throw 
}

#endregion

#region "User Evaluation"

    $evaluationOutput = "$($PSScriptRoot)$($config.Paths.evaluation)"

    $evaluationFile = Get-GroupUserEvaluation `
    -groupName $Global:mainGroupName `
    -outputPath $evaluationOutput `
    -maxDepth $Global:maxDepth

#endregion

#region "Compare direct and indirect User"

    $resultOutput = "$($PSScriptRoot)$($config.Paths.result)"

    Write-Log "--------------------------------------------------------------------" INFO
    Write-Log ""
    Write-Log "Start user comparison of the group: $($Global:mainGroupName)" INFO
    Compare-AndFlattenGroupUsers `
        -mainGroup $Global:mainGroupName `
        -evaluationFile $evaluationFile `
        -outPutPath $resultOutput


#endregion

#region "Remove Subgroup"

    Write-Log "--------------------------------------------------------------------" INFO
    Write-Log ""
    Write-Log "Start removing the sub-groups from: $($Global:mainGroupName)" INFO
    Compare-AndRemoveSubGroups `
        -mainGroup $Global:mainGroupName `
        -outPutPath $resultOutput


#endregion

Rename-Logfile -groupName $Global:mainGroupName
