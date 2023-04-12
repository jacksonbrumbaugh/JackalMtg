function Get-ScryfallCard {
  param (
    [Parameter(
      Mandatory,
      ValueFromRemainingArguments
    )]
    [string[]]
    $Name
  )

  process {
    $FuzzyName = $Name -join "+"
    $BaseURI = "https://api.scryfall.com/cards/named?fuzzy="
    $URI = $BaseURI + $FuzzyName
    Invoke-RestMethod -Method GET -URI $URI

  } # End block:process

} # End function
