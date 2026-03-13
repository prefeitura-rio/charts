# Prefeitura Rio - Helm Charts

Helm charts for deploying applications on Kubernetes.

## Usage

```bash
# Add the repository
helm repo add prefeitura-rio https://prefeitura-rio.github.io/charts
helm repo update

# Install a chart
helm install my-release prefeitura-rio/<chart-name>
```

## Available Charts

| Chart | Description | Documentation |
|-------|-------------|---------------|
| **base-chart** | Production-ready chart with Istio, autoscaling, secrets management, and more | [Docs](./charts/base-chart/) |
| **letta** | Stateful LLM applications with long-term memory | [Docs](./charts/letta/) |
| **typesense** | Fast, typo-tolerant search engine | [Docs](./charts/typesense/) |

## Development

```bash
# Enter development environment (Nix)
nix develop

# Work with a chart
cd charts/<chart-name>
just lint    # Lint the chart
just test    # Run tests
just package # Package the chart
```

## Contributing

1. Fork and create a feature branch
2. Make changes and ensure tests pass
3. Update documentation
4. Submit a pull request

Follow [Helm best practices](https://helm.sh/docs/chart_best_practices/) and [SemVer](https://semver.org/) for versioning.

## License

MIT License - see [LICENSE](LICENSE) file.

Maintained by Prefeitura do Rio de Janeiro.
