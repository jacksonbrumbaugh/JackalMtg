function Convert-Shipping {
  process {
    $DownloadDirectory = Join-Path $Home "Downloads"

    $FileDate = (Get-Date).ToString( "yyyyMMdd" )

    $ExportedShippingFile = Get-Item $DownloadDirectory\*ShippingExport*$FileDate*csv

    if ( [string]::IsNullOrEmpty($ExportedShippingFile) ) {
      Write-Error -Message "Failed to find an exported shipping file. " -ErrorAction "Stop"
    }

    $ShippingRecordArray = Import-CSV $ExportedShippingFile

    $FormattedShippingArray = foreach ( $ThisRecord in $ShippingRecordArray ) {
      $FullName = ($ThisRecord.FirstName + " " + $ThisRecord.LastName).ToUpper()
      $Add1 = ($ThisRecord.Address1).ToUpper()
      $Add2 = ($ThisRecord.Address2).ToUpper()
      $CSZ = ("{0}, {1}  {2}" -f $ThisRecord.City, $ThisRecord.State, $ThisRecord.PostalCode).ToUpper()

      $hasAdd2 = -not [string]::IsNullOrEmpty($Add2)

      $Line4 = $CSZ
      $Line3 = $Add1
      $Line2 = if ( $hasAdd2 ) { $Add2 } else { $FullName }
      $Line1 = if ( $hasAdd2 ) { $FullName } else { $null }

      [PSCustomObject]@{
        Line1 = $Line1
        Line2 = $Line2
        Line3 = $Line3
        Line4 = $Line4
      }

    }

    $OutputPath = Join-Path $DownloadDirectory "ShippingLabels-$FileDate.csv"
 
    $FormattedShippingArray | Export-CSV -NTI -Path $OutputPath

    if ( Test-Path $OutputPath ) {
      Remove-Item $ExportedShippingFile
    }

    $DymoAppPath = "C:\Program Files (x86)\DYMO\DYMO Connect\DYMOConnect.exe"
    if ( Test-Path $DymoAppPath ) {
      . $DymoAppPath
    }

  } # End block:process

} # End function
