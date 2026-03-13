# Chart Publishing Scripts

## Automatic Publishing (Recommended)

The repository uses GitHub Actions to automatically publish charts when changes are pushed to the `main` branch.

The workflow (`.github/workflows/release.yaml`) will:
1. Package all charts in the `charts/` directory
2. Create GitHub releases for new chart versions
3. Update the `index.yaml` in the `gh-pages` branch
4. Copy `index.html` to the `gh-pages` branch

No manual intervention is needed!

## Manual Publishing

If you need to manually publish charts:

### Option 1: Using the script

```bash
# From the repository root
./scripts/update-index.sh
```

This will:
- Package all charts to `packages/` directory
- Generate `index.yaml`

Then manually copy to gh-pages:
```bash
git checkout gh-pages
cp packages/*.tgz .
cp index.yaml .
cp index.html .
git add *.tgz index.yaml index.html
git commit -m "Release charts"
git push origin gh-pages
git checkout main
```

### Option 2: Using Helm directly

```bash
# Package charts
cd charts
helm package base-chart letta typesense -d ../packages

# Generate index
cd ../packages
helm repo index . --url https://prefeitura-rio.github.io/charts

# Move to gh-pages branch and commit
# (same as above)
```

## Updating index.html

The `index.html` is the front page of https://prefeitura-rio.github.io/charts

After updating chart versions in `index.html`, commit to main branch. The GitHub Actions workflow will automatically copy it to gh-pages.

Or manually:
```bash
git checkout gh-pages
git checkout main -- index.html
git commit -m "Update index.html"
git push origin gh-pages
```

## Verifying the Release

After publishing, verify:

```bash
helm repo add prefeitura-rio https://prefeitura-rio.github.io/charts
helm repo update
helm search repo prefeitura-rio
```

You should see all charts with their latest versions.
