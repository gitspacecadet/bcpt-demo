# Test BC API Connection
# Run this script to verify the Entra app can authenticate to Business Central

param(
    [string]$TenantId = "99029bc6-0bea-40ee-bf48-95a0f5d5598e",
    [string]$ClientId = "4a039eba-507c-4f36-8e2f-2741d50beb9e",
    [string]$ClientSecret = $env:BCPT_CLIENT_SECRET,
    [string]$Environment = "Production"
)

# Load from env file if secret not provided
if (-not $ClientSecret) {
    $envFile = Join-Path $PSScriptRoot "..\secrets\bcpt-credentials.env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                Set-Item -Path "env:$($matches[1])" -Value $matches[2]
            }
        }
        $ClientSecret = $env:BCPT_CLIENT_SECRET
    }
}

if (-not $ClientSecret) {
    Write-Error "Client secret not found. Set BCPT_CLIENT_SECRET environment variable or provide -ClientSecret parameter."
    exit 1
}

Write-Host "Testing BC API Connection..." -ForegroundColor Cyan
Write-Host "Tenant: $TenantId"
Write-Host "Client ID: $ClientId"
Write-Host "Environment: $Environment"
Write-Host ""

# Get OAuth token
$body = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://api.businesscentral.dynamics.com/.default"
}

try {
    Write-Host "Acquiring token..." -ForegroundColor Yellow
    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -Body $body
    Write-Host "Token acquired successfully!" -ForegroundColor Green
    Write-Host "Token expires in: $($tokenResponse.expires_in) seconds"
    Write-Host ""

    # Test BC API
    $headers = @{
        Authorization = "Bearer $($tokenResponse.access_token)"
        "Content-Type" = "application/json"
    }

    $bcUrl = "https://api.businesscentral.dynamics.com/v2.0/$TenantId/$Environment/api/v2.0/companies"
    Write-Host "Calling BC API: $bcUrl" -ForegroundColor Yellow

    $companies = Invoke-RestMethod -Uri $bcUrl -Headers $headers
    Write-Host "API call successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Found $($companies.value.Count) company(ies):" -ForegroundColor Cyan

    foreach ($company in $companies.value) {
        Write-Host "  - $($company.name)" -ForegroundColor White
        Write-Host "    ID: $($company.id)" -ForegroundColor Gray
        Write-Host "    Display Name: $($company.displayName)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "BC API connection test PASSED!" -ForegroundColor Green

    # Return company info for further use
    return $companies.value

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "BC API connection test FAILED!" -ForegroundColor Red
    exit 1
}
