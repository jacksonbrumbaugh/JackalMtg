function Get-FullScryfallSet {
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
            'KHM',
            'STX',
            'AFR',
            'MID',
            'VOW',
            'NEO',
            'SNC',
            'DMU',
            'BRO',
            'ONE',
            'MOM'
        )]
        $Set = 'MOM'
    )

<# Expand to rarity selection
Current verison only pulls the Rare && Mythic rarities
but would like to inclue an option to pull the Commons && Uncommons

URL'z:
"https://scryfall.com/search?q=set%3Aneo+%28rarity%3Ac+OR+rarity%3Au+OR+rarity%3Ar+OR+rarity%3Am%29&order=set&as=checklist"

&&

"https://scryfall.com/search?as=checklist&order=set&page=2&q=set%3Aneo+%28rarity%3Ac+OR+rarity%3Au+OR+rarity%3Ar+OR+rarity%3Am%29&unique=cards"
#>

    process {
        $URL = 'https://scryfall.com/search?q=set%3A' +
            $Set +
            "+%28rarity%3Ac+" +
            "OR+rarity%3Au+" + 
            "OR+rarity%3Ar+" + 
            "OR+rarity%3Am" +
            "%29&unique=cards&order=set&as=checklist"

        $Request = Invoke-WebRequest -Uri $URL #-UseBasicParsing
        $Table = $Request.ParsedHtml.GetElementsByTagName('table')[0]
        $Rows = $Table.Rows

        $Page2Url = "https://scryfall.com/search?as=checklist&order=set&page=2&q=set%3A" + 
            $Set + 
            "+%28rarity%3Ac+" + 
            "OR+rarity%3Au+" +
            "OR+rarity%3Ar+" +
            "OR+rarity%3Am" + 
            "%29&unique=cards"

            $Page2Request = Invoke-WebRequest -URI $Page2Url
            # "&unique=cards&page=2"

        $TablePage2 = $Page2Request.ParsedHtml.GetElementsByTagName('table')[0]
        $Rows += $TablePage2.Rows

        $TestHeader = $Rows[0]

        $i = 0
        $Fields = @{}
        $HasHeader = $false
        foreach ($Cell in $TestHeader.Cells) {
            if ($Cell.TagName -eq 'TH') {
                $HasHeader = $true

                $Value = $Cell.InnerText.trim() -replace '\W','|'
                $Value = $Value -replace 'Set\|\|','Set'
                $Value = $Value -replace '\|','Num'

                $Fields[$i] = $Value
            } else {
                $Fields[$i] = 'H$i'
            }
            $i++
        }

        $Cards = @()
        foreach ($Row in $Rows) {
            if ($HasHeader -and $Row -eq $Rows[0]) {
                continue
            }
            $i = 0
            $CardParams = [ordered]@{}
            foreach ($Cell in $Row.Cells) {
                $Value = $Cell.InnerText
                $CardParams[$Fields[$i++]] = if ($null -ne $Value) {
                    $Value.trim()
                } else {
                    $null
                }
            }
            $Cards += New-Object -TypeName PSObject -Property $CardParams
        }

        Write-Output $Cards
    }
}