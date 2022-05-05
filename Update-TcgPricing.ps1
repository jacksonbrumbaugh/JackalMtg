function Update-TcgPricing {
  [CmdletBinding()]
  param(
    [double]$Discount = 10,

    [double]
    [Alias("Ship", "Pkg")]
    $ShippingCost = 0.86
  ) #END block::param

  process {
    $ParamFilePath = Join-Path $PSScriptRoot "JackalMtgParams.json"

    if ( -not(Test-Path $ParamFilePath) ) {
      throw ( "Failed to find the parameter file : " + $ParamFilePath )
    }

    $Params = (Get-Content $ParamFilePath) | ConvertFrom-JSON

    $DownloadsPath = $Params.DownloadsDir
    if ( -not(Test-Path $DownloadsPath) ) {
      throw ( "Failed to find the Downloads folder : " + $DownloadsPath )
    }

    $UpdatedDir = $Params.UpdatesDir
    if ( -not(Test-Path $UpdatedDir) ) {
      throw ( "Failed to locate the Updates folder : " + $UpdatedDir )
    }

    $NowSet = $Params.CurrentSet

    $TcgExportFile = ( Get-ChildItem $DownloadsPath\TCG*Pricing*csv |
      Sort-Object -Descending LastWriteTime | Select-Object -First 1 -ExpandProperty FullName
    )

    if ( -not($TcgExportFile) ) {
      throw ( "Failed to locate a TCG Player Pricing Export CSV file in " + $DownloadsPath )
    }

    $InventoryList = Import-CSV $TcgExportFile

    $Multiplier = 1

    if ( $Discount -gt 1 ) {
      $Discount = $Discount / 100
    }

    if ( $Discount -gt 1 ) {
      throw "Cannot offer a discount above 100%"
    }

    if ( $Discount ) {
      $Multiplier = 1 - $Discount
    } else {
      $Discount = "0.0"
    }

    Write-Verbose ( "A discount of " + $Discount + " off TCG Market Price will be applied" )

    $TcgKeysHash = @{
      TcgProdName = "Product Name"
      TcgMktPrice = "TCG Market Price"
      TcgLowPrice = "TCG Low Price With Shipping"
      MyPrice     = "TCG MarketPlace Price"
      SetName     = "Set Name"
    }

    $InventoryList | ForEach-Object {
      $CardName = $_.($TcgKeysHash.TcgProdName)
      $TcgMktPrice = $_.($TcgKeysHash.TcgMktPrice) -as [double]
      $TcgLowPrice = $_.($TcgKeysHash.TcgLowPrice) -as [double]
      $CardSet = $_.($TcgKeysHash.SetName)

      if ( -not($TcgMktPrice) ) {
        Write-Warning ( "Failed to grab TCG Market Price for " + $CardName )
        continue
      }

      $DiscountPrice = [Math]::Floor( 100 * $Multiplier * $TcgMktPrice ) / 100

      $TargetPrice = if ( $CardSet -eq $NowSet ) {
        $TcgMktPrice
      } else {
        $DiscountPrice
      }

      $NewPrice = [Math]::Max( $TargetPrice, ($TcgLowPrice - $ShippingCost) )

      $_.($TcgKeysHash.MyPrice) = $NewPrice
    }

    $UpdatedFileName = "UpdatedPricing_{0}.csv" -f (Get-Date).ToString("yyyy-MM-dd")
    $UpdatedFilePath = Join-Path $UpdatedDir $UpdatedFileName

    $InventoryList | Export-CSV -NTI -Path $UpdatedFilePath

    $Result = [PSCustomObject]@{
      FileName = $UpdatedFileName
      Creation = Test-Path $UpdatedFilePath
    }

    if ( -not($Result.Creation) ) {
      Write-Warning ( "Failed to create an updated pricing CSV file" )
    } else {
      Remove-Item $TcgExportFile
      Invoke-Item $UpdatedDir
    }

    Write-Output $Result
  } #END block::process
}

<#
$Aliases_MTG_UpdateTcgPricing = @('UTP')

$Aliases_MTG_UpdateTcgPricing | ForEach-Object {
    Set-Alias -Name $_ -Value Update-TcgPricing
}
#>