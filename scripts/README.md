# Chart Publishing Scripts

## Automatic Publishing

The repository uses GitHub Actions to automatically publish charts when changes are pushed to the `main` branch.

The workflow (`.github/workflows/release.yaml`) will:
1. Package all charts in the `charts/` directory
2. Create GitHub releases for new chart versions
3. Generate `index.yaml` in the `gh-pages` branch
4. Generate `index.html` from `index.yaml` in the `gh-pages` branch

No manual intervention needed!

## Manual Publishing

To manually trigger the workflow:

```bash
gh workflow run release.yaml
```

Or from GitHub UI:
1. Go to Actions tab
2. Select "Release Charts" workflow
3. Click "Run workflow"

## Generating index.html Locally

The `index.html` landing page is generated from `index.yaml` using `index.py`:

```bash
cd scripts
./index.py <path-to-index.yaml> <output-index.html>
```

Requirements:
- Python 3.11+
- uv (will auto-install dependencies: PyYAML, Jinja2)

The script:
- Parses `index.yaml` to extract chart information
- Extracts keywords from Chart.yaml metadata
- Renders `index.html.j2` template

## Verifying the Release

After publishing, verify:

```bash
helm repo add prefeitura-rio https://prefeitura-rio.github.io/charts
helm repo update
helm search repo prefeitura-rio
```

You should see all charts with their latest versions.

## Files

- `index.py` - Python script to generate HTML from YAML
- `index.html.j2` - Jinja2 template for the landing page
- `README.md` - This file
