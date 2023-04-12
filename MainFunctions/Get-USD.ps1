function Get-USD {
  param (
    [Parameter(
      Mandatory,
      ValueFromRemainingArguments
    )]
    [string[]]
    $Name
  )

  process {
    $CardData = Get-ScryfallCard $Name

    [PSCustomObject]@{
      Name = $CardData.Name
      USD  = $CardData.Prices.USD
    }

  } # End block:process

} # End function
