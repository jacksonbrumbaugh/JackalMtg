function New-ArenaChecklist {
    [CmdletBinding()]
    param(
        [string]
        [ValidateSet(
            'BFZ',
            'OGW',
            'SOI',
            'EMN',
            'KLD',
            'AER',
            'AKH',
            'HOU',
            'XLN',
            'RIX',
            'DOM',
            'M19',
            'GRN',
            'RNA',
            'WAR',
            'M20',
            'ELD',
            'THB',
            'IKO',
            'M21',
            'ZNR',
            'KHM'
        )]
        $Set = 'KHM',

        [string]
        $MtgDir = 'J:/MTG/Rares_Mythics'
    )

    begin {
        if (-not (Test-Path $MtgDir)) {
            throw "Cannot execute $($MyInvocation.MyCommand).  Cannot locate $MtgDir. "
        }

        $ColorlessChar = 'L'

        $ColorOrderHash = @{
            W              = 1
            U              = 2
            B              = 3
            R              = 4
            G              = 5
            $ColorlessChar = 9999
        }

        $TypeOrderHash = @{
            Creature     = 0
            Planeswalker = 1
            Instant      = 2
            Sorcery      = 3
            Enchantment  = 4
            Artifact     = 5
            Land         = 6
            Double       = 7
        }

        $BasicTypeHash = @{
            CRE = 'Creature'
            PLA = 'Planeswalker'
            INS = 'Instant'
            SOR = 'Sorcery'
            ENC = 'Enchantment'
            ART = 'Artifact'
            LND = 'Land'
            MDF = 'Double'
        }

        $TypeHash = @{
            'Lgd. Planeswalker'  = $BasicTypeHash['PLA']
            'Creature'           = $BasicTypeHash['CRE']
            'Snow Creature'      = $BasicTypeHash['CRE']
            'Enchantment'        = $BasicTypeHash['ENC']
            'Artifact'           = $BasicTypeHash['ART']
            'Lgd. Creature'      = $BasicTypeHash['CRE']
            'Lgd. Snow Creature' = $BasicTypeHash['CRE']
            'Instant'            = $BasicTypeHash['INS']
            'Snow Instant'       = $BasicTypeHash['INS']
            'Sorcery'            = $BasicTypeHash['SOR']
            'Snow Sorcery'       = $BasicTypeHash['SOR']
            'Lgd. Enchantment'   = $BasicTypeHash['ENC']
            'Lgd. Artifact'      = $BasicTypeHash['ART']
            'Artifact Creature'  = $BasicTypeHash['CRE']
            'Land'               = $BasicTypeHash['LND']
            'Snow Land'          = $BasicTypeHash['LND']
            'None'               = $BasicTypeHash['MDF']
        }
    }

    process {
        Write-Host "Pulling $Set cards from Scryfall"
        $Cards = Get-ScryfallSet $Set | ForEach-Object {
            $CardName = $_.Name

            $Type = $_.Type
            if ($null -eq $Type) {
                $Type = 'None'
            }
            if ($Type -notin $TypeHash.Keys) {
                if ($Type -match '//') {
                    $Type = $Type.split()[0]
                } else {
                    Write-Warning "Skipping since could not determine type for $CardName from $Type"
                    Continue
                }
            }

            $SimpleType = $TypeHash[$Type]

            $CardNum = [int]$_.Num

            $Cost = $_.Cost
            if ($null -eq $Cost) {
                $Cost = ''
            }
            $Color = ''
            foreach ($Symbol in $Cost.ToCharArray()) {
                $SymbolStr = $Symbol.ToString() -replace "[^WUBRG]",''
                if ($SymbolStr -notin $Color) {
                    $Color += $SymbolStr
                }
            }
            if ($Color -eq '') {
                $Color = $ColorlessChar
            }
            if ($Cost -eq '') {
                $Cost = 0
            }
            #$Color = $Cost -replace "[^WUBRG]",'' -replace "^\s*$",$ColorlessChar
            $ColorSort = if ($Color -in ('W', 'U', 'B', 'R', 'G', $ColorlessChar)) {
                $ColorOrderHash[$Color]
            } else {
                100 + $CardNum
            }

            [PSCustomObject]@{
                Name      = $CardName
                ManaCost  = $Cost
                Type      = $SimpleType
                Rarity    = $_.R
                Color     = $Color
                CMC       = Measure-CMC $Cost
                Num       = $CardNum
                TypeSort  = $TypeOrderHash[$SimpleType]
                ColorSort = $ColorSort
                CostLen   = $Cost.length
            }
        } | Sort-Object TypeSort, ColorSort, CMC, CostLen, Num

        Write-Host 'Sorting cards for checklist'
        $PrevType = 'CREATURE'
        $Checklist = @($PrevType)
        foreach ($Card in $Cards) {
            $Type = $Card.Type.ToUpper()
            if ($PrevType -ne $Type) {
                $Checklist += ''
                $Checklist += $Type
            }
            $PrevType = $Type
            $Checklist += $Card.Name, $Card.ManaCost, $Card.Rarity -join "`t"
        }

        $ChecklistFile = Join-Path $MtgDir "Rares_Mythics-$Set.txt"

        if (Test-Path $ChecklistFile) {
            Copy-Item $ChecklistFile -Destination ($ChecklistFile + '.bkup')
        }

        Set-Content -Path $ChecklistFile -Value $Checklist

        if (Test-Path $ChecklistFile) {
            Invoke-Item $ChecklistFile
        }
    }
}
