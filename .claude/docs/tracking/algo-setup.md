# AL-Go for GitHub Setup - IN PROGRESS

## Objective
Configure this repository as an AL-Go PTE repository for automated build and deployment to Business Central SaaS.

## Target Environment
- **BC Environment**: Production
- **Tenant ID**: 99029bc6-0bea-40ee-bf48-95a0f5d5598e
- **Company**: CRONUS USA, Inc. (edf8a60c-fdb9-f011-af60-6045bde9b982)

## Progress

### Completed
- [x] Added AL-Go MCP server to `.claude/settings.local.json`
- [x] Added GitHub MCP server (official `@github/mcp-server`)
- [x] Created `.AL-Go/settings.json` with PTE configuration
- [x] Downloaded AL-Go workflow files from microsoft/AL-Go-PTE:
  - CICD.yaml
  - _BuildALGoProject.yaml
  - PublishToEnvironment.yaml
  - PullRequestHandler.yaml
  - UpdateGitHubGoSystemFiles.yaml
- [x] Created `.AL-Go/localDevEnv.ps1` and `cloudDevEnv.ps1`

### Pending
- [ ] Configure GitHub repository secrets for deployment
- [ ] Push changes and trigger first CI/CD build
- [ ] Test deployment to Production environment

## GitHub Secrets Required

For AL-Go to deploy to BC SaaS, you need to create a GitHub secret called `Production_AuthContext` with the following JSON structure:

```json
{
  "tenantId": "99029bc6-0bea-40ee-bf48-95a0f5d5598e",
  "clientId": "4a039eba-507c-4f36-8e2f-2741d50beb9e",
  "clientSecret": "<YOUR_CLIENT_SECRET>",
  "scope": "https://api.businesscentral.dynamics.com/.default"
}
```

### How to Add the Secret

1. Go to: https://github.com/gitspacecadet/bcpt-demo/settings/secrets/actions
2. Click "New repository secret"
3. Name: `Production_AuthContext`
4. Value: The JSON above with your actual client secret
5. Click "Add secret"

Alternatively, via GitHub CLI:
```bash
gh secret set Production_AuthContext --body '{"tenantId":"99029bc6-0bea-40ee-bf48-95a0f5d5598e","clientId":"4a039eba-507c-4f36-8e2f-2741d50beb9e","clientSecret":"<SECRET>","scope":"https://api.businesscentral.dynamics.com/.default"}'
```

## Files Created/Modified

| File | Description |
|------|-------------|
| `.AL-Go/settings.json` | AL-Go repository settings |
| `.AL-Go/localDevEnv.ps1` | Local development environment script |
| `.AL-Go/cloudDevEnv.ps1` | Cloud development environment script |
| `.github/workflows/CICD.yaml` | Main CI/CD workflow |
| `.github/workflows/_BuildALGoProject.yaml` | Reusable build workflow |
| `.github/workflows/PublishToEnvironment.yaml` | Manual deployment workflow |
| `.github/workflows/PullRequestHandler.yaml` | PR validation workflow |
| `.github/workflows/UpdateGitHubGoSystemFiles.yaml` | AL-Go self-update workflow |

## MCP Servers Added

| MCP Server | Package | Purpose |
|------------|---------|---------|
| `github` | `@github/mcp-server` | GitHub API operations |
| `al-go` | `al-go-mcp-server` | AL-Go documentation and guidance |

## Workflow Overview

### CI/CD Pipeline
- **Trigger**: Push to main/release/feature branches
- **Build**: Compiles AL code using AL-Go Actions v8.1
- **Deploy**: Automatically deploys to Production on main branch

### Manual Deployment
- **Workflow**: Publish To Environment
- **Usage**: Manually deploy specific versions to environments

## Resume Next Session

After configuring the GitHub secret:
```
Push the AL-Go changes and trigger a CI/CD build
```

## References

- [AL-Go Documentation](https://github.com/microsoft/AL-Go)
- [AL-Go for GitHub PTE Template](https://github.com/microsoft/AL-Go-PTE)
- [AL-Go MCP Server](https://github.com/louagej/al-go-mcp-server)
