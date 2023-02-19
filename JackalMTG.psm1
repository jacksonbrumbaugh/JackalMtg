$ModuleRootDir = $PSScriptRoot
$ModuleName = Split-Path $ModuleRootDir -Leaf

$ChildDirs = Get-ChildItem $ModuleRootDir -Directory

$NoExportKeywordArray = @(
  "Help",
  "Support"
)

foreach ( $ThisDir in $ChildDirs ) {
  foreach ( $ThisScript in (Get-ChildItem -Path (Get-Item $ModuleRootDir\$ThisDir) -Include "*.ps1" -Recurse) ) {
    $ThisScriptItem = Get-Item $ThisScript
    $ThisScriptFullName = $ThisScriptItem.FullName

    # Dot-Sourcing; loads the function as part of the module
    . $ThisScriptFullName

    $ThisDirName = Split-Path (Split-Path $ThisScriptFullName) -Leaf
    $FunctionName = (Split-Path $ThisScriptFullName -Leaf).replace( '.ps1', '' )

    $doExport = $true
    foreach ( $ThisKeyword in $NoExportKeywordArray ) {
      if ( $ThisDirName -match $ThisKeyword ) {
        $doExport = $false
      }
    }

    if ( $doExport ) {
      # Lets users use / see the function
      Export-ModuleMember $FunctionName
    }

  } # End block:foreach ThisScript

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
