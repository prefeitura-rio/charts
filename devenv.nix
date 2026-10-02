{ pkgs, ... }:

let
  untt = "${pkgs.kubernetes-helmPlugins.helm-unittest}/helm-unittest/untt";
  chartDirs = pkgs.writeShellScript "helm-chart-dirs" ''
    set -euo pipefail

    while IFS= read -r -d "" chartFile; do
      chartDir="$(dirname "$chartFile")"
      chartType="$(awk '$1 == "type:" { print $2; exit }' "$chartFile")"

      if [ "$chartType" != "library" ]; then
        printf '%s\n' "$chartDir"
      fi
    done < <(find charts -mindepth 2 -maxdepth 3 -type d -name charts -prune -o -name Chart.yaml -print0 | sort -z)
  '';
  helmDeps = pkgs.writeShellScript "helm-deps" ''
    set -euo pipefail
    cd "$(git rev-parse --show-toplevel)"

    while IFS= read -r chart; do
      helm dependency build "$chart"
    done < <(${chartDirs})
  '';
  helmLintAll = pkgs.writeShellScript "helm-lint-all" ''
    set -euo pipefail
    cd "$(git rev-parse --show-toplevel)"

    while IFS= read -r chart; do
      chartName="$(awk '$1 == "name:" { print $2; exit }' "$chart/Chart.yaml")"

      if [ "$chartName" = "agent-sandbox" ]; then
        chartAppVersion="$(awk '/^appVersion:/ { gsub(/"/, "", $2); print $2; exit }' "$chart/Chart.yaml")"
        helm lint "$chart" --set "image.tag=$chartAppVersion"
      else
        helm lint "$chart"
      fi
    done < <(${chartDirs})
  '';
  helmChartPath = pkgs.writeShellScript "helm-chart-path" ''
    set -euo pipefail
    requested="''${CHART:-base-chart}"

    while IFS= read -r chart; do
      chartName="$(awk '$1 == "name:" { print $2; exit }' "$chart/Chart.yaml")"
      if [ "$chartName" = "$requested" ]; then
        printf '%s\n' "$chart"
        exit 0
      fi
    done < <(${chartDirs})

    printf 'chart not found: %s\n' "$requested" >&2
    exit 1
  '';
in
{
  languages.helm.enable = true;

  git-hooks.hooks = {
    prettier = {
      enable = true;
      types = [ "yaml" ];
      excludes = [ "templates/" ];
    };

    helm-lint = {
      enable = true;
      name = "helm-lint";
      description = "Lint all Helm charts";
      entry = "${helmLintAll}";
      pass_filenames = false;
      types = [ "yaml" ];
    };
  };

  tasks = {
    "helm:deps" = {
      description = "Build dependencies for all application charts";
      exec = "${helmDeps}";
    };

    "helm:lint" = {
      description = "Lint all charts";
      after = [ "helm:deps" ];
      exec = "${helmLintAll}";
    };

    "helm:test" = {
      description = "Run unit tests for all charts";
      after = [ "helm:lint" ];
      exec = ''
        set -euo pipefail
        cd "$(git rev-parse --show-toplevel)"
        while IFS= read -r chart; do
          "${untt}" "$chart"
        done < <(${chartDirs})
      '';
    };

    "helm:package" = {
      description = "Package a chart — set CHART=<name> (default: base-chart)";
      after = [ "helm:deps" ];
      exec = "helm package \"$(${helmChartPath})\"";
    };
  };
}
