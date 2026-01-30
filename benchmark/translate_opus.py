#!/usr/bin/env python3
"""
Benchmark pipeline for Claude Opus 4.5
Translates 7 Solidity contracts to Sui Move via the Anthropic API,
following the methodology in BENCHMARK_METHODOLOGY.md.

Flow per contract:
  1. Initial translation (Solidity + prompt + reference test context)
  2. Compilation fix iterations (up to 5)
  3. Copy reference tests
  4. Test fix iterations (up to 2)
"""

import os
import re
import subprocess
import shutil
import json
import sys
import time
from pathlib import Path
from datetime import datetime

import anthropic

# ====================== Configuration ======================

API_KEY = "your-api-key"
MODEL_ID = "claude-opus-4-5-20251101"
BENCHMARK_DIR = Path("/your/preferred/path")
OUTPUT_DIR = BENCHMARK_DIR / "output_claude-4.5-opus"
REFERENCE_DIR = BENCHMARK_DIR / "sui_move"
SOLIDITY_DIR = BENCHMARK_DIR / "solidity"

MAX_COMPILE_ITERATIONS = 5
MAX_TEST_ITERATIONS = 2
TEMPERATURE = 0.2
MAX_TOKENS = 4096

# ====================== Contract Definitions ======================

CONTRACTS = [
    {"dir": "0_hello_world",    "sol": "HelloWorld.sol",      "pkg": "hello_world",    "addr": "hello_world",    "ref_test": "hello_world_tests.move"},
    {"dir": "1_tipjar",         "sol": "Tipjar.sol",          "pkg": "tipjar",         "addr": "tipjar",         "ref_test": "tipjar_tests.move"},
    {"dir": "2_guestbook",      "sol": "Guestbook.sol",       "pkg": "guestbook",      "addr": "guestbook",      "ref_test": "guestbook_tests.move"},
    {"dir": "3_todo_list",      "sol": "TodoList.sol",        "pkg": "todo_list",      "addr": "todo_list",      "ref_test": "todo_list_tests.move"},
    {"dir": "4_simple_coin",    "sol": "Coin.sol",            "pkg": "coin",           "addr": "coin",           "ref_test": "coin_tests.move"},
    {"dir": "5_counter",        "sol": "Counter.sol",         "pkg": "counter",        "addr": "counter",        "ref_test": "counter_tests.move"},
    {"dir": "6_weather_oracle", "sol": "WeatherOracle.sol",   "pkg": "weather_oracle", "addr": "weather_oracle", "ref_test": "weather_oracle_tests.move"},
]

# ====================== Translation Prompt (from BENCHMARK_METHODOLOGY.md) ======================

TRANSLATION_PROMPT = r"""# Smart Contract Translation: Solidity → Sui Move

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

Always prioritize correctness and safety over feature parity. If a Solidity pattern doesn't translate cleanly to Move, explain the recommended Sui-native approach.
"""

# ====================== File Parsing ======================

def extract_code_blocks(text):
    """Extract code blocks from markdown response text."""
    blocks = []
    pattern = r'```(\w*)\n(.*?)```'
    for match in re.finditer(pattern, text, re.DOTALL):
        lang = match.group(1).lower()
        code = match.group(2).strip()
        # Capture preceding text for context (to identify file names)
        start = max(0, match.start() - 300)
        context = text[start:match.start()].lower()
        blocks.append({"lang": lang, "code": code, "context": context})
    return blocks


def parse_response_files(text, contract):
    """Parse the API response to extract Move.toml and .move source files."""
    blocks = extract_code_blocks(text)

    move_toml = None
    move_sources = {}  # filename → content

    for block in blocks:
        code = block["code"]
        lang = block["lang"]
        context = block["context"]

        # ---- Identify Move.toml ----
        if lang in ("toml", "") and "[package]" in code:
            move_toml = code
            continue

        # ---- Identify .move source files ----
        if lang in ("move", "rust", "") and re.search(r'\bmodule\s+\w+::', code):
            # Skip test-only modules
            if code.lstrip().startswith("#[test_only]"):
                continue
            # Derive filename from module declaration
            m = re.search(r'module\s+\w+::(\w+)', code)
            filename = (m.group(1) + ".move") if m else "source.move"
            move_sources[filename] = code

    return move_toml, move_sources


def generate_fallback_toml(contract):
    """Generate a minimal Move.toml if the model didn't provide one."""
    return f"""[package]
name = "{contract['pkg']}"
edition = "2024.beta"

[dependencies]

[addresses]
{contract['addr']} = "0x0"
"""


def write_package(output_dir, contract, move_toml, move_sources):
    """Write Move.toml and source files to the output directory."""
    # Move.toml
    toml_content = move_toml if move_toml else generate_fallback_toml(contract)
    (output_dir / "Move.toml").write_text(toml_content + "\n")

    # Source files
    sources_dir = output_dir / "sources"
    if move_sources:
        for f in sources_dir.glob("*.move"):
            f.unlink()
        for filename, content in move_sources.items():
            (sources_dir / filename).write_text(content + "\n")


def update_package(output_dir, new_toml, new_sources):
    """Update only the files present in the fix response."""
    if new_toml:
        (output_dir / "Move.toml").write_text(new_toml + "\n")
    if new_sources:
        sources_dir = output_dir / "sources"
        for f in sources_dir.glob("*.move"):
            f.unlink()
        for filename, content in new_sources.items():
            (sources_dir / filename).write_text(content + "\n")


# ====================== Build & Test ======================

def run_sui(cmd, cwd, timeout=120):
    """Run a sui CLI command and return the CompletedProcess."""
    try:
        return subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        class _Timeout:
            returncode = 1
            stdout = ""
            stderr = "Command timed out after 120s"
        return _Timeout()


def call_api(client, messages, retries=3):
    """Call the Anthropic API with retry logic."""
    for attempt in range(retries):
        try:
            response = client.messages.create(
                model=MODEL_ID,
                max_tokens=MAX_TOKENS,
                messages=messages,
                temperature=TEMPERATURE,
            )
            return response.content[0].text
        except anthropic.RateLimitError:
            wait = 30 * (attempt + 1)
            print(f"    Rate limited, waiting {wait}s...")
            time.sleep(wait)
        except anthropic.APIError as e:
            if attempt < retries - 1:
                print(f"    API error ({e}), retrying...")
                time.sleep(5)
            else:
                raise
    raise RuntimeError("API call failed after retries")


# ====================== Main Pipeline ======================

def translate_contract(client, contract):
    """Full translation pipeline for a single contract."""
    dir_name = contract["dir"]
    print(f"\n{'='*60}")
    print(f"  {dir_name}")
    print(f"{'='*60}")

    # ---- Setup directories ----
    output_dir = OUTPUT_DIR / dir_name
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "sources").mkdir(exist_ok=True)
    (output_dir / "tests").mkdir(exist_ok=True)
    # Remove stale build artifacts
    build_dir = output_dir / "build"
    if build_dir.exists():
        shutil.rmtree(build_dir)
    lock_file = output_dir / "Move.lock"
    if lock_file.exists():
        lock_file.unlink()

    # ---- Read inputs ----
    solidity_code = (SOLIDITY_DIR / dir_name / contract["sol"]).read_text()

    # ================================================================
    # Phase 1: Initial Translation
    # ================================================================
    print("  Phase 1: Initial translation...")

    user_msg = f"""{TRANSLATION_PROMPT}

Here is the Solidity contract to translate to Sui Move:

```solidity
{solidity_code}
```

IMPORTANT — package structure requirements:
- Package name in Move.toml: "{contract['pkg']}"
- Address in Move.toml [addresses] section: {contract['addr']} = "0x0"
- Edition: "2024.beta"
- Do NOT add explicit Sui framework git dependencies. Leave the [dependencies] section empty (the Sui framework is included automatically by the sui CLI).

Provide the complete Move.toml in a ```toml code block, then all .move source files each in their own ```move code block.
Do NOT include test files — those will be supplied separately.
"""

    messages = [{"role": "user", "content": user_msg}]
    reply = call_api(client, messages)
    messages.append({"role": "assistant", "content": reply})

    move_toml, move_sources = parse_response_files(reply, contract)
    write_package(output_dir, contract, move_toml, move_sources)

    src_names = list(move_sources.keys()) if move_sources else []
    print(f"    Move.toml: {'✓' if move_toml else '✗ (fallback)'}")
    print(f"    Sources:   {src_names}")

    # ================================================================
    # Phase 2: Compilation Fix Iterations (up to 5)
    # ================================================================
    build_ok = False
    for i in range(MAX_COMPILE_ITERATIONS):
        result = run_sui(["sui", "move", "build"], output_dir)
        combined = result.stdout + result.stderr

        if result.returncode == 0:
            print(f"  ✅ Build succeeded (attempt {i+1})")
            build_ok = True
            break

        print(f"  ❌ Build failed (attempt {i+1}/{MAX_COMPILE_ITERATIONS})")

        error_snippet = combined[-4000:]
        messages.append({
            "role": "user",
            "content": (
                f"Fix the error:\n\n{error_snippet}\n\n"
                "Provide the complete fixed files. "
                "Move.toml in a ```toml block, source files each in a ```move block."
            ),
        })

        reply = call_api(client, messages)
        messages.append({"role": "assistant", "content": reply})

        new_toml, new_sources = parse_response_files(reply, contract)
        update_package(output_dir, new_toml, new_sources)

    if not build_ok:
        # One final build check
        result = run_sui(["sui", "move", "build"], output_dir)
        if result.returncode == 0:
            build_ok = True
            print("  ✅ Build succeeded (final check)")

    # ================================================================
    # Phase 3: Copy Reference Tests
    # ================================================================
    print("  Phase 3: Copying reference tests...")
    ref_test_src = REFERENCE_DIR / dir_name / "tests" / contract["ref_test"]
    test_dst = output_dir / "tests" / contract["ref_test"]
    if ref_test_src.exists():
        shutil.copy2(ref_test_src, test_dst)
        print(f"    → {contract['ref_test']}")

    # ================================================================
    # Phase 4: Test Fix Iterations (up to 2)
    # ================================================================
    test_ok = False
    for i in range(MAX_TEST_ITERATIONS):
        result = run_sui(["sui", "move", "test"], output_dir)
        combined = result.stdout + result.stderr

        if result.returncode == 0:
            m = re.search(r"Total tests: (\d+); passed: (\d+); failed: (\d+)", combined)
            info = f"{m.group(2)}/{m.group(1)}" if m else "OK"
            print(f"  ✅ Tests passed (attempt {i+1}): {info}")
            test_ok = True
            break

        print(f"  ❌ Tests failed (attempt {i+1}/{MAX_TEST_ITERATIONS})")

        error_snippet = combined[-4000:]

        messages.append({
            "role": "user",
            "content": f"Fix the failing test cases: {error_snippet}",
        })

        reply = call_api(client, messages)
        messages.append({"role": "assistant", "content": reply})

        new_toml, new_sources = parse_response_files(reply, contract)
        update_package(output_dir, new_toml, new_sources)

    if not test_ok:
        result = run_sui(["sui", "move", "test"], output_dir)
        if result.returncode == 0:
            test_ok = True

    return {"contract": dir_name, "build": build_ok, "test": test_ok}


# ====================== Entry Point ======================

def main():
    print("=" * 60)
    print("  CLAUDE OPUS 4.5 — BENCHMARK TRANSLATION PIPELINE")
    print("=" * 60)
    print(f"  Model:     {MODEL_ID}")
    print(f"  Output:    {OUTPUT_DIR}")
    print(f"  Contracts: {len(CONTRACTS)}")
    print(f"  Started:   {datetime.now().isoformat()}")
    print()

    OUTPUT_DIR.mkdir(exist_ok=True)
    client = anthropic.Anthropic(api_key=API_KEY)

    results = []
    for contract in CONTRACTS:
        try:
            r = translate_contract(client, contract)
            results.append(r)
        except Exception as e:
            print(f"  ⚠️  Error: {e}")
            results.append({"contract": contract["dir"], "build": False, "test": False, "error": str(e)})

    # ---- Summary ----
    print(f"\n{'='*60}")
    print("  RESULTS")
    print(f"{'='*60}")
    builds = sum(1 for r in results if r["build"])
    tests  = sum(1 for r in results if r["test"])
    for r in results:
        b = "✅" if r["build"] else "❌"
        t = "✅" if r["test"]  else "❌"
        err = f"  ({r['error']})" if "error" in r else ""
        print(f"  {r['contract']:25s}  build {b}   test {t}{err}")
    print(f"\n  Compilation: {builds}/{len(results)}")
    print(f"  Tests:       {tests}/{len(results)}")
    print(f"  Finished:    {datetime.now().isoformat()}")


if __name__ == "__main__":
    main()
