{ pkgs, ... }:

let
  untt = "${pkgs.kubernetes-helmPlugins.helm-unittest}/helm-unittest/untt";
  helmLintAll = pkgs.writeShellScript "helm-lint-all" ''
    cd "$(git rev-parse --show-toplevel)"
    for chart in charts/*/; do
      helm lint "$chart"
    done
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
    "helm:lint" = {
      description = "Lint all charts";
      exec = "bash -c 'helm lint charts/*'";
    };

    "helm:test" = {
      description = "Run unit tests for all charts";
      after = [ "helm:lint" ];
      exec = "bash -c '${untt} charts/*'";
    };

    "helm:package" = {
      description = "Package a chart — set CHART=<name> (default: base-chart)";
      exec = "helm package charts/\${CHART:-base-chart}";
    };
  };
}
