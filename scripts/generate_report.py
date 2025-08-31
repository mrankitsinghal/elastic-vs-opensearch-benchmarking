import json
from tabulate import tabulate
from datetime import datetime
import os

# Read the benchmark results from current directory
results_file = "combined_benchmark_results.json"
with open(results_file, "r") as f:
    results = json.load(f)

# Extract statistics
elasticsearch_stats = results.get("elasticsearch_stats", results.get("elasticsearch_stats", {}))
opensearch_stats = results.get("opensearch_stats", results.get("opensearch_stats", {}))

# Color codes for markdown
GREEN = "🟢"
RED = "🔴"
NEUTRAL = "⚪"

def get_color_code(elasticsearch_value, opensearch_value, lower_is_better=True):
    if elasticsearch_value < opensearch_value:
        return GREEN if lower_is_better else RED
    elif opensearch_value < elasticsearch_value:
        return RED if lower_is_better else GREEN
    return NEUTRAL

# Prepare data for tables
metrics = []

# Add metrics for each query type
for query_name in set(elasticsearch_stats.keys()) | set(opensearch_stats.keys()):
    # ESS metrics
    ess_metrics = elasticsearch_stats.get(query_name, {})
    if ess_metrics:
        metrics.extend([
            [f"{query_name} - Average Latency", "Elasticsearch", f"{ess_metrics['avg_latency']:.2f}", "ms", NEUTRAL],
            [f"{query_name} - Minimum Latency", "Elasticsearch", f"{ess_metrics['min_latency']:.2f}", "ms", NEUTRAL],
            [f"{query_name} - Maximum Latency", "Elasticsearch", f"{ess_metrics['max_latency']:.2f}", "ms", NEUTRAL],
            [f"{query_name} - 95th Percentile Latency", "Elasticsearch", f"{ess_metrics['p95_latency']:.2f}", "ms", NEUTRAL],
            [f"{query_name} - 99th Percentile Latency", "Elasticsearch", f"{ess_metrics['p99_latency']:.2f}", "ms", NEUTRAL],
            [f"{query_name} - Requests per Second", "Elasticsearch", f"{ess_metrics['requests_per_second']:.2f}", "ops/sec", NEUTRAL],
            [f"{query_name} - Error Rate", "Elasticsearch", f"{ess_metrics['error_rate']:.2f}", "%", NEUTRAL]
        ])

    # AWS metrics
    aws_metrics = opensearch_stats.get(query_name, {})
    if aws_metrics and ess_metrics:
        # Add color coding for AWS metrics based on comparison with ESS
        metrics.extend([
            [f"{query_name} - Average Latency", "OpenSearch", f"{aws_metrics['avg_latency']:.2f}", "ms", 
             get_color_code(ess_metrics['avg_latency'], aws_metrics['avg_latency'])],
            [f"{query_name} - Minimum Latency", "OpenSearch", f"{aws_metrics['min_latency']:.2f}", "ms",
             get_color_code(ess_metrics['min_latency'], aws_metrics['min_latency'])],
            [f"{query_name} - Maximum Latency", "OpenSearch", f"{aws_metrics['max_latency']:.2f}", "ms",
             get_color_code(ess_metrics['max_latency'], aws_metrics['max_latency'])],
            [f"{query_name} - 95th Percentile Latency", "OpenSearch", f"{aws_metrics['p95_latency']:.2f}", "ms",
             get_color_code(ess_metrics['p95_latency'], aws_metrics['p95_latency'])],
            [f"{query_name} - 99th Percentile Latency", "OpenSearch", f"{aws_metrics['p99_latency']:.2f}", "ms",
             get_color_code(ess_metrics['p99_latency'], aws_metrics['p99_latency'])],
            [f"{query_name} - Requests per Second", "OpenSearch", f"{aws_metrics['requests_per_second']:.2f}", "ops/sec",
             get_color_code(ess_metrics['requests_per_second'], aws_metrics['requests_per_second'], lower_is_better=False)],
            [f"{query_name} - Error Rate", "OpenSearch", f"{aws_metrics['error_rate']:.2f}", "%",
             get_color_code(ess_metrics['error_rate'], aws_metrics['error_rate'])]
        ])

# Add summary metrics
ess_total_requests = sum(metrics['total_requests'] for metrics in elasticsearch_stats.values())
ess_successful_requests = sum(metrics['successful_requests'] for metrics in elasticsearch_stats.values())
ess_overall_error_rate = sum(metrics['error_rate'] for metrics in elasticsearch_stats.values()) / len(elasticsearch_stats)
ess_avg_requests_per_second = sum(metrics['requests_per_second'] for metrics in elasticsearch_stats.values())

aws_total_requests = sum(metrics['total_requests'] for metrics in opensearch_stats.values())
aws_successful_requests = sum(metrics['successful_requests'] for metrics in opensearch_stats.values())
aws_overall_error_rate = sum(metrics['error_rate'] for metrics in opensearch_stats.values()) / len(opensearch_stats)
aws_avg_requests_per_second = sum(metrics['requests_per_second'] for metrics in opensearch_stats.values())

metrics.extend([
    ["Total Requests", "Elasticsearch", str(ess_total_requests), "requests", NEUTRAL],
    ["Successful Requests", "Elasticsearch", str(ess_successful_requests), "requests", NEUTRAL],
    ["Overall Error Rate", "Elasticsearch", f"{ess_overall_error_rate:.2f}", "%", NEUTRAL],
    ["Average Requests per Second", "Elasticsearch", f"{ess_avg_requests_per_second:.2f}", "ops/sec", NEUTRAL],
    ["Total Requests", "OpenSearch", str(aws_total_requests), "requests", NEUTRAL],
    ["Successful Requests", "OpenSearch", str(aws_successful_requests), "requests", NEUTRAL],
    ["Overall Error Rate", "OpenSearch", f"{aws_overall_error_rate:.2f}", "%",
     get_color_code(ess_overall_error_rate, aws_overall_error_rate)],
    ["Average Requests per Second", "OpenSearch", f"{aws_avg_requests_per_second:.2f}", "ops/sec",
     get_color_code(ess_avg_requests_per_second, aws_avg_requests_per_second, lower_is_better=False)],
    ["Test Duration", "Both", str(results['test_duration']), "seconds", NEUTRAL],
    ["Number of Clients", "Both", str(results['num_clients']), "clients", NEUTRAL]
])

# Generate markdown report
report_file = "benchmark_report.md"
with open(report_file, "w") as f:
    f.write(f"""# Elasticsearch vs OpenSearch Performance Benchmark Report
## Combined Performance Analysis
Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

This report presents the results of search performance tests conducted on:
- Elasticsearch cluster
- OpenSearch cluster

## Test Configuration
- Index: {results['index_name']}
- Test duration: {results['test_duration']} seconds per operation
- Search operations tested:
  - Company name search (match query for "consulting")
  - Country filter search (filter for "United States")
  - Industry search (term query on rics_100)
  - Complex search (company name + country filter + employee count range)
  - Industry aggregation (terms aggregation with sub-aggregations)
- Client concurrency: {results['num_clients']} concurrent clients
- Elasticsearch Endpoint: {results.get('elasticsearch_endpoint', 'N/A')}
- OpenSearch Endpoint: {results.get('opensearch_endpoint', 'N/A')}

## Performance Metrics

### Query Performance Metrics
{tabulate(metrics, 
    headers=["Metric", "Cluster", "Value", "Unit", "Status"],
    tablefmt="pipe")}

### Legend
- 🟢 Better performance than the other cluster
- 🔴 Worse performance than the other cluster
- ⚪ Neutral (no direct comparison or equal performance)

## Conclusions and Recommendations

*[Fill this section after analyzing the benchmark results]*

- Performance analysis for each query type
- Cost considerations
- Scalability observations
- Recommended configuration changes or optimizations

## Raw Results
The complete benchmark results are available in: combined_benchmark_results.json
""")
