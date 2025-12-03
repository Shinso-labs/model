"""Main benchmark runner for the Solidity to Move translation model."""

import os
import json
import time
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict

from api_client import TranslationAPIClient
from evaluator import MoveCodeEvaluator, EvaluationResult
from config import SOLIDITY_DIR, SUI_MOVE_DIR, TEST_CASES, RESULTS_DIR
from logger_config import get_logger, setup_logging, get_default_log_file

# Initialize logger for this module
logger = get_logger('benchmark_runner')


@dataclass
class BenchmarkCase:
    """A single benchmark test case."""
    name: str
    solidity_file: str
    reference_move_file: str
    solidity_code: str
    reference_move_code: str


@dataclass
class BenchmarkResult:
    """Results from running a benchmark case."""
    test_case: str
    success: bool
    error: Optional[str]
    generated_code: Optional[str]
    evaluation: Optional[EvaluationResult]
    response_time: float
    timestamp: str


class BenchmarkRunner:
    """Orchestrates the benchmark pipeline."""

    def __init__(self, stream_to_console: bool = False):
        self.api_client = TranslationAPIClient(stream_to_console=stream_to_console)
        self.evaluator = MoveCodeEvaluator()
        self.results: List[BenchmarkResult] = []

    def load_test_case(self, case_name: str) -> Optional[BenchmarkCase]:
        """Load a single test case from the benchmark directory."""
        try:
            logger.debug(f"Loading test case: {case_name}")

            # Find Solidity file
            sol_dir = Path(SOLIDITY_DIR) / case_name
            sol_files = list(sol_dir.glob("*.sol"))
            if not sol_files:
                logger.warning(f"No Solidity file found for {case_name} in {sol_dir}")
                return None
            sol_file = sol_files[0]
            logger.debug(f"Found Solidity file: {sol_file}")

            # Find Move file
            move_dir = Path(SUI_MOVE_DIR) / case_name / "sources"
            move_files = list(move_dir.glob("*.move"))
            if not move_files:
                logger.warning(f"No Move file found for {case_name} in {move_dir}")
                return None
            move_file = move_files[0]
            logger.debug(f"Found Move file: {move_file}")

            # Read contents
            with open(sol_file, 'r') as f:
                solidity_code = f.read()

            with open(move_file, 'r') as f:
                reference_move_code = f.read()

            logger.info(f"Loaded test case '{case_name}': {len(solidity_code)} chars Solidity, {len(reference_move_code)} chars Move")

            return BenchmarkCase(
                name=case_name,
                solidity_file=str(sol_file),
                reference_move_file=str(move_file),
                solidity_code=solidity_code,
                reference_move_code=reference_move_code
            )

        except Exception as e:
            logger.error(f"Error loading test case {case_name}: {e}", exc_info=True)
            return None

    def run_single_benchmark(self, case: BenchmarkCase) -> BenchmarkResult:
        """Run benchmark for a single test case."""
        logger.info(f"\n{'='*60}")
        logger.info(f"Running benchmark: {case.name}")
        logger.info(f"{'='*60}")

        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

        # Call API for translation
        logger.info(f"[{case.name}] Starting translation...")
        api_result = self.api_client.translate(case.solidity_code)

        if not api_result or not api_result.get("success"):
            error_msg = api_result.get("error", "Unknown error") if api_result else "No response from API"
            logger.error(f"[{case.name}] Translation failed: {error_msg}")
            return BenchmarkResult(
                test_case=case.name,
                success=False,
                error=error_msg,
                generated_code=None,
                evaluation=None,
                response_time=api_result.get("response_time", 0) if api_result else 0,
                timestamp=timestamp
            )

        generated_code = api_result.get("generated_code", "")
        raw_generated_code = api_result.get("raw_generated_code", "")
        response_time = api_result.get("response_time", 0)

        logger.info(f"[{case.name}] Translation completed in {response_time:.2f}s")

        # Save raw output immediately to a streaming log file
        if raw_generated_code:
            stream_log_dir = os.path.join(RESULTS_DIR, "streaming_logs")
            os.makedirs(stream_log_dir, exist_ok=True)
            stream_log_file = os.path.join(stream_log_dir, f"{case.name}_raw_output.move")
            with open(stream_log_file, 'w') as f:
                f.write(f"# Raw streaming output for {case.name}\n")
                f.write(f"# Generated at: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"# Response time: {response_time:.2f}s\n\n")
                f.write(raw_generated_code)
            logger.debug(f"[{case.name}] Saved raw streaming output to: {stream_log_file}")

        # Evaluate the generated code
        logger.info(f"[{case.name}] Starting evaluation...")
        evaluation = self.evaluator.evaluate(
            generated_code,
            case.reference_move_code,
            case.name
        )

        logger.info(f"[{case.name}] Evaluation scores:")
        logger.info(f"  - Syntax: {evaluation.syntax_score:.1f}/100")
        logger.info(f"  - Similarity: {evaluation.similarity_score:.1f}/100")
        logger.info(f"  - Structure: {evaluation.structure_score:.1f}/100")
        logger.info(f"  - BLEU: {evaluation.bleu_score:.1f}/100")
        logger.info(f"  - Semantic: {evaluation.semantic_score:.1f}/100")
        if evaluation.compilable is not None:
            logger.info(f"  - Compilable: {'Yes' if evaluation.compilable else 'No'}")
        logger.info(f"  - Overall: {'PASS' if evaluation.passed else 'FAIL'}")

        return BenchmarkResult(
            test_case=case.name,
            success=True,
            error=None,
            generated_code=generated_code,
            evaluation=evaluation,
            response_time=response_time,
            timestamp=timestamp
        )

    def run_all_benchmarks(self, test_cases: List[str] = None) -> List[BenchmarkResult]:
        """Run benchmarks for all test cases."""
        if test_cases is None:
            test_cases = TEST_CASES

        logger.info("\n" + "=" * 60)
        logger.info("SOLIDITY TO MOVE TRANSLATION BENCHMARK")
        logger.info("=" * 60)
        logger.debug(f"Test cases to run: {test_cases}")

        # Test API connection first
        logger.info("\nTesting API connection...")
        if not self.api_client.test_connection():
            logger.error("Failed to connect to API. Please check your configuration.")
            return []

        logger.info("API connection successful!")

        # Load and run all test cases
        logger.info(f"\nPreparing to run {len(test_cases)} test cases...")
        for idx, case_name in enumerate(test_cases, 1):
            logger.info(f"\n[{idx}/{len(test_cases)}] Processing test case: {case_name}")
            case = self.load_test_case(case_name)
            if case:
                result = self.run_single_benchmark(case)
                self.results.append(result)
            else:
                logger.warning(f"Skipping {case_name} due to loading errors")

        logger.info(f"\nCompleted {len(self.results)}/{len(test_cases)} test cases")
        return self.results

    def save_results(self, output_dir: str = None):
        """Save benchmark results to disk."""
        if output_dir is None:
            output_dir = RESULTS_DIR

        logger.debug(f"Saving results to directory: {output_dir}")
        os.makedirs(output_dir, exist_ok=True)

        # Generate timestamp for this run
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        results_file = os.path.join(output_dir, f"benchmark_results_{timestamp}.json")

        # Convert results to serializable format
        logger.debug("Serializing benchmark results...")
        serializable_results = []
        for result in self.results:
            result_dict = {
                "test_case": result.test_case,
                "success": result.success,
                "error": result.error,
                "response_time": result.response_time,
                "timestamp": result.timestamp,
            }

            if result.evaluation:
                result_dict["evaluation"] = {
                    "syntax_score": result.evaluation.syntax_score,
                    "similarity_score": result.evaluation.similarity_score,
                    "structure_score": result.evaluation.structure_score,
                    "bleu_score": result.evaluation.bleu_score,
                    "semantic_score": result.evaluation.semantic_score,
                    "compilable": result.evaluation.compilable,
                    "passed": result.evaluation.passed,
                    "metrics": result.evaluation.metrics,
                }

            serializable_results.append(result_dict)

        # Save JSON results
        logger.debug(f"Writing results to: {results_file}")
        with open(results_file, 'w') as f:
            json.dump({
                "timestamp": timestamp,
                "total_tests": len(self.results),
                "passed": sum(1 for r in self.results if r.evaluation and r.evaluation.passed),
                "failed": sum(1 for r in self.results if not r.evaluation or not r.evaluation.passed),
                "results": serializable_results
            }, f, indent=2)

        logger.info(f"\nResults saved to: {results_file}")

        # Save generated code for each test case (both raw and cleaned)
        logger.debug("Saving generated code files...")
        for result in self.results:
            if result.generated_code:
                # Save cleaned code
                code_file = os.path.join(
                    output_dir,
                    f"{timestamp}_{result.test_case}_generated.move"
                )
                with open(code_file, 'w') as f:
                    f.write(result.generated_code)
                logger.debug(f"Saved cleaned code: {code_file}")

        logger.info(f"Saved {len(self.results)} generated code files")
        return results_file

    def print_summary(self):
        """Print a summary of all benchmark results."""
        if not self.results:
            logger.info("\nNo results to summarize.")
            return

        logger.info("\n" + "=" * 60)
        logger.info("BENCHMARK SUMMARY")
        logger.info("=" * 60)

        total = len(self.results)
        successful = sum(1 for r in self.results if r.success)
        passed = sum(1 for r in self.results if r.evaluation and r.evaluation.passed)

        logger.info(f"\nTotal test cases: {total}")
        logger.info(f"Successful translations: {successful}/{total}")
        logger.info(f"Passed evaluations: {passed}/{total}")

        if successful > 0:
            avg_response_time = sum(r.response_time for r in self.results) / len(self.results)
            logger.info(f"Average response time: {avg_response_time:.2f}s")

        # Score breakdown
        if any(r.evaluation for r in self.results):
            evals_with_scores = [r.evaluation for r in self.results if r.evaluation]
            if evals_with_scores:
                avg_syntax = sum(e.syntax_score for e in evals_with_scores) / len(evals_with_scores)
                avg_similarity = sum(e.similarity_score for e in evals_with_scores) / len(evals_with_scores)
                avg_structure = sum(e.structure_score for e in evals_with_scores) / len(evals_with_scores)
                avg_bleu = sum(e.bleu_score for e in evals_with_scores) / len(evals_with_scores)
                avg_semantic = sum(e.semantic_score for e in evals_with_scores) / len(evals_with_scores)

                logger.info(f"\nAverage scores:")
                logger.info(f"  - Syntax: {avg_syntax:.1f}/100")
                logger.info(f"  - Similarity: {avg_similarity:.1f}/100")
                logger.info(f"  - Structure: {avg_structure:.1f}/100")
                logger.info(f"  - BLEU: {avg_bleu:.1f}/100")
                logger.info(f"  - Semantic: {avg_semantic:.1f}/100")

                # Compilation stats
                compilable_count = sum(1 for e in evals_with_scores if e.compilable is True)
                non_compilable_count = sum(1 for e in evals_with_scores if e.compilable is False)
                if compilable_count > 0 or non_compilable_count > 0:
                    total_checked = compilable_count + non_compilable_count
                    logger.info(f"  - Compilation rate: {compilable_count}/{total_checked} ({compilable_count/total_checked*100:.1f}%)")

        # Per-test results
        logger.info(f"\nPer-test results:")
        for result in self.results:
            status = "PASS" if result.evaluation and result.evaluation.passed else "FAIL"
            logger.info(f"  {result.test_case:20s} - {status}")


def main():
    """Main entry point for the benchmark runner."""
    # Setup logging
    log_file = get_default_log_file()
    setup_logging(log_level="INFO", log_file=log_file)

    logger.info("=" * 60)
    logger.info("Benchmark Pipeline Started")
    logger.info(f"Log file: {log_file}")
    logger.info("=" * 60)

    runner = BenchmarkRunner()

    # Run all benchmarks
    runner.run_all_benchmarks()

    # Print summary
    runner.print_summary()

    # Save results
    runner.save_results()

    logger.info("\nBenchmark pipeline completed successfully")


if __name__ == "__main__":
    main()
