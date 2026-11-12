# AGENTS.md

Helm charts of Prefeitura do Rio, published as OCI artifacts to
`oci://ghcr.io/prefeitura-rio/charts/<chart>`. Other repositories (Flux
HelmReleases, Kustomize `helmCharts`, Terraform in `prefeitura-rio/infra`)
consume them with a pinned version.

## Layout

- `charts/<chart>/`: one application chart per directory (`Chart.yaml`,
  `values.yaml`, `templates/`, `README.md`). A chart may keep its application
  chart nested as `charts/<chart>/<chart>/`.
- `charts/<chart>/tests/`: helm-unittest suites (`*_test.yaml`) and the values
  files they use.
- `.github/workflows/pr.yaml`: runs on every pull request to `main`; builds the
  dependencies, lints and unit-tests the charts the PR changes (all charts when
  the workflow itself changes).
- `.github/workflows/release.yaml`: runs on push to `main` and publishes one
  chart (see Releases).
- `devenv.nix`: the same checks as Nix tasks (`helm:lint`, `helm:test`), for
  people who use devenv.

## Checks

Use Helm 3 (CI pins `v3.19.0`) and the helm-unittest plugin `1.1.0`, the
versions both workflows use:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest --version v1.1.0
```

For every chart you change:

```bash
helm dependency build charts/<chart>   # only when Chart.yaml has dependencies
helm lint charts/<chart>
helm unittest charts/<chart>
```

All three must pass before opening a PR, and the `helm lint and unittest` check
of the PR must be green. `base-chart` and `sequin` pull `valkey` (and
`base-chart` also `rabbitmq`) from `oci://registry-1.docker.io/cloudpirates`;
the downloaded `charts/<chart>/charts/*.tgz` are ignored by git.

## Rules

- Never edit `version` in `Chart.yaml` by hand: the release workflow bumps the
  patch version, commits `chore: bump <chart> to <version> [skip ci]` to `main`
  and tags `<chart>-v<version>`.
- The commit subject on `main` decides which chart is published: `<chart>: ...`
  or a Conventional Commit with the chart as scope, `<type>(<chart>): ...`
  (e.g. `feat(base-chart): add probes`). Any other subject publishes nothing.
  One chart per PR.
- A chart is a contract with every repository that uses it: keep changes
  backward compatible with the values they already set (new keys default to the
  current behavior), update the chart `README.md` and add helm-unittest cases in
  `charts/<chart>/tests/` for new behavior.
- Adopting a new chart version is a change in the consuming repository, not
  here.
- Never commit secrets, real credentials or personal data in values, tests or
  examples.
