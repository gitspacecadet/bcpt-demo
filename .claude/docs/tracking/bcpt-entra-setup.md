# BCPT Entra App Setup - COMPLETED

## Objective
Create an Entra (Azure AD) app registration to authenticate and run BCPT performance tests against Business Central.

## Target Environment
- **BC URL**: https://businesscentral.dynamics.com/99029bc6-0bea-40ee-bf48-95a0f5d5598e/Production
- **Tenant ID**: 99029bc6-0bea-40ee-bf48-95a0f5d5598e
- **Tenant Domain**: CRM001668.onmicrosoft.com

## Entra App Registration - CREATED

| Property | Value |
|----------|-------|
| **Display Name** | BCPT-Automation |
| **Application (Client) ID** | `4a039eba-507c-4f36-8e2f-2741d50beb9e` |
| **Object ID** | `50b95aa5-4b79-4427-bcc9-3d06eea7ee68` |
| **Service Principal ID** | `e618a5a9-10bf-4dac-9900-d5dd28fd3a22` |
| **Tenant ID** | `99029bc6-0bea-40ee-bf48-95a0f5d5598e` |
| **Redirect URI** | `https://businesscentral.dynamics.com/OAuthLanding.htm` |
| **API Permissions** | Dynamics 365 Business Central - API.ReadWrite.All (Application) |
| **Admin Consent** | Granted |
| **Secret Expiry** | 1 year from 2025-12-04 |

## Progress

### Completed
- [x] Created CLAUDE.md for project guidance
- [x] Created .claude/settings.local.json with MCP servers
- [x] Added lokka-mcp for Entra operations (approval required)
- [x] Added business-central MCP server for BC API operations
- [x] Verified Azure CLI available
- [x] User authenticated as admin@CRM001668.onmicrosoft.com
- [x] Created Entra app registration "BCPT-Automation"
- [x] Added Dynamics 365 Business Central API permissions
- [x] Created service principal
- [x] Generated client secret (valid 1 year)
- [x] Granted admin consent
- [x] Added redirect URI: https://businesscentral.dynamics.com/OAuthLanding.htm

### Completed
- [x] **USER ACTION COMPLETED**: App registered in Business Central
- [x] Test API connection to BC - **PASSED** (2025-12-04)

### Next Steps
- [ ] Deploy BCPT extension to environment
- [ ] Run BCPT suite via API

## BC App Registration (Completed)

The Entra app was registered in BC manually with these settings:
- **Client ID**: `4a039eba-507c-4f36-8e2f-2741d50beb9e`
- **Description**: BCPT-Automation
- **State**: Enabled
- **Permission Sets**: D365 AUTOMATION, D365 FULL ACCESS

## Client Secret

**IMPORTANT**: The client secret is stored in `.claude/secrets/bcpt-credentials.env`
This file is gitignored and should NEVER be committed.

## API Test Results (2025-12-04)

```
Testing BC API Connection...
Tenant: 99029bc6-0bea-40ee-bf48-95a0f5d5598e
Client ID: 4a039eba-507c-4f36-8e2f-2741d50beb9e
Environment: Production

Token acquired successfully!
Token expires in: 3599 seconds

API call successful!

Found 2 company(ies):
  - CRONUS USA, Inc. (ID: edf8a60c-fdb9-f011-af60-6045bde9b982)
  - My Company (ID: d8990917-fdb9-f011-af60-6045bde9b982)

BC API connection test PASSED!
```

## Resume Next Session

To deploy the BCPT extension and run tests:

```
Deploy BCPT extension to BC and run a test suite
```

## MCP Servers Configured

| MCP Server | Purpose |
|------------|---------|
| `lokka` | Microsoft Graph / Entra ID operations |
| `business-central` | BC API operations (list companies, run BCPT) |

## Lokka MCP App Registration

| Property | Value |
|----------|-------|
| **Display Name** | Lokka-MCP-Claude |
| **Application (Client) ID** | `eab57e14-d379-4ee1-a1ba-52434b6e7540` |
| **Object ID** | `f11a5607-5c20-46c7-923e-c4eb3e86766e` |
| **Service Principal ID** | `0593d8e7-241e-4b7d-90d9-50f73067250e` |
| **Tenant ID** | `99029bc6-0bea-40ee-bf48-95a0f5d5598e` |
| **Redirect URI** | `http://localhost` |
| **API Permissions** | Microsoft Graph: Application.Read.All, Directory.Read.All, User.Read.All |
| **Admin Consent** | Granted |
| **Secret Expiry** | 1 year from 2025-12-04 |

The lokka MCP is pre-configured in settings.local.json with client credentials for automatic authentication.

## Usage

### PowerShell Authentication
```powershell
$tenantId = "99029bc6-0bea-40ee-bf48-95a0f5d5598e"
$clientId = "4a039eba-507c-4f36-8e2f-2741d50beb9e"
$clientSecret = $env:BCPT_CLIENT_SECRET

$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "https://api.businesscentral.dynamics.com/.default"
}

$token = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method Post -Body $body
```

### BC API Call
```powershell
$headers = @{ Authorization = "Bearer $($token.access_token)" }
$bcUrl = "https://api.businesscentral.dynamics.com/v2.0/$tenantId/Production/api/v2.0/companies"
Invoke-RestMethod -Uri $bcUrl -Headers $headers
```

### Test Script
```powershell
# Run from project root
powershell -ExecutionPolicy Bypass -File ".claude/scripts/test-bc-api.ps1"
```
