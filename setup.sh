#!/bin/bash

# Elasticsearch vs OpenSearch Benchmarking Setup Script
# This script helps you get started with the benchmarking tools

set -e

echo "=== Elasticsearch vs OpenSearch Benchmarking Setup ==="

# Check if pyenv is installed
if ! command -v pyenv &> /dev/null; then
    echo "❌ Error: pyenv is not installed."
    echo "Please install pyenv first:"
    echo "https://github.com/pyenv/pyenv#installation"
    exit 1
fi

echo "✅ pyenv is installed"

# Check if pyenv-virtualenv is installed
if ! pyenv commands | grep -q "virtualenv"; then
    echo "❌ Error: pyenv-virtualenv plugin is not installed."
    echo "Installing pyenv-virtualenv..."
    git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
    echo "✅ pyenv-virtualenv installed. Please restart your shell and run this script again."
    exit 0
fi

echo "✅ pyenv-virtualenv is installed"

# Create environment configuration
if [ ! -f ".env" ]; then
    echo "📝 Creating environment configuration..."
    cp .env.example .env
    echo "✅ Created .env file. Please edit it with your cluster details."
else
    echo "✅ .env file already exists"
fi

# Create Rally configuration  
if [ ! -f "rally.ini" ]; then
    echo "📝 Creating Rally configuration..."
    cp rally.ini.example rally.ini
    echo "✅ Created rally.ini file"
else
    echo "✅ rally.ini file already exists"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit .env with your cluster endpoints and credentials"
echo "2. Optionally edit rally.ini for Rally-specific settings"
echo "3. Run one of the benchmark scripts:"
echo "   - ./es_benchmarking.sh           (Elasticsearch only)"
echo "   - ./opensearch_benchmarking.sh   (OpenSearch only)"
echo "   - ./combined_benchmarking.sh     (Both clusters)"
echo ""
echo "For more information, see README.md"