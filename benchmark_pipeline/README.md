# Solidity to Move Translation Benchmark Pipeline

A comprehensive testing and benchmarking pipeline for evaluating the quality of Solidity to Sui Move code translations.

## Features

- **Automated Testing**: Run translations on all benchmark cases automatically
- **Comprehensive Evaluation**: Industry-standard metrics including BLEU score, semantic similarity, and structural analysis
- **Compilation Verification**: Tests if generated Move code actually compiles (requires `sui` CLI)
- **Detailed Reporting**: Generate both JSON and HTML reports with visualizations
- **Model Comparison**: Compare multiple benchmark runs to track progress and evaluate different models
- **Code Cleanup**: Automatically removes unwanted tokens and artifacts from generated code
- **Error Handling**: Robust retry logic and error reporting
- **Extensible**: Easy to add new test cases and evaluation metrics

## Project Structure

```bash
benchmark_pipeline/
├── config.py                    # Configuration settings
├── api_client.py                # API client with code cleanup
├── evaluator.py                 # Comprehensive evaluation metrics (BLEU, semantic, etc.)
├── benchmark_runner.py          # Main benchmark orchestrator
├── reporter.py                  # HTML and text report generation
├── compare_models.py            # Multi-model comparison tool
├── BENCHMARK_KPI_GUIDE.md      # Detailed KPI documentation
├── requirements.txt             # Python dependencies
├── setup.sh                     # Setup script
├── run_benchmark.sh             # Convenience script to run benchmarks
└── results/                     # Generated results and reports
```

## Quick Start

The easiest way to get started:

```bash
# Run setup (creates venv and installs dependencies)
bash setup.sh

# Run the full benchmark
bash run_benchmark.sh
```

## Installation

### Option 1: Automated Setup (Recommended)

Run the setup script to create a virtual environment and install dependencies:

```bash
bash setup.sh
```

This will:

- Create a Python virtual environment in `venv/`
- Install all required dependencies
- Prepare the pipeline for use

### Option 2: Manual Setup

1. Create a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Configure your API credentials in `config.py` (already pre-configured with your endpoint)

## Usage

### Running the Full Benchmark

#### Using the convenience script:

```bash
bash run_benchmark.sh
```

This script will automatically activate the virtual environment, run all benchmarks, generate reports, and open the HTML report.

#### Manual execution:

Activate the virtual environment first:

```bash
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

Then run the benchmark:

```bash
python benchmark_runner.py
```

This will:

1. Load all test cases from the benchmark folders
2. Translate each Solidity contract using your API
3. Evaluate the generated Move code against reference implementations
4. Save results to the `results/` directory
5. Print a summary to the console

### Running Specific Test Cases

You can modify `benchmark_runner.py` or create a custom script:

```python
from benchmark_runner import BenchmarkRunner

runner = BenchmarkRunner()
runner.run_all_benchmarks(test_cases=["0_hello_world", "1_tipjar"])
runner.print_summary()
runner.save_results()
```

### Generating Reports

Generate an HTML report from existing results (make sure venv is activated):

```bash
source venv/bin/activate

# Generate report for the latest results
python reporter.py latest

# Generate report for a specific results file
python reporter.py results/benchmark_results_20231030_120000.json
```

### Comparing Models

Compare multiple benchmark runs to track progress or evaluate different models:

```bash
source venv/bin/activate

# Compare all benchmark runs
python compare_models.py --all

# Compare specific runs
python compare_models.py results/run1.json results/run2.json

# Export comparison to CSV
python compare_models.py --all  # Automatically exports to CSV
```

The comparison report shows:

- Side-by-side metrics for all models
- Best performer in each category
- Composite score ranking
- Specific recommendations for improvement

### Using Individual Components

#### API Client

```python
from api_client import TranslationAPIClient

client = TranslationAPIClient()
result = client.translate(solidity_code)

if result['success']:
    print(result['generated_code'])
```

#### Evaluator

```python
from evaluator import MoveCodeEvaluator

evaluator = MoveCodeEvaluator()
evaluation = evaluator.evaluate(
    generated_code,
    reference_code,
    test_case_name
)

print(f"Syntax Score: {evaluation.syntax_score}")
print(f"BLEU Score: {evaluation.bleu_score}")
print(f"Semantic Score: {evaluation.semantic_score}")
print(f"Compilable: {evaluation.compilable}")
print(f"Passed: {evaluation.passed}")
```

## Evaluation Metrics

The pipeline evaluates translations using comprehensive, industry-standard metrics:

### Core Metrics

#### 1. Syntax Score (0-100)

Basic syntactic correctness of generated Move code:

- Proper module declaration (20 pts)
- Valid use statements with `::` (15 pts)
- Struct and function definitions (20 pts)
- Balanced braces `{}` (20 pts)
- Move-specific patterns (`UID`, `TxContext`, etc.) (25 pts)

#### 2. BLEU Score (0-100)

Industry-standard n-gram based similarity metric (used in machine translation):

- Calculates 1-gram through 4-gram precision
- Applies geometric mean and brevity penalty
- **Comparable** across all code translation models

#### 3. Similarity Score (0-100)

Character-level sequence similarity using Python's difflib.

#### 4. Structure Score (0-100)

High-level structural similarity:

- Module names
- Struct definitions (with Jaccard similarity)
- Function definitions

#### 5. Semantic Score (0-100)

Semantic equivalence based on code structure and intent:

- Module declaration (20% weight)
- Struct matching (30% weight)
- Function matching (30% weight)
- Import matching (20% weight)

#### 6. Compilation Rate (%)

Whether generated code successfully compiles with `sui move build`:

- **Most important metric for production readiness**
- Requires `sui` CLI to be installed
- Returns `N/A` if `sui` CLI not available

### Overall Pass/Fail

A test case passes if **ALL** of the following criteria are met:

- Syntax score ≥ 50
- Semantic score ≥ 40
- Structure score ≥ 40
- BLEU score ≥ 20
- Generated code is not empty

These thresholds can be adjusted in `evaluator.py`.

### Detailed Metrics Documentation

See `BENCHMARK_KPI_GUIDE.md` for comprehensive documentation on all metrics, including:

- What each metric measures
- How to interpret scores
- Industry comparison benchmarks
- Recommendations for improvement

## Output Files

### JSON Results

`results/benchmark_results_<timestamp>.json`

- Complete benchmark data
- Scores for each test case
- Error messages and metadata

### Generated Code

`results/<timestamp>_<test_case>_generated.move`

- The actual Move code generated by the model

### HTML Report

`results/report_<timestamp>.html`

- Visual dashboard with charts
- Summary statistics
- Detailed per-test results

## Adding New Test Cases

1. Add Solidity contract to `../benchmark/solidity/<case_name>/`
2. Add reference Move implementation to `../benchmark/sui_move/<case_name>/sources/`
3. Add case name to `TEST_CASES` in `config.py`

## Customization

### Adjusting API Settings

Edit `config.py`:

```python
REQUEST_TIMEOUT = 60  # seconds
MAX_RETRIES = 3
```

### Customizing Evaluation Thresholds

Edit `evaluator.py`, method `evaluate()`:

```python
passed = (
    syntax_score >= 50 and
    similarity_score >= 30 and
    structure_score >= 40
)
```

### Adding New Metrics

Extend the `MoveCodeEvaluator` class in `evaluator.py`:

```python
def _check_custom_metric(self, code: str) -> float:
    # Your custom evaluation logic
    score = 0.0
    # ...
    return score
```

## Example Output

```bash
==============================================================
SOLIDITY TO MOVE TRANSLATION BENCHMARK
==============================================================

Testing API connection...
API connection successful!

Running benchmark: 0_hello_world
============================================================
Translating 0_hello_world...
Translation completed in 2.34s
Evaluating 0_hello_world...
Evaluation scores:
  - Syntax: 85.0/100
  - Similarity: 67.3/100
  - Structure: 75.0/100
  - BLEU: 42.5/100
  - Semantic: 68.0/100
  - Compilable: Yes
  - Overall: PASS

...

==============================================================
BENCHMARK SUMMARY
==============================================================

Total test cases: 7
Successful translations: 7/7
Passed evaluations: 6/7
Average response time: 2.45s

Average scores:
  - Syntax: 82.1/100
  - Similarity: 64.8/100
  - Structure: 71.4/100
  - BLEU: 38.2/100
  - Semantic: 62.5/100
  - Compilation rate: 5/7 (71.4%)

Per-test results:
  0_hello_world        - PASS
  1_tipjar             - PASS
  2_guestbook          - PASS
  3_todo_list          - FAIL
  4_simple_coin        - PASS
  5_counter            - PASS
  6_weather_oracle     - PASS

Results saved to: results/benchmark_results_20231030_143022.json
```

## Troubleshooting

### API Connection Fails

- Check that the API URL and key in `config.py` are correct
- Verify network connectivity
- Check API endpoint status

### Import Errors

- Ensure you're running from the correct directory
- Install all dependencies: `pip install -r requirements.txt`

### No Test Cases Found

- Verify the benchmark folder structure matches the expected format
- Check that `BENCHMARK_ROOT` in `config.py` points to the correct directory

## License

MIT
