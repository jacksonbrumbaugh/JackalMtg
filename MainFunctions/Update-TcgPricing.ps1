function Update-TcgPricing {
  [CmdletBinding()]
  param(
    [double]
    [Alias("Off")]
    $Discount,

    [switch]
    [Alias("NB")]
    $NoBracket
  ) #END block::param

  begin {
    function New-BufferLine { Write-Host "" }

    $ErrorDetails = @{
      ErrorAction = "Stop"
    }

    $StopSellingFileName = "StopSellingList.txt"
  }

  process {
    $Params = Get-JklMtgParam

    $UserParams = $Params.($env:Username)

    if ( [string]::IsNullOrEmpty($UserParams) ) {
      $ErrorDetails.Message = "Failed to find your username ($env:Username) configured in the JackalMtgParams.json file. "
      Write-Error @ErrorDetails
    }

    $DownloadsPath = "C:/Users/{0}/Downloads" -f $env:Username
    $TargetDrive = $UserParams.TargetDrive
    $SellerDir = Join-Path $TargetDrive $UserParams.MainSellerDir
    $ArchiveDir = Join-Path $SellerDir $UserParams.TcgExportArchive
    $UpdatesDir = Join-Path $SellerDir $UserParams.UpdatesDir
    $UpdatedDir = Join-Path $UpdatesDir $UserParams.UpdatedDir
    $HalfOffDir = Join-Path $SellerDir $UserParams.HalfOffDir

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

    $ParamDiscount = $UserParams.UsualDiscount
    $ShippingCost = $UserParams.ShippingCost -as [double]
    $MinimumPrice = $UserParams.MinimumPrice -as [double]

    @(
      $ShippingCost,
      $MinimumPrice
    ) | ForEach-Object {
      if ( -not($_) ) {
        throw ( "A needed parameter price was not set in the JSON Params file" )
      }
    }

    $NowSet = $UserParams.CurrentSet

    if ( -not($NowSet) ) {
      $NowSet = "N/A"
      Write-Warning ( "The current set was not listed in the JSON Params file" )
    }

    $TcgExportFile = ( Get-ChildItem $DownloadsPath\TCG*Pricing*csv |
      Sort-Object -Descending LastWriteTime | Select-Object -First 1 -ExpandProperty FullName
    )

    if ( [string]::IsNullOrEmpty($TcgExportFile) ) {
      $ArchivedExportFiles = Get-ChildItem $ArchiveDir | Sort-Object -Descending LastWriteTime
      $NewestArchivedFileName = $ArchivedExportFiles[0].FullName
      $NewestArchiveDate = $NewestArchivedFileName -replace ".*Export_(\d*)_.*",'$1'
      $Today = (Get-Date).ToString("yyyyMMdd")

      if ( $NewestArchiveDate -eq $Today ) {
        $TcgExportFile = $NewestArchivedFileName
      }
    }

    if ( [string]::IsNullOrEmpty($TcgExportFile) ) {
      throw ( "Failed to locate a TCG Player Pricing Export CSV file in " + $DownloadsPath )
    }

    $ExportFileName = (Get-Item $TcgExportFile).Name
    $ExportDate = $ExportFileName -replace ".*Export_(\d*)_.*",'$1'
    Write-Host "Exported TCGPlayer file date"
    $ExportDate
    New-BufferLine

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

    $FoundHalfOffList = $false
    $HalfOFfListPath = Get-ChildItem $HalfOffDir\*Cards*csv
    if ( $HalfOFfListPath ) {
      $FoundHalfOffList = $true
      $HalfOffCardsListed = $false
      $HalfOffCardsList = @()
      $HalfOffList = Import-CSV $HalfOFfListPath
      Write-Host "A half-off list was located & will be applied"
      New-BufferLine
    }

    Write-Host "Loaded current set as:"
    Write-Host $NowSet
    New-BufferLine
    Write-Host "Loading inventory from the CSV file"
    New-BufferLine
    $InventoryList = Import-CSV $TcgExportFile

    $TcgKeysHash = @{
      TcgProdName = "Product Name"
      TcgMktPrice = "TCG Market Price"
      TcgLowPrice = "TCG Low Price With Shipping"
      MyPrice     = "TCG MarketPlace Price"
      SetName     = "Set Name"
      Qty         = "Total Quantity"
      ID          = "TCGplayer Id"
    }

    Write-Host "Determining price for each card in inventory"
    New-BufferLine

    $StopSellingFile = Join-Path $UpdatesDir $StopSellingFileName

    $UpdatedInventoryArray = foreach ( $Card in $InventoryList ) {
      $CardName = $Card.($TcgKeysHash.TcgProdName)
      $CardID = $Card.($TcgKeysHash.ID)
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

      $BottomPrice = [Math]::Round($MinimumPrice / ( 1 - 0.15 ), 2)
      $FloorFlag = $false
      if ( -not $NoBracket ) {
        $Discount = switch ( $TcgMktPrice ) {
          { $_ -gt 15 } { 0.10; break }
          { $_ -gt 10 } { 0.15; break }
          { $_ -gt 1  } { 0.20; break }
          { $_ -ge $BottomPrice } { 0.15; break } # 
          Default       {
            $FloorFlag = $true
            1.00
          }
        }
        $Multiplier = 1 - $Discount
      }

      $SkipMinMaxChecks = $false
      if ( $FoundHalfOffList ) {
        if ( $CardID -in $HalfOffList.($TcgKeysHash.ID) ) {
          $SkipMinMaxChecks = $true
          $HalfOffCardsListed = $true
          $Multiplier = 0.5
        }
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
      if ( -not $SkipMinMaxChecks ) {

        foreach ( $MinCheck in $MinChecks ) {
          $CheckPrice = $MinCheck.Price
          $CheckType = $MinCheck.Type
          if ( $CheckPrice -lt $MinimumPrice ) {
            if ( -not (Test-Path $StopSellingFile) ) {
              New-Item $StopSellingFile
            }

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

            $CardName | Add-Content -Path $StopSellingFile
          }
        }
      }

      if ( $WarningFlag ) {
        Write-Warning $Warning
        New-BufferLine
      }

      $TargetPrice = if ( $SkipMinMaxChecks ) {
        $DiscountPrice
      } else {
        if ( $CardSet -eq $NowSet ) {
          $TcgMktPrice
        } else {
          $DiscountPrice
        }
      }

      $CardShipping = if ( $TcgLowPrice -lt 5 ) {
        0.99
      } else {
        $ShippingCost
      }

      $NewPrice = if ( $SkipMinMaxChecks ) {
        $HalfOffCardsList += $CardName  + " from the set " + $CardSet
        #Write-Host ( "A half-off discount was applied to " + $CardName  + " from the set " + $CardSet )
        #New-BufferLine
        $TargetPrice
      } else {
        [Math]::Max( $TargetPrice, ($TcgLowPrice - $CardShipping) )
      }

      $Card.($TcgKeysHash.MyPrice) = $NewPrice

      # Output to UpdatedInventoryArray
      $Card

    } #END loop::foreach( $Card in $InventoryList )

    if ( $HalfOffCardsListed ) {
      Write-Host "The half-off discount as applied to the following cards"
      $HalfOffCardsList | ForEach-Object {
        $HalfOffListMsg = " > " + $_
        Write-Host $HalfOffListMsg
      }
      New-BufferLine
    }

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
    $UpdatedInventoryArray | Export-CSV -NTI -Path $UpdatesFilePath

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

} # End function

<#
$Aliases_MTG_UpdateTcgPricing = @('UTP')

$Aliases_MTG_UpdateTcgPricing | ForEach-Object {
    Set-Alias -Name $_ -Value Update-TcgPricing
}
#>