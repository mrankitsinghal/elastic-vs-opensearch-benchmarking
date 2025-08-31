#!/bin/bash

# Script to benchmark search performance on Elasticsearch clusters using Rally
# Generic benchmarking tool for Elasticsearch

# Default configuration - Use environment variables with fallback defaults
PYTHON_VERSION="${PYTHON_VERSION:-3.11.4}"
ELASTICSEARCH_HOSTS="${ELASTICSEARCH_HOSTS:-https://your-elasticsearch-cluster.com}"
ELASTICSEARCH_USER="${ELASTICSEARCH_USER:-your-username}"
ELASTICSEARCH_PASSWORD="${ELASTICSEARCH_PASSWORD:-your-password}"
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
    VENV_NAME="elasticsearch-rally-$PYTHON_VERSION"

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

    # Install or update Rally and compatible elasticsearch version
    echo "Installing/updating Elasticsearch Rally and compatible elasticsearch version in virtual environment..."
    pip install --upgrade pip
    pip install --upgrade esrally

    # Verify rally installation
    echo "Verifying rally installation..."
    python -c "import esrally" || {
        echo "Error: esrally module not found. Installation may have failed."
        exit 1
    }

    # Get the path to the esrally executable within the virtual environment
    RALLY_PATH="$VIRTUAL_ENV/bin/esrally"
    
    # If esrally is not in the expected location, try to find it
    if [ ! -f "$RALLY_PATH" ]; then
        echo "Looking for esrally executable in alternative locations..."
        RALLY_PATH=$(find "$VIRTUAL_ENV" -name esrally -type f 2>/dev/null | head -n 1)
        
        if [ -z "$RALLY_PATH" ]; then
            echo "Error: esrally executable not found in virtual environment."
            echo "Attempting to reinstall esrally..."
            pip uninstall -y esrally
            pip install --no-cache-dir esrally
            
            RALLY_PATH="$VIRTUAL_ENV/bin/esrally"
            if [ ! -f "$RALLY_PATH" ]; then
                echo "Error: Failed to install esrally properly."
                echo "Please try installing esrally manually:"
                echo "1. Activate the virtual environment: pyenv activate $VENV_NAME"
                echo "2. Install esrally: pip install esrally"
                echo "3. Verify installation: which esrally"
                exit 1
            fi
        fi
    fi

    # Make sure the esrally executable is executable
    chmod +x "$RALLY_PATH"

    # Verify esrally is working
    echo "Testing esrally installation..."
    "$RALLY_PATH" --version || {
        echo "Error: esrally executable is not working properly."
        exit 1
    }

    echo "Python environment setup complete."
    echo "Using Python $(python --version)"
    echo "Virtual environment: $VENV_NAME"
    echo "esrally executable path: $RALLY_PATH"
    echo "Virtual environment path: $VIRTUAL_ENV"
    echo "esrally version: $("$RALLY_PATH" --version)"
}

# Configuration variables
configure_benchmark() {
    echo "Configuring benchmark parameters (press Enter to use default values):"

    # Elasticsearch configuration
    read -p "Enter Elasticsearch endpoint [default: $ELASTICSEARCH_HOSTS]: " input
    if [ ! -z "$input" ]; then
        ELASTICSEARCH_HOSTS=$input
    fi

    read -p "Enter Elasticsearch username [default: $ELASTICSEARCH_USER]: " input
    if [ ! -z "$input" ]; then
        ELASTICSEARCH_USER=$input
    fi

    read -sp "Enter Elasticsearch password [default: $ELASTICSEARCH_PASSWORD]: " input
    if [ ! -z "$input" ]; then
        ELASTICSEARCH_PASSWORD=$input
    fi
    echo ""

    read -p "Enter index name [default: $INDEX_NAME]: " input
    if [ ! -z "$input" ]; then
        INDEX_NAME=$input
    fi

    read -p "Enter test duration in seconds [default: $TEST_DURATION]: " input
    if [ ! -z "$input" ]; then
        TEST_DURATION=$input
    fi

    REPORT_DIR="results/elasticsearch_rally_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $REPORT_DIR

    echo "Configuration complete."
    echo "Using configuration:"
    echo "Elasticsearch endpoint: $ELASTICSEARCH_HOSTS"
    echo "Index name: $INDEX_NAME"
    echo "Test duration: $TEST_DURATION seconds"
    echo "Reports will be saved to: $REPORT_DIR"
}

# Create a Rally configuration file (rally.ini)
create_rally_config() {
    echo "Creating Rally configuration file..."

    cat > rally.ini <<EOF
[reporting]
report_dir = ${REPORT_DIR}

[defaults]
hosts = ${ELASTICSEARCH_HOSTS}
username = ${ELASTICSEARCH_USER}
password = ${ELASTICSEARCH_PASSWORD}

EOF

    echo "Rally configuration file created: rally.ini"
}

# Create a Rally workload file
create_rally_workload() {
    echo "Creating Rally workload..."

    WORKLOAD_NAME="elasticsearch-search-workload"
    WORKLOAD_DIR="${REPORT_DIR}/${WORKLOAD_NAME}"
    mkdir -p "${WORKLOAD_DIR}/mappings"

    # Create track.json
    cat > "${WORKLOAD_DIR}/track.json" <<EOF
{
  "version": 2,
  "description": "Search benchmark for generic index",
  "indices": [
    {
      "name": "${INDEX_NAME}",
      "body": "mappings/index-mapping.json"
    }
  ],
  "operations": [
    {
      "name": "company-name-search",
      "operation-type": "search",
      "indices": ["${INDEX_NAME}"],
      "body": {
        "query": {
          "match": {
            "company_name": "consulting"
          }
        }
      }
    },
    {
      "name": "country-filter-search",
      "operation-type": "search",
      "indices": ["${INDEX_NAME}"],
      "body": {
        "query": {
          "bool": {
            "must": [
              { "match_all": {} }
            ],
            "filter": [
              { "term": { "country": "United States" } }
            ]
          }
        }
      }
    },
    {
      "name": "industry-search",
      "operation-type": "search",
      "indices": ["${INDEX_NAME}"],
      "body": {
        "query": {
          "term": {
            "rics_100": "Management Consulting Services"
          }
        }
      }
    },
    {
      "name": "complex-search",
      "operation-type": "search",
      "indices": ["${INDEX_NAME}"],
      "body": {
        "query": {
          "bool": {
            "must": [
              { "match": { "company_name": "consulting" } }
            ],
            "filter": [
              { "term": { "country": "United States" } },
              { "range": { "employee_count": { "gte": 2 } } }
            ]
          }
        }
      }
    },
    {
      "name": "industry-aggregation",
      "operation-type": "search",
      "indices": ["${INDEX_NAME}"],
      "body": {
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
  ],
  "challenges": [
    {
      "name": "default",
      "description": "Default challenge",
      "schedule": [
        {
          "operation": "company-name-search",
          "clients": 10,
          "warmup-time-period": 30,
          "time-period": ${TEST_DURATION}
        },
        {
          "operation": "country-filter-search",
          "clients": 10,
          "warmup-time-period": 30,
          "time-period": ${TEST_DURATION}
        },
        {
          "operation": "industry-search",
          "clients": 10,
          "warmup-time-period": 30,
          "time-period": ${TEST_DURATION}
        },
        {
          "operation": "complex-search",
          "clients": 10,
          "warmup-time-period": 30,
          "time-period": ${TEST_DURATION}
        },
        {
          "operation": "industry-aggregation",
          "clients": 10,
          "warmup-time-period": 30,
          "time-period": ${TEST_DURATION}
        }
      ]
    }
  ]
}
EOF

    # Create the mapping file
    cat > "${WORKLOAD_DIR}/mappings/index-mapping.json" <<EOF
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "properties": {
      "rcid": { "type": "integer" },
      "company_name": {
        "type": "text",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "year_founded": { "type": "integer" },
      "employee_count": { "type": "integer" },
      "company_website": { "type": "text" },
      "linkedin_url": { "type": "text" },
      "rics_400": { "type": "keyword" },
      "rics_200": { "type": "keyword" },
      "rics_100": { "type": "keyword" },
      "rics_50": { "type": "keyword" },
      "naics": { "type": "keyword" },
      "company_type": { "type": "keyword" },
      "company_description": {
        "type": "text",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "country": { "type": "keyword" },
      "state": { "type": "keyword" },
      "city": { "type": "keyword" },
      "ultimate_parent_name": {
        "type": "text",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      }
    }
  }
}
EOF

    # Verify files were created
    if [ ! -f "${WORKLOAD_DIR}/track.json" ]; then
        echo "Error: Failed to create track.json file"
        exit 1
    fi

    if [ ! -f "${WORKLOAD_DIR}/mappings/index-mapping.json" ]; then
        echo "Error: Failed to create mapping file"
        exit 1
    fi

    echo "Rally track files created:"
    echo "Track file: ${WORKLOAD_DIR}/track.json"
    echo "Mapping file: ${WORKLOAD_DIR}/mappings/index-mapping.json"
    echo "Track directory contents:"
    ls -la "${WORKLOAD_DIR}"
    echo "Mappings directory contents:"
    ls -la "${WORKLOAD_DIR}/mappings"
}

# Function to run Rally benchmark with authentication
run_rally_benchmark() {
    local workload_name=$1
    local scenario=$2 # which cluster we are testing. ess or aws

    echo "Running Rally benchmark for $scenario..."

    # Verify track.json exists
    if [ ! -f "${REPORT_DIR}/${workload_name}/track.json" ]; then
        echo "Error: track.json not found at ${REPORT_DIR}/${workload_name}/track.json"
        exit 1
    fi

    if [[ "$scenario" == "ess" ]]; then
      hosts="${ELASTICSEARCH_HOSTS}"
      "$RALLY_PATH" race --pipeline=benchmark-only --target-hosts="$hosts" --track-path="${REPORT_DIR}/${workload_name}" --challenge=default --client-options="timeout:60" --report-file="${REPORT_DIR}/${scenario}_rally_report.json" --on-error=abort
      if [ $? -ne 0 ]; then
        echo "Error: Rally benchmark failed. Check logs in ~/.rally/logs for details."
        exit 1
      fi
    else
      echo "Unknown scenario $scenario"
      exit 1
    fi

    echo "Rally benchmark for $scenario completed."
}

# Function to run benchmark with authentication
run_benchmark() {
    local workload_name=$1
    local scenario=$2 # which cluster we are testing. ess or aws

    echo "Running benchmark for $scenario..."

    # Create a Python script for benchmarking
    cat > "${REPORT_DIR}/benchmark_${scenario}.py" <<EOF
import time
import json
import concurrent.futures
from datetime import datetime

# Import the appropriate client based on scenario
if "${scenario}" == "ess":
    from elasticsearch import Elasticsearch
    Client = Elasticsearch
else:
    from opensearchpy import OpenSearch
    Client = OpenSearch

# Configuration
SCENARIO = "${scenario}"
HOSTS = "${ELASTICSEARCH_HOSTS}" if SCENARIO == "ess" else "${OPENSEARCH_HOSTS}"
USERNAME = "${ELASTICSEARCH_USER}" if SCENARIO == "ess" else None
PASSWORD = "${ELASTICSEARCH_PASSWORD}" if SCENARIO == "ess" else None
INDEX_NAME = "${INDEX_NAME}"
TEST_DURATION = ${TEST_DURATION}
NUM_CLIENTS = 10

# Initialize client
client_options = {
    "request_timeout": 60,
    "verify_certs": False
}

if SCENARIO == "ess":
    if USERNAME and PASSWORD:
        client_options["basic_auth"] = (USERNAME, PASSWORD)
    es = Client(HOSTS, **client_options)
else:
    # For AWS OpenSearch, we need to specify the host and port separately
    host = HOSTS.replace("https://", "").replace("/", "")
    es = Client(
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
        print(f"Error running query {query_name}: {str(e)}")  # Add error logging
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
print(f"Starting benchmark for {SCENARIO} with {NUM_CLIENTS} clients...")
print(f"Using endpoint: {HOSTS}")  # Add endpoint logging

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
output_file = "${REPORT_DIR}/${scenario}_benchmark_results.json"
with open(output_file, "w") as f:
    json.dump({
        "scenario": SCENARIO,
        "timestamp": datetime.now().isoformat(),
        "test_duration": TEST_DURATION,
        "num_clients": NUM_CLIENTS,
        "endpoint": HOSTS,
        "stats": stats,
        "raw_results": all_results
    }, f, indent=2)

print(f"Benchmark results saved to {output_file}")
EOF

    # Install required packages
    pip install opensearch-py

    # Run the benchmark script
    python "${REPORT_DIR}/benchmark_${scenario}.py"

    echo "Benchmark for $scenario completed."
}

# Create combined report
create_combined_report() {
    echo "Generating combined report..."

    # Check if report files exist
    if [ -f "${REPORT_DIR}/ess_rally_report.json" ]; then
        ESS_REPORT="Results available in: ${REPORT_DIR}/ess_rally_report.json"
    else
        ESS_REPORT="[Report file not found or benchmark did not complete successfully]"
    fi

    cat > ${REPORT_DIR}/elasticsearch_rally_report.md <<EOF
# Elasticsearch Performance Benchmark Report
## Elasticsearch Benchmark Using Rally
Date: $(date)

This report presents the results of search performance tests conducted using Elasticsearch Rally on:
Elasticsearch cluster

## Test Configuration
- Index: ${INDEX_NAME}
- Test duration: ${TEST_DURATION} seconds per operation
- Search operations tested:
  - Company name search (match query for "consulting")
  - Country filter search (filter for "United States")
  - Industry search (term query on rics_100)
  - Complex search (company name + country filter + employee count range)
  - Industry aggregation (terms aggregation with sub-aggregations)
- Client concurrency: 10 concurrent clients

## Elasticsearch Results
${ESS_REPORT}

## Performance Metrics

| Metric | Value |
|--------|-------|
| Avg. Company Name Search Latency (ms) | TBD |
| Avg. Country Filter Search Latency (ms) | TBD |
| Avg. Industry Search Latency (ms) | TBD |
| Avg. Complex Search Latency (ms) | TBD |
| Avg. Industry Aggregation Latency (ms) | TBD |
| Max Throughput (ops/sec) | TBD |
| 99th Percentile Latency (ms) | TBD |
| Error Rate (%) | TBD |

## Conclusions and Recommendations

*[Fill this section after analyzing the benchmark results]*

- Performance analysis for each query type
- Cost considerations
- Scalability observations
- Recommended configuration changes or optimizations

EOF

    echo "Rally report generated: ${REPORT_DIR}/elasticsearch_rally_report.md"
    echo "Please analyze the JSON result files and complete the metrics table in the report."
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
    echo "===== Elasticsearch Search Benchmark Tool ====="
    echo "This script will benchmark search performance on Elasticsearch cluster using Rally"
    echo "and generate a performance report."
    echo ""

    # Setup Python environment
    setup_python_environment

    # Configure benchmark parameters
    configure_benchmark

    # Create Rally workload
    create_rally_workload

    WORKLOAD_NAME="elasticsearch-search-workload"

    # Run benchmarks
    echo "Starting benchmarks..."
    
    # Run Elasticsearch benchmark with Rally
    run_rally_benchmark "${WORKLOAD_NAME}" "ess"

    # Create report
    create_combined_report

    # Cleanup
    cleanup

    echo ""
    echo "===== Benchmark Complete ====="
    echo "Reports are available in the ${REPORT_DIR} directory."
    echo "Please review the results and complete the metrics table and conclusions in the report."
}

# Run the main function
main