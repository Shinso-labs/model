# Sui Move Translation Benchmark Results

**Benchmark Date:** 2026-01-05 17:48:08

## Visual Comparison

![Benchmark Charts](benchmark_charts.png)

## Scoring System

- **Compilation (40 points):** Code compiles without errors
- **Test Pass Rate (50 points):** (Tests Passed / Expected Tests) × 50
- **Code Quality (10 points):** Based on warning count
- **Total Score:** Sum of all categories (max 100 per contract)

## Detailed Results by Contract

| Contract | Model | Compiles | Tests Passed | Expected | Pass Rate | Warnings | Score |
|----------|-------|----------|--------------|----------|-----------|----------|-------|
| 0_hello_world | solmover | ✅ | 11 | 11 | 100.0% | 0 | 100.0/100 |
| 0_hello_world | gemini-2.5 | ❌ | 0 | 11 | 0.0% | 0 | 10.0/100 |
| 0_hello_world | qwen3-coder | ❌ | 0 | 11 | 0.0% | 0 | 10.0/100 |
| 1_tipjar | solmover | ✅ | 12 | 12 | 100.0% | 0 | 100.0/100 |
| 1_tipjar | gemini-2.5 | ✅ | 12 | 12 | 100.0% | 0 | 100.0/100 |
| 1_tipjar | qwen3-coder | ✅ | 12 | 12 | 100.0% | 15 | 93.0/100 |
| 2_guestbook | solmover | ✅ | 12 | 12 | 100.0% | 0 | 100.0/100 |
| 2_guestbook | gemini-2.5 | ❌ | 0 | 12 | 0.0% | 0 | 10.0/100 |
| 2_guestbook | qwen3-coder | ❌ | 0 | 12 | 0.0% | 0 | 10.0/100 |
| 3_todo_list | solmover | ❌ | 0 | 14 | 0.0% | 0 | 10.0/100 |
| 3_todo_list | gemini-2.5 | ❌ | 0 | 14 | 0.0% | 0 | 10.0/100 |
| 3_todo_list | qwen3-coder | ❌ | 0 | 14 | 0.0% | 0 | 10.0/100 |
| 4_simple_coin | solmover | ✅ | 12 | 12 | 100.0% | 0 | 100.0/100 |
| 4_simple_coin | gemini-2.5 | ❌ | 0 | 12 | 0.0% | 0 | 10.0/100 |
| 4_simple_coin | qwen3-coder | ❌ | 0 | 12 | 0.0% | 0 | 10.0/100 |
| 5_counter | solmover | ✅ | 14 | 14 | 100.0% | 1 | 97.0/100 |
| 5_counter | gemini-2.5 | ❌ | 0 | 14 | 0.0% | 0 | 10.0/100 |
| 5_counter | qwen3-coder | ❌ | 0 | 14 | 0.0% | 0 | 10.0/100 |
| 6_weather_oracle | solmover | ❌ | 0 | 13 | 0.0% | 0 | 10.0/100 |
| 6_weather_oracle | gemini-2.5 | ✅ | 0 | 13 | 0.0% | 0 | 50.0/100 |
| 6_weather_oracle | qwen3-coder | ❌ | 0 | 13 | 0.0% | 0 | 10.0/100 |

## Summary Statistics

| Model | Avg Score | Compilation Rate | Avg Test Pass Rate | Total Tests Passed |
|-------|-----------|------------------|--------------------|--------------------|
| solmover | 73.9/100 | 71.4% | 69.3% | 61/88 |
| gemini-2.5 | 28.6/100 | 28.6% | 13.6% | 12/88 |
| qwen3-coder | 21.9/100 | 14.3% | 13.6% | 12/88 |

## Score Breakdown by Category

| Model | Avg Compilation | Avg Test Score | Avg Quality |
|-------|-----------------|----------------|-------------|
| solmover | 28.6/40 | 35.7/50 | 9.6/10 |
| gemini-2.5 | 11.4/40 | 7.1/50 | 10.0/10 |
| qwen3-coder | 5.7/40 | 7.1/50 | 9.0/10 |
