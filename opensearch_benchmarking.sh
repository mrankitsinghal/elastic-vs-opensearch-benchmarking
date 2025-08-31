#!/bin/bash

# Script to benchmark search performance on OpenSearch clusters
# Generic benchmarking tool for OpenSearch

# Default configuration - Use environment variables with fallback defaults
PYTHON_VERSION="${PYTHON_VERSION:-3.11.4}"
OPENSEARCH_HOSTS="${OPENSEARCH_HOSTS:-https://your-opensearch-cluster.amazonaws.com}"
INDEX_NAME="${INDEX_NAME:-sample-companies}"
TEST_DURATION="${TEST_DURATION:-600}"

# Check if pyenv is installed
if ! command -v pyenv &> /dev/null; then
    echo "Error: pyenv is not installed. Please install pyenv first."
    echo "Visit https://github.com/pyenv/pyenv#installation for installation instructions."
    exit 1
fi

# Set up Python environment
setup_python_environment() {
    echo "Available Python versions in pyenv:"
    pyenv versions

    read -p "Enter Python version to use [default: $PYTHON_VERSION]: " input
    if [ ! -z "$input" ]; then
        PYTHON_VERSION=$input
    fi

    # Check if the selected version is installed
    if ! pyenv versions | grep -q "$PYTHON_VERSION"; then
        echo "Python version $PYTHON_VERSION is not installed."
        read -p "Would you like to install it? (y/n): " INSTALL_PYTHON
        if [[ "$INSTALL_PYTHON" == "y" ]]; then
            echo "Installing Python $PYTHON_VERSION..."
            pyenv install $PYTHON_VERSION
        else
            echo "Please select an installed Python version and try again."
            exit 1
        fi
    fi

    # Create virtual environment name
    VENV_NAME="opensearch-benchmark-$PYTHON_VERSION"

    # Check if virtualenv plugin is installed
    if ! pyenv commands | grep -q "virtualenv"; then
        echo "pyenv-virtualenv plugin is not installed."
        echo "Installing pyenv-virtualenv..."
        git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
        echo "Please restart your shell and run this script again."
        exit 1
    fi

    # Check if virtual environment already exists
    if pyenv versions | grep -q "$VENV_NAME"; then
        echo "Virtual environment '$VENV_NAME' already exists."
        read -p "Would you like to use the existing environment? (y/n): " USE_EXISTING
        if [[ "$USE_EXISTING" != "y" ]]; then
            echo "Please remove the existing environment first."
            exit 1
        fi
    else
        # Create virtual environment
        echo "Creating virtual environment $VENV_NAME with Python $PYTHON_VERSION..."
        pyenv virtualenv $PYTHON_VERSION $VENV_NAME || {
            echo "Failed to create virtual environment."
            exit 1
        }
    fi

    # Activate virtual environment
    echo "Activating virtual environment $VENV_NAME..."
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    pyenv activate $VENV_NAME || {
        echo "Failed to activate virtual environment."
        exit 1
    }

    # Ensure we're in the virtual environment
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        echo "Error: Virtual environment not activated properly"
        exit 1
    fi

    # Install required packages
    echo "Installing required packages..."
    pip install --upgrade pip
    pip install opensearch-py
    pip install tabulate
    pip install psutil
    pip install py-cpuinfo

    echo "Python environment setup complete."
    echo "Using Python $(python --version)"
    echo "Virtual environment: $VENV_NAME"
    echo "Virtual environment path: $VIRTUAL_ENV"
}

# Configuration variables
configure_benchmark() {
    echo "Configuring benchmark parameters (press Enter to use default values):"

    # OpenSearch configuration
    read -p "Enter OpenSearch endpoint [default: $OPENSEARCH_HOSTS]: " input
    if [ ! -z "$input" ]; then
        OPENSEARCH_HOSTS=$input
    fi

    read -p "Enter index name [default: $INDEX_NAME]: " input
    if [ ! -z "$input" ]; then
        INDEX_NAME=$input
    fi

    read -p "Enter test duration in seconds [default: $TEST_DURATION]: " input
    if [ ! -z "$input" ]; then
        TEST_DURATION=$input
    fi

    REPORT_DIR="results/opensearch_benchmark_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $REPORT_DIR

    echo "Configuration complete."
    echo "Using configuration:"
    echo "OpenSearch endpoint: $OPENSEARCH_HOSTS"
    echo "Index name: $INDEX_NAME"
    echo "Test duration: $TEST_DURATION seconds"
    echo "Reports will be saved to: $REPORT_DIR"
}

# Create benchmark script
create_benchmark_script() {
    echo "Creating benchmark script..."

    cat > "${REPORT_DIR}/benchmark_opensearch.py" <<EOF
import time
import json
import concurrent.futures
from datetime import datetime
from opensearchpy import OpenSearch

# Configuration
HOSTS = "${OPENSEARCH_HOSTS}"
INDEX_NAME = "${INDEX_NAME}"
TEST_DURATION = ${TEST_DURATION}
NUM_CLIENTS = 10

# Initialize OpenSearch client
host = HOSTS.replace("https://", "").replace("/", "")
es = OpenSearch(
    hosts=[{"host": host, "port": 443}],
    http_compress=True,
    use_ssl=True,
    verify_certs=False,
    ssl_assert_hostname=False,
    ssl_show_warn=False
)

# Test queries
queries = {
    "company-name-search": {
        "query": {
            "match": {
                "company_name": "consulting"
            }
        }
    },
    "country-filter-search": {
        "query": {
            "bool": {
                "must": [{"match_all": {}}],
                "filter": [{"term": {"country": "United States"}}]
            }
        }
    },
    "industry-search": {
        "query": {
            "term": {
                "rics_100": "Management Consulting Services"
            }
        }
    },
    "complex-search": {
        "query": {
            "bool": {
                "must": [{"match": {"company_name": "consulting"}}],
                "filter": [
                    {"term": {"country": "United States"}},
                    {"range": {"employee_count": {"gte": 2}}}
                ]
            }
        }
    },
    "industry-aggregation": {
        "size": 0,
        "aggs": {
            "industries": {
                "terms": {
                    "field": "rics_100",
                    "size": 20
                },
                "aggs": {
                    "avg_employees": {
                        "avg": {
                            "field": "employee_count"
                        }
                    },
                    "countries": {
                        "terms": {
                            "field": "country",
                            "size": 10
                        }
                    }
                }
            }
        }
    }
}

def run_query(query_name, query_body):
    start_time = time.time()
    try:
        response = es.search(index=INDEX_NAME, body=query_body)
        end_time = time.time()
        return {
            "query": query_name,
            "success": True,
            "latency": (end_time - start_time) * 1000,  # Convert to ms
            "hits": response["hits"]["total"]["value"] if "hits" in response else None
        }
    except Exception as e:
        print(f"Error running query {query_name}: {str(e)}")
        return {
            "query": query_name,
            "success": False,
            "error": str(e)
        }

def run_benchmark_worker():
    results = []
    start_time = time.time()
    
    while time.time() - start_time < TEST_DURATION:
        for query_name, query_body in queries.items():
            result = run_query(query_name, query_body)
            results.append(result)
    
    return results

# Run benchmark with multiple clients
print(f"Starting benchmark with {NUM_CLIENTS} clients...")
print(f"Using endpoint: {HOSTS}")

with concurrent.futures.ThreadPoolExecutor(max_workers=NUM_CLIENTS) as executor:
    futures = [executor.submit(run_benchmark_worker) for _ in range(NUM_CLIENTS)]
    all_results = []
    for future in concurrent.futures.as_completed(futures):
        all_results.extend(future.result())

# Calculate statistics
stats = {}
for query_name in queries.keys():
    query_results = [r for r in all_results if r["query"] == query_name]
    successful_results = [r for r in query_results if r["success"]]
    
    if successful_results:
        latencies = [r["latency"] for r in successful_results]
        stats[query_name] = {
            "total_requests": len(query_results),
            "successful_requests": len(successful_results),
            "error_rate": (len(query_results) - len(successful_results)) / len(query_results) * 100,
            "avg_latency": sum(latencies) / len(latencies),
            "min_latency": min(latencies),
            "max_latency": max(latencies),
            "p95_latency": sorted(latencies)[int(len(latencies) * 0.95)],
            "p99_latency": sorted(latencies)[int(len(latencies) * 0.99)],
            "requests_per_second": len(successful_results) / TEST_DURATION
        }

# Save results
output_file = "${REPORT_DIR}/opensearch_benchmark_results.json"
with open(output_file, "w") as f:
    json.dump({
        "timestamp": datetime.now().isoformat(),
        "test_duration": TEST_DURATION,
        "num_clients": NUM_CLIENTS,
        "index_name": INDEX_NAME,
        "endpoint": HOSTS,
        "stats": stats,
        "raw_results": all_results
    }, f, indent=2)

print(f"Benchmark results saved to {output_file}")
EOF

    # Make the script executable
    chmod +x "${REPORT_DIR}/benchmark_opensearch.py"

    echo "Benchmark script created: ${REPORT_DIR}/benchmark_opensearch.py"
}

# Function to run benchmark
run_benchmark() {
    echo "Running benchmark..."

    # Run the benchmark script
    python "${REPORT_DIR}/benchmark_opensearch.py"

    echo "Benchmark completed."
}

# Create report
create_report() {
    echo "Generating report..."

    # Check if results file exists
    if [ -f "${REPORT_DIR}/opensearch_benchmark_results.json" ]; then
        # Create a Python script to generate the tabular report
        cat > "${REPORT_DIR}/generate_report.py" <<EOF
import json
from tabulate import tabulate
from datetime import datetime
import os

# Get the directory of this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Read the benchmark results
results_file = os.path.join(SCRIPT_DIR, "opensearch_benchmark_results.json")
with open(results_file, "r") as f:
    results = json.load(f)

# Extract statistics
stats = results["stats"]

# Prepare data for tables
query_metrics = []
for query_name, metrics in stats.items():
    # Add latency metrics
    query_metrics.extend([
        [f"{query_name} - Average Latency", "", f"{metrics['avg_latency']:.2f}", "ms"],
        [f"{query_name} - Minimum Latency", "", f"{metrics['min_latency']:.2f}", "ms"],
        [f"{query_name} - Maximum Latency", "", f"{metrics['max_latency']:.2f}", "ms"],
        [f"{query_name} - 95th Percentile Latency", "", f"{metrics['p95_latency']:.2f}", "ms"],
        [f"{query_name} - 99th Percentile Latency", "", f"{metrics['p99_latency']:.2f}", "ms"],
        [f"{query_name} - Requests per Second", "", f"{metrics['requests_per_second']:.2f}", "ops/sec"],
        [f"{query_name} - Error Rate", "", f"{metrics['error_rate']:.2f}", "%"]
    ])

# Add summary metrics
total_requests = sum(metrics['total_requests'] for metrics in stats.values())
successful_requests = sum(metrics['successful_requests'] for metrics in stats.values())
overall_error_rate = sum(metrics['error_rate'] for metrics in stats.values()) / len(stats)
avg_requests_per_second = sum(metrics['requests_per_second'] for metrics in stats.values())

query_metrics.extend([
    ["Total Requests", "", str(total_requests), "requests"],
    ["Successful Requests", "", str(successful_requests), "requests"],
    ["Overall Error Rate", "", f"{overall_error_rate:.2f}", "%"],
    ["Average Requests per Second", "", f"{avg_requests_per_second:.2f}", "ops/sec"],
    ["Test Duration", "", str(results['test_duration']), "seconds"],
    ["Number of Clients", "", str(results['num_clients']), "clients"]
])

# Generate markdown report
report_file = os.path.join(SCRIPT_DIR, "benchmark_report.md")
with open(report_file, "w") as f:
    f.write(f"""# Search Performance Benchmark Report for Generic Index
## OpenSearch Benchmark
Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

This report presents the results of search performance tests conducted on:
OpenSearch cluster

## Test Configuration
- Test duration: {results['test_duration']} seconds per operation
- Search operations tested:
  - Company name search (match query for "consulting")
  - Country filter search (filter for "United States")
  - Industry search (term query on rics_100)
  - Complex search (company name + country filter + employee count range)
  - Industry aggregation (terms aggregation with sub-aggregations)
- Client concurrency: {results['num_clients']} concurrent clients
- Endpoint: {results['endpoint']}

## Performance Metrics

### Query Performance Metrics
{tabulate(query_metrics, 
    headers=["Metric", "Task", "Value", "Unit"],
    tablefmt="pipe")}

## Conclusions and Recommendations

*[Fill this section after analyzing the benchmark results]*

- Performance analysis for each query type
- Cost considerations
- Scalability observations
- Recommended configuration changes or optimizations

## Raw Results
The complete benchmark results are available in: opensearch_benchmark_results.json
""")
EOF

        # Run the report generation script from the report directory
        cd "${REPORT_DIR}" && python generate_report.py
        RESULTS_FILE="Results available in: ${REPORT_DIR}/benchmark_report.md"
    else
        echo "Error: Benchmark results file not found at ${REPORT_DIR}/opensearch_benchmark_results.json"
        RESULTS_FILE="[Results file not found or benchmark did not complete successfully]"
    fi

    echo "Report generated: ${REPORT_DIR}/benchmark_report.md"
    echo "Please review the results and complete the conclusions section in the report."
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."

    read -p "Would you like to deactivate the virtual environment? (y/n): " DEACTIVATE_VENV
    if [[ "$DEACTIVATE_VENV" == "y" ]]; then
        pyenv deactivate
        echo "Virtual environment deactivated."
    else
        echo "Virtual environment '$VENV_NAME' remains active."
    fi
}

# Main function
main() {
    echo "===== OpenSearch Search Benchmark Tool ====="
    echo "This script will benchmark search performance on OpenSearch cluster"
    echo "and generate a performance report."
    echo ""

    # Setup Python environment
    setup_python_environment

    # Configure benchmark parameters
    configure_benchmark

    # Create benchmark script
    create_benchmark_script

    # Run benchmark
    echo "Starting benchmark..."
    run_benchmark

    # Create report
    create_report

    # Cleanup
    cleanup

    echo ""
    echo "===== Benchmark Complete ====="
    echo "Reports are available in the ${REPORT_DIR} directory."
    echo "Please review the results and complete the conclusions section in the report."
}

# Run the main function
main