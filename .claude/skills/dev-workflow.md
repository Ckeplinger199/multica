---
description: Multica development workflow — branch management, PR creation, and deployment process. Use after completing a feature or fix to create the correct PRs.
user_invocable: true
---

# Multica Development Workflow

## Branch Strategy

| Branch | Environment | URL |
|--------|-------------|-----|
| `main` | Production | https://multica.ai |
| `dev` | Staging/Testing | https://multica-app.copilothub.ai |

Feature branches are created from `dev` (or `main`) and merged through a two-stage PR process.

## After Completing Your Work

### Step 1: Create PR to `dev`

Create a pull request targeting the `dev` branch for staging deployment and testing.

```bash
gh pr create --base dev --title "<conventional title>" --body "$(cat <<'EOF'
## Summary
<describe changes>

## Test plan
<how to verify>
EOF
)"
```

Post the PR link as a comment on your issue so the team knows it's ready for review.

### Step 2: Wait for staging verification

After the PR to `dev` is merged and deployed to https://multica-app.copilothub.ai, the team will verify the changes on staging. Do **not** proceed to step 3 until staging verification is confirmed.

### Step 3: Create PR to `main`

Once staging is verified, create a second pull request to merge your feature branch into `main` for production deployment.

```bash
gh pr create --base main --title "<conventional title>" --body "$(cat <<'EOF'
## Summary
<describe changes>

Staging PR: <link to dev PR>

## Test plan
Verified on staging: https://multica-app.copilothub.ai
EOF
)"
```

## PR Title Format

Follow conventional commit format for PR titles:
- `feat(scope): description` — new feature
- `fix(scope): description` — bug fix
- `refactor(scope): description` — code refactor
- `docs: description` — documentation
- `test(scope): description` — tests
- `chore(scope): description` — maintenance

## Checklist

Before creating any PR:
1. Ensure your branch is pushed to remote: `git push -u origin <branch>`
2. Run relevant checks (`make check` or subset)
3. Target `dev` first, never push directly to `main`
