function Update-TcgPricing {
  [CmdletBinding()]
  param(
    [double]
    [Alias( "D", "Off" )]
    $Discount
  ) #END block::param

  process {
    $ParamFilePath = Join-Path $PSScriptRoot "JackalMtgParams.json"

    if ( -not(Test-Path $ParamFilePath) ) {
      throw ( "Failed to find the parameter file : " + $ParamFilePath )
    }

    $Params = (Get-Content $ParamFilePath) | ConvertFrom-JSON

    $DownloadsPath = $Params.DownloadsDir
    $UpdatesDir = $Params.UpdatesDir
    $UpdatedDir = $Params.UpdatedDir
    $ParamDiscount = $Params.UsualDiscount

    @(
      $DownloadsPath,
      $UpdatesDir,
      $UpdatedDir
    ) | ForEach-Object {
      if ( -not(Test-Path $_) ) {
        throw ( "Failed to find a needed dir : " + $_ )
      }
    }

    $ShippingCost = $Params.ShippingCost -as [double]
    $MinimumPrice = $Params.MinimumPrice -as [double]

    ($ShippingCost, $MinimumPrice) | ForEach-Object {
      if ( -not($_) ) {
        throw ( "A needed parameter price was not set in the JSON Params file" )
      }
    }

    $NowSet = $Params.CurrentSet

    if ( -not($NowSet) ) {
      throw ( "The current set was not listed in the JSON Params file" )
    }

    Write-Host ( "Using current set as: " + $NowSet )

    $TcgExportFile = ( Get-ChildItem $DownloadsPath\TCG*Pricing*csv |
      Sort-Object -Descending LastWriteTime | Select-Object -First 1 -ExpandProperty FullName
    )

    if ( -not($TcgExportFile) ) {
      throw ( "Failed to locate a TCG Player Pricing Export CSV file in " + $DownloadsPath )
    }

    if ( -not $PSBoundParameters.ContainsKey('Discount') ) {
      $Discount = $ParamDiscount
    }

    Write-Host "Loading inventory from the CSV file"
    $InventoryList = Import-CSV $TcgExportFile

    $Multiplier = 1

    if ( $Discount -gt 100 ) {
      throw "Cannot offer a discount above 100%"
    }

    if ( $Discount -gt 1 ) {
      $Discount = $Discount / 100
    }

    if ( $Discount ) {
      $Multiplier = 1 - $Discount
    } else {
      $Discount = 0
    }

    Write-Verbose ( "A discount of " + $Discount + " off TCG Market Price will be applied" )

    $TcgKeysHash = @{
      TcgProdName = "Product Name"
      TcgMktPrice = "TCG Market Price"
      TcgLowPrice = "TCG Low Price With Shipping"
      MyPrice     = "TCG MarketPlace Price"
      SetName     = "Set Name"
      Qty         = "Total Quantity"
    }

    Write-Host "Determining pricing for each card in inventory"

    foreach ( $Card in $InventoryList ) {
      $CardName = $Card.($TcgKeysHash.TcgProdName)
      $TcgMktPrice = $Card.($TcgKeysHash.TcgMktPrice) -as [double]
      $TcgLowPrice = $Card.($TcgKeysHash.TcgLowPrice) -as [double]
      $CardSet = $Card.($TcgKeysHash.SetName)
      $CardQty = $Card.($TcgKeysHash.Qty) -as [int]

      if ( $CardQty -eq 0 ) {
        Write-Verbose ( "Skipping " + $CardName + " : 0 qty in stock" )
        continue
      }

      if ( -not($TcgMktPrice) ) {
        Write-Warning ( "Failed to grab TCG Market Price for " + $CardName )
        continue
      }

      $DiscountPrice = [Math]::Floor( 100 * $Multiplier * $TcgMktPrice ) / 100

      $MinChecks = @(
        @{ Type = "TCG MKT";    Price = $TcgMktPrice },
        @{ Type = "Discounted"; Price = $DiscountPrice }
      )

      foreach ( $MinCheck in $MinChecks ) {
        $Warning = $null
        $CheckPrice = $MinCheck.Price
        $CheckType = $MinCheck.Type
        if ( $CheckPrice -lt $MinimumPrice ) {
          $Warning = (
            $CardName + " would have a " + $CheckType  + " price of " + $CheckPrice +
            " but the min of " + $MinimumPrice + " was used instead"
          )
          if ( $CheckType -eq "Discounted" ) {
            $DiscountPrice = $MinimumPrice
          }
          if ( $CheckType -eq "TCG MKT" ) {
            $TcgMktPrice = $MinimumPrice
          }
        }
      }

      if ( $Warning ) {
        Write-Warning $Warning
      }

      $TargetPrice = if ( $CardSet -eq $NowSet ) {
        $TcgMktPrice
      } else {
        $DiscountPrice
      }

      $NewPrice = [Math]::Max( $TargetPrice, ($TcgLowPrice - $ShippingCost) )

      $Card.($TcgKeysHash.MyPrice) = $NewPrice
    } #END loop::foreach( $Card in $InventoryList )

    $DateStamp = (Get-Date).ToString("yyyy-MM-dd")
    $UpdatesFileName = "UpdatedPricing_{0}.csv" -f $DateStamp

    $ShortAlphabet = ('B', 'C', 'D', 'E', 'F')
    $n = 0
    do {
      $CheckFilePath = Join-Path $UpdatedDir $UpdatesFileName
      if ( Test-Path $CheckFilePath ) {
        if ( $n -eq 0 ) {
          Write-Host "Determining output file name"
        }
        $Letter = $ShortAlphabet[$n++]
        $NewStamp = $DateStamp + '.' + $Letter
        $UpdatesFileName = $UpdatesFileName -replace $DateStamp, $NewStamp
      }
    } while ( Test-Path $CheckFilePath )

    $UpdatesFilePath = Join-Path $UpdatesDir $UpdatesFileName

    Write-Host "Exporting updated pricing CSV file"
    $InventoryList | Export-CSV -NTI -Path $UpdatesFilePath

    $Result = [PSCustomObject]@{
      FileName = $UpdatesFileName
      Creation = Test-Path $UpdatesFilePath
    }

    if ( -not($Result.Creation) ) {
      Write-Warning ( "Failed to create an updated pricing CSV file" )
    } else {
      Remove-Item $TcgExportFile
      Invoke-Item $UpdatesDir
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
