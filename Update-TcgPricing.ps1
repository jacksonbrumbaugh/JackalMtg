function Update-TcgPricing {
  [CmdletBinding()]
  param(
    [double]$Discount
  ) #END block::param

  process {
    $UpdatedDir = "J:\MTG\Seller\PriceUpdates"
    if ( -not(Test-Path $UpdatedDir) ) {
      throw ( "Failed to locate the Updated folder : " + $UpdatedDir )
    }

    $DownloadsPath = "C:\Users\jcb55\Downloads"
    if ( -not(Test-Path $DownloadsPath) ) {
      throw ( "Failed to find the Downloads folder : " + $DownloadsPath )
    }

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

    $Name = "Product Name"
    $TcgMarket = "TCG Market Price"
    $MyPrice = "TCG MarketPlace Price"

    $InventoryList | ForEach-Object {
      $MarketPrice = $_.$TcgMarket -as [double]
      if ( -not($MarketPrice) ) {
        Write-Warning ( "Failed to grab TCG Market Price for " + $_.$Name )
        continue
      }

      $NewPrice = [Math]::Floor( 100 * $Multiplier * $MarketPrice ) / 100

      $_.$MyPrice = $NewPrice
    }

    $UpdatedFileName = "UpdatedPricing_{0}.csv" -f (Get-Date).ToString("yyyy-MM-dd")
    $UpdatedFilePath = Join-Path $UpdatedDir $UpdatedFileName

    $InventoryList | Export-CSV -NTI -Path $UpdatedFilePath

    $Result = [PSCustomObject]@{
      FileName = $UpdatedFileName
      Creation = Test-Path $UpdatedFilePath
    }

    if ( -not($Result.Creation) ) {
      Write-Warning ( "Failed to create an updated pricing CSV file")
    } else {
      Remove-Item $TcgExportFile
    }

    Write-Output $Result
  } #END block::process
}

