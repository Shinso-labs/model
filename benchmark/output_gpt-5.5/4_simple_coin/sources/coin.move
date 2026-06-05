// sources/coin.move
module coin::coin;

use std::option;
use sui::coin::{Coin, TreasuryCap};
use sui::tx_context::TxContext;

const E_ZERO_ADDRESS: u64 = 1;
const DECIMALS: u8 = 2;

/// Sui coin type for First Coin.
///
/// Tests that use `TreasuryCap<COIN>` or `Coin<COIN>` must import this type with:
/// `use coin::coin::{Self as coin, COIN};`
public struct COIN has drop {}

public struct Minted has copy, drop {
    recipient: address,
    amount: u64,
}

public struct Burned has copy, drop {
    operator: address,
    amount: u64,
}

/// Package initializer.
///
/// Creates:
/// - `TreasuryCap<COIN>`: equivalent to Solidity `TREASURY_ROLE`
/// - `CoinMetadata<COIN>`: name/symbol/decimals metadata
fun init(witness: COIN, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = sui::coin::create_currency(
        witness,
        DECIMALS,
        b"COIN",
        b"First Coin",
        b"First Coin (COIN): Sui-native translation of the Solidity ERC-20.",
        option::none<sui::url::Url>(),
        ctx,
    );

    // Metadata is immutable, matching fixed ERC-20 metadata.
    sui::transfer::public_freeze_object(metadata);

    // Publisher receives mint/burn authority.
    sui::transfer::public_transfer(treasury_cap, sui::tx_context::sender(ctx));
}

/// Test-only initializer used by `sui::test_scenario` tests.
///
/// This creates a fresh `TreasuryCap<COIN>` and transfers it to the scenario sender.
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(COIN {}, ctx);
}

/// Mirrors Solidity `decimals()`.
public fun decimals(): u8 {
    DECIMALS
}

/// Convenience metadata helper.
public fun name(): vector<u8> {
    b"First Coin"
}

/// Convenience metadata helper.
public fun symbol(): vector<u8> {
    b"COIN"
}

/// Mint a `Coin<COIN>` and return it.
///
/// This function is intentionally public and named exactly `mint` because tests call:
/// `coin::mint(&mut treasury_cap, amount, ctx)`.
///
/// Access control is enforced by requiring mutable access to `TreasuryCap<COIN>`.
public fun mint(
    treasury_cap: &mut TreasuryCap<COIN>,
    amount: u64,
    ctx: &mut TxContext,
): Coin<COIN> {
    sui::coin::mint(treasury_cap, amount, ctx)
}

/// Mint and transfer to a recipient.
///
/// Solidity equivalent:
/// `mint(address to, uint256 amount) external onlyRole(TREASURY_ROLE)`
public entry fun mint_to(
    treasury_cap: &mut TreasuryCap<COIN>,
    recipient: address,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(recipient != @0x0, E_ZERO_ADDRESS);

    let minted_coin = sui::coin::mint(treasury_cap, amount, ctx);
    sui::transfer::public_transfer(minted_coin, recipient);

    sui::event::emit(Minted {
        recipient,
        amount,
    });
}

/// Solidity `mintAndTransfer` equivalent.
public entry fun mint_and_transfer(
    treasury_cap: &mut TreasuryCap<COIN>,
    recipient: address,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(recipient != @0x0, E_ZERO_ADDRESS);

    let minted_coin = sui::coin::mint(treasury_cap, amount, ctx);
    sui::transfer::public_transfer(minted_coin, recipient);

    sui::event::emit(Minted {
        recipient,
        amount,
    });
}

/// Burn a `Coin<COIN>`.
///
/// This function is intentionally public and named exactly `burn` because tests call:
/// `coin::burn(&mut treasury_cap, minted_coin)`.
///
/// Sui-native coin burning requires `TreasuryCap<COIN>`, unlike ERC20Burnable where
/// holders can burn balances directly.
public fun burn(
    treasury_cap: &mut TreasuryCap<COIN>,
    coin: Coin<COIN>,
): u64 {
    sui::coin::burn(treasury_cap, coin)
}

/// Entry burn helper that also emits an event.
public entry fun burn_entry(
    treasury_cap: &mut TreasuryCap<COIN>,
    coin: Coin<COIN>,
    ctx: &mut TxContext,
) {
    let amount = sui::coin::burn(treasury_cap, coin);

    sui::event::emit(Burned {
        operator: sui::tx_context::sender(ctx),
        amount,
    });
}
