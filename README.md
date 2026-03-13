# Prefeitura Rio - Helm Charts

A collection of Helm charts for deploying applications on Kubernetes, maintained by Prefeitura do Rio de Janeiro.

## Usage

### Add the Helm Repository

```bash
helm repo add prefeitura-rio https://prefeitura-rio.github.io/charts
helm repo update
```

### Install a Chart

```bash
helm install my-release prefeitura-rio/<chart-name>
```

## Available Charts

### 📦 base-chart

A comprehensive, production-ready Helm chart for deploying applications on Kubernetes with support for:

- **Service Mesh**: Istio integration (VirtualService, DestinationRule, AuthorizationPolicy, RequestAuthentication)
- **Autoscaling**: HPA and KEDA ScaledObject support
- **Secrets Management**: Infisical integration
- **ConfigMaps**: Environment variables and volume mount support
- **High Availability**: PodDisruptionBudget and pod anti-affinity
- **CI/CD**: Argo CD sync waves and ArgoCD Image Updater
- **Dependencies**: Optional Valkey (Redis) and RabbitMQ
- **CronJobs**: Support for scheduled tasks
- **Init Containers**: Database migrations and dependency waiting

**Installation:**
```bash
helm install my-app prefeitura-rio/base-chart \
  --set image.repository=myorg/myapp \
  --set image.tag=v1.0.0
```

[📖 View Documentation](./charts/base-chart/)

### 🤖 letta

Helm chart for deploying Letta - an open-source framework for building stateful LLM applications with long-term memory.

**Features:**
- Stateful LLM applications
- Long-term memory management
- Docker-based deployment
- PostgreSQL integration

**Installation:**
```bash
helm install letta prefeitura-rio/letta
```

[📖 View Documentation](./charts/letta/)

### 🔍 typesense

Fast, typo-tolerant search engine optimized for instant search experiences.

**Features:**
- Lightning-fast search
- Typo tolerance
- Faceting and filtering
- Geo-search support

**Installation:**
```bash
helm install typesense prefeitura-rio/typesense
```

[📖 View Documentation](./charts/typesense/)

## Development

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) >= 3.0
- [just](https://github.com/casey/just) (optional, for running tasks)
- [Nix](https://nixos.org/) (optional, for development environment)

### Using Nix Development Environment

This repository includes a Nix flake for a reproducible development environment:

```bash
# Enter the development shell
nix develop

# Or use direnv (if you have it configured)
direnv allow
```

### Working with Charts

#### base-chart Development

```bash
cd charts/base-chart

# Lint the chart
just lint

# Test the chart with all features enabled
just test

# Run both lint and test
just

# Package the chart
just package
```



### Running Tests

The base-chart includes comprehensive unit tests using [helm-unittest](https://github.com/helm-unittest/helm-unittest):

```bash
cd charts/base-chart
helm unittest .
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository** and create a feature branch
2. **Make your changes** and ensure tests pass
3. **Update documentation** if needed
4. **Submit a pull request** with a clear description

### Chart Development Guidelines

- Follow [Helm best practices](https://helm.sh/docs/chart_best_practices/)
- Include comprehensive tests for new features
- Update `Chart.yaml` version following [SemVer](https://semver.org/)
- Document all values in `values.yaml` with comments
- Add examples to the chart's README

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- 🐛 [Report a bug](https://github.com/prefeitura-rio/charts/issues/new)
- 💡 [Request a feature](https://github.com/prefeitura-rio/charts/issues/new)
- 📧 Contact: [Add contact information if applicable]

## Maintainers

Maintained by the Prefeitura do Rio de Janeiro team.
