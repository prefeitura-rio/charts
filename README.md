# Prefeitura Rio - Helm Charts

Helm charts for deploying applications on Kubernetes, published to GHCR as OCI artifacts.

## Usage

```bash
# Install a chart
helm install my-release oci://ghcr.io/prefeitura-rio/charts/<chart-name> --version <version>

# Pull a chart
helm pull oci://ghcr.io/prefeitura-rio/charts/<chart-name> --version <version>
```

## Available Charts

| Chart             | Description                                                                  | Documentation                   |
| ----------------- | ---------------------------------------------------------------------------- | ------------------------------- |
| **base-chart**    | Production-ready chart with Istio, autoscaling, secrets management, and more | [Docs](./charts/base-chart/)    |
| **cloudsql-proxy** | Sidecar proxy for connecting to Google Cloud SQL instances                  | [Docs](./charts/cloudsql-proxy/) |
| **sequin**        | Stream changes from Postgres databases                                       | [Docs](./charts/sequin/)        |
| **typesense**     | Fast, typo-tolerant search engine                                            | [Docs](./charts/typesense/)     |

## Development

```bash
# Enter development environment (Nix)
nix develop

# Lint all charts
devenv tasks run helm:lint

# Run unit tests for all charts
devenv tasks run helm:test
```

## Contributing

1. Fork and create a feature branch
2. Make changes and ensure tests pass
3. Update documentation
4. Submit a pull request with a commit message starting with `<chart-name>:` to trigger a release

Follow [Helm best practices](https://helm.sh/docs/chart_best_practices/) and [SemVer](https://semver.org/) for versioning.

## License

GPL License - see [LICENSE](LICENSE) file.

Maintained by Prefeitura do Rio de Janeiro.
