# Configuration - Update these values with your actual values
$baseUrl = "https://[hostname]/BeyondTrust/api/public/v3/"
$apiKey = "key"
$runAsUser = "apiuser"




# Get the directory of the current script
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define the path to the stale assets CSV file and the output CSV file for results
$staleAssetsCsvPath = Join-Path -Path $scriptDirectory -ChildPath "output_stale_assets.csv"
$outputCsvPath = Join-Path -Path $scriptDirectory -ChildPath "deletion_results.csv"

# Used to bypass any cert errors
#region Trust All Certificates
# Uncomment the following block if you want to trust an unsecure connection when pointing to local Password Cache.
#
# The Invoke-RestMethod CmdLet does not currently have an option for ignoring SSL warnings (i.e self-signed CA certificates).
# This policy is a temporary workaround to allow that for development purposes.
# Warning: If using this policy, be absolutely sure the host is secure.
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem)
    {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#endregion

# Build the Authorization header
$headers = @{ Authorization="PS-Auth key=${apiKey}; runas=${runAsUser}" }

# Sign in to the BeyondTrust API
$signInResult = Invoke-RestMethod -Uri "${baseUrl}Auth/SignAppIn" -Method POST -Headers $headers -SessionVariable session

# Check if the sign-in was successful
if ($signInResult -eq $null -or $signInResult.error -ne $null) {
    Write-Error "Failed to sign in to BeyondTrust API."
    exit 1
}

# Import the CSV data
$staleAssets = Import-Csv -Path $staleAssetsCsvPath

# Create an array to hold results
$results = @()

# Iterate through each stale asset and perform the DELETE operation
foreach ($asset in $staleAssets) {
    $managedSystemID = $asset.ManagedSystemID
    $assetName = $asset.AssetName

    # Build the URI for the DELETE request
    $deleteUri = "${baseUrl}ManagedSystems/$managedSystemID"

    try {
        # Perform the DELETE request
        $response = Invoke-RestMethod -Uri $deleteUri -Method DELETE -Headers $headers -WebSession $session -ErrorAction Stop

        # Determine the status based on the response
        if ($response -eq $null -or $response -eq "") {
            $status = "Successfully Deleted"
        } else {
            $status = "Failed"
        }
    } catch {
        # Mark as failed for any exceptions
        $status = "Failed"
    }

    # Add the result to the results array
    $result = [pscustomobject]@{
        AssetName = $assetName
        ManagedSystemID = $managedSystemID
        Status = $status
    }
    $results += $result
}

# Export results to CSV
$results | Export-Csv -Path $outputCsvPath -NoTypeInformation

Write-Output "Deletion process complete. Results saved to $outputCsvPath."
Write-Output $response
