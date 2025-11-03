# Benchmark KPI Guide

## Overview

This document describes the Key Performance Indicators (KPIs) used in the Solidity to Sui Move translation benchmark pipeline. These metrics are designed to be comparable with mainstream code generation and translation models.

## Core Metrics

### 1. Syntax Score (0-100)

**What it measures:** Basic syntactic correctness of generated Move code.

**Calculation:**

- Module declaration presence (20 points)
- Proper `use` statements with `::` (15 points)
- Struct or function definitions (20 points)
- Balanced braces `{}` (20 points)
- Move-specific patterns (`TxContext`, `UID`, `object::`, etc.) (25 points)

**Thresholds:**

- **Excellent:** ≥80
- **Good:** 60-79
- **Fair:** 40-59
- **Poor:** <40

**Industry comparison:** Similar to basic syntax checking in code generation models like GPT-4 Code, Codex, and CodeLlama.

---

### 2. BLEU Score (0-100)

**What it measures:** N-gram based similarity between generated and reference code (standard machine translation metric).

**Calculation:**

- Tokenizes code into words and symbols
- Calculates 1-gram through 4-gram precision
- Applies geometric mean and brevity penalty
- Scaled to 0-100 for easier interpretation

**Thresholds:**

- **Excellent:** ≥50
- **Good:** 30-49
- **Fair:** 15-29
- **Poor:** <15

**Industry comparison:**

- Widely used in machine translation (Google Translate, DeepL)
- Used in code generation papers (CodeBERT, GraphCodeBERT, CodeT5)
- Comparable metric across all language translation models

**Note:** BLEU is lower for code than natural language because code requires exact syntax. A BLEU score of 30+ is considered good for code translation.

---

### 3. Similarity Score (0-100)

**What it measures:** Character-level sequence similarity using Python's difflib.

**Calculation:**

- Uses SequenceMatcher to compare full text
- Ratio of matching characters to total characters
- Direct text similarity without tokenization

**Thresholds:**

- **Excellent:** ≥70
- **Good:** 50-69
- **Fair:** 30-49
- **Poor:** <30

**Industry comparison:** Similar to edit distance metrics used in code clone detection and plagiarism detection tools.

---

### 4. Structure Score (0-100)

**What it measures:** High-level structural similarity (modules, structs, functions).

**Calculation:**

- Extracts module names, struct names, and function names
- Compares these structural elements between generated and reference
- Uses Jaccard similarity (intersection/union)

**Thresholds:**

- **Excellent:** ≥80
- **Good:** 60-79
- **Fair:** 40-59
- **Poor:** <40

**Industry comparison:** Similar to AST (Abstract Syntax Tree) based metrics used in program synthesis research.

---

### 5. Semantic Score (0-100)

**What it measures:** Semantic equivalence based on code structure and intent.

**Calculation:**

- Module declaration (20% weight)
- Struct matching (30% weight) - names and count
- Function matching (30% weight) - signatures and count
- Import matching (20% weight) - `use` statements

**Thresholds:**

- **Excellent:** ≥70
- **Good:** 50-69
- **Fair:** 30-49
- **Poor:** <30

**Industry comparison:**

- Related to CodeBLEU's dataflow matching
- Similar to semantic preserving transformations in program synthesis
- Used in neural program synthesis models (AlphaCode, CodeGen)

---

### 6. Compilation Rate (%)

**What it measures:** Percentage of generated code that successfully compiles.

**Calculation:**

- Attempts to compile each generated Move file using `sui move build`
- Binary pass/fail per test case
- Aggregated as percentage across all tests

**Thresholds:**

- **Production-ready:** 100%
- **Good:** 80-99%
- **Fair:** 50-79%
- **Poor:** <50%

**Industry comparison:**

- Critical metric for practical code generation
- Used in Codex, AlphaCode, and GitHub Copilot evaluations
- **Most important metric for real-world deployment**

**Note:** Requires `sui` CLI to be installed. Returns `N/A` if not available.

---

## Additional Metrics

### 7. Response Time (seconds)

**What it measures:** Model inference time per test case.

**Use:** Compare inference speed with other models.

**Industry comparison:** Important for production deployment; typically:

- **Fast:** <1s
- **Moderate:** 1-5s
- **Slow:** >5s

---

### 8. Detailed Structural Metrics

These are reported in the `metrics` object:

#### Struct Match Ratio

- **Formula:** `(struct_intersection / struct_union) * 100`
- **Meaning:** How many struct names match between generated and reference

#### Function Match Ratio

- **Formula:** `(function_intersection / function_union) * 100`
- **Meaning:** How many function names match between generated and reference

#### Keyword Coverage

- **Formula:** `(matched_keywords / reference_keywords) * 100`
- **Meaning:** Percentage of Move keywords from reference that appear in generated code

#### Exact Match

- **Boolean:** Does generated code exactly match reference?
- **Rare:** Usually 0% for translation tasks
- **High value:** Indicates potential overfitting if too high

---

## Pass/Fail Criteria

A test case **PASSES** if **ALL** of the following are true:

```bash
✓ Syntax Score ≥ 50
✓ Semantic Score ≥ 40
✓ Structure Score ≥ 40
✓ BLEU Score ≥ 20
✓ Generated code is not empty
```

**Rationale:** Ensures generated code is:

1. Syntactically valid
2. Semantically similar to reference
3. Structurally correct
4. Has reasonable n-gram overlap
5. Actually generated (not empty response)

---

## Comparison with Mainstream Models

### GPT-4 / Claude (Code Translation)

**Typical Performance:**

- BLEU: 30-50
- Compilation Rate: 70-90%
- Semantic Score: 50-70

### Codex / GitHub Copilot (Code Generation)

**Typical Performance:**

- Syntax Score: 70-85
- Compilation Rate: 60-80%
- Response Time: <2s

### Specialized Translation Models (e.g., CodeT5, GraphCodeBERT)

**Typical Performance:**

- BLEU: 40-60
- Structure Score: 70-90
- Semantic Score: 60-80

### Your Model Benchmarking

Use these KPIs to:

1. **Track Progress:** Run benchmarks regularly to see improvement over time
2. **Compare Models:** Test multiple models with same contracts and compare scores
3. **Identify Weaknesses:** Low scores in specific metrics indicate areas for improvement
4. **Validate Changes:** Ensure training changes improve scores without regression

---

## Running the Benchmark

```bash
cd /Users/vargaelod/shinso/model/benchmark_pipeline

# Run full benchmark
python benchmark_runner.py

# Generate report from latest results
python reporter.py latest
```

## Output Files

- **JSON Results:** `results/benchmark_results_<timestamp>.json`
- **HTML Report:** `results/report_<timestamp>.html`
- **Generated Code:** `results/<timestamp>_<testcase>_generated.move`

---

## Recommendations for Model Improvement

Based on KPI analysis:

| Low Score            | Recommendation                                                   |
| -------------------- | ---------------------------------------------------------------- |
| **Syntax Score**     | Improve training on Move syntax patterns, add more Move examples |
| **BLEU Score**       | Enhance training data quality, use more paired examples          |
| **Semantic Score**   | Focus on function/struct mapping in training, add semantic loss  |
| **Compilation Rate** | Add compilation feedback to training loop, filter bad examples   |
| **Structure Score**  | Train on AST-level transformations, not just text                |

---

## Citation

When comparing models, please report:

1. All 5 core scores (Syntax, BLEU, Similarity, Structure, Semantic)
2. Compilation rate
3. Average response time
4. Number of test cases
5. Pass rate (% of tests passing all criteria)

Example:

```bash
Model: SolMover v1.0
Test Cases: 7
Pass Rate: 42.9% (3/7)
Avg BLEU: 28.3
Avg Semantic: 35.7
Compilation Rate: 57.1%
```
