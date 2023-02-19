$ModuleRootDir = $PSScriptRoot
$ModuleName = Split-Path $ModuleRootDir -Leaf

$ChildDirs = Get-ChildItem $ModuleRootDir -Directory

$NoExportKeywordArray = @(
  "Help",
  "Support"
)

foreach ( $Dir in $ChildDirs ) {
  $DirItem = Get-Item $ModuleRootDir\$Dir

  $CmdScripts = Get-ChildItem -Path $DirItem -Recurse -Include "*.ps1"

  foreach ( $Script in $CmdScripts ) {
    $ScriptItem = Get-Item $Script
    $ScriptFullName = $ScriptItem.FullName

    # Dot-Sourcing; loads the function as part of the module
    . $ScriptFullName

    $DirName = Split-Path (Split-Path $ScriptFullName) -Leaf
    $FunctionName = (Split-Path $ScriptFullName -Leaf).replace( '.ps1', '' )

    $doExport = $true
    foreach ( $ThisKeyword in $NoExportKeywordArray ) {
      if ( $DirName -match $ThisKeyword ) {
        $doExport = $false
      }
    }

    if ( $doExport ) {
      # Lets users use / see the function
      Export-ModuleMember $FunctionName
    }

  } # End block:foreach Script in CmdScripts

} # End block:foreach Dir in ChildDIrs

$Aliases = (Get-Alias).Where{ $_.Source -eq $ModuleName }
$AliasNames = $Aliases.Name -replace "(.*) ->.*","`$1"
foreach ( $Alias in $AliasNames ) {
  # Lets users use / see the alias
  Export-ModuleMember -Alias $Alias
}




Get-ChildItem $PSScriptRoot\*.ps1 -Exclude $ExcludeList | ForEach-Object {
  . $_.FullName
}
