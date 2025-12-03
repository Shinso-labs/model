module tipjar::tip_jar;

use sui::coin::{Self, Coin};
use sui::event;
use sui::sui::SUI;

public struct TipJar has key {
    id: UID,
    owner: address,
    total_tips_received: u64,
    tip_count: u64
}

public struct TipSend has copy, drop {
    tipper: address,
    amount: u64,
    total_tips: u64,
    tip_count: u64
}

public struct TipCreated has copy, drop {
    tip_jar_id: ID,
    owner: address
}

const InvalidTipAmount: u64 = 1;

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

    transfer::share_object(tip_jar);
}

public fun send_tip(tip_jar: &mut TipJar, payment: Coin<SUI>, ctx: &mut TxContext) {
    let tip_amount = coin::value(&payment);

    assert!(tip_amount > 0, InvalidTipAmount);

    transfer::public_transfer(payment, tip_jar.owner);

    tip_jar.total_tips_received = tip_jar.total_tips_received + tip_amount;
    tip_jar.tip_count = tip_jar.tip_count + 1;

    event::emit(TipSend {
        tipper: ctx.sender(),
        amount: tip_amount,
        total_tips: tip_jar.total_tips_received,
        tip_count: tip_jar.tip_count
    });
}

public fun get_total_tips(tip_jar: &TipJar): u64 {
    tip_jar.total_tips_received
}

public fun get_tip_count(tip_jar: &TipJar): u64 {
    tip_jar.tip_count
}

public fun get_owner(tip_jar: &TipJar): address {
    tip_jar.owner
}

public fun is_owner(tip_jar: &TipJar, addr: address): bool {
    tip_jar.owner == addr
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}