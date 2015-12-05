$script:current_branch_path = ""

. .\GitTabExpansion.ps1
. .\GibAdvancedFuncs.ps1

function gibResetBranchDir(){
    $script:current_branch_path = ""
}

function gibCheckPath($path_to_check = $null){
    
    if($null -eq $path_to_check){
        if ($null -eq $input){
            $path_to_check = $script:current_branch_path
        }
        else{
            $path_to_check = $input[0]
        }
    }
    
    # convert all '\' to '/'
    $path_to_check = $path_to_check -replace "\\",'/'
    
    # Add '/' if it doesnt end with '/'
    if ($path_to_check -match "(.*?)(?<!/)$"){
        $path_to_check =  $Matches[1] + '/'
    }
    
    if ($path_to_check -eq '/'){
        # empty path is valid
        $true
        return
    }
    
    # Get all branches (in the event of a nonempty string with trailing '/')
    $branches = @(git branch --no-color | foreach { if($_ -match "^\*?\s*(?<ref>.*)") { $matches['ref'] } }) +
                @(git branch --no-color -r | foreach { if($_ -match "^  (?<ref>\S+)(?: -> .+)?") { $matches['ref'] } })
    
    $branches = $branches | 
                        where { $_ -ne '(no branch)' -and $_ -like "$path_to_check*"}
    
    if ($branches.count -gt 0){
        $true
        return
    }
    else{
        $false
        return
    }
}

function gibCheckBranch($branch_path = $null){
    if ($null -eq $branch_path){
        $false
    }
    else{
        $no_of_branches = $(git rev-parse --quiet --verify "$branch_path^{commit}").count
        if ($no_of_branches -eq 1){
            $true
        }
        else{
            $false
        }
    }
}

function gibCheckCommitHash(){
    Param(
        [CmdletBinding()]
        [string] $commit_hash
    )
    if ($null -eq $commit_hash){
        $false
    }
    else{
        if($commit_hash -match "^[0-9a-f]+" -and $commit_hash.Length -ge 7){
            $no_of_commits = $(git rev-parse --quiet --verify "$commit_hash^{commit}").count
            if ($no_of_commits -eq 1){
                $true
            }
            else{
                $false
            }
        }
        else{
            $false
        }
    }
}

function gibCleanRelPath($relpath, $abspath=$script:current_branch_path){
    
    $rel_path = $relpath
    $abs_path = $abspath
    if(-not (gibCheckPath $abs_path)){
        $abs_path
        Write-Error "The Current Directory '$current_dir' is invalid"
        return
    }
    [string] $cleaned_rel_path = ""
    
    if ($rel_path -ne ""){
        
        # replace '\' by '/'
        $rel_path = $rel_path -replace "\\", "/"
        
        # remove trailing '/'
        $rel_path = $rel_path -replace "(.*?)/?$", '$1'
        $abs_path = $abs_path -replace "(.*?)/?$", '$1'
        
        # split path by '/'
        $rel_path_parts = $rel_path.split("/")
        $abs_path_parts = $abs_path.split("/")
        
        [int[]] $ValidPathSegments = $null
        [int]   $SegmentIndex = 0
        
        $rel_path_parts | foreach {
            switch -regex ($_){
                "^$"{
                    # reset path. this is reminescent of /<address>
                    $ValidPathSegments = @($SegmentIndex)
                    $abs_path_parts = @("")
                }
                "^\.$"{
                    # do nothing for ./
                    # add segment only if first segment
                    
                    if($ValidPathSegments.count -eq 0){
                        $ValidPathSegments += $SegmentIndex
                    }
                }
                "^\.\.$"{
                    if ($abs_path_parts.count -ge 2){
                        # if (Last Segment is '..' '.' or '' or it is first element then add)
                        # else delete previous
                        if($ValidPathSegments.count -eq 0 -or $rel_path_parts[$ValidPathSegments[-1]] -match "^(\.\.|\.)"){
                            $ValidPathSegments += $SegmentIndex
                        }
                        elseif ($ValidPathSegments.count -eq 1){
                            $ValidPathSegments = $null
                        }
                        else{
                            $ValidPathSegments = $ValidPathSegments[0..($ValidPathSegments.count-2)]
                        }
                        $abs_path_parts = $abs_path_parts[0..($abs_path_parts.count-2)]
                    }
                    else{
                        # if abs is not already in root and <previous conditions>, then add
                        if ($abs_path_parts -ne ''){
                            if($ValidPathSegments.count -eq 0 -or $rel_path_parts[$ValidPathSegments[-1]] -match "^(\.\.|\.)"){
                                $ValidPathSegments += $SegmentIndex
                            }
                            elseif ($ValidPathSegments.count -eq 1){
                                $ValidPathSegments = $null
                            }
                            else{
                                $ValidPathSegments = $ValidPathSegments[0..($ValidPathSegments.count-2)]
                            }
                        }
                        $abs_path_parts = @("")
                    }
                }
                "^[^\.\$\\/\r\n]+$"{
                    # Add current folder
                    # $rel_path_parts += $_
                    
                    # special case in case path_parts_current contains only ""
                    if ($abs_path_parts.count -eq 1 -and $abs_path_parts[0] -eq ""){
                        $abs_path_parts[0] = $_
                    }
                    else{
                        $abs_path_parts = $abs_path_parts + $_
                    }
                    $ValidPathSegments += $SegmentIndex
                }
            }
            $SegmentIndex = $SegmentIndex + 1;
            # echo "ValidPathSegments: $ValidPathSegments"
        }
        if($ValidPathSegments.count -eq 0){
            $cleaned_rel_path = ""
        }
        elseif($ValidPathSegments.count -eq 1 -and $rel_path_parts[$ValidPathSegments[0]] -eq ''){
            $cleaned_rel_path = '/'
        }
        else{
            $cleaned_rel_path = $rel_path_parts[$ValidPathSegments] -join '/'
        }
    }
    
    $cleaned_rel_path
}

function gibConvertReltoAbs(){
    param(
        [string]$rel_path = "",
        [string]$current_dir = $script:current_branch_path
    )
    
    $abs_path = $current_dir
    $abs_path | clip
    
    if(-not (gibCheckPath $abs_path)){
        $abs_path
        Write-Error "The Current Directory '$current_dir' is invalid"
        return
    }
    
    if ($rel_path -ne ""){
        
        # replace '\' by '/'
        $rel_path = $rel_path -replace "\\", "/"
        
        # remove trailing '/'
        $rel_path = $rel_path -replace "(.*?)/?$", '$1'
        $abs_path = $abs_path -replace "(.*?)/?$", '$1'
        
        # split path by '/'
        $rel_path_parts = $rel_path.split("/")
        $abs_path_parts = $abs_path.split("/")
        
        $rel_path_parts | foreach {
            switch -regex ($_){
                "^$"{
                    # reset path. this is reminescent of /<address>
                    $abs_path_parts = @("")
                }
                "^\.$"{
                    # do nothing for ./
                }
                "^\.\.$"{
                    if ($abs_path_parts.count -ge 2){
                        $abs_path_parts = $abs_path_parts[0..($abs_path_parts.count-2)]
                    }
                    else{
                        $abs_path_parts = @("")
                    }
                }
                "^[^\.\$\\/\r\n]+$"{
                    # Add current folder
                    # $rel_path_parts += $_
                    
                    # special case in case path_parts_current contains only ""
                    if ($abs_path_parts.count -eq 1 -and $abs_path_parts[0] -eq ""){
                        $abs_path_parts[0] = $_
                    }
                    else{
                        $abs_path_parts = $abs_path_parts + $_
                    }
                }
            }
        }
        
        $abs_path = ($abs_path_parts -join '/' )
    }
    
    $abs_path
}

function gibBranchDirList() {
    param(
        [Parameter(Position=0)]
        [string]$regexp = ".*",
        [string]$relpath = '.',
        [switch]$recursive,
        [switch]$nondisplaymode
    )
    
    # a pure '/' path should be converted into '' to fit the branch naming convention
    $local_curr_branch_path = $script:current_branch_path
    $final_branch_path = gibConvertReltoAbs($relpath)
    
    
    $branches = @(git branch --no-color | foreach { if($_ -match "^\*?\s*(?<ref>.*)") { $matches['ref'] } }) +
                @(git branch --no-color -r | foreach { if($_ -match "^  (?<ref>\S+)(?: -> .+)?") { $matches['ref'] } })
    
    # Select by path.
    # Strip subsequent path if exists and add prefix
    # Selecting Elems which match regex
    
    if (-not $recursive){
        $branches = $branches |
                        where { $_ -ne '(no branch)' -and $_ -like "$($final_branch_path)*" } | 
                        foreach {
                            if ($_ -match "^$($final_branch_path)/?(?<CurrentRefName>[^/\r\n]*/?).*"){
                                $Matches['CurrentRefName']
                            }
                        } |
                        where {$_ -match "^$regexp"}
    }
    else{
        $branches = $branches |
                        where { $_ -ne '(no branch)' -and $_ -like "$($final_branch_path)*" } | 
                        foreach {
                            if ($_ -match "^$($final_branch_path)/?(?<CurrentRefName>[^\r\n]*)"){
                                $Matches['CurrentRefName']
                            }
                        } |
                        where {$_ -match "^$regexp"}
    }
    
    # Get all unique names
    $branches = $branches | Sort-Object | Get-Unique
    
    # $branches = $branches
    # $branches = $branches |
                    # where { $_ -ne '(no branch)' -and $_ -like "$filter*" } |
                    # foreach { $prefix + $_ }
    if(-not $nondisplaymode) {echo ""}
    $branches
    if(-not $nondisplaymode) {echo ""}
}

function gibSetBranchDir($relpath = ""){
    
    $abs_path = gibConvertReltoAbs($relpath)
    
    # validate new path
    
    if (-not (gibCheckPath($abs_path))){
        Write-Error "'$abs_path' is an invalid branch directory"
    }
    else{
        $script:current_branch_path = $abs_path
    }
    
    $script:current_branch_path
}

function gibRelBranches($filter, $includeHEAD = $false) {

    $prefix = $null
    if ($filter -match "^(?<from>\S*\.{4,5})(?<to>.*)") {
        $prefix = $matches['from']
        $filter = $matches['to']
    }
    # Handling the splitting into path and name
    # note, here, as contrary to normal convention, 
    # the path doesnt carry the '/'
    
    if ($filter -match "^(?<path>.*/)(?<refname>[^/\r\n]*$)"){
        $filter_path    = $matches['path']
        $filter_refname = $matches['refname']
    }
    else {
        $filter_path = ""
        $filter_refname = $filter
    }
    
    # clean the filter relative path
    # filter-path contains the final slash, and along with
    # the provision in gibCleanRelPath, appropriately
    # segregates the single '/' path case
    # all other cases are bereft of the final '/'
    $filter_path = gibCleanRelPath($filter_path)
    
    $branches = @(
                    gibBranchDirList -regexp "$($filter_refname).*" -relpath $filter_path -recursive -nondisplaymode |
                    foreach {
                        # in case of single '/' or '' path, just append
                        # else, append with '/'
                        if ($filter_path -match "^(/|)$"){
                            $filter_path + $_
                        }
                        else{
                            $filter_path + '/' + $_
                        }
                    }
                )
    $head_branches = @(if ($includeHEAD) { 'HEAD','FETCH_HEAD','ORIG_HEAD','MERGE_HEAD' })
    
    # Select by path.
    # Strip subsequent path if exists and add prefix
    $branches = $branches |
                    where { $_ -ne '(no branch)'} | 
                    foreach {
                        # $($filter_path)/?$($filter_refname) because if $filter_path
                        # is empty, there will be no slash
                        
                        # this is to convert all '.' to '\.' to not confuse regex
                        $temp_filter_path = $filter_path -replace "\.", '\.'
                        $temp_filter_refname = $filter_refname -replace "\.", '\.'
                        
                        if ($_ -match "^(?<CurrentPath>$($temp_filter_path)/?$($temp_filter_refname)[^/\r\n]*)/?.*"){
                            $prefix + $Matches['CurrentPath']
                        }
                    }
    
    # Get all unique names
    $branches = $branches | Sort-Object | Get-Unique
    
    # Head branches only when no path is specified
    if ($filter_path -eq ''){
        $branches = @($branches) + $head_branches
    }
    
    # $branches = $branches
    # $branches = $branches |
                    # where { $_ -ne '(no branch)' -and $_ -like "$filter*" } |
                    # foreach { $prefix + $_ }

    $branches
}

function gibRenameBranches() {
    Param(
        [string[]]
        [parameter(mandatory=$true, position=0, ValueFromRemainingArguments=$true)]$renameList
    )
    
    if ($renameList.count -eq 0){
        return
    }
    
    [string[]] $errorList
    # split the originalName and NewName
    [string[]] $originalNames = $renameList | foreach {
                                    if ($_ -match "^(?<origName>.+?):(.+?)$"){
                                        $Matches["origName"]
                                    }
                                    else{
                                        Throw "Error: $_ does not match the <originalName>:<newName> format"
                                    }
                                }
    [string[]] $newNames      = $renameList | foreach {
                                    if ($_ -match "^(.+?):(?<newName>.+?)$"){
                                        $Matches["newName"]
                                    }
                                }
	
    # find the hashes of all given branches and verify the branches in the process
    [string[]] $branchCommitHashes = $originalNames | foreach{
                                         $currentBranchHash = (git rev-parse --quiet --verify "$_^{commit}")
                                         if ($currentBranchHash.count -ge 1){
                                             $currentBranchHash
                                         }
                                         else {
                                             Throw "Error: $_ is not a valid branch"
                                         }
                                     }
    
    [int[]] $branchNameIndex = 0..($originalNames.count-1)
	
	# see if any of the original names are subpaths of the new name
	# in that case throw error as such a renaming takes multiple steps.
	$branchNameIndex | foreach {
		$origName = $originalNames[$_]
        $newName = $newNames[$_]
		
		if ($newName -match "$origName/.*"){
			Throw "$origName is a subpath of $newName. This will lead to errors during remote renaming. Aborting Rename."
		}
	}
	
	# rename branches to new names
	echo "`nRenaming Local Branches"
    $branchNameIndex | foreach {
        
        $origName = $originalNames[$_]
        $newName = $newNames[$_]
        $branchHash = $branchCommitHashes[$_]
        
        # check if the newName already exists
        if ((gibCheckBranch $newName) -or (gibCheckPath $newName) -or (gibCheckCommitHash $newName)){
            Throw "Error: The Name $newName already exists. Cannot replace"
        }
        else {
            # rename the required branch
            git branch -m $origName $newName 1>$null
			if (-not $?) {
				Throw "git based error"
			}
			else {
				$origName + ' -> ' + $newName
			}
        }
    }
	
    # find all the old branches which are cofigured to be pushed
    # to origin
    [int[]] $origOriginBranchIndex = (0..($originalNames.count-1)) | where {gibCheckBranch "origin/$($originalNames[$_])"}
    
    # for all new branches which correspond to branches which
    # correspond to branches which track origin, we push it to 
    # origin under the new name to create the new remote branches
    if ($origOriginBranchIndex.count -ge 1){
		echo "`nCreating Remote branches: "
        $newBranchList = ($newNames[$origOriginBranchIndex] | foreach {$_ + ':' + $_}) -join ' '
        Invoke-Expression "git push origin $newBranchList"
		if (-not $?) {
			Throw "git based error"
		}
    }
    
	# reset upstream of all the new named branches.
	if ($origOriginBranchIndex.count -ge 1){
        echo "`nUpdating Upstream branches: "
		$origOriginBranchIndex | foreach{
			git branch --set-upstream-to="origin/$($newNames[$_])" $newNames[$_] 1>$null
			if (-not $?) {
				Throw "git based error"
			}
			else {
				$newNames[$_] + " -> " + "origin/$($newNames[$_])"
			}
		}
    }
	
    # delete all the old branches in origin
    
    if ($origOriginBranchIndex.count -ge 1){
		echo "`nRemoving Old Remote Branches: "
        $oldBranchList = $originalNames[$origOriginBranchIndex] | foreach { ":" + $_}
        $oldBranchList = $oldBranchList -join ' '
        Invoke-Expression "git push origin $oldBranchList"
		if (-not $?) {
			Throw "git based error"
		}
    }
}

function gibRename(){
	Param(
		[string] [parameter(position=0, mandatory=$true)] $originalName,
		[string] [parameter(position=1, mandatory=$true)] $newName,
		[string] [parameter(position=2, mandatory=$false)] $currentDir=$script:current_branch_path
	)
	
	# separate Path from Item Name
	if ($originalName -match "^(?<path>.*)/(?<name>[a-zA-Z][\-a-zA-Z0-9_/]*)$"){
		$originalPath = $Matches["path"]
		$originalName = $Matches["name"]
	}
	elseif ($originalName -match "^[a-zA-Z][\-a-zA-Z0-9_/]*$"){
		$originalPath = ""
		$originalName = $originalName
	}
	else {
		Throw "$originalName is not a possible Branch Name"
	}
	
	# validate newName
	if ($newName -notmatch "^[a-zA-Z][\-a-zA-Z0-9_]*$") {
		Throw "$newName is not a possible Branch Name"
	}
	
	# convert Path from relative to absolute
	$originalPath = gibConvertReltoAbs $originalPath
	$originalPath
	if ($originalPath.Length -gt 0) { $originalPath = $originalPath + '/'; }
	
	# if item is Branch Dir, then list all branches in that Dir
	[string[]] $branchNameList
	[string[]] $newBranchNameList
	if (gibCheckPath "$originalPath$originalName") {
		# list out all the local branches
		$branchNameList = @(git branch --no-color | 
							foreach { if($_ -match "^\*?\s*(?<ref>.*)") { $matches['ref'] } } |
							where {$_ -like "$originalPath$originalName/*"})
		# calculate new branch name
		$newBranchNameList = @($branchNameList | foreach { 
								if($_ -match "^(?<path>$originalPath)($originalName)/(?<remainingpath>.*)$"){
									$Matches["path"] + $newName + '/' + $Matches["remainingpath"]
								}
							 })
	}
	elseif (gibCheckBranch "$originalPath$originalName") {
		$branchNameList = @("$originalPath$originalName")
		$newBranchNameList = @("$originalPath$newName")
	}
	if ($branchNameList.count -eq 0){
		Throw "$originalPath$originalName is not a valid Item or is non replaceable (possible remote branch)"
	}
	else{
		$replacementArr = (0..($branchNameList.count-1)) | foreach {$branchNameList[$_] + ':' + $newBranchNameList[$_]}
		gibRenameBranches $replacementArr
	}
}

function gibMove(){
	Param(
		[string] [parameter(position=0, mandatory=$true)] $originalName,
		[string] [parameter(position=1, mandatory=$true)] $newPath,
		[string] [parameter(position=2, mandatory=$false)] $currentDir=$script:current_branch_path
	)
	
	# separate Path from Item Name
	if ($originalName -match "^(?<path>.*)/(?<name>[a-zA-Z][\-a-zA-Z0-9_/]*)$"){
		$originalPath = $Matches["path"]
		$originalName = $Matches["name"]
	}
	elseif ($originalName -match "^[a-zA-Z][\-a-zA-Z0-9_/]*$"){
		$originalPath = ""
		$originalName = $originalName
	}
	else {
		Throw "$originalName is not a possible Branch Name"
	}
	
	# validate newPath
	$newPathSegments = $newPath -split '/'
	$newPathSegments | foreach {
		if ($_ -notmatch "^([\-a-zA-Z0-9_]*[a-zA-Z][\-a-zA-Z0-9_]*|\.\.|\.|)$") {
			Throw "$newName is not a possible Branch Name"
		}
	}
	
	# convert Path from relative to absolute
	$originalPath = gibConvertReltoAbs $originalPath
	if ($originalPath.Length -gt 0) { $originalPath = $originalPath + '/'; }
	$newPath = gibConvertReltoAbs $newPath
	if ($newPath.Length -gt 0) { $newPath = $newPath + '/'; }
	
	# if item is Branch Dir, then list all branches in that Dir
	[string[]] $branchNameList
	[string[]] $newBranchNameList
	if (gibCheckPath "$originalPath$originalName") {
		# list out all the local branches
		$branchNameList = @(git branch --no-color | 
							foreach { if($_ -match "^\*?\s*(?<ref>.*)") { $matches['ref'] } } |
							where {$_ -like "$originalPath$originalName/*"})
		# calculate new branch name
		$newBranchNameList = @($branchNameList | foreach { 
								if($_ -match "^($originalPath)($originalName)/(?<remainingpath>.*)$"){
									$newPath + $originalName + '/' + $Matches["remainingpath"]
								}
							 })
	}
	elseif (gibCheckBranch "$originalPath$originalName") {
		$branchNameList = @("$originalPath$originalName")
		$newBranchNameList = @("$newPath$originalName")
	}
	if ($branchNameList.count -eq 0){
		Throw "$originalPath$originalName is not a valid Item or is non replaceable (possible remote branch)"
	}
	else{
		$replacementArr = (0..($branchNameList.count-1)) | foreach {$branchNameList[$_] + ':' + $newBranchNameList[$_]}
		gibRenameBranches $replacementArr
	}
}


$script:gibCommandList = @(
    'cd',
    'dir',
    'curr',
    'getbr',
    'gohome',
	'rename',
	'move',
    'showrev'
)

function script:gibCommands($filter) {
    $gibCommandList | where {$_ -like "$filter*"}
    gitCommands $filter
}

$script:gibCommandArgs = @{
    cd = 'relpath'
    dir = 'regexp relpath recursive nondisplaymode'
    curr = ''
    getbr = 'relpath abspath'
    gohome = ''
}

function script:gibCommandOps ($gibCommandArgList, $gibCommand, $gibArg) {
    $gibCommandArgList.$gibCommand -split ' ' | 
        where {$_ -like "$gibArg*"}
}

function GibTabExpansion($lastBlock) {
    
    [string[]] $debug_info = $null
    if($lastBlock -match "^$(Get-AliasPattern gib) (?<cmd>\S+)(?<args> .*)$") {
        $lastBlock = expandGitAlias 'gib' $Matches['cmd'] $Matches['args']
    }
    $debug_info += $lastBlock
    
    # Handles Tab completion specific to gib commands
    switch -regex ($lastBlock -replace "^$(Get-AliasPattern gib) ",""){
        
        # Handles gib <cmd> case
        "^(?<cmd>\S*)$" {
            gibCommands $matches['cmd'] $TRUE
        }
        
        # Handles the gib <cmd> .... -<option> case
        "^(?<cmd>\S*)(?<middle>\s.*(?<=\s)\-)(?<option>\S*)$"{
            $debug_info += 'Entered Handles the gib <cmd> .... -<option> case ' + "$($matches['cmd']) + $($matches['middle']) + $($matches['option'])"
            gibCommandOps $gibCommandArgs $matches['cmd'] $matches['option'] | 
                foreach {'-' + $_}
        }
        
        # Handles the gib <gib specific command> ... -- <path> scenario
        "(?<cmd>\S*)(?<middle>\s.*)==\s*(?<path>\S*|)"{
            # Return Empty Array.
            if($gibCommandList -contains $matches['cmd']){
                return @();
            }
        }
        # Handles the gib ... <branch>
        "^(?<cmd>\S*)(?<middle>\s.*)(?<=\s)(?<branch>[\S&&^0-9\.]\S*|)$"{
            
            $debug_info += 'Handles the gib ... <branch> case ' + "$($matches['cmd']) + $($matches['middle']) + $($matches['branch'])"
            gibRelBranches $matches['branch']
        }
        
    }
    
    # Handles tab completion pertaining to git commands
    switch -regex ($lastBlock -replace "^$(Get-AliasPattern gib) ","") {
        
        # Handles git <cmd> (commands & aliases)
        "^(?<cmd>\S*)$" {
            gitCommands $matches['cmd'] $TRUE
        }
        
        # Handles git <cmd> <op>
        "^(?<cmd>$($subcommands.Keys -join '|'))\s+(?<op>\S*)$" {
            gitCmdOperations $subcommands $matches['cmd'] $matches['op']
        }

        # Handles git flow <cmd> <op>
        "^flow (?<cmd>$($gitflowsubcommands.Keys -join '|'))\s+(?<op>\S*)$" {
            gitCmdOperations $gitflowsubcommands $matches['cmd'] $matches['op']
        }
        
        # Handles git flow <command> <op> <name>
        "^flow (?<command>\S*)\s+(?<op>\S*)\s+(?<name>\S*)$" {
            gitFeatures $matches['name'] $matches['command']
        }

        # Handles git remote (rename|rm|set-head|set-branches|set-url|show|prune) <stash>
        "^remote.* (?:rename|rm|set-head|set-branches|set-url|show|prune).* (?<remote>\S*)$" {
            gitRemotes $matches['remote']
        }

        # Handles git stash (show|apply|drop|pop|branch) <stash>
        "^stash (?:show|apply|drop|pop|branch).* (?<stash>\S*)$" {
            gitStashes $matches['stash']
        }

        # Handles git bisect (bad|good|reset|skip) <ref>
        "^bisect (?:bad|good|reset|skip).* (?<ref>\S*)$" {
            gibRelBranches $matches['ref'] $true
        }

        # Handles git tfs unshelve <shelveset>
        "^tfs +unshelve.* (?<shelveset>\S*)$" {
            gitTfsShelvesets $matches['shelveset']
        }

        # Handles git branch -d|-D|-m|-M <branch name>
        # Handles git branch <branch name> <start-point>
        "^branch.* (?<branch>\S*)$" {
            gibRelBranches $matches['branch']
        }

        # Handles git help <cmd> (commands only)
        "^help (?<cmd>\S*)$" {
            gitCommands $matches['cmd'] $FALSE
        }

        # Handles git push remote <ref>:<branch>
        "^push.* (?<remote>\S+) (?<ref>[^\s\:]*\:)(?<branch>\S*)$" {
            gitRemoteBranches $matches['remote'] $matches['ref'] $matches['branch']
        }

        # Handles git push remote <branch>
        # Handles git pull remote <branch>
        "^(?:push|pull).* (?:\S+) (?<branch>[^\s\:]*)$" {
            gibRelBranches $matches['branch']
        }

        # Handles git pull <remote>
        # Handles git push <remote>
        # Handles git fetch <remote>
        "^(?:push|pull|fetch).* (?<remote>\S*)$" {
            gitRemotes $matches['remote']
        }

        # Handles git reset HEAD <path>
        # Handles git reset HEAD -- <path>
        "^reset.* HEAD(?:\s+--)? (?<path>\S*)$" {
            gitIndex $matches['path']
        }

        # Handles git <cmd> <ref>
        "^commit.*-[Cc]\s+(?<ref>\S*)$" {
            gibRelBranches $matches['ref'] $true
        }

        # Handles git add <path>
        "^add.* (?<files>\S*)$" {
            gitAddFiles $matches['files']
        }

        # Handles git checkout -- <path>
        "^checkout.* -- (?<files>\S*)$" {
            gitCheckoutFiles $matches['files']
        }

        # Handles git rm <path>
        "^rm.* (?<index>\S*)$" {
            gitDeleted $matches['index']
        }

        # Handles git diff/difftool <path>
        "^(?:diff|difftool)(?:.* (?<staged>(?:--cached|--staged))|.*) (?<files>\S*)$" {
            gitDiffFiles $matches['files'] $matches['staged']
        }

        # Handles git merge/mergetool <path>
        "^(?:merge|mergetool).* (?<files>\S*)$" {
            gitMergeFiles $matches['files']
        }

        # Handles git <cmd> <ref>
        "^(?:checkout|cherry|cherry-pick|diff|difftool|log|merge|rebase|reflog\s+show|reset|revert|show) .*(?<= )(?<ref>\S*)$" {
            gibRelBranches $matches['ref'] $true
        }
    }
    
    $debug_info | clip
}

function script:gibConvertArgs (){
    
    Param(
        [parameter(mandatory=$false, position=0, ValueFromRemainingArguments=$true)] $Arguments
    )
    # This is responsible for converting all the relative branch names to their
    # absolute counterparts for 
    
    # removing all git options
    # removing all commit hashes (assuming no ambiguity
    # Keeping only those which are a valid path.
    # converting them into absolute path
    $Arguments | foreach{
            if  (
                  ($_ -notmatch "^\-.*") -and
                  -not (gibCheckCommitHash $_ ) 
                ){
                
                # incase it is not an option or commit hash
                $abspath = gibConvertReltoAbs $_
                $abspath
            }
            else{
                $_
            }
        }
    
}

function gib(){
    
    Param
    (
        [parameter(mandatory=$true, position=0)][string]$subcommand,
        [parameter(mandatory=$false, position=1, ValueFromRemainingArguments=$true)]$arglist
    )
    # editing arguments and putting every non-parameter-name in quotes
    $arglist = $arglist | foreach{
                        if ($_ -notmatch "^\-.*"){
                            $temp = ($_ -replace "'", '''''')
                            $temp = "'" + $temp + "'"
                        }
                        else{
                            $temp = $_
                        }
                        $temp
                    }
    switch ($subcommand){
        'cd'{
            Invoke-Expression "gibSetBranchDir $arglist"
        }
        'dir'{
            Invoke-Expression "gibBranchDirList $arglist"
        }
        'curr'{
            $script:current_branch_path
        }
        'getbr'{
            Invoke-Expression "gibConvertReltoAbs $arglist"
        }
        'gohome'{
            gibResetBranchDir
        }
		'rename'{
			Invoke-Expression "gibRename $arglist"
		}
		'move'{
			Invoke-Expression "gibMove $arglist"
		}
        'showrev'{
            Invoke-Expression "gibGetFileRev $arglist"
        }
        default{
            Invoke-Expression "git $subcommand $(Invoke-Expression `"gibConvertArgs $arglist`")"
        }
    }
    #"-------"
    #$arglist |foreach{ "'" + $_ + "'"}
    #"-------"
}

$script:BackupCount = 1
if (Test-Path Function:\TabExpansion) {
    while (Test-Path Function:\TabExpansionBackup$script:BackupCount){
        $script:BackupCount++;
    }
    Rename-Item Function:\TabExpansion TabExpansionBackup$script:BackupCount
}

$PowerTab_RegisterTabExpansion = if (Get-Module -Name powertab) { Get-Command Register-TabExpansion -Module powertab -ErrorAction SilentlyContinue }
if ($PowerTab_RegisterTabExpansion)
{
    & $PowerTab_RegisterTabExpansion "gib" -Type Command {
        param($Context, [ref]$TabExpansionHasOutput, [ref]$QuoteSpaces)  # 1:
        
        $line = $Context.Line
        $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()
        $TabExpansionHasOutput.Value = $true
        GibTabExpansion $lastBlock
    }
    return
}

function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()

    switch -regex ($lastBlock) {
        # Execute gib tab completion for all gib-related commands
        "^$(Get-AliasPattern gib) (.*)" { GibTabExpansion $lastBlock }
        
        # Fall back on existing tab expansion
        default { if (Test-Path Function:\TabExpansionBackup$script:BackupCount) {& TabExpansionBackup$script:BackupCount $line $lastWord } }
    }
}