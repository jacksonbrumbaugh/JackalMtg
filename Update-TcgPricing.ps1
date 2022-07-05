function Update-TcgPricing {
  [CmdletBinding()]
  param(
    [double]
    [Alias( "D", "Off" )]
    $Discount,

    [switch]
    [Alias("NB", "N")]
    $NoBracket
  ) #END block::param

  begin {
    function New-BufferLine { Write-Host "" }
  }

  process {
    $ParamFilePath = Join-Path $PSScriptRoot "JackalMtgParams.json"

    if ( -not(Test-Path $ParamFilePath) ) {
      throw ( "Failed to find the parameter file : " + $ParamFilePath )
    }

    $Params = ( Get-Content $ParamFilePath ) | ConvertFrom-JSON

    $DownloadsPath = $Params.DownloadsDir
    $TargetDrive = $Params.TargetDrive
    $SellerDir = Join-Path $TargetDrive $Params.MainSellerDir
    $ArchiveDir = Join-Path $SellerDir $Params.TcgExportArchive
    $UpdatesDir = Join-Path $SellerDir $Params.UpdatesDir
    $UpdatedDir = Join-Path $UpdatesDir $Params.UpdatedDir

    @(
      $DownloadsPath,
      $TargetDrive,
      $SellerDir,
      $ArchiveDir,
      $UpdatesDir,
      $UpdatedDir
    ) | ForEach-Object {
      if ( -not(Test-Path $_) ) {
        throw ( "Failed to find a needed path : " + $_ )
      }
    }

    $ParamDiscount = $Params.UsualDiscount
    $ShippingCost = $Params.ShippingCost -as [double]
    $MinimumPrice = $Params.MinimumPrice -as [double]

    @(
      $ShippingCost,
      $MinimumPrice
    ) | ForEach-Object {
      if ( -not($_) ) {
        throw ( "A needed parameter price was not set in the JSON Params file" )
      }
    }

    $NowSet = $Params.CurrentSet

    if ( -not($NowSet) ) {
      $NowSet = "N/A"
      Write-Warning ( "The current set was not listed in the JSON Params file" )
    }

    $TcgExportFile = ( Get-ChildItem $DownloadsPath\TCG*Pricing*csv |
      Sort-Object -Descending LastWriteTime | Select-Object -First 1 -ExpandProperty FullName
    )

    if ( -not($TcgExportFile) ) {
      throw ( "Failed to locate a TCG Player Pricing Export CSV file in " + $DownloadsPath )
    }

    Write-Host "Loaded current set as:"
    Write-Host $NowSet
    New-BufferLine
    Write-Host "Loading inventory from the CSV file"
    New-BufferLine
    $InventoryList = Import-CSV $TcgExportFile

    if ( $NoBracket ) {
      if ( -not $PSBoundParameters.ContainsKey('Discount') ) {
        $Discount = $ParamDiscount
      }
      
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
      
      $MsgPart01 = "A discount of"
      $MsgPart02 = "from TCG Market Price will be applied"
      $DiscountMsg = if ( $Discount -eq 0 ) {
        $MsgPart01 = "No discount"
        $MsgPart01 + " " + $MsgPart02
      } else {
        "{0} {1:D2}% {2}" -f $MsgPart01, ( 100*$Discount -as [int] ), $MsgPart02
      }
      Write-Host $DiscountMsg
    } else {
      $Discount = 0
      Write-Host "Discounts will be applied by a bracketing system"
    }
    New-BufferLine

    $TcgKeysHash = @{
      TcgProdName = "Product Name"
      TcgMktPrice = "TCG Market Price"
      TcgLowPrice = "TCG Low Price With Shipping"
      MyPrice     = "TCG MarketPlace Price"
      SetName     = "Set Name"
      Qty         = "Total Quantity"
    }

    Write-Host "Determining price for each card in inventory"
    New-BufferLine

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
        New-BufferLine
        continue
      }

      $FloorFlag = $false
      if ( -not $NoBracket ) {
        $Discount = switch ( $TcgMktPrice ) {
          { $_ -gt 15   } { 0.10; break }
          { $_ -ge 10   } { 0.15; break }
          { $_ -ge 5    } { 0.20; break }
          { $_ -ge 1    } { 0.15; break }
          { $_ -ge 0.56 } { 0.10; break }
          Default         { 1; $FloorFlag = $true; break }
        }
        $Multiplier = 1 - $Discount
      }

      $DiscountPrice = if ( -not $FloorFlag ) {
        [Math]::Floor( 100 * $Multiplier * $TcgMktPrice ) / 100
      } else {
        0.5
      }

      $MinChecks = @(
        @{ Type = "TCG MKT";    Price = $TcgMktPrice },
        @{ Type = "Discounted"; Price = $DiscountPrice }
      )

      $WarningFlag = $null
      foreach ( $MinCheck in $MinChecks ) {
        $CheckPrice = $MinCheck.Price
        $CheckType = $MinCheck.Type
        if ( $CheckPrice -lt $MinimumPrice ) {
          $WarningFlag = $true

          $Warning = $CardName
          $Warning += " was set to have a "
          $Warning += $CheckType
          $Warning += " price of "
          $Warning += $CheckPrice
          $Warning += " but the min of "
          $Warning +=  $MinimumPrice
          $Warning += " was used instead"

          if ( $CheckType -eq "Discounted" ) {
            $DiscountPrice = $MinimumPrice
          }
          if ( $CheckType -eq "TCG MKT" ) {
            $TcgMktPrice = $MinimumPrice
          }
        }
      }

      if ( $WarningFlag ) {
        Write-Warning $Warning
        New-BufferLine
      }

      $TargetPrice = if ( $CardSet -eq $NowSet ) {
        $TcgMktPrice
      } else {
        $DiscountPrice
      }

      $CardShipping = if ( $TcgLowPrice -lt 5 ) {
        0.99
      } else {
        $ShippingCost
      }

      $NewPrice = [Math]::Max( $TargetPrice, ($TcgLowPrice - $CardShipping) )

      $Card.($TcgKeysHash.MyPrice) = $NewPrice
    } #END loop::foreach( $Card in $InventoryList )

    $DateStamp = (Get-Date).ToString("yyyy-MM-dd")
    $UpdatesFileName = "UpdatedPricing_{0}.csv" -f $DateStamp

    $ShortAlphabet = ('B', 'C', 'D', 'E', 'F')
    $Letter = $ShortAlphabet[0]
    $n = 0
    do {
      if ( $Letter -eq $ShortAlphabet[-1] ) {
        throw "Too many versions of output file have already been created"
      }
      $CheckFilePath = Join-Path $UpdatedDir $UpdatesFileName
      if ( Test-Path $CheckFilePath ) {
        if ( $n -eq 0 ) {
          Write-Verbose ""
          Write-Host "Determining output file name"
          New-BufferLine
        }
        $Letter = $ShortAlphabet[$n++]
        $NewStamp = $DateStamp + '.' + $Letter
        $UpdatesFileName = $UpdatesFileName -replace $DateStamp, $NewStamp
      }
    } while ( Test-Path $CheckFilePath )

    $UpdatesFilePath = Join-Path $UpdatesDir $UpdatesFileName

    Write-Host "Exporting updated pricing CSV file"
    New-BufferLine
    $InventoryList | Export-CSV -NTI -Path $UpdatesFilePath

    $Result = [PSCustomObject]@{
      FileName = $UpdatesFileName
      Creation = Test-Path $UpdatesFilePath
    }

    if ( -not($Result.Creation) ) {
      Write-Warning ( "Failed to create an updated pricing CSV file" )
    } else {
      if ( Test-Path $ArchiveDir ) {
        Write-Host "Archiving Exported TCG file"
        Move-Item $TcgExportFile $ArchiveDir -Force
        Invoke-Item $UpdatesDir
      }
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