# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a benchmark system for evaluating LLM ability to translate Solidity smart contracts into Sui Move. It scores 6 models across 7 contracts of increasing complexity (88 total test cases) on compilation success, test pass rate, and code quality.

## Key Commands

```bash
# Setup
python -m venv venv && source venv/bin/activate && pip install -r requirements.txt

# === Apples-to-apples no-tools benchmark (single-shot, no compile/test loops) ===
# Produces output_<model>_no_tools/ directories
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=...
export SOLMOVER_API_KEY=...        # OVH key for the hosted Solmover endpoint
python translate_no_tools.py                       # all configured models
python translate_no_tools.py claude-4.7-opus solmover   # subset

# === Score everything (skips models whose output dir is missing) ===
python run_benchmark.py

# === Generate the PDF article from results ===
python create_article.py

# Test a single model's contract manually
cd output_<model>/<contract>/
sui move build
sui move test
```

Requires: Python 3.13+, Sui CLI (`sui`), and dependencies from `requirements.txt` (matplotlib, numpy, scipy, reportlab, openai, anthropic).

## Translation scripts

All three translation scripts use the **same methodology**: 5× compile-fix + 2× test-fix iteration loop where the script feeds `sui move build` / `sui move test` output back as a user message. None of them pass `tools=` to any API — pure multi-turn chat completion. This is intentional: Solmover has no tool-calling capability, so the benchmark explicitly excludes API tool use to keep newer models (Opus 4.7 etc.) from gaining an unfair "outside context" advantage.

- `translate_opus.py` — single-model, hardcoded for Anthropic Claude Opus 4.5. Used for the 2026-01-30 run.
- `translate_solmover.py` — single-model, hardcoded for the OVH-hosted Solmover (OpenAI-compatible endpoint). Includes hardened parsing for bare Move blocks and forces the canonical `Move.toml` (the model tends to inject Aptos deps).
- `translate_no_tools.py` — multi-provider (Anthropic + OpenAI + OpenAI-compatible). Used for adding new models (Opus 4.7, latest GPT). Reads keys from env vars, no hardcoded credentials. Edit the `MODELS` list at the top to add/remove models.

`run_benchmark.py` skips any `MODELS` entry whose output directory doesn't exist, so partially-populated runs report cleanly.

## Architecture

- `solidity/` — Source Solidity contracts (the input to each model's translation task)
- `sui_move/` — Gold-standard reference Sui Move implementations with full test suites
- `output_<model>/` — Each model's translated Move packages (one per contract), structured as standard Sui Move packages (`Move.toml`, `sources/`, `tests/`)
- `run_benchmark.py` — Main entry point. Iterates models × contracts, runs `sui move test` via subprocess, parses stdout/stderr for compilation status, test counts, and warnings, then computes scores and runs statistical analysis (chi-square, Fisher's exact, Wilson score CIs). Outputs `benchmark_results.json` and `BENCHMARK_REPORT.md`.
- `create_article.py` — Reads results and generates a formatted PDF report using ReportLab.
- `BENCHMARK_METHODOLOGY.md` — Detailed scoring rubric, translation flow, and statistical methodology.

## Scoring (per contract, 100 points max)

| Category | Points | Criteria |
|---|---|---|
| Compilation | 40 | `sui move build` succeeds |
| Test Pass Rate | 50 | `(passed / expected) × 50` |
| Code Quality | 10 | 0 warnings = 10, 1-5 = 7, 6+ = 3 |

## Adding a New Model

1. Create `output_<model>/` with 7 subdirectories (`0_hello_world` through `6_weather_oracle`), each a valid Sui Move package
2. Add the model key to `MODELS` and `MODELS_CONFIG` dicts in `run_benchmark.py`
3. Run `python run_benchmark.py`

## Contracts (by index)

0=hello_world, 1=tipjar, 2=guestbook, 3=todo_list, 4=simple_coin, 5=counter, 6=weather_oracle. Expected test counts are defined in `EXPECTED_TESTS` in `run_benchmark.py`.
