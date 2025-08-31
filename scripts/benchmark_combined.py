import time
import json
import os
import concurrent.futures
from datetime import datetime
from elasticsearch import Elasticsearch
from opensearchpy import OpenSearch

# Configuration - Use environment variables with fallback defaults
ELASTICSEARCH_HOSTS = os.getenv("ELASTICSEARCH_HOSTS", "https://your-elasticsearch-cluster.com")
ELASTICSEARCH_USER = os.getenv("ELASTICSEARCH_USER", "your-username")
ELASTICSEARCH_PASSWORD = os.getenv("ELASTICSEARCH_PASSWORD", "your-password")
OPENSEARCH_HOSTS = os.getenv("OPENSEARCH_HOSTS", "https://your-opensearch-cluster.amazonaws.com")
INDEX_NAME = os.getenv("INDEX_NAME", "sample-companies")
TEST_DURATION = int(os.getenv("TEST_DURATION", "20"))
NUM_CLIENTS = int(os.getenv("NUM_CLIENTS", "10"))

# Initialize clients
elasticsearch_client = Elasticsearch(
    ELASTICSEARCH_HOSTS,
    basic_auth=(ELASTICSEARCH_USER, ELASTICSEARCH_PASSWORD),
    verify_certs=False,
    timeout=60
)

opensearch_host = OPENSEARCH_HOSTS.replace("https://", "").replace("/", "")
opensearch_client = OpenSearch(
    hosts=[{"host": opensearch_host, "port": 443}],
    http_compress=True,
    use_ssl=True,
    verify_certs=False,
    ssl_assert_hostname=False,
    ssl_show_warn=False,
    timeout=60
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

def run_query(client, query_name, query_body, cluster_name):
    start_time = time.time()
    try:
        response = client.search(index=INDEX_NAME, body=query_body)
        end_time = time.time()
        return {
            "cluster": cluster_name,
            "query": query_name,
            "success": True,
            "latency": (end_time - start_time) * 1000,  # Convert to ms
            "hits": response["hits"]["total"]["value"] if "hits" in response else None
        }
    except Exception as e:
        print(f"Error running query {query_name} on {cluster_name}: {str(e)}")
        return {
            "cluster": cluster_name,
            "query": query_name,
            "success": False,
            "error": str(e)
        }

def run_benchmark_worker(client, cluster_name):
    results = []
    start_time = time.time()
    
    while time.time() - start_time < TEST_DURATION:
        for query_name, query_body in queries.items():
            result = run_query(client, query_name, query_body, cluster_name)
            results.append(result)
    
    return results

# Run benchmarks
print("Starting benchmarks...")
print(f"Using Elasticsearch endpoint: {ELASTICSEARCH_HOSTS}")
print(f"Using OpenSearch endpoint: {OPENSEARCH_HOSTS}")
print(f"Using index: {INDEX_NAME}")

# Run Elasticsearch benchmark
print("\nRunning Elasticsearch benchmark...")
with concurrent.futures.ThreadPoolExecutor(max_workers=NUM_CLIENTS) as executor:
    futures = [executor.submit(run_benchmark_worker, elasticsearch_client, "Elasticsearch") for _ in range(NUM_CLIENTS)]
    elasticsearch_results = []
    for future in concurrent.futures.as_completed(futures):
        elasticsearch_results.extend(future.result())

# Run OpenSearch benchmark
print("\nRunning OpenSearch benchmark...")
with concurrent.futures.ThreadPoolExecutor(max_workers=NUM_CLIENTS) as executor:
    futures = [executor.submit(run_benchmark_worker, opensearch_client, "OpenSearch") for _ in range(NUM_CLIENTS)]
    opensearch_results = []
    for future in concurrent.futures.as_completed(futures):
        opensearch_results.extend(future.result())

# Calculate statistics
def calculate_stats(results, cluster_name):
    stats = {}
    cluster_results = [r for r in results if r["cluster"] == cluster_name]
    
    for query_name in queries.keys():
        query_results = [r for r in cluster_results if r["query"] == query_name]
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
    return stats

elasticsearch_stats = calculate_stats(elasticsearch_results, "Elasticsearch")
opensearch_stats = calculate_stats(opensearch_results, "OpenSearch")

# Save results
results_dir = os.getenv("RESULTS_DIR", ".")
output_file = os.path.join(results_dir, "combined_benchmark_results.json")
with open(output_file, "w") as f:
    json.dump({
        "timestamp": datetime.now().isoformat(),
        "test_duration": TEST_DURATION,
        "num_clients": NUM_CLIENTS,
        "index_name": INDEX_NAME,
        "elasticsearch_endpoint": ELASTICSEARCH_HOSTS,
        "opensearch_endpoint": OPENSEARCH_HOSTS,
        "elasticsearch_stats": elasticsearch_stats,
        "opensearch_stats": opensearch_stats,
        "raw_results": {
            "elasticsearch": elasticsearch_results,
            "opensearch": opensearch_results
        }
    }, f, indent=2)

print(f"\nBenchmark results saved to {output_file}")
