# Benchmark KPI Guide

## Overview

This document describes the Key Performance Indicators (KPIs) used in the Solidity to Sui Move translation benchmark. The benchmark evaluates translated Move code through functional testing: compilation success, test pass rates, and code quality.

## Methodology

### Input Data and Knowledge Base

All models have full access to:

- Handwritten reference Sui Move implementations in `../benchmark/sui_move/`
- Original Solidity smart contracts in `../benchmark/solidity/`
- Comprehensive test suites (10-14 tests per contract)

### Translation Flow

The translation takes place in the Shinso App, where each model follows this process:

#### 1. Initial Translation

Models receive the flattened Solidity file with this boilerplate prompt:

```md
# Smart Contract Translation: Solidity → Sui Move

You are an expert blockchain developer specializing in translating Solidity smart contracts to Sui Move. Your translations preserve contract logic while leveraging Move's safety features and Sui's object-centric model.

## Translation Guidelines

### 1. **Semantic Mapping**
- **Storage patterns**: EVM storage → Sui Object model
- **State variables**: mapping → Sui dynamic fields or Tables
- **Access control**: OpenZeppelin AccessControl → Sui Capability pattern
- **Reentrancy**: Checks-Effects-Interactions → Move's resource safety (implicit protection)
- **Function visibility**: public, external, internal, private → Move's public, public(package), native visibility

### 2. **Type Conversions**
- uint256 → u64 or u128 (Move has no overflow by default)
- address → address (Sui addresses are 32 bytes)
- mapping(address => uint) → Table<address, u64> from Sui framework
- bool → bool
- string → vector<u8> (or use Sui's String type)
- Arrays → vector<T> in Move

### 3. **Key Differences to Address**

**EVM vs Sui Model:**
- EVM: Contract-centric (contracts own storage)
- Sui: Object-centric (objects are first-class, owned by addresses)

**Gas & Execution:**
- Solidity: Gas-based, sequential execution
- Sui: Storage-based fees, parallel execution via owned objects

**Events:**
- Solidity: emit EventName(args) → Move: Use sui::event::emit()

**Inheritance:**
- Solidity: Contract inheritance
- Move: Struct composition + module imports

### 4. **Move Safety Features to Add**

- **Resource Safety**: Structs with "key" ability cannot be copied/dropped
- **Abort Conditions**: Use "assert!()" for runtime checks
- **Capability Pattern**: For admin/privileged operations
- **Object Ownership**: Clearly define object ownership (owned, shared, immutable)

### 5. **Common Patterns Translation**

**ERC20/ERC721 → Sui Coins/NFTs:**
- Use Sui's native "sui::coin" module for fungible tokens
- Use "sui::object" with "key" + "store" for NFTs

**Pausable Contracts:**
- Use a shared object with a pause flag
- Check flag in entry functions

**Upgradeable Contracts:**
- Sui packages are immutable by default
- Use package upgrade mechanism or mutable shared objects for data

### 6. **Output Format**

For each translation, provide:

1. **Move.toml**: Package manifest with dependencies and addresses
2. **Module Structure**: Complete Move module with proper imports
3. **Struct Definitions**: Define resource types with appropriate abilities
4. **Init Function**: Module initializer (runs once on publish)
5. **Entry Functions**: Public functions callable from transactions
6. **Comments**: Explain key translation decisions inline
7. **Testing Considerations**: Note important test cases

**IMPORTANT**: Always generate the Move.toml file first, then the .move source files. The Move.toml should include:
- Package name matching the module name
- Sui framework dependency
- Address mappings

**CRITICAL PATH STRUCTURE**:
All files MUST be created in the src/<package-name>/ directory structure:
- Move.toml goes in: src/<package-name>/Move.toml
- Move modules go in: src/<package-name>/sources/<module>.move

For example, a counter package creates:
- src/counter/Move.toml
- src/counter/sources/counter.move

### 7. **Example Translation Pattern**

Solidity:
\`\`\`solidity
contract Counter {
    uint256 public count;
    function increment() public {
        count++;
    }
}
\`\`\`

Expected output (note the src/counter/ prefix on all paths):

<dyad-write path="src/counter/Move.toml" description="Create package manifest">
[package]
name = "counter"
version = "0.0.1"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "testnet-v1.55.0" }

[addresses]
counter = "0x0"
</dyad-write>

<dyad-write path="src/counter/sources/counter.move" description="Create Move module">
module counter::counter {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Shared counter object
    public struct Counter has key {
        id: UID,
        count: u64,
    }

    /// Initialize and share the counter
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Counter {
            id: object::new(ctx),
            count: 0,
        });
    }

    /// Increment the counter (anyone can call)
    public entry fun increment(counter: &mut Counter) {
        counter.count = counter.count + 1;
    }

    /// Read the counter value
    public fun value(counter: &Counter): u64 {
        counter.count
    }
}
</dyad-write>

## Critical Security Considerations

When translating contracts:

1. **Verify arithmetic operations**: Move has no overflow by default, but be explicit
2. **Access control**: Implement Capability pattern for privileged operations
3. **Reentrancy**: Document how Move's resource safety prevents reentrancy
4. **External calls**: Sui doesn't have arbitrary calls; use programmable transactions
5. **Testing**: Recommend property-based tests for invariants

## Response Format

When translating a contract:

1. Brief overview of the original contract's purpose
2. **Move.toml file** (ALWAYS include this first)
3. Complete Move module code with inline comments (in sources/ subdirectory)
4. Summary of key translation decisions
5. Security considerations and differences from original
6. Testing recommendations

**File Structure Requirements:**

- Always create Move.toml at: src/<package_name>/Move.toml
- Place all .move files at: src/<package_name>/sources/<module_name>.move
- The package name MUST match the specific contract being translated (e.g., if translating a Counter contract, use "counter" as the package name; if translating an ERC20 contract, use "erc20_token", etc.)
- ONLY create files for the contract being translated - do NOT create additional example packages
- NEVER forget the src/<package_name>/ prefix on ALL file paths

Always prioritize correctness and safety over feature parity. If a Solidity pattern doesn't translate cleanly to Move, explain the recommended Sui-native approach.
```

#### 2. Compilation Fixes (5 iterations)

With access to `sui cli` (sui 1.61.2-homebrew), models receive compilation errors and iterate:

```javascript
streamMessage({
  prompt: `Fix the error: ${message}`,
  chatId: selectedChatId,
});
```

Where `${message}` holds the formatted output of the `sui move build` command.

#### 3. Test Adjustments

After compilation succeeds, pre-written test cases are adjusted for compatibility (hard typing issues and compatibility problems are fixed).

#### 4. Test Fixes (2 iterations)

Models receive failing test output and iterate:

```javascript
streamMessage({
  prompt: `Fix the failing test cases: ${message}`,
  chatId: selectedChatId,
});
```

#### 5. Benchmark Execution

Run the `run_benchmark.py` script on the final outputs.

---

## Scoring System

The benchmark uses a 100-point scoring system with three categories:

### 1. Compilation (40 points)

**What it measures:** Whether the generated Move code compiles without errors.

**Calculation:**

- Runs `sui move build` in the contract directory
- **Success:** 40 points
- **Failure:** 0 points

**Thresholds:**

- **Production-ready:** 100% (all contracts compile)
- **Good:** 80-99%
- **Fair:** 50-79%
- **Poor:** <50%

**Why it matters:** Non-compiling code is completely unusable. This is the most fundamental requirement for any code generation system.

---

### 2. Test Pass Rate (50 points)

**What it measures:** Percentage of unit tests that pass execution.

**Calculation:**

- Runs `sui move test` in the contract directory
- Parses output: `Test result: OK. Total tests: X; passed: Y; failed: Z`
- Score = `(tests_passed / tests_expected) × 50`

**Example:**

- Expected tests: 12
- Tests passed: 9
- Score: `(9 / 12) × 50 = 37.5 points`

**Test Suites per Contract:**

| Contract          | Expected Tests |
|-------------------|----------------|
| 0_hello_world     | 11             |
| 1_tipjar          | 12             |
| 2_guestbook       | 12             |
| 3_todo_list       | 14             |
| 4_simple_coin     | 12             |
| 5_counter         | 14             |
| 6_weather_oracle  | 13             |
| **Total**         | **88**         |

**Why it matters:** Compilation proves syntactic correctness, but tests prove functional correctness. A contract that compiles but fails all tests has incorrect business logic.

---

### 3. Code Quality (10 points)

**What it measures:** Code quality based on compiler warning count.

**Calculation:**

- Counts occurrences of "warning" in `sui move test` output
- **0 warnings:** 10 points
- **1-5 warnings:** 7 points
- **6+ warnings:** 3 points

**Common warnings:**

- Unused variables
- Unused imports
- Deprecated patterns
- Unnecessary type annotations

**Why it matters:** Warnings indicate code smell, potential bugs, or non-idiomatic Move code. Production code should aim for zero warnings.

---

### 4. Total Score (100 points)

**Calculation:**

```bash
Total Score = Compilation Score + Test Pass Score + Quality Score
            = (0 or 40) + (0-50) + (3, 7, or 10)
```

**Score Interpretation:**

| Score Range | Quality Level    | Description                                      |
|-------------|------------------|--------------------------------------------------|
| 90-100      | Excellent        | Compiles, passes all/most tests, clean code      |
| 70-89       | Good             | Compiles, passes majority of tests, some issues  |
| 40-69       | Fair             | Compiles or passes some tests, major gaps        |
| 0-39        | Poor             | Doesn't compile or minimal test success          |

---

## Running the Benchmark

### Setup

```bash
cd /Users/vargaelod/shinso/model/benchmark

# Ensure sui CLI is installed
sui --version  # Should show sui 1.61.2-homebrew or similar
```

### Execute Benchmark

```bash
# Run benchmark on all models
python run_benchmark.py

# Outputs generated:
# - benchmark_results.json: Raw results data
# - BENCHMARK_REPORT.md: Human-readable report with tables
```

### Output Format

**Console Output:**

```bash
==========================================================
   SUI MOVE TRANSLATION BENCHMARK
==========================================================

Testing: solmover
==========================================================

  Testing 0_hello_world... ✅ 11/11 tests | Score: 100.0/100
  Testing 1_tipjar... ✅ 12/12 tests | Score: 100.0/100
  Testing 2_guestbook... ✅ 12/12 tests | Score: 100.0/100
  Testing 3_todo_list... ❌ Compilation failed | Score: 10.0/100
```

**JSON Results (`benchmark_results.json`):**

```json
{
  "timestamp": "2025-12-03T18:05:55",
  "results": [
    {
      "model": "solmover",
      "contract": "0_hello_world",
      "compiles": true,
      "tests_passed": 11,
      "tests_expected": 11,
      "warnings": 0,
      "compile_score": 40,
      "test_score": 50.0,
      "quality_score": 10,
      "total_score": 100.0,
      "errors": []
    }
  ]
}
```

**Markdown Report (`BENCHMARK_REPORT.md`):**

- Detailed results by contract table
- Summary statistics per model
- Score breakdown by category

---

## Test Contracts

The benchmark includes 7 progressively complex smart contracts:

1. **0_hello_world**: Basic object creation and transfer
2. **1_tipjar**: Simple value transfer pattern
3. **2_guestbook**: Storage patterns with dynamic fields
4. **3_todo_list**: Complex state management (CRUD operations)
5. **4_simple_coin**: Token minting/burning with TreasuryCap
6. **5_counter**: Shared object pattern with access control
7. **6_weather_oracle**: Oracle pattern with AdminCap and NFTs

Each contract has comprehensive test coverage (11-14 tests) verifying:

- Object initialization
- Function correctness
- Access control
- Edge cases and error handling
- State management
- Resource transfers

---

## Interpreting Results

### Compilation Rate

**Formula:** `(Contracts that compile / Total contracts) × 100`

**Example Results:**

- **SolMover:** 71.4% (5/7 contracts compile)
- **Gemini-2.5:** 28.6% (2/7 contracts compile)

**Interpretation:**

- A model with <50% compilation rate has fundamental syntax/structure problems
- 70-90% indicates good syntax understanding with some edge case issues
- 100% is ideal but rare without iterative refinement

### Average Test Pass Rate

**Formula:** `(Total tests passed / Total tests expected) × 100`

**Example Results:**

- **SolMover:** 69.3% (61/88 tests pass)
- **Gemini-2.5:** 13.6% (12/88 tests pass)

**Interpretation:**

- Pass rate correlates with functional correctness
- A contract can compile but pass 0% tests (wrong logic)
- 80%+ pass rate indicates strong functional translation
- <30% suggests fundamental misunderstanding of contract logic

### Average Total Score

**Formula:** `Sum of all contract scores / Number of contracts`

**Example Results:**

- **SolMover:** 73.9/100
- **Gemini-2.5:** 28.6/100

**Interpretation:**

- **70+:** Model is production-viable for basic contracts
- **50-70:** Model needs refinement for reliability
- **30-50:** Model understands some patterns but unreliable
- **<30:** Model is not yet functional for this task

### Score Breakdown by Category

This shows where models excel or struggle:

**Example:**

| Model       | Avg Compilation | Avg Test Score | Avg Quality |
|-------------|-----------------|----------------|-------------|
| solmover    | 28.6/40         | 35.7/50        | 9.6/10      |
| gemini-2.5  | 11.4/40         | 7.1/50         | 10.0/10     |

**Analysis:**

- **SolMover:** Good compilation (71%), decent test pass rate (71%), excellent quality
- **Gemini-2.5:** Poor compilation (29%), poor test pass rate (14%), but clean code when it works

---

## Recommendations for Model Improvement

Based on benchmark results:

| Low Score Area          | Likely Cause                                    | Recommendation                                                      |
|-------------------------|------------------------------------------------|---------------------------------------------------------------------|
| **Compilation (<70%)**  | Syntax errors, wrong imports, type mismatches  | Add more Move syntax examples to training, focus on common patterns|
| **Test Pass (<60%)**    | Incorrect logic translation, wrong semantics   | Improve Solidity→Move semantic mapping, add more paired examples   |
| **Quality (warnings)**  | Non-idiomatic code, unused variables           | Add Move best practices to training, use linting in feedback loop  |

### Specific Improvements

1. **If failing on complex contracts (3_todo_list, 6_weather_oracle):**
   - Model struggles with stateful operations or advanced patterns
   - Add more training examples of dynamic fields, capability patterns

2. **If passing simple contracts but failing complex ones:**
   - Model understands basics but not composition
   - Focus on multi-struct interactions, access control patterns

3. **If compiling but failing tests:**
   - Syntax correct but logic wrong
   - Strengthen training on functional equivalence, not just structural translation

---

## Comparison with Other Systems

While this benchmark focuses on functional testing, similar approaches are used by:

- **GitHub Copilot:** Compilation rate + unit test pass rate for code suggestions
- **AlphaCode:** Test case pass rate as primary evaluation metric
- **CodeGen/CodeT5:** Functional correctness (pass@k) metrics

Our approach prioritizes **functional correctness** over **code similarity**, making it ideal for evaluating production-ready translation models.

---

## Citation Format

When reporting benchmark results, include:

```bash
Model: [Model Name]
Benchmark: Solidity → Sui Move Functional Testing
Test Contracts: 7
Total Test Cases: 88
Compilation Rate: [X]%
Avg Test Pass Rate: [Y]%
Average Score: [Z]/100
```

**Example:**

```bash
Model: SolMover v1.0
Benchmark: Solidity → Sui Move Functional Testing
Test Contracts: 7
Total Test Cases: 88
Compilation Rate: 71.4%
Avg Test Pass Rate: 69.3%
Average Score: 73.9/100
```
