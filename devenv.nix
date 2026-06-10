{ pkgs, ... }:

{
  languages.helm.enable = true;

  tasks = {
    "helm:lint" = {
      description = "Lint a chart — set CHART=<name> (default: base-chart)";
      exec = "helm lint charts/\${CHART:-base-chart}";
    };

    "helm:test" = {
      description = "Run unit tests for a chart — set CHART=<name> (default: base-chart)";
      after = [ "helm:lint" ];
      exec = "${pkgs.kubernetes-helmPlugins.helm-unittest}/helm-unittest/untt charts/\${CHART:-base-chart}";
    };

    "helm:test-all" = {
      description = "Run unit tests for all charts";
      exec = ''
        for chart in charts/*/; do
          echo "Testing $chart..."
          ${pkgs.kubernetes-helmPlugins.helm-unittest}/helm-unittest/untt "$chart"
        done
      '';
    };

    "helm:package" = {
      description = "Package a chart — set CHART=<name> (default: base-chart)";
      exec = "helm package charts/\${CHART:-base-chart}";
    };
  };
}
