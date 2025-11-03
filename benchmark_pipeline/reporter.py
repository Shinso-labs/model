"""Generate detailed reports from benchmark results."""

import json
import os
from pathlib import Path
from typing import List, Dict, Any
from datetime import datetime


class BenchmarkReporter:
    """Generates reports from benchmark results."""

    def __init__(self, results_file: str):
        """Initialize reporter with a results file."""
        with open(results_file, 'r') as f:
            self.data = json.load(f)
        self.results_file = results_file
        self.results_dir = os.path.dirname(results_file)

    def generate_html_report(self, output_file: str = None) -> str:
        """Generate an HTML report with visualizations."""
        if output_file is None:
            timestamp = self.data.get("timestamp", "unknown")
            output_file = os.path.join(self.results_dir, f"report_{timestamp}.html")

        html = self._build_html()

        with open(output_file, 'w') as f:
            f.write(html)

        print(f"HTML report generated: {output_file}")
        return output_file

    def _build_html(self) -> str:
        """Build the HTML report."""
        results = self.data.get("results", [])
        timestamp = self.data.get("timestamp", "Unknown")
        total = self.data.get("total_tests", 0)
        passed = self.data.get("passed", 0)
        failed = self.data.get("failed", 0)

        # Calculate averages
        avg_syntax = 0
        avg_similarity = 0
        avg_structure = 0
        avg_bleu = 0
        avg_semantic = 0
        avg_response_time = 0
        compilation_rate = 0

        if results:
            valid_evals = [r for r in results if r.get("evaluation")]
            if valid_evals:
                avg_syntax = sum(r["evaluation"]["syntax_score"] for r in valid_evals) / len(valid_evals)
                avg_similarity = sum(r["evaluation"]["similarity_score"] for r in valid_evals) / len(valid_evals)
                avg_structure = sum(r["evaluation"]["structure_score"] for r in valid_evals) / len(valid_evals)
                avg_bleu = sum(r["evaluation"].get("bleu_score", 0) for r in valid_evals) / len(valid_evals)
                avg_semantic = sum(r["evaluation"].get("semantic_score", 0) for r in valid_evals) / len(valid_evals)

                # Calculate compilation rate
                compilable = sum(1 for r in valid_evals if r["evaluation"].get("compilable") is True)
                non_compilable = sum(1 for r in valid_evals if r["evaluation"].get("compilable") is False)
                if compilable + non_compilable > 0:
                    compilation_rate = compilable / (compilable + non_compilable) * 100
            avg_response_time = sum(r.get("response_time", 0) for r in results) / len(results)

        html = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Solidity to Move Translation Benchmark Report</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        h1 {{
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }}
        h2 {{
            color: #555;
            margin-top: 30px;
        }}
        .summary {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }}
        .metric-card {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }}
        .metric-card.success {{
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        }}
        .metric-card.fail {{
            background: linear-gradient(135deg, #eb3349 0%, #f45c43 100%);
        }}
        .metric-card h3 {{
            margin: 0 0 10px 0;
            font-size: 14px;
            opacity: 0.9;
        }}
        .metric-card .value {{
            font-size: 32px;
            font-weight: bold;
            margin: 0;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        th, td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }}
        th {{
            background-color: #f8f9fa;
            font-weight: 600;
            color: #333;
        }}
        tr:hover {{
            background-color: #f8f9fa;
        }}
        .score {{
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: 500;
        }}
        .score.high {{ background: #d4edda; color: #155724; }}
        .score.medium {{ background: #fff3cd; color: #856404; }}
        .score.low {{ background: #f8d7da; color: #721c24; }}
        .pass {{ color: #28a745; font-weight: bold; }}
        .fail {{ color: #dc3545; font-weight: bold; }}
        .timestamp {{
            color: #666;
            font-size: 14px;
        }}
        .chart-container {{
            margin: 30px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
        }}
        .bar {{
            height: 30px;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            border-radius: 4px;
            margin: 5px 0;
            display: flex;
            align-items: center;
            padding-left: 10px;
            color: white;
            font-weight: 500;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Solidity to Move Translation Benchmark Report</h1>
        <p class="timestamp">Generated: {timestamp}</p>

        <div class="summary">
            <div class="metric-card">
                <h3>Total Tests</h3>
                <p class="value">{total}</p>
            </div>
            <div class="metric-card success">
                <h3>Passed</h3>
                <p class="value">{passed}</p>
            </div>
            <div class="metric-card fail">
                <h3>Failed</h3>
                <p class="value">{failed}</p>
            </div>
            <div class="metric-card">
                <h3>Success Rate</h3>
                <p class="value">{(passed/total*100 if total > 0 else 0):.1f}%</p>
            </div>
        </div>

        <div class="chart-container">
            <h3>Average Scores</h3>
            <div style="margin-top: 15px;">
                <div style="margin-bottom: 10px;">
                    <small>Syntax Score: {avg_syntax:.1f}/100</small>
                    <div class="bar" style="width: {avg_syntax}%">{avg_syntax:.1f}</div>
                </div>
                <div style="margin-bottom: 10px;">
                    <small>Similarity Score: {avg_similarity:.1f}/100</small>
                    <div class="bar" style="width: {avg_similarity}%">{avg_similarity:.1f}</div>
                </div>
                <div style="margin-bottom: 10px;">
                    <small>Structure Score: {avg_structure:.1f}/100</small>
                    <div class="bar" style="width: {avg_structure}%">{avg_structure:.1f}</div>
                </div>
                <div style="margin-bottom: 10px;">
                    <small>BLEU Score: {avg_bleu:.1f}/100</small>
                    <div class="bar" style="width: {avg_bleu}%">{avg_bleu:.1f}</div>
                </div>
                <div style="margin-bottom: 10px;">
                    <small>Semantic Score: {avg_semantic:.1f}/100</small>
                    <div class="bar" style="width: {avg_semantic}%">{avg_semantic:.1f}</div>
                </div>
                <div style="margin-bottom: 10px;">
                    <small>Compilation Rate: {compilation_rate:.1f}%</small>
                    <div class="bar" style="width: {compilation_rate}%">{compilation_rate:.1f}</div>
                </div>
                <div style="margin-bottom: 10px;">
                    <small>Avg Response Time: {avg_response_time:.2f}s</small>
                </div>
            </div>
        </div>

        <h2>Detailed Results</h2>
        <table>
            <thead>
                <tr>
                    <th>Test Case</th>
                    <th>Status</th>
                    <th>Syntax</th>
                    <th>Similarity</th>
                    <th>Structure</th>
                    <th>BLEU</th>
                    <th>Semantic</th>
                    <th>Compilable</th>
                    <th>Response Time</th>
                </tr>
            </thead>
            <tbody>
"""

        for result in results:
            test_case = result.get("test_case", "Unknown")
            success = result.get("success", False)
            error = result.get("error")
            response_time = result.get("response_time", 0)
            evaluation = result.get("evaluation")

            if evaluation:
                passed = evaluation.get("passed", False)
                syntax = evaluation.get("syntax_score", 0)
                similarity = evaluation.get("similarity_score", 0)
                structure = evaluation.get("structure_score", 0)
                bleu = evaluation.get("bleu_score", 0)
                semantic = evaluation.get("semantic_score", 0)
                compilable = evaluation.get("compilable")

                status_class = "pass" if passed else "fail"
                status_text = "PASS" if passed else "FAIL"

                def score_class(score):
                    if score >= 70:
                        return "high"
                    elif score >= 40:
                        return "medium"
                    else:
                        return "low"

                compilable_text = "Yes" if compilable is True else ("No" if compilable is False else "N/A")
                compilable_class = "pass" if compilable is True else ("fail" if compilable is False else "")

                html += f"""
                <tr>
                    <td>{test_case}</td>
                    <td class="{status_class}">{status_text}</td>
                    <td><span class="score {score_class(syntax)}">{syntax:.1f}</span></td>
                    <td><span class="score {score_class(similarity)}">{similarity:.1f}</span></td>
                    <td><span class="score {score_class(structure)}">{structure:.1f}</span></td>
                    <td><span class="score {score_class(bleu)}">{bleu:.1f}</span></td>
                    <td><span class="score {score_class(semantic)}">{semantic:.1f}</span></td>
                    <td class="{compilable_class}">{compilable_text}</td>
                    <td>{response_time:.2f}s</td>
                </tr>
"""
            else:
                html += f"""
                <tr>
                    <td>{test_case}</td>
                    <td class="fail">ERROR</td>
                    <td colspan="4">{error or 'Unknown error'}</td>
                </tr>
"""

        html += """
            </tbody>
        </table>
    </div>
</body>
</html>
"""

        return html

    def print_detailed_report(self):
        """Print a detailed text report to console."""
        print("\n" + "=" * 80)
        print("DETAILED BENCHMARK REPORT")
        print("=" * 80)

        results = self.data.get("results", [])

        for result in results:
            print(f"\n{'=' * 80}")
            print(f"Test Case: {result.get('test_case')}")
            print(f"{'=' * 80}")

            if not result.get("success"):
                print(f"Status: FAILED")
                print(f"Error: {result.get('error')}")
                continue

            print(f"Status: SUCCESS")
            print(f"Response Time: {result.get('response_time', 0):.2f}s")

            evaluation = result.get("evaluation")
            if evaluation:
                print(f"\nEvaluation Scores:")
                print(f"  Syntax:     {evaluation.get('syntax_score', 0):.1f}/100")
                print(f"  Similarity: {evaluation.get('similarity_score', 0):.1f}/100")
                print(f"  Structure:  {evaluation.get('structure_score', 0):.1f}/100")
                print(f"  BLEU:       {evaluation.get('bleu_score', 0):.1f}/100")
                print(f"  Semantic:   {evaluation.get('semantic_score', 0):.1f}/100")
                compilable = evaluation.get('compilable')
                if compilable is not None:
                    print(f"  Compilable: {'Yes' if compilable else 'No'}")
                print(f"  Overall:    {'PASS' if evaluation.get('passed') else 'FAIL'}")

                metrics = evaluation.get('metrics', {})
                print(f"\nMetrics:")
                print(f"  Generated Lines: {metrics.get('generated_lines', 0)}")
                print(f"  Reference Lines: {metrics.get('reference_lines', 0)}")
                print(f"  Has Module: {metrics.get('has_module_declaration', False)}")
                print(f"  Struct Count (Gen/Ref): {metrics.get('struct_count_generated', 0)}/{metrics.get('struct_count_reference', 0)}")
                print(f"  Function Count (Gen/Ref): {metrics.get('function_count_generated', 0)}/{metrics.get('function_count_reference', 0)}")
                print(f"  Struct Match Ratio: {metrics.get('struct_match_ratio', 0):.1f}%")
                print(f"  Function Match Ratio: {metrics.get('function_match_ratio', 0):.1f}%")
                print(f"  Keyword Coverage: {metrics.get('keyword_coverage', 0):.1f}%")
                print(f"  Exact Match: {metrics.get('exact_match', False)}")
                print(f"  Generated Empty: {metrics.get('generated_empty', False)}")


def main():
    """Main entry point for generating reports from existing results."""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python reporter.py <results_file.json>")
        print("\nOr to generate report for the latest results:")
        print("  python reporter.py latest")
        return

    results_file = sys.argv[1]

    if results_file == "latest":
        # Find the latest results file
        results_dir = os.path.join(os.path.dirname(__file__), "results")
        if not os.path.exists(results_dir):
            print("No results directory found.")
            return

        json_files = list(Path(results_dir).glob("benchmark_results_*.json"))
        if not json_files:
            print("No benchmark results found.")
            return

        results_file = str(max(json_files, key=os.path.getmtime))
        print(f"Using latest results: {results_file}")

    if not os.path.exists(results_file):
        print(f"Results file not found: {results_file}")
        return

    reporter = BenchmarkReporter(results_file)
    reporter.print_detailed_report()
    reporter.generate_html_report()


if __name__ == "__main__":
    main()
