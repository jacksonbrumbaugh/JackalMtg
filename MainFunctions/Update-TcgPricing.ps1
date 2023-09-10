<#
.SYNOPSIS
Creates a CSV file of updated card prices to be uploaded to TCGPlayer.com

.NOTES
Created by Jackson Brumbaugh
Version Code: 2023Sep10-JCB

Stretch: [
  {
    Name: Call-Out Fuction
    Desc: [
      Bundle the {Write-Host __; Write-BufferLine} block into its own function Write-CallOut
    ]
  }
]
#>
function Update-TcgPricing {
  [CmdletBinding( DefaultParameterSetName = "UseTcgMkt")]
  param (
    <# Kept using this so much that JCB decided to make it the default use case
    [Parameter(
      Mandatory = $true,
      ParameterSetName = "UseTcgMkt"
      )]
      [Alias("NoDiscount")]
      [switch]
      $FullPrice,
    #>

    [Parameter(
      Mandatory = $true,
      ParameterSetName = "UseBracket"
    )]
    [switch]
    $Bracket,

    [Parameter(
      Mandatory = $true,
      ParameterSetName = "UseThisDiscount"
    )]
    [double]
    $Discount,

    [Parameter(
      Mandatory = $true,
      ParameterSetName = "UseDefaultDiscount"
    )]
    [switch]
    $DefaultDiscount

  ) # End block:param

  begin {
    function Write-BufferLine { Write-Host "" }

    $ErrorDetails = @{
      ErrorAction = "Stop"
    }

    $BelowThresholdFileName = "ListOfCardsBelowSellingThreshold.txt"

    $SelectedParameterSetName = $PSCmdlet.ParameterSetName
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

    if ( $env:Username -eq "JackalBruit" ) {
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

    $ParamDiscount = $UserParams.UsualDiscount -as [double]
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

    $UseDiscountBracket = $true

    $UseFullPriceParamSet = $SelectedParameterSetName -match "UseTcgMkt"
    $DiscountMsg = if ( $PSBoundParameters.ContainsKey("Discount") -or $DefaultDiscount -or $UseFullPriceParamSet ) {
      $UseDiscountBracket = $false

      $AppliedDiscount = switch -Wildcard ( $SelectedParameterSetName ) {
        "*This*"   { $Discount }
        "*Default*" { $ParamDiscount }
        "*TcgMkt*" { 0 }
      }

      Write-Verbose "AppliedDiscount: $($AppliedDiscount)"

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

      # Send up to DiscountMsg
      $MsgPart01 = "A discount of"
      $MsgPart02 = "from TCG Market Price will be applied. "
      if ( $AppliedDiscount -eq 0 ) {
        "No discount" + " " + $MsgPart02
      } else {
        "{0} {1:D2}% {2}" -f $MsgPart01, ( 100*$AppliedDiscount -as [int] ), $MsgPart02
      }
    } else {
      $Discount = 0
      "Discounts will be applied by a bracket system. "
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

    # JCB has a hunch more param sets will be added to skip this call-out
    if ( $SelectedParameterSetName -in ("UseTcgMkt") ) {
      # This call-out is useful when using a discount EXCEPT FOR the current / most-recent standard legal set   
      Write-Host "Loaded current set as:"
      Write-Host $NowSet
      Write-BufferLine
    }

    Write-Host "Loading inventory from the CSV file"
    Write-Host "CSV File Name: $($ExportFileName)"
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

    Write-Host "Setting price for each card from inventory"
    Write-BufferLine

    $BelowThresholdFile = Join-Path $UpdatesDir $BelowThresholdFileName

    $ValueAsOfLine = "TCG Market Values as of {0}" -f (Get-Date).ToString( "ddd yyyy.MM.dd" )
    if ( Test-Path $BelowThresholdFile ) {
      Set-Content -Path $BelowThresholdFile -Value $ValueAsOfLine
    }

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
        continue
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

      $FloorFlag = $false
      # The discount will be reapplied below
      $MaxDiscount = 0.5
      $BottomPrice = 0.2 # [Math]::Round($MinimumPrice / ( 1 - $MaxDiscount ), 2)
      if ( $UseDiscountBracket ) {
        $Discount = switch ( $TcgMktPrice ) {
          { $_ -gt 15 } { 0.10; break }
          { $_ -gt 10 } { 0.15; break }
          { $_ -gt 5  } { 0.20; break }
          { $_ -gt 3  } { 0.25; break }
          { $_ -gt 2  } { 0.30; break }
          { $_ -gt 1  } { 0.40; break }
          { $_ -ge $BottomPrice } { $MaxDiscount; break }
          Default {
            $FloorFlag = $true
            0
          }
        }
        $Multiplier = 1 - $Discount
      }

      $ThisCardGetsHalfOff = $false
      if ( $FoundHalfOffList ) {
        if ( $CardID -in $HalfOffList.($TcgKeysHash.ID) ) {
          $ThisCardGetsHalfOff = $true
          $HalfOffCardsListed = $true
          $Multiplier = 0.5
        }
      }

      $DiscountPrice = if ( -not $FloorFlag ) {
        # Multiply then divide by the 100 to mimic rounding
        [Math]::Floor( 100 * $Multiplier * $TcgMktPrice ) / 100
      } else {
        $MinimumPrice
      }

      $TargetPrice = $DiscountPrice

      $MinChecks = @(
        @{ Type = "TCG MKT";    Price = $TcgMktPrice },
        @{ Type = "Discounted"; Price = $DiscountPrice }
      )

      $WarningFlag = $null
      if ( $ThisCardGetsHalfOff ) {
        # Open for future development ... & to avoid a -not in the IF statement
      } else {
        foreach ( $MinCheck in $MinChecks ) {
          $CheckPrice = $MinCheck.Price
          $CheckType = $MinCheck.Type
          # Use strictly less than ... or ull get A TON of warnings
          if ( $CheckPrice -lt $MinimumPrice ) {
            if ( -not (Test-Path $BelowThresholdFile) ) {
              $ValueAsOfLine | Set-Content -Path $BelowThresholdFile
            }

            $WarningFlag = $true

            $TargetPrice = $MinimumPrice

            $Warning = $CardName
            $Warning += " has a "
            $Warning += $CheckType
            $Warning += " price of "
            $Warning += $CheckPrice
            $Warning += " but the min of "
            $Warning +=  $MinimumPrice
            $Warning += " was used instead. "

            # 35 arbitrarily chosen
            $BelowThresholdLine = "{0, -35}: `${1:N2}" -f $CardName, $TcgMktPrice

            $BelowThresholdLine | Add-Content -Path $BelowThresholdFile

            # This should break out of the foreach loop since I only care that the price was below 1 of the checked prices
            break

          } # End block:if CheckPrice is less than the Minimum selling price

        } # End block:foreach MinCheck

      } # End block:if Checking for below min selling price

      if ( $WarningFlag ) {
        #Write-Warning $Warning
        #Write-BufferLine
      }

      if ( $CardSet -eq $NowSet ) {
        # Cards from the Now (most recent standard) Set do not get a discount
        $TargetPrice = [math]::Max( $TcgMktPrice, $MinimumPrice )
      }

      # TCG Player mandates that any order total less than $5 must charge a min $0.99 S&H fee
      $CardShipping = if ( $TcgLowPrice -lt 5 ) {
        0.99
      } else {
        $ShippingCost
      }

      $NewPrice = if ( $ThisCardGetsHalfOff ) {
        $HalfOffCardsList += $CardName  + " from the set " + $CardSet
        $TargetPrice
      } else {
        [Math]::Max( $TargetPrice, ($TcgLowPrice - $CardShipping) )
      }

      if ( $NewPrice -lt 0.5 ) {
        $NewPrice = switch ( $NewPrice ) {
          { $_ -ge 0.2 } {
            0.2 + 0.05*[math]::Ceiling( ($NewPrice - 0.2)/0.05)
          }
          Default {
            0.2
          }
        }
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
        $ErrorDetails.Message = "Too many versions of output file have already been created. Try another day \="
        Write-Error @ErrorDetails
      }

      $CheckFilePath = Join-Path $UpdatedDir $UpdatesFileName
      if ( Test-Path $CheckFilePath ) {
        if ( $n -eq 0 ) {
          Write-Verbose ""
          Write-Host "Setting output file name"
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

    # Testing if moving this up will prevent the call-out about archiving the TCG Export file
    Write-Output $Result

    if ( -not($Result.Creation) ) {
      Write-Warning ( "Failed to create an updated pricing CSV file" )
    } else {
      if ( Test-Path $ArchiveDir ) {
        Write-Host "Archiving Exported TCG file"
        Move-Item $TcgExportFile $ArchiveDir -Force
        Invoke-Item $UpdatesDir
      }
    }

  } # End block:process

} # End function

<#
$Aliases_MTG_UpdateTcgPricing = @('UTP')

$Aliases_MTG_UpdateTcgPricing | ForEach-Object {
    Set-Alias -Name $_ -Value Update-TcgPricing
}
#>