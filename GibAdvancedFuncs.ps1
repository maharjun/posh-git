function gibGetFileRev() {
	param(
        [parameter(mandatory=$true, position=0)][string] $RevisionName = "HEAD",
        [parameter(mandatory=$true, position=1, ValueFromRemainingArguments=$true)]$FileNames
	)
    
    $Rev_Hash = (git rev-list $RevisionName -1)
    $Rev_Hash = $Rev_Hash[0..6] -join ''
    
    $HasDoubleEq = $FileNames | where {$_ -like '=='}
    $Rev_Hash
    &{
        if($HasDoubleEq -eq $null){
            $FileNames
        }
        else{
            [int] $IndexofDoubleEq = [array]::IndexOf($FileNames, '==')
            $FileNames[($IndexofDoubleEq+1)..($FileNames.count)]
        }
    } | 
    foreach {$_ -replace "\\",'/'} | 
        foreach{
            if ($_ -match "(?<path>.*/)(?<FileName>[^/]*?)\.(?<Extension>[^/\.]+)$"){
                $outputFile = "$($matches['path'])$($matches['FileName'])_$($Rev_Hash).$($matches['Extension'])"
            }
            elseif ($_ -match "(?<FileName>[^/]*)\.(?<Extension>[^/\.]+)$"){
                $outputFile = "./$($matches['FileName'])_$($Rev_Hash).$($matches['Extension'])"
            }
            [System.IO.File]::WriteAllLines(($(pwd).Path + '/' + $outputFile) , (git show "$($Rev_Hash):$($_)"))
        }
}

function gibShowSubModuleStatus() {
	
	[string[]] $OutputsSubModuleNames;
	[string[]] $OutputsSubModuleCommitHash;
	[string[]] $OutputsSubModuleCommitName;
	[string[]] $OutputsSubModuleCommitDescribe;
	
	git submodule status | foreach {
		if ($_ -match "^[ \+U](?<CommitHash>\S*) (?<SubModPath>\S*) (?<describe>\(\S*\))") {
			$OutputsSubModuleNames += @($Matches["SubModPath"])
			$OutputsSubModuleLog = (git -C $Matches['SubModPath'] log head --oneline -1)
			$OutputsSubModuleCommitDescribe += @($Matches["describe"])
			
			$OutputsSubModuleNames
			""
			$OutputsSubModuleCommitHash
			""
			$OutputsSubModuleCommitName
			""
			$OutputsSubModuleCommitDescribe
			""
			
			if ($OutputsSubModuleLog -match "^(?<CommitHash>\S*) (?<CommitName>.*)$") {
				$OutputsSubModuleCommitHash += @($Matches["CommitHash"])
				$OutputsSubModuleCommitName += @($Matches["CommitName"])
			}
		}
		elseif ($_ -match "^-(?<CommitHash>\S*) (?<SubModPath>\S*) \(\S*\)") {
			$OutputsSubModuleNames += @($Matches["SubModPath"])
			$OutputsSubModuleCommitHash += @("")
			$OutputsSubModuleCommitDescribe += @("")
			$OutputsSubModuleCommitName += @("UnInitialized")
		}
	}
	
	$MaxLenSubModuleNames          = $OutputSubModuleNames          | %{$_.length} | measure -Maximum;
	$MaxLenSubModuleCommitHash     = $OutputSubModuleCommitHash     | %{$_.length} | measure -Maximum;
	$MaxLenSubModuleCommitName     = $OutputSubModuleCommitName     | %{$_.length} | measure -Maximum;
	$MaxLenSubModuleCommitDescribe = $OutputSubModuleCommitDescribe | %{$_.length} | measure -Maximum;
	
	1..($OutputSubModuleNames.length) | foreach {
	
		"{0,-$MaxLenSubModuleNames} {1,-$MaxLenSubModuleCommitHash} {2,-$MaxLenSubModuleCommitName} {3, -$MaxLenSubModuleCommitDescribe}" -f
		$OutputSubModuleNames[$_], $OutputSubModuleCommitHash[$_], $OutputSubModuleCommitName[$_], $OutputsSubModuleCommitDescribe[$_]
	}
	
}