# Elasticsearch vs OpenSearch Performance Benchmarking

A comprehensive benchmarking suite for comparing search performance between Elasticsearch and OpenSearch clusters. This tool helps you evaluate and compare the performance characteristics of different search engines using realistic workloads.

## 🚀 Features

- **Multi-Engine Support**: Benchmark both Elasticsearch and OpenSearch clusters
- **Flexible Configuration**: Environment variable-based configuration for easy deployment
- **Comprehensive Metrics**: Latency, throughput, error rates, and percentile analysis
- **Concurrent Testing**: Multi-client load testing capabilities
- **Detailed Reports**: Automated report generation with performance comparisons
- **Rally Integration**: Uses Elasticsearch Rally for standardized benchmarking
- **Clean Architecture**: Organized structure with examples and templates

## 📁 Repository Structure

```
├── README.md                    # This file
├── setup.sh                     # Quick setup script
├── .env.example                 # Environment template
├── rally.ini.example            # Rally config template
├── scripts/
│   ├── benchmark_combined.py    # Python benchmark runner
│   └── generate_report.py       # Report generator
├── examples/
│   ├── local-cluster.env        # Local development config
│   ├── cloud-cluster.env        # Cloud deployment config
│   └── sample-queries.json      # Example query patterns
├── results/                     # Benchmark results (auto-created)
├── es_benchmarking.sh          # Elasticsearch-only benchmarking
├── opensearch_benchmarking.sh  # OpenSearch-only benchmarking
└── combined_benchmarking.sh    # Combined comparison
```

## 🔧 Prerequisites

- Python 3.11+ (managed via pyenv)
- pyenv and pyenv-virtualenv
- Access to Elasticsearch and/or OpenSearch clusters
- Sufficient network bandwidth between the benchmark client and target clusters

## ⚡ Quick Start

### 1. Initial Setup

Run the setup script to prepare your environment:

```bash
./setup.sh
```

This will:
- Check for required dependencies (pyenv, pyenv-virtualenv)
- Create `.env` and `rally.ini` files from templates
- Guide you through the initial configuration

### 2. Configure Your Environment

Edit the `.env` file with your cluster details:

```bash
# Copy from examples or create your own
cp examples/local-cluster.env .env
# or
cp examples/cloud-cluster.env .env

# Then edit with your actual values
nano .env
```

### 3. Run Benchmarks

Choose from three available benchmarking scripts:

```bash
# Benchmark Elasticsearch only
./es_benchmarking.sh

# Benchmark OpenSearch only
./opensearch_benchmarking.sh

# Benchmark both and compare (recommended)
./combined_benchmarking.sh
```

### 4. View Results

Results are saved in timestamped directories under `results/`:

```bash
# List recent results
ls -la results/

# View the latest benchmark report
cat results/combined_benchmark_*/benchmark_report.md

# View raw JSON data
cat results/combined_benchmark_*/combined_benchmark_results.json
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `ELASTICSEARCH_HOSTS` | Elasticsearch cluster endpoint | `https://your-elasticsearch-cluster.com` | `https://my-es.elastic.cloud:443` |
| `ELASTICSEARCH_USER` | Elasticsearch username | `your-username` | `elastic` |
| `ELASTICSEARCH_PASSWORD` | Elasticsearch password | `your-password` | `secure-password-123` |
| `OPENSEARCH_HOSTS` | OpenSearch cluster endpoint | `https://your-opensearch-cluster.amazonaws.com` | `https://search-domain.us-east-1.es.amazonaws.com` |
| `INDEX_NAME` | Target index name for benchmarking | `sample-companies` | `my-index` |
| `TEST_DURATION` | Duration of each test in seconds | `600` | `300` |
| `NUM_CLIENTS` | Number of concurrent clients | `10` | `5` |

### Configuration Examples

**Local Development:**
```bash
cp examples/local-cluster.env .env
```

**Cloud Production:**
```bash
cp examples/cloud-cluster.env .env
```

**Custom Configuration:**
```bash
# Set individual variables
export ELASTICSEARCH_HOSTS="https://my-cluster.com"
export ELASTICSEARCH_USER="admin"
export INDEX_NAME="my-test-index"
export TEST_DURATION=300
```

## 🔍 Benchmark Types

The tool includes several predefined query patterns:

1. **Company Name Search**: Simple match queries
2. **Country Filter Search**: Filtered queries with terms
3. **Industry Search**: Exact term matching
4. **Complex Search**: Multi-clause boolean queries with filters
5. **Industry Aggregation**: Terms aggregations with sub-aggregations

### Custom Queries

You can modify the queries in `scripts/benchmark_combined.py` or reference `examples/sample-queries.json` for inspiration.

## 📊 Output & Reports

### Benchmark Results

Results are saved in JSON format containing:
- Test configuration and timestamps
- Per-query performance statistics
- Raw result data for further analysis
- Cluster endpoint information

### Performance Report

The generated markdown report includes:
- Comparative performance metrics
- Color-coded performance indicators
- Latency percentiles (95th, 99th)
- Error rates and throughput measurements
- Summary statistics

### Sample Report Structure

```
results/combined_benchmark_20240831_143022/
├── combined_benchmark_results.json    # Raw data
└── benchmark_report.md               # Formatted report
```

## 🛠️ Advanced Usage

### Custom Query Patterns

Edit `scripts/benchmark_combined.py` to add your own query patterns:

```python
queries = {
    "your-custom-query": {
        "query": {
            "bool": {
                "must": [{"match": {"field": "value"}}]
            }
        }
    }
}
```

### Performance Tuning

For accurate benchmarks:

1. **Network**: Ensure stable, high-bandwidth connection to clusters
2. **Resources**: Run on dedicated hardware when possible
3. **Duration**: Use longer test durations (10+ minutes) for stable results
4. **Warmup**: Consider implementing query warmup phases
5. **Isolation**: Avoid running other intensive operations during benchmarks

### Cluster Preparation

Before benchmarking:

1. Ensure clusters have similar hardware specifications
2. Verify index mappings and settings are consistent
3. Consider disabling replicas during write-heavy benchmarks
4. Monitor cluster health throughout testing

## 🐛 Troubleshooting

### Common Issues

**Connection Errors**
```bash
# Check network connectivity
curl -X GET "https://your-cluster.com/_cluster/health"

# Verify credentials
curl -u user:password -X GET "https://your-cluster.com"
```

**Environment Issues**
```bash
# Check Python environment
pyenv versions
which python

# Reinstall dependencies
pip install --upgrade elasticsearch opensearch-py tabulate
```

**Performance Inconsistencies**
- Run multiple test iterations and average results
- Check for cluster resource constraints
- Monitor cluster metrics during benchmarking

### Debug Mode

Enable verbose logging:

```bash
export RALLY_LOG_LEVEL=DEBUG
export PYTHONPATH="${PYTHONPATH}:$(pwd)/scripts"
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test with your clusters
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📝 Examples & Templates

The `examples/` directory contains:

- **local-cluster.env**: Configuration for local development
- **cloud-cluster.env**: Configuration for cloud deployments
- **sample-queries.json**: Example query patterns to inspire your benchmarks

## 🔒 Security Notes

- Never commit credentials to version control
- Use environment variables for sensitive information
- Consider using IAM roles for cloud deployments
- Review cluster access logs after benchmarking

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review cluster logs and connection settings
3. Ensure environment variables are correctly set
4. Verify network connectivity to target clusters
5. Open an issue on GitHub with detailed error information

## ⭐ Acknowledgments

- Built with [Elasticsearch Rally](https://github.com/elastic/rally) for standardized benchmarking
- Supports both Elasticsearch and OpenSearch ecosystems
- Inspired by the need for objective performance comparisons

---

**Note**: This benchmarking tool is designed for performance evaluation and should be used with appropriate caution in production environments. Always benchmark against non-production clusters when possible.