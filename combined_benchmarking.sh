#!/bin/bash

# Script to benchmark search performance on both Elasticsearch and OpenSearch clusters
# Generic benchmarking tool for comparing performance

set -e

# Default configuration - Use environment variables with fallback defaults
PYTHON_VERSION="${PYTHON_VERSION:-3.11.4}"
ELASTICSEARCH_HOSTS="${ELASTICSEARCH_HOSTS:-https://your-elasticsearch-cluster.com}"
ELASTICSEARCH_USER="${ELASTICSEARCH_USER:-your-username}"
ELASTICSEARCH_PASSWORD="${ELASTICSEARCH_PASSWORD:-your-password}"
OPENSEARCH_HOSTS="${OPENSEARCH_HOSTS:-https://your-opensearch-cluster.amazonaws.com}"
INDEX_NAME="${INDEX_NAME:-sample-companies}"
TEST_DURATION="${TEST_DURATION:-600}"
NUM_CLIENTS="${NUM_CLIENTS:-10}"

echo "=== Elasticsearch vs OpenSearch Benchmark ==="
echo "This script will benchmark both clusters and generate a comparison report"
echo ""

# Check if environment variables are set to default values
if [[ "$ELASTICSEARCH_HOSTS" == "https://your-elasticsearch-cluster.com" ]]; then
    echo "⚠️  Warning: Using default Elasticsearch endpoint. Please set ELASTICSEARCH_HOSTS environment variable."
fi

if [[ "$OPENSEARCH_HOSTS" == "https://your-opensearch-cluster.amazonaws.com" ]]; then
    echo "⚠️  Warning: Using default OpenSearch endpoint. Please set OPENSEARCH_HOSTS environment variable."
fi

if [[ "$ELASTICSEARCH_USER" == "your-username" ]]; then
    echo "⚠️  Warning: Using default credentials. Please set ELASTICSEARCH_USER and ELASTICSEARCH_PASSWORD."
fi

echo ""
echo "Current configuration:"
echo "  Elasticsearch: $ELASTICSEARCH_HOSTS"
echo "  OpenSearch: $OPENSEARCH_HOSTS"
echo "  Index: $INDEX_NAME"
echo "  Test Duration: $TEST_DURATION seconds"
echo "  Concurrent Clients: $NUM_CLIENTS"
echo ""

read -p "Continue with this configuration? (y/n): " CONTINUE
if [[ "$CONTINUE" != "y" ]]; then
    echo "Please set your environment variables and try again."
    echo "See .env.example for reference."
    exit 1
fi

# Check if pyenv is installed
if ! command -v pyenv &> /dev/null; then
    echo "❌ Error: pyenv is not installed. Please install pyenv first."
    echo "Visit https://github.com/pyenv/pyenv#installation for installation instructions."
    exit 1
fi

# Set up Python environment
setup_python_environment() {
    echo "🐍 Setting up Python environment..."
    
    # Check if the selected version is installed
    if ! pyenv versions | grep -q "$PYTHON_VERSION"; then
        echo "Python version $PYTHON_VERSION is not installed."
        read -p "Would you like to install it? (y/n): " INSTALL_PYTHON
        if [[ "$INSTALL_PYTHON" == "y" ]]; then
            echo "Installing Python $PYTHON_VERSION..."
            pyenv install $PYTHON_VERSION
        else
            echo "Please install Python $PYTHON_VERSION or update PYTHON_VERSION environment variable."
            exit 1
        fi
    fi

    # Create virtual environment name
    VENV_NAME="elasticsearch-opensearch-benchmark-$PYTHON_VERSION"

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
            echo "Please remove the existing environment with: pyenv uninstall $VENV_NAME"
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

    # Install required packages
    echo "📦 Installing required packages..."
    pip install --upgrade pip
    pip install elasticsearch opensearch-py tabulate

    echo "✅ Python environment setup complete."
    echo "Using Python $(python --version)"
}

# Run the benchmark
run_benchmark() {
    echo "🚀 Starting combined benchmark..."
    
    # Create results directory with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    RESULTS_DIR="results/combined_benchmark_$TIMESTAMP"
    mkdir -p "$RESULTS_DIR"
    
    echo "Results will be saved to: $RESULTS_DIR"
    
    # Export environment variables for the Python script
    export ELASTICSEARCH_HOSTS
    export ELASTICSEARCH_USER  
    export ELASTICSEARCH_PASSWORD
    export OPENSEARCH_HOSTS
    export INDEX_NAME
    export TEST_DURATION
    export NUM_CLIENTS
    export RESULTS_DIR
    
    # Run the benchmark script
    python scripts/benchmark_combined.py
    
    # Generate the report
    echo "📊 Generating report..."
    cd "$RESULTS_DIR"
    python ../../scripts/generate_report.py
    cd - > /dev/null
    
    echo ""
    echo "✅ Benchmark completed successfully!"
    echo "📁 Results saved to: $RESULTS_DIR"
    echo "📄 Report available at: $RESULTS_DIR/benchmark_report.md"
    echo ""
    echo "To view the report:"
    echo "  cat '$RESULTS_DIR/benchmark_report.md'"
}

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up..."
    read -p "Would you like to deactivate the virtual environment? (y/n): " DEACTIVATE_VENV
    if [[ "$DEACTIVATE_VENV" == "y" ]]; then
        pyenv deactivate 2>/dev/null || true
        echo "Virtual environment deactivated."
    else
        echo "Virtual environment remains active."
    fi
}

# Main execution
main() {
    # Setup Python environment
    setup_python_environment
    
    # Run benchmark
    run_benchmark
    
    # Cleanup
    cleanup
}

# Handle script interruption
trap cleanup EXIT

# Run the main function
main "$@"