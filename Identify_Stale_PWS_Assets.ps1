# Get the directory of the current script
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define the paths to the input and output CSV files
$inputCsvPath = Join-Path -Path $scriptDirectory -ChildPath "assets.csv"
$outputCsvPathAllAssets = Join-Path -Path $scriptDirectory -ChildPath "output_all_assets.csv"
$outputCsvPathStaleAssets = Join-Path -Path $scriptDirectory -ChildPath "output_stale_assets.csv"

# Define date formats to try
$dateFormats = @("MM/dd/yyyy HH:mm", "MM/dd/yyyy h:mm:ss tt", "MM/dd/yyyy HH:mm:ss", "M/d/yyyy h:mm:ss tt", "M/d/yyyy HH:mm:ss")

# Function to safely parse a date with multiple formats
function Parse-Date {
    param (
        [string]$dateString
    )
    foreach ($format in $dateFormats) {
        try {
            return [DateTime]::ParseExact($dateString, $format, $null)
        } catch {
            continue
        }
    }
    return $null  # Return null if no format matches
}

# Import the CSV data
$assets = Import-Csv -Path $inputCsvPath

# Convert CreateDate and LastUpdateDate to DateTime using the Parse-Date function
$assets | ForEach-Object {
    $_.CreateDate = Parse-Date $_.CreateDate
    $_.LastUpdateDate = Parse-Date $_.LastUpdateDate
}

# Group by AssetName to find duplicates
$groupedAssets = $assets | Group-Object -Property AssetName

# Initialize arrays to store results
$allAssets = @()
$staleAssets = @()

foreach ($group in $groupedAssets) {
    $groupItems = $group.Group
    if ($groupItems.Count -gt 1) {
        # Find the most recent asset
        $mostRecentAsset = $groupItems | Sort-Object -Property CreateDate -Descending | Select-Object -First 1
        
        foreach ($item in $groupItems) {
            $status = if ($item.AssetID -eq $mostRecentAsset.AssetID) { 'current' } else { 'stale' }
            $item | Add-Member -MemberType NoteProperty -Name Status -Value $status -PassThru
            
            if ($status -eq 'stale') {
                $staleAssets += $item
            }
        }
    } else {
        $groupItems[0] | Add-Member -MemberType NoteProperty -Name Status -Value 'current' -PassThru
    }
    
    $allAssets += $groupItems
}

# Select required columns for the first output
$allAssets | Select-Object AssetName, AssetID, ManagedSystemID, CreateDate, Status | Export-Csv -Path $outputCsvPathAllAssets -NoTypeInformation

# Select required columns for the stale assets output, matching the first output columns
$staleAssets | Select-Object AssetName, AssetID, ManagedSystemID, CreateDate, Status | Export-Csv -Path $outputCsvPathStaleAssets -NoTypeInformation
