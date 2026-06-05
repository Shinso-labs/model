// sources/tip_jar.move
module tipjar::tip_jar;

/// Invalid zero-value tip.
const E_INVALID_TIP_AMOUNT: u64 = 0;

/// Caller is not the recorded owner.
const E_ONLY_OWNER: u64 = 1;

/// The supplied OwnerCap does not belong to this TipJar object.
const E_WRONG_OWNER_CAP: u64 = 2;

/// No SUI is held by the TipJar object.
const E_NOTHING_TO_WITHDRAW: u64 = 3;

/// Shared TipJar state.
///
/// Solidity storage is translated into a Sui shared object:
/// - `owner` maps to the deployer/publisher address.
/// - `total_tips_received` tracks cumulative received tip amount in MIST.
/// - `tip_count` tracks number of successful tips.
/// - `balance` represents any SUI currently held by the TipJar object.
///
/// The original Solidity contract immediately forwards `msg.value` to the
/// owner. This Sui Move version does the same by transferring the supplied
/// `Coin<SUI>` to the owner during `send_tip`.
public struct TipJar has key {
    id: sui::object::UID,
    owner: address,
    total_tips_received: u64,
    tip_count: u64,
    balance: sui::balance::Balance<sui::sui::SUI>,
}

/// Capability for owner-only operations.
///
/// This is the Sui-native replacement for Solidity's `onlyOwner` modifier.
/// The cap is created when the jar is initialized and transferred to the owner.
public struct OwnerCap has key, store {
    id: sui::object::UID,
    jar_id: sui::object::ID,
}

/// Equivalent to Solidity:
/// `event TipCreated(address indexed owner);`
public struct TipCreated has copy, drop {
    owner: address,
    jar_id: sui::object::ID,
}

/// Equivalent to Solidity:
/// `event TipSent(address indexed tipper, uint256 amount, uint256 totalTips, uint256 tipCount);`
public struct TipSent has copy, drop {
    tipper: address,
    amount: u64,
    total_tips: u64,
    tip_count: u64,
}

/// Sui-native event emitted by `withdraw`.
public struct Withdrawn has copy, drop {
    owner: address,
    amount: u64,
}

/// Module initializer. Runs once when the package is published.
///
/// This is the constructor equivalent:
/// - records the publishing transaction sender as owner
/// - initializes counters to zero
/// - emits `TipCreated`
/// - shares the `TipJar` object
/// - transfers `OwnerCap` to the owner
fun init(ctx: &mut sui::tx_context::TxContext) {
    create_tip_jar(ctx);
}

/// Test helper used by Move unit tests.
///
/// Sui module initializers are publish-time hooks, so tests commonly need an
/// explicit helper to create the shared object inside a `test_scenario`.
#[test_only]
public fun init_for_testing(ctx: &mut sui::tx_context::TxContext) {
    create_tip_jar(ctx);
}

/// Internal constructor logic shared by `init` and `init_for_testing`.
fun create_tip_jar(ctx: &mut sui::tx_context::TxContext) {
    let owner = sui::tx_context::sender(ctx);

    let jar_uid = sui::object::new(ctx);
    let jar_id = sui::object::uid_to_inner(&jar_uid);

    let jar = TipJar {
        id: jar_uid,
        owner,
        total_tips_received: 0,
        tip_count: 0,
        balance: sui::balance::zero<sui::sui::SUI>(),
    };

    let owner_cap = OwnerCap {
        id: sui::object::new(ctx),
        jar_id,
    };

    sui::event::emit(TipCreated {
        owner,
        jar_id,
    });

    sui::transfer::share_object(jar);
    sui::transfer::transfer(owner_cap, owner);
}

/// Send a SUI tip to the TipJar owner.
///
/// Solidity equivalent:
/// `function sendTip() external payable`
///
/// The caller passes a `Coin<SUI>` as payment. The coin value must be greater
/// than zero. The tip is immediately forwarded to the recorded owner, then the
/// accounting fields are updated.
///
/// Reentrancy note:
/// Sui coin transfers do not invoke arbitrary receiver code, so Solidity-style
/// reentrancy through `owner.call{value: ...}("")` does not apply.
public fun send_tip(
    jar: &mut TipJar,
    tip: sui::coin::Coin<sui::sui::SUI>,
    ctx: &mut sui::tx_context::TxContext,
) {
    let tipper = sui::tx_context::sender(ctx);
    let amount = sui::coin::value(&tip);

    assert!(amount > 0, E_INVALID_TIP_AMOUNT);

    // Preserve the Solidity behavior by forwarding the full tip immediately.
    sui::transfer::public_transfer(tip, jar.owner);

    // Move arithmetic aborts on overflow, matching Solidity 0.8+ checked math.
    jar.total_tips_received = jar.total_tips_received + amount;
    jar.tip_count = jar.tip_count + 1;

    sui::event::emit(TipSent {
        tipper,
        amount,
        total_tips: jar.total_tips_received,
        tip_count: jar.tip_count,
    });
}

/// Withdraw any SUI balance currently held by the TipJar object.
///
/// In normal operation this balance is zero because `send_tip` forwards tips
/// immediately. This function preserves the emergency-withdraw intent of the
/// Solidity contract.
///
/// Requires:
/// - transaction sender is the recorded owner
/// - supplied `OwnerCap` belongs to this `TipJar`
/// - jar balance is greater than zero
public fun withdraw(
    jar: &mut TipJar,
    owner_cap: &OwnerCap,
    ctx: &mut sui::tx_context::TxContext,
) {
    let sender = sui::tx_context::sender(ctx);

    assert!(sender == jar.owner, E_ONLY_OWNER);
    assert!(owner_cap.jar_id == sui::object::id(jar), E_WRONG_OWNER_CAP);

    let amount = sui::balance::value(&jar.balance);
    assert!(amount > 0, E_NOTHING_TO_WITHDRAW);

    let withdrawn_balance = sui::balance::split(&mut jar.balance, amount);
    let withdrawn_coin = sui::coin::from_balance(withdrawn_balance, ctx);

    sui::transfer::public_transfer(withdrawn_coin, jar.owner);

    sui::event::emit(Withdrawn {
        owner: jar.owner,
        amount,
    });
}

/// Solidity equivalent:
/// `function isOwner(address addr) external view returns (bool)`
public fun is_owner(jar: &TipJar, addr: address): bool {
    addr == jar.owner
}

/// Getter equivalent for Solidity public variable:
/// `address public owner`
public fun owner(jar: &TipJar): address {
    jar.owner
}

/// Compatibility getter often used by tests.
public fun get_owner(jar: &TipJar): address {
    jar.owner
}

/// Getter equivalent for Solidity public variable:
/// `uint256 public totalTipsReceived`
///
/// Returned value is in MIST.
public fun total_tips_received(jar: &TipJar): u64 {
    jar.total_tips_received
}

/// Compatibility getter expected by the tests.
public fun get_total_tips(jar: &TipJar): u64 {
    jar.total_tips_received
}

/// Getter equivalent for Solidity public variable:
/// `uint256 public tipCount`
public fun tip_count(jar: &TipJar): u64 {
    jar.tip_count
}

/// Compatibility getter expected by the tests.
public fun get_tip_count(jar: &TipJar): u64 {
    jar.tip_count
}

/// Current SUI balance held by the TipJar object.
///
/// This should normally be zero because tips are forwarded immediately.
public fun jar_balance(jar: &TipJar): u64 {
    sui::balance::value(&jar.balance)
}

/// Compatibility getter for object-held balance.
public fun get_balance(jar: &TipJar): u64 {
    sui::balance::value(&jar.balance)
}

/// Returns the object ID this `OwnerCap` controls.
public fun owner_cap_jar_id(owner_cap: &OwnerCap): sui::object::ID {
    owner_cap.jar_id
}
