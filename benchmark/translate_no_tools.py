#!/usr/bin/env python3
"""
Multi-provider benchmark translation pipeline (no tool calls).

Same methodology as translate_opus.py / translate_solmover.py — 5× compile-fix
+ 2× test-fix iterations driven by feeding `sui move build` / `sui move test`
output back as a user message — but generalized across providers and with an
explicit no-tools guarantee:

  * No `tools=` parameter passed to any API. The model only sees user messages.
  * No Anthropic server-side tools (web_search, code_execution, etc.).
  * No OpenAI function calling / `tool_choice`.
  * No MCP, no extended-thinking config.

The iterative compile/test loop is part of the BENCHMARK methodology, not a
tool call: the *script* runs `sui` and posts the output as a chat message;
the model never invokes a tool. This levels the field with Solmover, which
has no tool-calling capability at all.

Usage:
    export ANTHROPIC_API_KEY=...
    export OPENAI_API_KEY=...
    export SOLMOVER_API_KEY=...        # OVH key for the hosted Solmover endpoint
    export OPENAI_MODEL_ID=...         # optional: override "latest GPT" id
    python translate_no_tools.py                       # all configured models
    python translate_no_tools.py claude-4.7-opus       # subset

Then score: python run_benchmark.py
"""

import os
import re
import sys
import shutil
import subprocess
import time
from pathlib import Path
from datetime import datetime

import anthropic
from openai import OpenAI


BENCHMARK_DIR = Path(__file__).resolve().parent
SOLIDITY_DIR = BENCHMARK_DIR / "solidity"
REFERENCE_DIR = BENCHMARK_DIR / "sui_move"

CONTRACTS = [
    {"dir": "0_hello_world",    "sol": "HelloWorld.sol",    "pkg": "hello_world",    "addr": "hello_world",    "ref_test": "hello_world_tests.move"},
    {"dir": "1_tipjar",         "sol": "Tipjar.sol",        "pkg": "tipjar",         "addr": "tipjar",         "ref_test": "tipjar_tests.move"},
    {"dir": "2_guestbook",      "sol": "Guestbook.sol",     "pkg": "guestbook",      "addr": "guestbook",      "ref_test": "guestbook_tests.move"},
    {"dir": "3_todo_list",      "sol": "TodoList.sol",      "pkg": "todo_list",      "addr": "todo_list",      "ref_test": "todo_list_tests.move"},
    {"dir": "4_simple_coin",    "sol": "Coin.sol",          "pkg": "coin",           "addr": "coin",           "ref_test": "coin_tests.move"},
    {"dir": "5_counter",        "sol": "Counter.sol",       "pkg": "counter",        "addr": "counter",        "ref_test": "counter_tests.move"},
    {"dir": "6_weather_oracle", "sol": "WeatherOracle.sol", "pkg": "weather_oracle", "addr": "weather_oracle", "ref_test": "weather_oracle_tests.move"},
]

# ====================== Models ======================
# Defaults: just the *new* models being added to the lineup. The legacy
# 7 models in run_benchmark.py keep their existing output dirs from the
# 2026-01-30 run (same methodology — also no tools).

MODELS = [
    {
        "name": "claude-4.7-opus",
        "provider": "anthropic",
        "model_id": "claude-opus-4-7",
        "max_tokens": 8192,
    },
    {
        "name": "gpt-5.5",
        "provider": "openai",
        # Override with OPENAI_MODEL_ID env var if a newer GPT lands.
        "model_id": os.environ.get("OPENAI_MODEL_ID", "gpt-5.5"),
        "max_tokens": 8192,
    },
    # Re-run examples — uncomment to include in the new run:
    # {
    #     "name": "solmover_2026q2",
    #     "provider": "openai_compat",
    #     "model_id": None,  # auto-discovered via /v1/models
    #     # Set the hosted endpoint via the SOLMOVER_BASE_URL env var
    #     # (e.g. the OVH AI deployment URL) — do not hardcode it here.
    #     "base_url": os.environ.get("SOLMOVER_BASE_URL"),
    #     "max_tokens": 16384,
    # },
    # {
    #     "name": "claude-4.5-opus_2026q2",
    #     "provider": "anthropic",
    #     "model_id": "claude-opus-4-5-20251101",
    #     "max_tokens": 8192,
    # },
]

TEMPERATURE = 0.2
MAX_COMPILE_ITERATIONS = 5
MAX_TEST_ITERATIONS = 2

# ====================== Translation Prompt ======================
# Verbatim from translate_opus.py / translate_solmover.py for fairness.

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


# ====================== Response parsing ======================
# Ported from translate_solmover.py (handles bare Move blocks without module
# decls, filters cross-package noise — translate_opus.py's parser is simpler
# and misses bare blocks).

def extract_code_blocks(text):
    blocks = []
    pattern = r"```(\w*)\n(.*?)```"
    for match in re.finditer(pattern, text, re.DOTALL):
        blocks.append({
            "lang": match.group(1).lower(),
            "code": match.group(2).strip(),
        })
    return blocks


def _looks_like_move_source(code):
    indicators = [
        r"\bstruct\s+\w+\s+has\s+",
        r"\bpublic\s+(entry\s+)?fun\b",
        r"\buse\s+sui::",
        r"\bimport\s+0x[0-9a-fA-F]+::",
        r"\bfun\s+init\s*\(",
    ]
    return sum(1 for pat in indicators if re.search(pat, code)) >= 2


def _is_test_module(code):
    if code.lstrip().startswith("#[test_only]"):
        return True
    m = re.search(r"\bmodule\s+(?:\w+::)?(\w+)", code)
    if m and "test" in m.group(1).lower():
        return True
    head = code[:300].lower()
    if "test suite" in head or "test module" in head:
        return True
    return False


def parse_response_files(text, contract):
    blocks = extract_code_blocks(text)
    move_toml = None
    move_sources = {}
    first_bare_block = None

    for block in blocks:
        code = block["code"]
        lang = block["lang"]
        has_package = "[package]" in code
        has_module_sui = bool(re.search(r"\bmodule\s+\w+::", code))
        has_module_plain = bool(re.search(r"\bmodule\s+\w+\s*\{", code))

        if lang in ("toml", "") and has_package:
            move_toml = code
            continue

        if lang not in ("move", "rust", ""):
            continue

        if _is_test_module(code):
            continue

        if has_module_sui:
            m = re.search(r"module\s+(\w+)::(\w+)", code)
            if m:
                mod_addr, mod_name = m.group(1), m.group(2)
                if mod_addr != contract["addr"] and mod_addr not in ("0x0", "0x1"):
                    continue
                move_sources[mod_name + ".move"] = code
            else:
                move_sources["source.move"] = code
        elif has_module_plain:
            m = re.search(r"module\s+(\w+)\s*\{", code)
            mod_name = m.group(1) if m else contract["pkg"]
            code = re.sub(
                r"module\s+\w+\s*\{",
                f"module {contract['addr']}::{mod_name} {{",
                code,
                count=1,
            )
            move_sources[mod_name + ".move"] = code
        elif _looks_like_move_source(code) and first_bare_block is None:
            first_bare_block = code

    if not move_sources and first_bare_block:
        wrapped = f"module {contract['addr']}::{contract['pkg']} {{\n{first_bare_block}\n}}"
        move_sources[contract["pkg"] + ".move"] = wrapped

    return move_toml, move_sources


def fallback_toml(contract):
    return f"""[package]
name = "{contract['pkg']}"
edition = "2024.beta"

[dependencies]

[addresses]
{contract['addr']} = "0x0"
"""


def write_package(output_dir, contract, move_toml, move_sources, force_canonical_toml=True):
    """Initial package write. Always force canonical Move.toml — many models
    add wrong-framework deps (Aptos, hardcoded git revs) that break the build.
    """
    (output_dir / "Move.toml").write_text(fallback_toml(contract))
    sources_dir = output_dir / "sources"
    if move_sources:
        for f in sources_dir.glob("*.move"):
            f.unlink()
        for filename, content in move_sources.items():
            (sources_dir / filename).write_text(content + "\n")


def update_package(output_dir, new_toml, new_sources):
    """Iteration update. Ignore new_toml (we keep the canonical one). Replace
    sources only if the model produced new ones."""
    if new_sources:
        sources_dir = output_dir / "sources"
        for f in sources_dir.glob("*.move"):
            f.unlink()
        for filename, content in new_sources.items():
            (sources_dir / filename).write_text(content + "\n")


# ====================== Provider clients ======================

def _require_env(name):
    val = os.environ.get(name)
    if not val:
        raise RuntimeError(f"{name} not set in environment")
    return val


def get_client(provider, base_url=None):
    if provider == "anthropic":
        return anthropic.Anthropic(api_key=_require_env("ANTHROPIC_API_KEY"))
    if provider == "openai":
        return OpenAI(api_key=_require_env("OPENAI_API_KEY"))
    if provider == "openai_compat":
        return OpenAI(api_key=_require_env("SOLMOVER_API_KEY"), base_url=base_url)
    raise ValueError(f"Unknown provider: {provider}")


def discover_model(client):
    models = list(client.models.list())
    if not models:
        raise RuntimeError("No models found at /v1/models")
    return models[0].id


# Per-process caches for parameter quirks discovered at runtime.
# - Newer Anthropic models (claude-opus-4-7) deprecated `temperature`.
# - Newer OpenAI reasoning models (gpt-5.x) renamed `max_tokens` →
#   `max_completion_tokens` and may also reject `temperature`.
_NO_TEMPERATURE = set()
_USE_MAX_COMPLETION_TOKENS = set()


def call_api(provider, client, model_id, messages, max_tokens, retries=4):
    """Call the model. NO tools, NO tool_choice, NO server-side tools, NO
    function calling — pure multi-turn text completion."""
    for attempt in range(retries):
        try:
            include_temp = model_id not in _NO_TEMPERATURE
            if provider == "anthropic":
                kwargs = dict(model=model_id, max_tokens=max_tokens, messages=messages)
                if include_temp:
                    kwargs["temperature"] = TEMPERATURE
                r = client.messages.create(**kwargs)
                return r.content[0].text
            else:
                kwargs = dict(model=model_id, messages=messages)
                if model_id in _USE_MAX_COMPLETION_TOKENS:
                    kwargs["max_completion_tokens"] = max_tokens
                else:
                    kwargs["max_tokens"] = max_tokens
                if include_temp:
                    kwargs["temperature"] = TEMPERATURE
                r = client.chat.completions.create(**kwargs)
                return r.choices[0].message.content
        except Exception as e:
            err = str(e).lower()
            # max_tokens → max_completion_tokens for newer OpenAI models.
            if (
                "max_tokens" in err
                and ("not supported" in err or "unsupport" in err or "use 'max_completion_tokens'" in err)
            ):
                if model_id not in _USE_MAX_COMPLETION_TOKENS:
                    print(f"    [info] {model_id} requires max_completion_tokens — switching")
                    _USE_MAX_COMPLETION_TOKENS.add(model_id)
                    continue
            # temperature deprecated/unsupported → drop it.
            if "temperature" in err and ("deprecat" in err or "unsupport" in err or "not supported" in err):
                if model_id not in _NO_TEMPERATURE:
                    print(f"    [info] {model_id} rejects temperature — dropping it for this run")
                    _NO_TEMPERATURE.add(model_id)
                    continue
            if "rate" in err and "limit" in err:
                wait = 30 * (attempt + 1)
                print(f"    Rate limited, waiting {wait}s...")
                time.sleep(wait)
            elif attempt < retries - 1:
                print(f"    API error ({e}), retrying in 5s...")
                time.sleep(5)
            else:
                raise
    raise RuntimeError("API call failed after retries")


# ====================== Build & Test ======================

def run_sui(cmd, cwd, timeout=120):
    try:
        return subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        class _T:
            returncode = 1
            stdout = ""
            stderr = "Command timed out after 120s"
        return _T()


# ====================== Per-contract pipeline ======================

def translate_one(provider, client, model_id, contract, output_dir, max_tokens):
    contract_out = output_dir / contract["dir"]
    contract_out.mkdir(parents=True, exist_ok=True)
    (contract_out / "sources").mkdir(exist_ok=True)
    (contract_out / "tests").mkdir(exist_ok=True)
    bdir = contract_out / "build"
    if bdir.exists():
        shutil.rmtree(bdir)
    lock = contract_out / "Move.lock"
    if lock.exists():
        lock.unlink()

    print(f"\n  {'='*58}")
    print(f"  {contract['dir']}")
    print(f"  {'='*58}")

    sol = (SOLIDITY_DIR / contract["dir"] / contract["sol"]).read_text()

    # ---- Phase 1: Initial translation ----
    print("  Phase 1: initial translation...")
    user_msg = f"""{TRANSLATION_PROMPT}

Here is the Solidity contract to translate to Sui Move:

```solidity
{sol}
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
    t0 = time.time()
    try:
        reply = call_api(provider, client, model_id, messages, max_tokens)
    except Exception as e:
        print(f"    ⚠️  initial call failed: {e}")
        return {"contract": contract["dir"], "build": False, "test": False, "error": str(e)}
    print(f"    ← {len(reply)} chars in {time.time()-t0:.1f}s")
    messages.append({"role": "assistant", "content": reply})

    move_toml, move_sources = parse_response_files(reply, contract)
    write_package(contract_out, contract, move_toml, move_sources)

    # ---- Phase 2: Compile fix iterations ----
    build_ok = False
    for i in range(MAX_COMPILE_ITERATIONS):
        result = run_sui(["sui", "move", "build"], contract_out)
        combined = result.stdout + result.stderr
        if result.returncode == 0:
            print(f"  ✅ Build succeeded (attempt {i+1})")
            build_ok = True
            break
        print(f"  ❌ Build failed (attempt {i+1}/{MAX_COMPILE_ITERATIONS})")
        snippet = combined[-4000:]
        messages.append({
            "role": "user",
            "content": (
                f"Fix the error:\n\n{snippet}\n\n"
                "Provide the complete fixed files. "
                "Move.toml in a ```toml block, source files each in a ```move block."
            ),
        })
        try:
            reply = call_api(provider, client, model_id, messages, max_tokens)
        except Exception as e:
            print(f"    ⚠️  fix call failed: {e}")
            break
        messages.append({"role": "assistant", "content": reply})
        new_toml, new_sources = parse_response_files(reply, contract)
        update_package(contract_out, new_toml, new_sources)

    if not build_ok:
        result = run_sui(["sui", "move", "build"], contract_out)
        if result.returncode == 0:
            build_ok = True
            print("  ✅ Build succeeded (final check)")

    # ---- Phase 3: Copy reference tests ----
    print("  Phase 3: copying reference tests...")
    ref_test_src = REFERENCE_DIR / contract["dir"] / "tests" / contract["ref_test"]
    test_dst = contract_out / "tests" / contract["ref_test"]
    if ref_test_src.exists():
        shutil.copy2(ref_test_src, test_dst)

    # ---- Phase 4: Test fix iterations ----
    test_ok = False
    for i in range(MAX_TEST_ITERATIONS):
        result = run_sui(["sui", "move", "test"], contract_out)
        combined = result.stdout + result.stderr
        if result.returncode == 0:
            m = re.search(r"Total tests: (\d+); passed: (\d+); failed: (\d+)", combined)
            info = f"{m.group(2)}/{m.group(1)}" if m else "OK"
            print(f"  ✅ Tests passed (attempt {i+1}): {info}")
            test_ok = True
            break
        print(f"  ❌ Tests failed (attempt {i+1}/{MAX_TEST_ITERATIONS})")
        snippet = combined[-4000:]
        messages.append({"role": "user", "content": f"Fix the failing test cases: {snippet}"})
        try:
            reply = call_api(provider, client, model_id, messages, max_tokens)
        except Exception as e:
            print(f"    ⚠️  fix call failed: {e}")
            break
        messages.append({"role": "assistant", "content": reply})
        new_toml, new_sources = parse_response_files(reply, contract)
        update_package(contract_out, new_toml, new_sources)

    if not test_ok:
        result = run_sui(["sui", "move", "test"], contract_out)
        if result.returncode == 0:
            test_ok = True

    return {"contract": contract["dir"], "build": build_ok, "test": test_ok}


# ====================== Per-model pipeline ======================

def run_model(model_cfg):
    name = model_cfg["name"]
    provider = model_cfg["provider"]
    output_dir = BENCHMARK_DIR / f"output_{name}"
    output_dir.mkdir(exist_ok=True)

    print(f"\n{'='*70}")
    print(f"  MODEL: {name}  ({provider})")
    print(f"  Output: {output_dir}")
    print(f"{'='*70}")

    client = get_client(provider, base_url=model_cfg.get("base_url"))
    model_id = model_cfg["model_id"] or discover_model(client)
    print(f"  Endpoint model id: {model_id}")
    print(f"  Iterations: {MAX_COMPILE_ITERATIONS} compile + {MAX_TEST_ITERATIONS} test")

    results = []
    for contract in CONTRACTS:
        try:
            results.append(
                translate_one(provider, client, model_id, contract, output_dir, model_cfg["max_tokens"])
            )
        except Exception as e:
            print(f"  ⚠️  {contract['dir']} failed: {e}")
            results.append({"contract": contract["dir"], "build": False, "test": False, "error": str(e)})

    print(f"\n  Summary for {name}:")
    builds = sum(1 for r in results if r["build"])
    tests = sum(1 for r in results if r["test"])
    for r in results:
        b = "✅" if r["build"] else "❌"
        t = "✅" if r["test"] else "❌"
        err = f"  ({r['error']})" if "error" in r else ""
        print(f"    {r['contract']:25s}  build {b}   test {t}{err}")
    print(f"  Compilation: {builds}/{len(results)}    Tests: {tests}/{len(results)}")
    return results


def main():
    args = [a for a in sys.argv[1:] if a != "all"]
    if args:
        wanted = set(args)
        models = [m for m in MODELS if m["name"] in wanted]
        unknown = wanted - {m["name"] for m in models}
        if unknown:
            print(f"Unknown model(s): {unknown}")
            print(f"Available: {[m['name'] for m in MODELS]}")
            sys.exit(1)
    else:
        models = MODELS

    print("=" * 70)
    print("  BENCHMARK TRANSLATION (no tools, with iteration loop)")
    print("=" * 70)
    print(f"  Models:    {[m['name'] for m in models]}")
    print(f"  Contracts: {len(CONTRACTS)}")
    print(f"  Started:   {datetime.now().isoformat()}")

    for m in models:
        try:
            run_model(m)
        except Exception as e:
            print(f"\n  ⚠️  Model {m['name']} failed entirely: {e}")

    print(f"\nFinished: {datetime.now().isoformat()}")
    print(f"Next:    cd {BENCHMARK_DIR} && python run_benchmark.py")


if __name__ == "__main__":
    main()
