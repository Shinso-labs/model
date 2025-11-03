#!/bin/bash

# Solidity to Move Translation Benchmark Runner
# This script runs the full benchmark pipeline

echo "======================================"
echo "Solidity to Move Benchmark Pipeline"
echo "======================================"
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Running setup..."
    bash setup.sh
    if [ $? -ne 0 ]; then
        echo "Setup failed. Please check the errors above."
        exit 1
    fi
fi

# Activate virtual environment
echo "Activating virtual environment..."
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    source venv/Scripts/activate
else
    source venv/bin/activate
fi

# Run the benchmark
echo "Starting benchmark..."
echo ""
python benchmark_runner.py

# Check if benchmark completed successfully
if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "Benchmark completed successfully!"
    echo "======================================"
    echo ""
    echo "Generating HTML report..."
    python reporter.py latest

    if [ $? -eq 0 ]; then
        echo ""
        echo "Done! Check the results/ directory for:"
        echo "  - JSON results file"
        echo "  - Generated Move files"
        echo "  - HTML report"
        echo ""

        # Try to open the HTML report (macOS)
        if command -v open &> /dev/null; then
            LATEST_REPORT=$(ls -t results/report_*.html 2>/dev/null | head -1)
            if [ -n "$LATEST_REPORT" ]; then
                echo "Opening HTML report..."
                open "$LATEST_REPORT"
            fi
        fi
    fi
else
    echo ""
    echo "Benchmark failed. Check the output above for errors."
    exit 1
fi

# Deactivate virtual environment
deactivate
