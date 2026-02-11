# Create a Backup of the entered main group hierarchy with a max depth of 10.

function Get-GroupTreeInternal {
    param(
        [Parameter(Mandatory)][string]$groupDN,
        [int]$depth = 0,
        [int]$maxDepth = 10,
        [System.Collections.Generic.HashSet[string]]$path
    )


    # MaxDepth protection
    if ($depth -ge $maxDepth) {
        return [PSCustomObject]@{
            Name = "Maximum permitted depth reached: $($maxDepth)"
            Members = @()
        }
    }

    # Loop detection at current path
    if ($path.Contains($groupDN)) {
        return [PSCustomObject]@{
            Name    = "[LOOP detected]"
            DN      = $groupDN
            Members = @()
        }
    }

    # Copy path for this branch
    $currentPath = [System.Collections.Generic.HashSet[string]]::new($Path)
    $null = $currentPath.Add($groupDN)

    try {
        $group = Get-ADGroup -Identity $groupDN -Properties DisplayName -ErrorAction Stop
    }
    catch {
        return [PSCustomObject]@{
            Name = "UNKNOWN GROUP"
            Error = $_.Exception.Message
            Members = @()
        }
    }

    $groupName = IF ($group.DisplayName) {
        $group.DisplayName
    } 
    else {
        $group.Name
    }

    try {
        $groupMembers = Get-ADGroupMember -Identity $groupDN -ErrorAction Stop
    }
    catch {
        return [PSCustomObject]@{
            Name = $groupName
            Error = "Members could not be resolved."
            Members = @()
        }
    }

    $members = foreach ($member in $groupMembers) {
        switch ($member.objectClass) {
            "user" {
                $member.Name
              }

            "group" {
                Get-GroupTreeInternal `
                -groupDN $member.DistinguishedName `
                -depth  ($depth +1 ) `
                -maxDepth $maxDepth `
                -path $currentPath
              }
            Default {
                [PSCustomObject]@{
                    Name = $member.Name
                    Type = $member.objectClass
                }
            }
        }
    }

    [PSCustomObject]@{
        Name = $groupName
        Members = $members
    }
}

function Get-GroupTree {
    param (
        [Parameter(Mandatory)][string]$groupIdentity,
        [int]$maxDepth = 10
    )

    try {
        $grp = Get-ADGroup -Identity $groupIdentity -ErrorAction Stop
    }
    catch {
        Write-Log "Group: '$($groupIdentity)'could not be found." ERROR
        Write-Log "Error: $($_.Exception.Message)"
        Rename-Logfile -groupName $Global:mainGroupName
        throw
    }

    $initalPath = [System.Collections.Generic.HashSet[string]]::new()

    Write-Log "Read current group structure '$($grp.Name)'"

    $tree = Get-GroupTreeInternal `
        -groupDN $grp.DistinguishedName `
        -depth 0 `
        -maxDepth $maxDepth `
        -path $initalPath

    return $tree
    
}

function New-GroupBackup {
    param (
        [Parameter(Mandatory)][string]$groupIdentity,
        [Parameter(Mandatory)][string]$outputDirectory,
        [int]$maxDepth = 10
    )

    try {
        if (-not (Test-Path -LiteralPath $outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
            Write-Log "Backup folder created: $($outputDirectory)" SUCCESS
        }

        $tree = Get-GroupTree -groupIdentity $groupIdentity -maxDepth $maxDepth

        $displayName = $tree.Name
        $safeFileName = $displayName -replace '[\\/:*?"<>|]', '_'
        $file = Join-Path $outputDirectory ("$($safeFileName)_$(Get-Date -format 'dd-MM-yyyy').json")

        $tree | ConvertTo-Json -Depth 50 | Out-File -FilePath $file -Encoding utf8

        Write-Log "Backup of the group has been written." SUCCESS
        return $file
    }
    catch {

        Write-Log "Error creating backup:" ERROR
        Write-Log "Error: $($_.Exception.Message)" ERROR
        Rename-Logfile -groupName $Global:mainGroupName
        throw
        
    }

    Export-ModuleMember -Function Get-GroupTree, New-GroupBackup
    
}
