---
name: deploy-frontend
description: >
  Deploy the Multica frontend to production. Use this skill when asked to deploy the frontend,
  promote to production, or ship the web app. Triggers a GitHub Actions workflow that promotes
  the latest Vercel staging deployment to production.
---

# Deploy Frontend to Production

## Overview

The Multica frontend (Next.js app in `apps/web/`) is hosted on Vercel:

- **Staging** (`https://multica-app.copilothub.ai`): Auto-deploys on every merge to `main`.
- **Production**: Promoted from staging via the `Deploy Frontend to Production` GitHub Actions workflow.

## How to Deploy

### 1. Verify Staging

Before deploying, confirm that staging is healthy. Ask the user or check:

- The latest CI on `main` is green.
- Staging (`https://multica-app.copilothub.ai`) is working correctly.

### 2. Trigger the Deployment

Run the GitHub Actions workflow:

```bash
gh workflow run "Deploy Frontend to Production" --repo multica-ai/multica
```

### 3. Monitor the Deployment

Watch the workflow run:

```bash
gh run list --repo multica-ai/multica --workflow="Deploy Frontend to Production" --limit 1
```

To get detailed status:

```bash
gh run watch --repo multica-ai/multica $(gh run list --repo multica-ai/multica --workflow="Deploy Frontend to Production" --limit 1 --json databaseId --jq '.[0].databaseId')
```

### 4. Report the Result

After the workflow completes, post the result as a comment on the relevant issue. Include:

- Whether the deployment succeeded or failed.
- A link to the workflow run.

## Required Secrets

The GitHub Actions workflow requires these secrets (configured in the repo settings):

- `VERCEL_TOKEN` — Vercel API token with deploy permissions
- `VERCEL_PROJECT_ID` — The Vercel project ID for `multica-web-production`
- `VERCEL_ORG_ID` — The Vercel organization (team) ID for `indexlabs`

## Troubleshooting

- **Workflow not found**: Ensure the workflow file exists at `.github/workflows/deploy-production.yml`.
- **Permission denied**: The `gh` CLI must be authenticated with repo access.
- **Vercel errors**: Check that the secrets are correctly configured in the repo settings.
