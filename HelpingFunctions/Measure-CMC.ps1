function Measure-CMC {
    [CmdletBinding()]
    param(
        [string[]]
        [Parameter(Mandatory,
            ValueFromPipeline)]
        [Alias('Cost', 'C')]
        $ManaCost
    )

    process {
        foreach ($MC in $ManaCost) {
            $CostValues = $MC -replace "[^WUBRG\d]",""

            $CMC = 0
            foreach ($Symbol in $CostValues.ToCharArray()) {
                $SymbolStr = $Symbol.ToString()
                if ($SymbolStr -match "\d") {
                    $CMC += $SymbolStr
                } else {
                    $CMC++
                }
            }

            Write-Output $CMC
        } # End foreach ManaCost

    } # End process block

} # End function

$Aliases_MTG_MeasureCMC = @('CMC')

$Aliases_MTG_MeasureCMC | ForEach-Object {
    Set-Alias -Name $_ -Value Measure-CMC
}
