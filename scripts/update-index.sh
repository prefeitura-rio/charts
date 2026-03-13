#!/bin/bash
set -e

# Script to generate Helm repository index
# This should be run from the root of the repository

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS_DIR="$REPO_ROOT/charts"
PACKAGES_DIR="$REPO_ROOT/packages"
REPO_URL="https://prefeitura-rio.github.io/charts"

echo "==> Creating packages directory..."
mkdir -p "$PACKAGES_DIR"

echo "==> Packaging charts..."
cd "$CHARTS_DIR"
for chart in base-chart letta typesense; do
    if [ -d "$chart" ]; then
        echo "Packaging $chart..."
        helm package "$chart" -d "$PACKAGES_DIR"
    fi
done

echo "==> Generating index.yaml..."
cd "$PACKAGES_DIR"
helm repo index . --url "$REPO_URL"

echo "==> Moving index.yaml to root..."
mv index.yaml "$REPO_ROOT/"

echo ""
echo "Done! To publish:"
echo "1. Copy packages/*.tgz to gh-pages branch"
echo "2. Copy index.yaml to gh-pages branch"
echo "3. Copy index.html to gh-pages branch"
echo "4. Commit and push gh-pages branch"
echo ""
echo "Or use the GitHub Actions workflow to automate this."
