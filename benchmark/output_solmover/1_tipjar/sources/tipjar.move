/// Tip jar module - allows users to create a shared tip jar and receive SUI tips
module tipjar::tip_jar;

use sui::coin::{Self, Coin};
use sui::event;
use sui::sui::SUI;

/// Shared tip jar object that tracks tips received
public struct TipJar has key {
    id: UID,
    owner: address,                 // Address that receives tips
    total_tips_received: u64,       // Total SUI received in atomic units
    tip_count: u64                  // Number of tips received
}

/// Event emitted when a tip is sent
public struct TipSend has copy, drop {
    tipper: address,
    amount: u64,
    total_tips: u64,
    tip_count: u64
}

/// Event emitted when a tip jar is created
public struct TipCreated has copy, drop {
    tip_jar_id: ID,
    owner: address
}

/// Error code for invalid tip amounts (zero or negative)
const InvalidTipAmount: u64 = 1;

/// Creates a new shared tip jar for the transaction sender
fun init(ctx: &mut TxContext) {
    let owner = ctx.sender();
    let tip_jar = TipJar {
        id: object::new(ctx),
        owner,
        total_tips_received: 0,
        tip_count: 0
    };

    let tip_jar_id = object::id(&tip_jar);
    
    event::emit(TipCreated {
        tip_jar_id,
        owner
    });

    // Make tip jar shared so anyone can send tips
    transfer::share_object(tip_jar);
}

/// Sends a tip to the jar owner and updates statistics
public fun send_tip(tip_jar: &mut TipJar, payment: Coin<SUI>, ctx: &mut TxContext) {
    let tip_amount = coin::value(&payment);

    assert!(tip_amount > 0, InvalidTipAmount);

    // Transfer tip to jar owner
    transfer::public_transfer(payment, tip_jar.owner);

    // Update tip statistics
    tip_jar.total_tips_received = tip_jar.total_tips_received + tip_amount;
    tip_jar.tip_count = tip_jar.tip_count + 1;

    event::emit(TipSend {
        tipper: ctx.sender(),
        amount: tip_amount,
        total_tips: tip_jar.total_tips_received,
        tip_count: tip_jar.tip_count
    });
}

/// Returns total tips received in atomic units
public fun get_total_tips(tip_jar: &TipJar): u64 {
    tip_jar.total_tips_received
}

/// Returns number of tips received
public fun get_tip_count(tip_jar: &TipJar): u64 {
    tip_jar.tip_count
}

/// Returns the tip jar owner's address
public fun get_owner(tip_jar: &TipJar): address {
    tip_jar.owner
}

/// Checks if the given address is the jar owner
public fun is_owner(tip_jar: &TipJar, addr: address): bool {
    tip_jar.owner == addr
}

/// Test-only function to initialize tip jar in tests
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}