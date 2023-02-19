function New-HalfOffCard {
  $Params = Get-JklMtgParam

  $TargetDrive = $Params.TargetDrive
  $SellerDir = Join-Path $TargetDrive $Params.MainSellerDir
  $HalfOffDir = Join-Path $SellerDir $Params.HalfOffDir
  $HalfOffLotPath = Join-Path $HalfOffDir "HalfOffLot.csv"
  $HalfOffCardsPath = Join-Path $HalfOffDir "HalfOffCards.csv"

  @(
    $HalfOffDir,
    $HalfOffLotPath,
    $HalfOffCardsPath
  ) | ForEach-Object {
    if ( -not(Test-Path $_) ) {
      throw ( "Failed to find a needed path : " + $_ )
    }
  }

  $LotList = Import-CSV $HalfOffLotPath
  $ChosenCard = $LotList | Get-Random
  $ChosenCardName = $ChosenCard."Product Name"
  $ChosenCardSet = $ChosenCard."Set Name"

  Write-Host ( $ChosenCardName + " from " + $ChosenCardSet + " was randomly picked" )

  $NewLotList = $LotList | ForEach-Object {
    if ( $_ -ne $ChosenCard ) {
      $_
    }
  }

  $HalfOffCardsList = Import-CSV $HalfOffCardsPath
  $NewHalfOffCardsList = $HalfOffCardsList, $ChosenCard | ForEach-Object {
    $_
  }

  $NewLotList | Export-CSV -NTI -Path $HalfOffLotPath
  $NewHalfOffCardsList | Export-CSV -NTI -Path $HalfOffCardsPath
}
