function Get-JklMtgParam ( [string]$Username = $env:USERNAME ) {
  $ParamFilePath = Join-Path $ModuleRootDir "JackalMtgParams.json"

  if ( -not(Test-Path $ParamFilePath) ) {
    throw ( "Failed to find the parameter file : " + $ParamFilePath )
  }

  $OutputObject = ( ( Get-Content $ParamFilePath ) | ConvertFrom-Json).$Username

  if ( [string]::IsNullOrEmpty($OutputObject) ) {
    throw ( "Failed to find MTG parameters for the username " + $Username + " configured in the JackalMtgParams.json file. " )
  }

  Write-Output $OutputObject

} # End function
