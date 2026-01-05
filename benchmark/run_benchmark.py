#!/usr/bin/env python3
"""
Benchmark script for comparing Sui Move translation models
Compares SolMover vs Gemini-2.5 vs Qwen3-Coder outputs
"""

import os
import subprocess
import json
import re
from datetime import datetime
from pathlib import Path
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend

# Configuration
BENCHMARK_DIR = Path("/Users/vargaelod/shinso/model/benchmark")
CONTRACTS = [
    "0_hello_world",
    "1_tipjar",
    "2_guestbook",
    "3_todo_list",
    "4_simple_coin",
    "5_counter",
    "6_weather_oracle"
]
MODELS = {
    "solmover": "output_solmover",
    "gemini-2.5": "output_gemini-2.5",
    "qwen3-coder": "output_qwen3-coder",
    "gemini-3-pro-preview": "output_gemini-3-pro-preview"
}

# Expected test counts (from the reference implementation)
EXPECTED_TESTS = {
    "0_hello_world": 11,
    "1_tipjar": 12,
    "2_guestbook": 12,
    "3_todo_list": 14,
    "4_simple_coin": 12,
    "5_counter": 14,
    "6_weather_oracle": 13
}


def test_contract(model_name, contract_name):
    """Test a single contract and return results"""
    output_dir = BENCHMARK_DIR / MODELS[model_name] / contract_name

    result = {
        "model": model_name,
        "contract": contract_name,
        "compiles": False,
        "tests_passed": 0,
        "tests_total": 0,
        "tests_expected": EXPECTED_TESTS[contract_name],
        "warnings": 0,
        "errors": [],
        "compile_score": 0,
        "test_score": 0,
        "quality_score": 0,
        "total_score": 0
    }

    if not output_dir.exists():
        result["errors"].append(f"Directory not found: {output_dir}")
        return result

    # Run sui move test
    try:
        process = subprocess.run(
            ["sui", "move", "test"],
            cwd=output_dir,
            capture_output=True,
            text=True,
            timeout=60
        )

        output = process.stdout + process.stderr

        # Check if compiled successfully
        if process.returncode == 0:
            result["compiles"] = True
            result["compile_score"] = 40

            # Parse test results
            test_match = re.search(r"Test result: OK\. Total tests: (\d+); passed: (\d+); failed: (\d+)", output)
            if test_match:
                result["tests_total"] = int(test_match.group(1))
                result["tests_passed"] = int(test_match.group(2))

            # Count warnings
            result["warnings"] = output.count("warning")

        else:
            # Compilation failed
            result["compiles"] = False
            result["compile_score"] = 0

            # Extract error types
            if "error[E" in output:
                error_codes = re.findall(r"error\[E\d+\]", output)
                result["errors"] = list(set(error_codes))[:5]  # Top 5 unique errors

        # Calculate test score (out of 50)
        if result["tests_expected"] > 0:
            result["test_score"] = round((result["tests_passed"] / result["tests_expected"]) * 50, 2)

        # Calculate quality score (out of 10)
        if result["warnings"] == 0:
            result["quality_score"] = 10
        elif result["warnings"] <= 5:
            result["quality_score"] = 7
        else:
            result["quality_score"] = 3

        # Calculate total score
        result["total_score"] = round(
            result["compile_score"] + result["test_score"] + result["quality_score"],
            2
        )

    except subprocess.TimeoutExpired:
        result["errors"].append("Test timeout (>60s)")
    except Exception as e:
        result["errors"].append(f"Error: {str(e)}")

    return result


def generate_charts(results, output_dir):
    """Generate visualization charts for benchmark results"""

    # Group by model
    models_data = {}
    for result in results:
        model = result["model"]
        if model not in models_data:
            models_data[model] = []
        models_data[model].append(result)

    # Calculate statistics
    model_stats = {}
    for model in MODELS.keys():
        model_results = [r for r in results if r["model"] == model]
        model_stats[model] = {
            "avg_score": sum(r["total_score"] for r in model_results) / len(model_results),
            "compile_rate": sum(1 for r in model_results if r["compiles"]) / len(model_results) * 100,
            "avg_compile": sum(r["compile_score"] for r in model_results) / len(model_results),
            "avg_test": sum(r["test_score"] for r in model_results) / len(model_results),
            "avg_quality": sum(r["quality_score"] for r in model_results) / len(model_results),
            "total_passed": sum(r["tests_passed"] for r in model_results),
            "total_expected": sum(r["tests_expected"] for r in model_results)
        }

    # Create figure with 3 subplots
    fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(18, 5))
    fig.suptitle('Benchmark Results Comparison', fontsize=16, fontweight='bold')

    models = list(MODELS.keys())
    colors = ['#4CAF50', '#2196F3', '#FF9800', '#9C27B0']

    # Chart 1: Overall Average Score
    scores = [model_stats[m]["avg_score"] for m in models]
    bars1 = ax1.bar(models, scores, color=colors[:len(models)], alpha=0.8, edgecolor='black')
    ax1.set_ylabel('Average Score', fontweight='bold')
    ax1.set_title('Overall Performance', fontweight='bold')
    ax1.set_ylim(0, 100)
    ax1.axhline(y=70, color='green', linestyle='--', linewidth=1, alpha=0.5, label='Production-viable')
    ax1.axhline(y=50, color='orange', linestyle='--', linewidth=1, alpha=0.5, label='Needs refinement')
    ax1.legend(fontsize=8)

    # Add value labels on bars
    for bar in bars1:
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}',
                ha='center', va='bottom', fontweight='bold')

    # Chart 2: Score Breakdown by Category
    compile_scores = [model_stats[m]["avg_compile"] for m in models]
    test_scores = [model_stats[m]["avg_test"] for m in models]
    quality_scores = [model_stats[m]["avg_quality"] for m in models]

    x = range(len(models))
    width = 0.25

    bars2a = ax2.bar([i - width for i in x], compile_scores, width, label='Compilation (40)', color='#FF6B6B', alpha=0.8, edgecolor='black')
    bars2b = ax2.bar(x, test_scores, width, label='Tests (50)', color='#4ECDC4', alpha=0.8, edgecolor='black')
    bars2c = ax2.bar([i + width for i in x], quality_scores, width, label='Quality (10)', color='#95E1D3', alpha=0.8, edgecolor='black')

    ax2.set_ylabel('Score', fontweight='bold')
    ax2.set_title('Score Breakdown by Category', fontweight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(models)
    ax2.legend()
    ax2.set_ylim(0, 55)

    # Add value labels
    for bars in [bars2a, bars2b, bars2c]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax2.text(bar.get_x() + bar.get_width()/2., height,
                        f'{height:.1f}',
                        ha='center', va='bottom', fontsize=8)

    # Chart 3: Compilation vs Test Pass Rate
    compile_rates = [model_stats[m]["compile_rate"] for m in models]
    test_pass_rates = [(model_stats[m]["total_passed"] / model_stats[m]["total_expected"] * 100)
                       for m in models]

    x3 = range(len(models))
    width3 = 0.35

    bars3a = ax3.bar([i - width3/2 for i in x3], compile_rates, width3,
                     label='Compilation Rate', color='#6C5CE7', alpha=0.8, edgecolor='black')
    bars3b = ax3.bar([i + width3/2 for i in x3], test_pass_rates, width3,
                     label='Test Pass Rate', color='#FDCB6E', alpha=0.8, edgecolor='black')

    ax3.set_ylabel('Percentage (%)', fontweight='bold')
    ax3.set_title('Compilation vs Test Success', fontweight='bold')
    ax3.set_xticks(x3)
    ax3.set_xticklabels(models)
    ax3.legend()
    ax3.set_ylim(0, 110)

    # Add value labels
    for bars in [bars3a, bars3b]:
        for bar in bars:
            height = bar.get_height()
            ax3.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.1f}%',
                    ha='center', va='bottom', fontsize=9, fontweight='bold')

    plt.tight_layout()

    # Save chart
    chart_path = output_dir / "benchmark_charts.png"
    plt.savefig(chart_path, dpi=300, bbox_inches='tight')
    plt.close()

    print(f"✓ Charts saved to: {chart_path}")

    return chart_path


def generate_markdown_table(results):
    """Generate a markdown table from results"""

    # Group by model
    models_data = {}
    for result in results:
        model = result["model"]
        if model not in models_data:
            models_data[model] = []
        models_data[model].append(result)

    # Generate comparison table
    markdown = "# Sui Move Translation Benchmark Results\n\n"
    markdown += f"**Benchmark Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"

    markdown += "## Visual Comparison\n\n"
    markdown += "![Benchmark Charts](benchmark_charts.png)\n\n"

    markdown += "## Scoring System\n\n"
    markdown += "- **Compilation (40 points):** Code compiles without errors\n"
    markdown += "- **Test Pass Rate (50 points):** (Tests Passed / Expected Tests) × 50\n"
    markdown += "- **Code Quality (10 points):** Based on warning count\n"
    markdown += "- **Total Score:** Sum of all categories (max 100 per contract)\n\n"

    markdown += "## Detailed Results by Contract\n\n"
    markdown += "| Contract | Model | Compiles | Tests Passed | Expected | Pass Rate | Warnings | Score |\n"
    markdown += "|----------|-------|----------|--------------|----------|-----------|----------|-------|\n"

    for contract in CONTRACTS:
        for model in MODELS.keys():
            result = next((r for r in results if r["contract"] == contract and r["model"] == model), None)
            if result:
                compiles = "✅" if result["compiles"] else "❌"
                pass_rate = f"{result['tests_passed']}/{result['tests_expected']}"
                percentage = f"{(result['tests_passed']/result['tests_expected']*100):.1f}%" if result['tests_expected'] > 0 else "N/A"
                score = f"{result['total_score']:.1f}/100"

                markdown += f"| {contract} | {model} | {compiles} | {result['tests_passed']} | {result['tests_expected']} | {percentage} | {result['warnings']} | {score} |\n"

    markdown += "\n## Summary Statistics\n\n"
    markdown += "| Model | Avg Score | Compilation Rate | Avg Test Pass Rate | Total Tests Passed |\n"
    markdown += "|-------|-----------|------------------|--------------------|--------------------|" "\n"

    for model in MODELS.keys():
        model_results = [r for r in results if r["model"] == model]

        avg_score = sum(r["total_score"] for r in model_results) / len(model_results)
        compile_rate = sum(1 for r in model_results if r["compiles"]) / len(model_results) * 100

        total_passed = sum(r["tests_passed"] for r in model_results)
        total_expected = sum(r["tests_expected"] for r in model_results)
        avg_pass_rate = (total_passed / total_expected * 100) if total_expected > 0 else 0

        markdown += f"| {model} | {avg_score:.1f}/100 | {compile_rate:.1f}% | {avg_pass_rate:.1f}% | {total_passed}/{total_expected} |\n"

    markdown += "\n## Score Breakdown by Category\n\n"
    markdown += "| Model | Avg Compilation | Avg Test Score | Avg Quality |\n"
    markdown += "|-------|-----------------|----------------|-------------|\n"

    for model in MODELS.keys():
        model_results = [r for r in results if r["model"] == model]
        avg_compile = sum(r["compile_score"] for r in model_results) / len(model_results)
        avg_test = sum(r["test_score"] for r in model_results) / len(model_results)
        avg_quality = sum(r["quality_score"] for r in model_results) / len(model_results)

        markdown += f"| {model} | {avg_compile:.1f}/40 | {avg_test:.1f}/50 | {avg_quality:.1f}/10 |\n"

    return markdown


def main():
    print("=" * 60)
    print("   SUI MOVE TRANSLATION BENCHMARK")
    print("=" * 60)
    print()

    results = []

    for model in MODELS.keys():
        print(f"\n{'=' * 60}")
        print(f"Testing: {model}")
        print('=' * 60)

        for contract in CONTRACTS:
            print(f"\n  Testing {contract}...", end=" ")
            result = test_contract(model, contract)
            results.append(result)

            if result["compiles"]:
                print(f"✅ {result['tests_passed']}/{result['tests_expected']} tests | Score: {result['total_score']:.1f}/100")
            else:
                print(f"❌ Compilation failed | Score: {result['total_score']:.1f}/100")
                if result["errors"]:
                    print(f"     Errors: {', '.join(result['errors'][:3])}")

    print("\n" + "=" * 60)
    print("Benchmark Complete!")
    print("=" * 60)

    # Save results
    results_json = BENCHMARK_DIR / "benchmark_results.json"
    with open(results_json, 'w') as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "results": results
        }, f, indent=2)
    print(f"\n✓ Results saved to: {results_json}")

    # Generate charts
    generate_charts(results, BENCHMARK_DIR)

    # Generate and save markdown report
    markdown = generate_markdown_table(results)
    report_file = BENCHMARK_DIR / "BENCHMARK_REPORT.md"
    with open(report_file, 'w') as f:
        f.write(markdown)
    print(f"✓ Report saved to: {report_file}")

    # Print summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for model in MODELS.keys():
        model_results = [r for r in results if r["model"] == model]
        avg_score = sum(r["total_score"] for r in model_results) / len(model_results)
        compile_rate = sum(1 for r in model_results if r["compiles"]) / len(model_results) * 100
        total_passed = sum(r["tests_passed"] for r in model_results)
        total_expected = sum(r["tests_expected"] for r in model_results)

        print(f"\n{model}:")
        print(f"  Average Score: {avg_score:.1f}/100")
        print(f"  Compilation Rate: {compile_rate:.1f}%")
        print(f"  Tests Passed: {total_passed}/{total_expected} ({total_passed/total_expected*100:.1f}%)")


if __name__ == "__main__":
    main()
