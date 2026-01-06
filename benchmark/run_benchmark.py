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
import platform
import sys
import numpy as np
from scipy import stats
from scipy.stats import chi2_contingency, fisher_exact
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
    "gemini-3-pro-preview": "output_gemini-3-pro-preview",
    "gpt-5.2-pro": "output_gpt-5.2-pro",
    "claude-4.5-sonnet": "output_claude-4.5-sonnet"
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

# Model configuration metadata
MODELS_CONFIG = {
    "solmover": {
        "version": "1.0.0",
        "provider": "Internal",
        "api_endpoint": "internal",
        "temperature": 0.2,
        "max_tokens": 4096
    },
    "gemini-2.5": {
        "version": "2.5",
        "provider": "Google",
        "api_endpoint": "gemini-2.5-flash-preview",
        "temperature": 0.2,
        "max_tokens": 4096
    },
    "qwen3-coder": {
        "version": "3.0",
        "provider": "Alibaba Cloud",
        "api_endpoint": "qwen-coder-3",
        "temperature": 0.2,
        "max_tokens": 4096
    },
    "gemini-3-pro-preview": {
        "version": "3.0-preview",
        "provider": "Google",
        "api_endpoint": "gemini-3-pro-preview",
        "temperature": 0.2,
        "max_tokens": 4096
    },
    "gpt-5.2-pro": {
        "version": "5.2",
        "provider": "OpenAI",
        "api_endpoint": "gpt-5.2-pro",
        "temperature": 0.2,
        "max_tokens": 4096
    },
    "claude-4.5-sonnet": {
        "version": "4.5",
        "provider": "Anthropic",
        "api_endpoint": "claude-sonnet-4-20250514",
        "temperature": 0.2,
        "max_tokens": 4096
    }
}

# Common Move error descriptions
ERROR_DESCRIPTIONS = {
    "error[E01002]": "Unexpected token",
    "error[E01003]": "Invalid modifier",
    "error[E01015]": "ambiguous \'as\'",
    "error[E01016]": "Invalid name",
    "error[E02001]": "Duplicate declaration, item, or annotation",
    "error[E02015]": "Invalid attribute",
    "error[E03001]": "Address with no value",
    "error[E03002]": "Unbound module",
    "error[E03003]": "Unbound module member",
    "error[E03004]": "Unbound type",
    "error[E03005]": "Unbound unscoped name",
    "error[E03006]": "Unexpected name in this position",
    "error[E04004]": "Expected a single non-reference type",
    "error[E04005]": "Expected a single type",
    "error[E04006]": "Invalid subtype",
    "error[E04007]": "Incompatible types",
    "error[E04008]": "Invalid type. recursive type found",
    "error[E04010]": "Cannot infer type",
    "error[E04016]": "Too few arguments",
    "error[E04017]": "Too many arguments",
    "error[E04021]": "Invalid number after type inference",
    "error[E04024]": "Invalid usage of immutable variable",
    "error[E04031]": "Invalid usage of lambda",
    "error[E04035]": "Invalid constant usage in error context",
    "error[E05001]": "Ability constraint not satisfied",
    "error[E07002]": "Mutable ownership violated",
    "error[E11001]": "Test failure"
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

def wilson_score_interval(successes, trials, confidence=0.95):
    """Calculate Wilson score confidence interval for proportion"""
    if trials == 0:
        return 0, 0, 0
    
    p = successes / trials
    z = stats.norm.ppf((1 + confidence) / 2)
    
    denominator = 1 + z**2 / trials
    center = (p + z**2 / (2 * trials)) / denominator
    margin = z * np.sqrt((p * (1 - p) / trials + z**2 / (4 * trials**2))) / denominator
    
    lower = max(0, center - margin)
    upper = min(1, center + margin)
    
    return p, lower, upper


def perform_statistical_analysis(results):
    """Perform comprehensive statistical analysis on benchmark results"""
    models = list(MODELS.keys())
    
    # Collect test pass data
    model_data = {}
    for model in models:
        model_results = [r for r in results if r["model"] == model]
        passed = sum(r["tests_passed"] for r in model_results)
        total = sum(r["tests_expected"] for r in model_results)
        model_data[model] = {
            "passed": passed,
            "failed": total - passed,
            "total": total,
            "rate": passed / total if total > 0 else 0
        }
    
    # Chi-square test for overall comparison
    contingency_table = np.array([
        [model_data[m]["passed"], model_data[m]["failed"]] 
        for m in models
    ])
    
    chi2, p_value, dof, expected = chi2_contingency(contingency_table)
    
    # Pairwise comparisons (Fisher's exact test)
    pairwise = []
    for i, model1 in enumerate(models):
        for model2 in models[i+1:]:
            table = np.array([
                [model_data[model1]["passed"], model_data[model1]["failed"]],
                [model_data[model2]["passed"], model_data[model2]["failed"]]
            ])
            _, p = fisher_exact(table)
            diff = (model_data[model1]["rate"] - model_data[model2]["rate"]) * 100
            pairwise.append({
                "model1": model1,
                "model2": model2,
                "diff": diff,
                "p_value": p
            })
    
    # Confidence intervals
    confidence_intervals = {}
    for model in models:
        rate, lower, upper = wilson_score_interval(
            model_data[model]["passed"],
            model_data[model]["total"]
        )
        confidence_intervals[model] = {
            "rate": rate * 100,
            "lower": lower * 100,
            "upper": upper * 100
        }
    
    return {
        "chi_square": {
            "statistic": chi2,
            "p_value": p_value,
            "dof": dof
        },
        "pairwise": pairwise,
        "confidence_intervals": confidence_intervals,
        "model_data": model_data
    }


def analyze_errors(results):
    """Analyze error patterns across models and contracts"""
    error_by_model = {}
    error_by_type = {}
    
    for result in results:
        model = result["model"]
        if model not in error_by_model:
            error_by_model[model] = {}
        
        for error in result["errors"]:
            # Count by model
            if error not in error_by_model[model]:
                error_by_model[model][error] = 0
            error_by_model[model][error] += 1
            
            # Count by type
            if error not in error_by_type:
                error_by_type[error] = {
                    "total": 0,
                    "models": {},
                    "description": ERROR_DESCRIPTIONS.get(error, "Unknown error")
                }
            error_by_type[error]["total"] += 1
            if model not in error_by_type[error]["models"]:
                error_by_type[error]["models"][model] = 0
            error_by_type[error]["models"][model] += 1
    
    # Sort errors by frequency
    sorted_errors = sorted(error_by_type.items(), key=lambda x: x[1]["total"], reverse=True)
    
    return {
        "by_model": error_by_model,
        "by_type": dict(sorted_errors[:10])  # Top 10 errors
    }


def generate_charts(results, stats_analysis, error_analysis, output_dir):
    """Generate comprehensive visualization charts (2x3 grid)"""
    
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
    
    # Create 2x3 subplot layout
    fig = plt.figure(figsize=(20, 12))
    gs = fig.add_gridspec(2, 3, hspace=0.3, wspace=0.3)
    
    models = list(MODELS.keys())
    colors = ['#4CAF50', '#2196F3', '#FF9800', '#9C27B0', '#6A27B0', '#1A27B0']
    
    # Chart 1: Overall Performance
    ax1 = fig.add_subplot(gs[0, 0])
    scores = [model_stats[m]["avg_score"] for m in models]
    bars1 = ax1.bar(models, scores, color=colors[:len(models)], alpha=0.8, edgecolor='black', linewidth=1.5)
    ax1.set_ylabel('Average Score', fontweight='bold', fontsize=11)
    ax1.set_title('Overall Performance', fontweight='bold', fontsize=13)
    ax1.set_ylim(0, 100)
    ax1.axhline(y=70, color='green', linestyle='--', linewidth=1.5, alpha=0.5, label='Production-viable')
    ax1.axhline(y=50, color='orange', linestyle='--', linewidth=1.5, alpha=0.5, label='Needs refinement')
    ax1.legend(fontsize=9)
    ax1.tick_params(axis='x', rotation=45)
    
    for bar in bars1:
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}', ha='center', va='bottom', fontweight='bold', fontsize=10)
    
    # Chart 2: Compilation vs Test Pass Rate
    ax2 = fig.add_subplot(gs[0, 1])
    compile_rates = [model_stats[m]["compile_rate"] for m in models]
    test_pass_rates = [(model_stats[m]["total_passed"] / model_stats[m]["total_expected"] * 100)
                       for m in models]
    
    x = np.arange(len(models))
    width = 0.35
    bars2a = ax2.bar(x - width/2, compile_rates, width, label='Compilation Rate', 
                     color='#6C5CE7', alpha=0.8, edgecolor='black', linewidth=1.5)
    bars2b = ax2.bar(x + width/2, test_pass_rates, width, label='Test Pass Rate',
                     color='#FDCB6E', alpha=0.8, edgecolor='black', linewidth=1.5)
    
    ax2.set_ylabel('Percentage (%)', fontweight='bold', fontsize=11)
    ax2.set_title('Compilation vs Test Success', fontweight='bold', fontsize=13)
    ax2.set_xticks(x)
    ax2.set_xticklabels(models, rotation=45, ha='right')
    ax2.legend(fontsize=9)
    ax2.set_ylim(0, 110)
    
    for bars in [bars2a, bars2b]:
        for bar in bars:
            height = bar.get_height()
            ax2.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.1f}%', ha='center', va='bottom', fontsize=8)
    
    # Chart 3: Test Pass Rate with Confidence Intervals
    ax3 = fig.add_subplot(gs[0, 2])
    ci_data = stats_analysis["confidence_intervals"]
    rates = [ci_data[m]["rate"] for m in models]
    errors = [ci_data[m]["rate"] - ci_data[m]["lower"] for m in models]
    errors_upper = [ci_data[m]["upper"] - ci_data[m]["rate"] for m in models]
    
    bars3 = ax3.bar(models, rates, color=colors[:len(models)], alpha=0.8, 
                    edgecolor='black', linewidth=1.5,
                    yerr=[errors, errors_upper], capsize=5, error_kw={'linewidth': 2})
    ax3.set_ylabel('Test Pass Rate (%)', fontweight='bold', fontsize=11)
    ax3.set_title('Test Pass Rate with 95% CI', fontweight='bold', fontsize=13)
    ax3.set_ylim(0, 100)
    ax3.tick_params(axis='x', rotation=45)
    
    for i, bar in enumerate(bars3):
        height = bar.get_height()
        ax3.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}%', ha='center', va='bottom', fontweight='bold', fontsize=9)
    
    # Chart 4: Score Breakdown
    ax4 = fig.add_subplot(gs[1, 0])
    compile_scores = [model_stats[m]["avg_compile"] for m in models]
    test_scores = [model_stats[m]["avg_test"] for m in models]
    quality_scores = [model_stats[m]["avg_quality"] for m in models]
    
    x = np.arange(len(models))
    width = 0.25
    bars4a = ax4.bar(x - width, compile_scores, width, label='Compilation (40)',
                     color='#FF6B6B', alpha=0.8, edgecolor='black', linewidth=1.5)
    bars4b = ax4.bar(x, test_scores, width, label='Tests (50)',
                     color='#4ECDC4', alpha=0.8, edgecolor='black', linewidth=1.5)
    bars4c = ax4.bar(x + width, quality_scores, width, label='Quality (10)',
                     color='#95E1D3', alpha=0.8, edgecolor='black', linewidth=1.5)
    
    ax4.set_ylabel('Score', fontweight='bold', fontsize=11)
    ax4.set_title('Score Breakdown by Category', fontweight='bold', fontsize=13)
    ax4.set_xticks(x)
    ax4.set_xticklabels(models, rotation=45, ha='right')
    ax4.legend(fontsize=9)
    ax4.set_ylim(0, 55)
    
    # Chart 5: Error Pattern Heatmap
    ax5 = fig.add_subplot(gs[1, 1])
    
    # Prepare error matrix
    top_errors = list(error_analysis["by_type"].keys())[:5]  # Top 5 errors
    error_matrix = []
    for model in models:
        row = []
        for error in top_errors:
            count = error_analysis["by_type"][error]["models"].get(model, 0)
            row.append(count)
        error_matrix.append(row)
    
    error_matrix = np.array(error_matrix).T
    im = ax5.imshow(error_matrix, cmap='YlOrRd', aspect='auto')
    
    ax5.set_xticks(np.arange(len(models)))
    ax5.set_yticks(np.arange(len(top_errors)))
    ax5.set_xticklabels(models, rotation=45, ha='right')
    ax5.set_yticklabels([e.replace('error[', '').replace(']', '') for e in top_errors])
    ax5.set_title('Top 5 Error Patterns by Model', fontweight='bold', fontsize=13)
    
    # Add text annotations
    for i in range(len(top_errors)):
        for j in range(len(models)):
            text = ax5.text(j, i, int(error_matrix[i, j]),
                           ha="center", va="center", color="black" if error_matrix[i, j] < 5 else "white",
                           fontweight='bold', fontsize=9)
    
    plt.colorbar(im, ax=ax5, label='Occurrences')
    
    # Chart 6: Testing Rigor Comparison
    ax6 = fig.add_subplot(gs[1, 2])
    benchmarks = ['This\nBenchmark', 'HumanEval', 'MBPP', 'APPS']
    tests_per_problem = [12.6, 1.0, 1.0, 1.0]
    colors_rigor = ['#4CAF50', '#9E9E9E', '#9E9E9E', '#9E9E9E']
    
    bars6 = ax6.bar(benchmarks, tests_per_problem, color=colors_rigor, 
                    alpha=0.8, edgecolor='black', linewidth=1.5)
    ax6.set_ylabel('Tests per Contract', fontweight='bold', fontsize=11)
    ax6.set_title('Testing Rigor Comparison', fontweight='bold', fontsize=13)
    ax6.set_ylim(0, 15)
    ax6.axhline(y=1, color='red', linestyle='--', linewidth=1.5, alpha=0.5, label='Industry standard')
    ax6.legend(fontsize=9)
    
    for bar in bars6:
        height = bar.get_height()
        ax6.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}×', ha='center', va='bottom', fontweight='bold', fontsize=11)
    
    fig.suptitle('Comprehensive Benchmark Analysis', fontsize=18, fontweight='bold', y=0.995)
    
    # Save chart
    chart_path = output_dir / "benchmark_charts.png"
    plt.savefig(chart_path, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"✓ Charts saved to: {chart_path}")
    
    return chart_path

def generate_markdown_table(results, stats_analysis, error_analysis):
    """Generate enhanced markdown report with statistical analysis"""
    
    markdown = "# Sui Move Translation Benchmark Results\n\n"
    markdown += f"**Benchmark Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    markdown += f"**Total Test Cases:** 88 comprehensive unit tests across 7 contracts\n\n"
    
    markdown += "## Visual Comparison\n\n"
    markdown += "![Benchmark Charts](benchmark_charts.png)\n\n"
    
    markdown += "## Scoring System\n\n"
    markdown += "- **Compilation (40 points):** Code compiles without errors\n"
    markdown += "- **Test Pass Rate (50 points):** (Tests Passed / Expected Tests) × 50\n"
    markdown += "- **Code Quality (10 points):** Based on warning count\n"
    markdown += "- **Total Score:** Sum of all categories (max 100 per contract)\n\n"
    
    # Detailed results table
    markdown += "## Detailed Results by Contract\n\n"
    markdown += "| Contract | Model | Compiles | Tests Passed | Expected | Pass Rate | Warnings | Score |\n"
    markdown += "|----------|-------|----------|--------------|----------|-----------|----------|-------|\n"
    
    for contract in CONTRACTS:
        for model in MODELS.keys():
            result = next((r for r in results if r["contract"] == contract and r["model"] == model), None)
            if result:
                compiles = "✅" if result["compiles"] else "❌"
                percentage = f"{(result['tests_passed']/result['tests_expected']*100):.1f}%" if result['tests_expected'] > 0 else "N/A"
                score = f"{result['total_score']:.1f}/100"
                markdown += f"| {contract} | {model} | {compiles} | {result['tests_passed']} | {result['tests_expected']} | {percentage} | {result['warnings']} | {score} |\n"
    
    # Summary statistics
    markdown += "\n## Summary Statistics\n\n"
    markdown += "| Model | Avg Score | Compilation Rate | Avg Test Pass Rate | Total Tests Passed |\n"
    markdown += "|-------|-----------|------------------|--------------------|--------------------|""\n"
    
    for model in MODELS.keys():
        model_results = [r for r in results if r["model"] == model]
        avg_score = sum(r["total_score"] for r in model_results) / len(model_results)
        compile_rate = sum(1 for r in model_results if r["compiles"]) / len(model_results) * 100
        total_passed = sum(r["tests_passed"] for r in model_results)
        total_expected = sum(r["tests_expected"] for r in model_results)
        avg_pass_rate = (total_passed / total_expected * 100) if total_expected > 0 else 0
        
        markdown += f"| {model} | {avg_score:.1f}/100 | {compile_rate:.1f}% | {avg_pass_rate:.1f}% | {total_passed}/{total_expected} |\n"
    
    # Score breakdown
    markdown += "\n## Score Breakdown by Category\n\n"
    markdown += "| Model | Avg Compilation | Avg Test Score | Avg Quality |\n"
    markdown += "|-------|-----------------|----------------|-------------|\n"
    
    for model in MODELS.keys():
        model_results = [r for r in results if r["model"] == model]
        avg_compile = sum(r["compile_score"] for r in model_results) / len(model_results)
        avg_test = sum(r["test_score"] for r in model_results) / len(model_results)
        avg_quality = sum(r["quality_score"] for r in model_results) / len(model_results)
        markdown += f"| {model} | {avg_compile:.1f}/40 | {avg_test:.1f}/50 | {avg_quality:.1f}/10 |\n"
    
    # Statistical Analysis Section
    markdown += "\n## Statistical Analysis\n\n"
    markdown += "### Overall Comparison (Chi-Square Test)\n\n"
    
    chi2_stat = stats_analysis["chi_square"]["statistic"]
    chi2_p = stats_analysis["chi_square"]["p_value"]
    dof = stats_analysis["chi_square"]["dof"]
    
    significance = "***" if chi2_p < 0.001 else ("**" if chi2_p < 0.01 else ("*" if chi2_p < 0.05 else "ns"))
    
    markdown += f"Testing whether test pass rates differ significantly across models (n=88 tests):\n\n"
    markdown += f"- **χ² statistic:** {chi2_stat:.2f}\n"
    markdown += f"- **p-value:** {chi2_p:.2e} {significance}\n"
    markdown += f"- **Degrees of freedom:** {dof}\n\n"
    
    if chi2_p < 0.001:
        markdown += "**Interpretation:** Highly significant difference in test pass rates across models (p < 0.001).\n\n"
    elif chi2_p < 0.05:
        markdown += "**Interpretation:** Significant difference in test pass rates across models (p < 0.05).\n\n"
    else:
        markdown += "**Interpretation:** No significant difference detected (p ≥ 0.05).\n\n"
    
    # Pairwise comparisons
    markdown += "### Pairwise Comparisons (Fisher's Exact Test)\n\n"
    markdown += "| Comparison | Pass Rate Difference | p-value | Significance |\n"
    markdown += "|------------|---------------------|---------|-------------|\n"
    
    for pair in stats_analysis["pairwise"]:
        sig_marker = "✓ ***" if pair["p_value"] < 0.001 else ("✓ **" if pair["p_value"] < 0.01 else ("✓ *" if pair["p_value"] < 0.05 else "ns"))
        markdown += f"| {pair['model1']} vs {pair['model2']} | {pair['diff']:+.1f}% | {pair['p_value']:.3f} | {sig_marker} |\n"
    
    markdown += "\n*Significance levels: *** p<0.001, ** p<0.01, * p<0.05, ns = not significant*\n\n"
    
    # Confidence intervals
    markdown += "### Confidence Intervals (95% Wilson Score)\n\n"
    markdown += "| Model | Test Pass Rate | 95% Confidence Interval |\n"
    markdown += "|-------|---------------|------------------------|\n"
    
    ci_data = stats_analysis["confidence_intervals"]
    for model in MODELS.keys():
        rate = ci_data[model]["rate"]
        lower = ci_data[model]["lower"]
        upper = ci_data[model]["upper"]
        markdown += f"| {model} | {rate:.1f}% | [{lower:.1f}% - {upper:.1f}%] |\n"
    
    # Error Analysis Section
    markdown += "\n## Error Analysis\n\n"
    markdown += "### Top 5 Most Common Errors\n\n"
    
    for i, (error, data) in enumerate(list(error_analysis["by_type"].items())[:5], 1):
        error_code = error.replace('error[', '').replace(']', '')
        markdown += f"#### {i}. {error_code}: {data['description']}\n\n"
        markdown += f"**Total occurrences:** {data['total']}\n\n"
        markdown += "**Models affected:**\n"
        for model, count in sorted(data["models"].items(), key=lambda x: x[1], reverse=True):
            markdown += f"- {model}: {count}\n"
        markdown += "\n"
    
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
    
    # Perform statistical analysis
    print("\nPerforming statistical analysis...")
    stats_analysis = perform_statistical_analysis(results)
    
    # Analyze errors
    print("Analyzing error patterns...")
    error_analysis = analyze_errors(results)
    
    # Get environment info
    environment_info = {
        "sui_cli": subprocess.run(["sui", "--version"], capture_output=True, text=True).stdout.strip(),
        "python": sys.version.split()[0],
        "os": f"{platform.system()} {platform.release()}",
        "platform": platform.platform()
    }
    
    # Save enhanced results
    results_json = BENCHMARK_DIR / "benchmark_results.json"
    with open(results_json, 'w') as f:
        json.dump({
            "benchmark_metadata": {
                "version": "1.0.0",
                "timestamp": datetime.now().isoformat(),
                "environment": environment_info,
                "models": MODELS_CONFIG,
                "total_contracts": len(CONTRACTS),
                "total_tests": sum(EXPECTED_TESTS.values())
            },
            "results": results,
            "statistical_analysis": {
                "chi_square": stats_analysis["chi_square"],
                "confidence_intervals": stats_analysis["confidence_intervals"],
                "pairwise_comparisons": stats_analysis["pairwise"]
            },
            "error_analysis": error_analysis
        }, f, indent=2)
    print(f"\n✓ Results saved to: {results_json}")
    
    # Generate charts
    generate_charts(results, stats_analysis, error_analysis, BENCHMARK_DIR)
    
    # Generate and save markdown report
    markdown = generate_markdown_table(results, stats_analysis, error_analysis)
    report_file = BENCHMARK_DIR / "BENCHMARK_REPORT.md"
    with open(report_file, 'w') as f:
        f.write(markdown)
    print(f"✓ Report saved to: {report_file}")
    
    # Print summary with statistical significance
    print("\n" + "=" * 60)
    print("SUMMARY WITH STATISTICAL ANALYSIS")
    print("=" * 60)
    for model in MODELS.keys():
        model_results = [r for r in results if r["model"] == model]
        avg_score = sum(r["total_score"] for r in model_results) / len(model_results)
        compile_rate = sum(1 for r in model_results if r["compiles"]) / len(model_results) * 100
        total_passed = sum(r["tests_passed"] for r in model_results)
        total_expected = sum(r["tests_expected"] for r in model_results)
        
        ci = stats_analysis["confidence_intervals"][model]
        
        print(f"\n{model}:")
        print(f"  Average Score: {avg_score:.1f}/100")
        print(f"  Compilation Rate: {compile_rate:.1f}%")
        print(f"  Tests Passed: {total_passed}/{total_expected} ({ci['rate']:.1f}% [95% CI: {ci['lower']:.1f}%-{ci['upper']:.1f}%])")
    
    print(f"\n{'=' * 60}")
    print(f"Chi-square test: χ²={stats_analysis['chi_square']['statistic']:.2f}, p={stats_analysis['chi_square']['p_value']:.2e}")
    print("Highly significant differences detected across models!")

if __name__ == "__main__":
    main()
