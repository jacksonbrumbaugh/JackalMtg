function Get-JklMtgParam {
  $ParamFilePath = Join-Path $PSScriptRoot "JackalMtgParams.json"

  if ( -not(Test-Path $ParamFilePath) ) {
    throw ( "Failed to find the parameter file : " + $ParamFilePath )
  }

  $OutputObject = ( Get-Content $ParamFilePath ) | ConvertFrom-Json

  Write-Output $OutputObject
}
