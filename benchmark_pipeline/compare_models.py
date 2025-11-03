"""Compare multiple benchmark results for model evaluation."""

import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Any
from datetime import datetime


class ModelComparator:
    """Compare multiple benchmark runs for model evaluation."""

    def __init__(self, results_dir: str = "results"):
        self.results_dir = results_dir

    def load_result_file(self, filepath: str) -> Dict[str, Any]:
        """Load a single benchmark result file."""
        with open(filepath, 'r') as f:
            return json.load(f)

    def calculate_summary_stats(self, results_data: Dict[str, Any]) -> Dict[str, float]:
        """Calculate summary statistics from a result file."""
        results = results_data.get("results", [])

        if not results:
            return {}

        valid_evals = [r["evaluation"] for r in results if r.get("evaluation")]

        if not valid_evals:
            return {}

        stats = {
            "total_tests": results_data.get("total_tests", 0),
            "passed": results_data.get("passed", 0),
            "failed": results_data.get("failed", 0),
            "pass_rate": results_data.get("passed", 0) / max(results_data.get("total_tests", 1), 1) * 100,
            "avg_syntax": sum(e["syntax_score"] for e in valid_evals) / len(valid_evals),
            "avg_similarity": sum(e["similarity_score"] for e in valid_evals) / len(valid_evals),
            "avg_structure": sum(e["structure_score"] for e in valid_evals) / len(valid_evals),
            "avg_bleu": sum(e.get("bleu_score", 0) for e in valid_evals) / len(valid_evals),
            "avg_semantic": sum(e.get("semantic_score", 0) for e in valid_evals) / len(valid_evals),
            "avg_response_time": sum(r.get("response_time", 0) for r in results) / len(results),
        }

        # Calculate compilation rate
        compilable = sum(1 for e in valid_evals if e.get("compilable") is True)
        non_compilable = sum(1 for e in valid_evals if e.get("compilable") is False)
        if compilable + non_compilable > 0:
            stats["compilation_rate"] = compilable / (compilable + non_compilable) * 100
        else:
            stats["compilation_rate"] = None

        # Calculate empty response rate
        empty_count = sum(1 for e in valid_evals if e.get("metrics", {}).get("generated_empty", False))
        stats["empty_response_rate"] = empty_count / len(valid_evals) * 100

        return stats

    def compare_results(self, result_files: List[str], labels: List[str] = None) -> str:
        """
        Compare multiple result files and generate a comparison report.

        Args:
            result_files: List of paths to result JSON files
            labels: Optional labels for each result file

        Returns:
            Formatted comparison report as string
        """
        if labels is None:
            labels = [f"Model {i+1}" for i in range(len(result_files))]

        if len(labels) != len(result_files):
            raise ValueError("Number of labels must match number of result files")

        # Load all results
        all_stats = []
        for filepath, label in zip(result_files, labels):
            data = self.load_result_file(filepath)
            stats = self.calculate_summary_stats(data)
            stats["label"] = label
            stats["timestamp"] = data.get("timestamp", "unknown")
            all_stats.append(stats)

        # Generate comparison report
        report = self._generate_comparison_report(all_stats)
        return report

    def _generate_comparison_report(self, all_stats: List[Dict[str, Any]]) -> str:
        """Generate a formatted comparison report."""
        lines = []
        lines.append("=" * 80)
        lines.append("MODEL COMPARISON REPORT")
        lines.append("=" * 80)
        lines.append("")

        # Summary table
        lines.append("SUMMARY")
        lines.append("-" * 80)
        header = f"{'Metric':<25}" + "".join(f"{s['label']:<20}" for s in all_stats)
        lines.append(header)
        lines.append("-" * 80)

        metrics = [
            ("Total Tests", "total_tests", "d"),
            ("Passed", "passed", "d"),
            ("Pass Rate", "pass_rate", ".1f", "%"),
            ("Avg Syntax Score", "avg_syntax", ".1f", "/100"),
            ("Avg BLEU Score", "avg_bleu", ".1f", "/100"),
            ("Avg Similarity", "avg_similarity", ".1f", "/100"),
            ("Avg Structure", "avg_structure", ".1f", "/100"),
            ("Avg Semantic", "avg_semantic", ".1f", "/100"),
            ("Compilation Rate", "compilation_rate", ".1f", "%"),
            ("Empty Response Rate", "empty_response_rate", ".1f", "%"),
            ("Avg Response Time", "avg_response_time", ".2f", "s"),
        ]

        for metric_name, key, fmt, *suffix in metrics:
            suffix = suffix[0] if suffix else ""
            row = f"{metric_name:<25}"
            for stats in all_stats:
                value = stats.get(key)
                if value is None:
                    row += f"{'N/A':<20}"
                elif fmt == "d":
                    row += f"{int(value):<20}"
                else:
                    row += f"{value:{fmt}}{suffix:<20}"
            lines.append(row)

        lines.append("-" * 80)
        lines.append("")

        # Best performer in each category
        lines.append("BEST PERFORMERS")
        lines.append("-" * 80)

        best_metrics = [
            ("Highest Pass Rate", "pass_rate", True),
            ("Best BLEU Score", "avg_bleu", True),
            ("Best Semantic Score", "avg_semantic", True),
            ("Best Compilation Rate", "compilation_rate", True),
            ("Fastest Response Time", "avg_response_time", False),
            ("Lowest Empty Response", "empty_response_rate", False),
        ]

        for metric_name, key, higher_is_better in best_metrics:
            valid_stats = [s for s in all_stats if s.get(key) is not None]
            if valid_stats:
                if higher_is_better:
                    best = max(valid_stats, key=lambda x: x[key])
                else:
                    best = min(valid_stats, key=lambda x: x[key])

                value = best[key]
                if key in ["pass_rate", "compilation_rate", "empty_response_rate"]:
                    value_str = f"{value:.1f}%"
                elif key == "avg_response_time":
                    value_str = f"{value:.2f}s"
                else:
                    value_str = f"{value:.1f}"

                lines.append(f"{metric_name:<30} {best['label']:<20} ({value_str})")

        lines.append("-" * 80)
        lines.append("")

        # Recommendations
        lines.append("RECOMMENDATIONS")
        lines.append("-" * 80)
        lines.append("")

        # Find the best overall model
        valid_with_bleu = [s for s in all_stats if s.get("avg_bleu") is not None]
        if valid_with_bleu:
            # Score based on: 30% BLEU, 30% Semantic, 20% Compilation, 20% Pass Rate
            for stats in valid_with_bleu:
                comp_rate = stats.get("compilation_rate")
                if comp_rate is None:
                    comp_rate = 0
                stats["composite_score"] = (
                    stats.get("avg_bleu", 0) * 0.3 +
                    stats.get("avg_semantic", 0) * 0.3 +
                    comp_rate * 0.2 +
                    stats.get("pass_rate", 0) * 0.2
                )

            best_overall = max(valid_with_bleu, key=lambda x: x["composite_score"])
            lines.append(f"Best Overall Model: {best_overall['label']}")
            lines.append(f"  Composite Score: {best_overall['composite_score']:.1f}/100")
            lines.append("")

        # Specific recommendations
        for stats in all_stats:
            lines.append(f"Model: {stats['label']}")

            issues = []
            if stats.get("avg_syntax", 0) < 60:
                issues.append("  - Improve syntax: Add more Move syntax patterns to training")
            if stats.get("avg_bleu", 0) < 30:
                issues.append("  - Improve BLEU: Enhance training data quality")
            if stats.get("avg_semantic", 0) < 50:
                issues.append("  - Improve semantic: Focus on function/struct mapping")
            if stats.get("compilation_rate", 0) is not None and stats.get("compilation_rate", 0) < 70:
                issues.append("  - Improve compilation: Add compilation feedback to training")
            if stats.get("empty_response_rate", 0) > 20:
                issues.append("  - Reduce empty responses: Check model output processing")
            if stats.get("pass_rate", 0) < 50:
                issues.append("  - Overall: Fundamental improvements needed across all metrics")

            if issues:
                lines.append("  Areas for Improvement:")
                lines.extend(issues)
            else:
                lines.append("  Status: Performing well across all metrics")
            lines.append("")

        lines.append("=" * 80)

        return "\n".join(lines)

    def export_to_csv(self, result_files: List[str], labels: List[str], output_file: str):
        """Export comparison to CSV format."""
        import csv

        all_stats = []
        for filepath, label in zip(result_files, labels):
            data = self.load_result_file(filepath)
            stats = self.calculate_summary_stats(data)
            stats["label"] = label
            stats["timestamp"] = data.get("timestamp", "unknown")
            all_stats.append(stats)

        with open(output_file, 'w', newline='') as f:
            if not all_stats:
                return

            # Collect all possible fields from all stats
            all_fields = set()
            for stats in all_stats:
                all_fields.update(stats.keys())

            fieldnames = ["label", "timestamp"] + sorted(all_fields - {"label", "timestamp"})
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(all_stats)

        print(f"Comparison exported to: {output_file}")


def main():
    """Main entry point for model comparison."""
    if len(sys.argv) < 2:
        print("Usage: python compare_models.py <result_file1> [result_file2] [...]")
        print("\nOr to compare all results in the results directory:")
        print("  python compare_models.py --all")
        print("\nExample:")
        print("  python compare_models.py results/benchmark_results_20251030_151444.json")
        return

    comparator = ModelComparator()

    if sys.argv[1] == "--all":
        # Find all result files
        results_dir = "results"
        result_file_paths = sorted(Path(results_dir).glob("benchmark_results_*.json"))

        if not result_file_paths:
            print(f"No benchmark results found in {results_dir}")
            return

        result_files = [str(f) for f in result_file_paths]
        labels = [f"Run {i+1} ({Path(f).stem.split('_')[-2]})" for i, f in enumerate(result_files)]
    else:
        result_files = sys.argv[1:]
        labels = [f"Model {i+1}" for i in range(len(result_files))]

    print(f"Comparing {len(result_files)} benchmark runs...\n")

    # Generate comparison report
    report = comparator.compare_results(result_files, labels)
    print(report)

    # Export to CSV
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_file = f"results/comparison_{timestamp}.csv"
    comparator.export_to_csv(result_files, labels, csv_file)


if __name__ == "__main__":
    main()
