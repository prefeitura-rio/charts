#!/bin/bash

CHART_RELEASER_VERSION=1.3.0
CHARTS_DIR=./charts
PACKAGE_DESTINATION_DIR=.deploy
CHARTS_OWNER=prefeitura-rio
CHARTS_REPONAME=charts

# Download chart-releaser
echo "Downloading chart-releaser..."
mkdir -p bin/ && cd bin/
curl -sSL https://github.com/helm/chart-releaser/releases/download/v${CHART_RELEASER_VERSION}/chart-releaser_${CHART_RELEASER_VERSION}_linux_amd64.tar.gz | tar xzf -
cd ..
echo "Done."

# Package helm charts
echo "Packaging helm charts..."
mkdir -p ${PACKAGE_DESTINATION_DIR}/
helm package ${CHARTS_DIR}/* --destination ${PACKAGE_DESTINATION_DIR}
echo "Done."

# Create a new release
echo "Creating a new release..."
./bin/cr upload -o ${CHARTS_OWNER} -r ${CHARTS_REPONAME} -p ${PACKAGE_DESTINATION_DIR} --token ${GITHUB_TOKEN}
echo "Done."

# Upload index to GitHub Pages
echo "Uploading index to GitHub Pages..."
git checkout gh-pages
./bin/cr index -i ./index.yaml -p ${PACKAGE_DESTINATION_DIR} --owner ${CHARTS_OWNER} -r ${CHARTS_REPONAME} --token ${GITHUB_TOKEN} -c https://${CHARTS_OWNER}.github.io/${CHARTS_REPONAME}/
git add -A
git commit -m "Update index.yaml"
# git push origin gh-pages
echo "Done."
