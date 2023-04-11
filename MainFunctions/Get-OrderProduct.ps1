function Get-OrderProduct {
  [CmdletBinding()]
  param ()

  process {
    Write-Warning "This function is still being developed. "

    <#
    After running Get-Listing
    want to use an input array of fuzzy card names to output the info for TCG Sales > CardsSold
    e.g.
    Magic - The Brothers' War: Urza, Lord Protector - #225 - Near Mint [Foil]
    the [Foil] bit only shows when appropriate

    Raw CmdLine Code
    $TotalValue = 0; foreach ( $ThisCard in $Listing ) {
    $Name = $ThisCard.Name
    $isSold = $false
    if ( $Name -match "Lord Protector" ) { $isSold = $true }
    if ( $Name -match "Yawgmoth Praetor" ) { $isSold = $true }
    if ( $Name -match "Brotherhood" ) { $isSold = $true }
    if ( $isSold ) {
    $TotalValue += $ThisCard.Price
    "Magic - {0}: {1} - #{2} - {3}" -f $ThisCard.Set, $ThisCard.Name, $ThisCard."Set Code", $ThisCard.Condition
    }
    }

    &

    foreach ( $ThisCard in $Listing ) {
    $Name = $ThisCard.Name
    $isSold = $false
    if ( $Name -match "Lord Protector" ) { $isSold = $true }
    if ( $Name -match "Yawgmoth Praetor" ) { $isSold = $true }
    if ( $Name -match "Brotherhood" ) { $isSold = $true }
    if ( $isSold ) {
    "Magic - {0}: {1} - #{2} - {3}" -f $ThisCard.Set, $ThisCard.Name, $ThisCard."Card Number", $ThisCard.Condition
    "Order Value: {0}" -f (17 * $ThisCard.Price / $TotalValue)
    ""
    }
    }
    #>
  }

} # End function
