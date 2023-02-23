<#
.SYNOPSIS
Creates a CSV file of updated card prices to be uploaded to TCGPlayer.com

.NOTES
Created by Jackson Brumbaugh
Version Code: 2023Feb23-A
#>
function Update-TcgPricing {
  [CmdletBinding()]
  param (
    [double]
    [Alias("Off")]
    $Discount,

    [switch]
    [Alias( "NoBracket", "NB")]
    $FlatDiscount
  ) # End block:param

  begin {
    function Write-BufferLine { Write-Host "" }

    $ErrorDetails = @{
      ErrorAction = "Stop"
    }

    $BelowThresholdFileName = "ListOfCardsBelowSellingThreshold.txt"
  }

  process {
    $UserParams = Get-JklMtgParam -Username $env:Username

    Write-Verbose "User parameters"
    Write-Verbose $UserParams

    $DownloadsPath = "C:/Users/{0}/Downloads" -f $env:Username
    $TargetDrive = $UserParams.TargetDrive
    $SellerDir = Join-Path $TargetDrive $UserParams.MainSellerDir
    $ArchiveDir = Join-Path $SellerDir $UserParams.TcgExportArchive
    $UpdatesDir = Join-Path $SellerDir $UserParams.UpdatesDir
    $UpdatedDir = Join-Path $UpdatesDir $UserParams.UpdatedDir
    $HalfOffDir = Join-Path $SellerDir $UserParams.HalfOffDir

    if ( $env:Username) {
      $DownloadsPath = "C:/Users/Jacka/Downloads"
    }

    $NeedDirArray = @(
      $DownloadsPath,
      $TargetDrive,
      $SellerDir,
      $ArchiveDir,
      $UpdatesDir,
      $UpdatedDir
    )
    
    foreach ( $ThisDir in $NeedDirArray ) {
      if ( -not(Test-Path $ThisDir) ) {
        $ErrorDetails.Message = "Failed to find the needed directory {0}. " -f $ThisDir
        Write-Error @ErrorDetails
      }
    }

    $ParamDiscount = $UserParams.UsualDiscount
    $ShippingCost = $UserParams.ShippingCost -as [double]
    $MinimumPrice = $UserParams.MinimumPrice -as [double]

    $NeedPriceArray = @(
      $ShippingCost,
      $MinimumPrice
    )

    foreach ( $ThisPrice in $NeedPriceArray ) {
      if ( ($ThisPrice -as [double]) -eq 0 ) {
        $ErrorDetails.Message = "Not all price parameters are set in the JackalMtgParams.json file. "
        Write-Error @ErrorDetails
      }
    }

    $NowSet = $UserParams.CurrentSet

    if ( -not($NowSet) ) {
      $NowSet = "N/A"
      Write-Warning ( "The current set was not listed in the JSON Params file" )
    }

    $TcgExportSearchPhrase = "TCG*Pricing*csv"
    $TcgExportFile = ( Get-ChildItem $DownloadsPath\$TcgExportSearchPhrase |
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
      $ErrorDetails.Message = "Failed to find a {0} file in the downloads folder {1}. " -f $TcgExportSearchPhrase, $DownloadsPath
      Write-Error @ErrorDetails
    }

    $ExportFileName = (Get-Item $TcgExportFile).Name
    $ExportDate = $ExportFileName -replace ".*Export_(\d*)_.*",'$1'
    Write-Host "Exported TCGPlayer file date"
    $ExportDate
    Write-BufferLine

    $DiscountMsg = if ( $FlatDiscount ) {
      $AppliedDiscount = if ( -not $PSBoundParameters.ContainsKey('Discount') ) {
        $ParamDiscount
      } else {
        $Discount
      }
      
      if ( $AppliedDiscount -gt 100 ) {
        $ErrorDetails.Message = "Cannot offer a discount above 100%! "
        Write-Error @ErrorDetails
      }
      
      if ( $AppliedDiscount -gt 1 ) {
        $AppliedDiscount = $AppliedDiscount / 100
      }
      
      $Multiplier = if ( $AppliedDiscount ) {
        1 - $AppliedDiscount
      } else {
        $AppliedDiscount = 0
        1
      }
      
      $MsgPart01 = "A discount of"
      $MsgPart02 = "from TCG Market Price will be applied"
      if ( $AppliedDiscount -eq 0 ) {
        $MsgPart01 = "No discount"
        $MsgPart01 + " " + $MsgPart02
      } else {
        "{0} {1:D2}% {2}" -f $MsgPart01, ( 100*$AppliedDiscount -as [int] ), $MsgPart02
      }
      Write-Host $DiscountMsg
    } else {
      $Discount = 0
      "Discounts will be applied by a bracketing system"
    }

    Write-Host $DiscountMsg
    Write-BufferLine

    $FoundHalfOffList = $false
    $HalfOFfListPath = Get-ChildItem $HalfOffDir\*Cards*csv
    if ( $HalfOFfListPath ) {
      $FoundHalfOffList = $true
      $HalfOffCardsListed = $false
      $HalfOffCardsList = @()
      $HalfOffList = Import-CSV $HalfOFfListPath
      Write-Host "A half-off list was located & will be applied"
      Write-BufferLine
    }

    Write-Host "Loaded current set as:"
    Write-Host $NowSet
    Write-BufferLine
    Write-Host "Loading inventory from the CSV file"
    Write-BufferLine
    $InventoryList = Import-CSV $TcgExportFile

    $TcgKeysHash = @{
      TcgProdName = "Product Name"
      TcgMktPrice = "TCG Market Price"
      TcgLowPrice = "TCG Low Price With Shipping"
      MyPrice     = "TCG MarketPlace Price"
      SetName     = "Set Name"
      Qty         = "Total Quantity"
      ID          = "TCGplayer Id"
      PhotoURL    = "Photo URL"
    }

    Write-Host "Determining price for each card in inventory"
    Write-BufferLine

    $BelowThresholdFile = Join-Path $UpdatesDir $BelowThresholdFileName

    $CardIndex = -1
    $UpdatedInventoryArray = foreach ( $Card in $InventoryList ) {
      $CardIndex++

      $CardName = $Card.($TcgKeysHash.TcgProdName)
      $CardID = $Card.($TcgKeysHash.ID)
      $TcgMktPrice = $Card.($TcgKeysHash.TcgMktPrice) -as [double]
      $TcgLowPrice = $Card.($TcgKeysHash.TcgLowPrice) -as [double]
      $CardSet = $Card.($TcgKeysHash.SetName)
      $CardQty = $Card.($TcgKeysHash.Qty) -as [int]
      $CardPic = $Card.($TcgKeysHash.PhotoURL)

      if ( [string]::IsNullOrEmpty($CardID) ) {
        Write-Warning ( "Failed to pull the card ID for {0}, the [{1}] card from the export file" -f $CardName, $CardIndex )
      }

      # Skip any inventory created via a photo ~ they cause glitches during the import prices step
      if ( -not [string]::IsNullOrEmpty($CardPic) ) {
        Write-Verbose ( "Skipping {0} : has a photo" -f $CardName )
        continue
      }

      if ( $CardQty -eq 0 ) {
        Write-Verbose ( "Skipping {0} : 0 qty in stock" -f $CardName )
        continue
      }

      if ( $TcgMktPrice -eq 0 ) {
        Write-Warning ( "Failed to find the TCG Market Price for {0}" -f $CardName )
        Write-BufferLine
        continue
      }

      $BottomPrice = [Math]::Round($MinimumPrice / ( 1 - 0.15 ), 2)
      $FloorFlag = $false
      if ( -not $FlatDiscount ) {
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
            if ( -not (Test-Path $BelowThresholdFile) ) {
              New-Item $BelowThresholdFile
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

            $CardName | Add-Content -Path $BelowThresholdFile
          }
        }
      }

      if ( $WarningFlag ) {
        Write-Warning $Warning
        Write-BufferLine
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
      Write-BufferLine
    }

    $DateStamp = (Get-Date).ToString("yyyy-MM-dd")
    $UpdatesFileName = "UpdatedPricing_{0}.csv" -f $DateStamp

    $ShortAlphabet = ('B', 'C', 'D', 'E', 'F')
    $Letter = $ShortAlphabet[0]
    $n = 0
    do {
      if ( $Letter -eq $ShortAlphabet[-1] ) {
        $ErrorDetails.Message = "Too many versions of output file have already been created. "
        Write-Error @ErrorDetails
      }

      $CheckFilePath = Join-Path $UpdatedDir $UpdatesFileName
      if ( Test-Path $CheckFilePath ) {
        if ( $n -eq 0 ) {
          Write-Verbose ""
          Write-Host "Determining output file name"
          Write-BufferLine
        }
        $Letter = $ShortAlphabet[$n++]
        $NewStamp = $DateStamp + '.' + $Letter
        $UpdatesFileName = $UpdatesFileName -replace $DateStamp, $NewStamp
      }
    } while ( Test-Path $CheckFilePath )

    $UpdatesFilePath = Join-Path $UpdatesDir $UpdatesFileName

    Write-Host "Exporting updated pricing CSV file"
    Write-BufferLine
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
