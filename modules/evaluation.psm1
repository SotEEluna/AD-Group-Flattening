function Get-GroupUserEvaluation {
    param (
       [Parameter(Mandatory)][string]$groupName,
       [Parameter(Mandatory)][string]$outputPath,
       [int]$maxDepth = 10
    )
    Write-Log "--------------------------------------------------------------------" INFO
    Write-Log ""
    Write-Log "Starte User-Auswertung der Gruppe: $($groupName)" INFO

    $users = @{}

    function Resolve-Group {
        param (
            [string]$group,
            [int]$depth
        )
        
        if ($depth -gt $maxDepth) {
            Write-Log "Maximale Tiefe erreicht bei Gruppe: $($group)" ERROR
            return
        }

        Write-Log "Untersuche Gruppe: $($group) (Tiefe $($depth))"

        $members = Get-ADGroupMember -Identity $group

        foreach ($member in $members) {
            switch ($member.objectClass) {
                "user" { 
                    if (-not $users.ContainsKey($member.samAccountName)) {
                        $users[$member.samAccountName] = [PSCustomObject]@{
                            samAccountName = $member.samAccountName
                            DisplayName = $member.Name
                        }
                    }
                 }
                "group" { 
                    Resolve-Group -group $member.samAccountName -depth ($depth + 1)
                 }
            }
        }
    }

    Resolve-Group -group $groupName -depth 0
    $resultFile = Join-Path $outputPath "$($groupName)_auswertung_result.json"

    $users.Values | 
    Sort-Object samAccountName | 
    Convertto-Json -Depth 3 | 
    Set-Content -Path $resultFile -Encoding UTF8

    Write-Log "User-Auswertung abgeschlossen. Ergebnis: $($resultFile)" SUCCESS
    return $resultFile
}


Export-ModuleMember -Function Get-GroupUserEvaluation



