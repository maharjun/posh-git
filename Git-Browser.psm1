if (Get-Module git-Browser) { return }
if (-not (Get-Module posh-git)){
	Import-Module $env:github_posh_git\posh-git.psm1
}

Push-Location $psScriptRoot
.\CheckVersion.ps1 > $null

. .\Git-Browser.ps1

$global:git_browser_path = (Get-Location).Path

Pop-Location

Export-ModuleMember `
	-Variable @(
		'git_browser_path'
		)`
    -Function @(
        'TabExpansion',
        'gibGetFileRev',
		'gibResetBranchDir',
		'gibCheckPath',
		'gibCheckBranch',
		'gibCleanRelPath',
		'gibConvertReltoAbs',
		'gibBranchDirList',
		'gibSetBranchDir',
		'gibRelBranches',
        'gibRenameBranches',
		'gibRename',
		'gibConvertArgs',
		'gibShowSubModuleStatus',
		'gib',
		'GibTabExpansion'
)



		