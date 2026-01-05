module tipjar::tip_jar {
    use std::option::{Self, Option};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, UID};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Abort codes aligned with Solidity require checks.
    const E_ZERO_TIP: u64 = 0;
    const E_NOTHING_TO_WITHDRAW: u64 = 1;

    /// Capability granting owner-only actions.
    public struct OwnerCap has key, store {
        id: UID,
    }

    /// Shared TipJar object holding stats and any residual vault funds.
    public struct TipJar has key {
        id: UID,
        owner: address,
        total_tips: u64,
        tip_count: u64,
        vault: Option<Coin<SUI>>,
    }

    /// Events mirroring Solidity semantics.
    public struct TipCreatedEvent has copy, drop {
        owner: address,
    }

    public struct TipSentEvent has copy, drop {
        tipper: address,
        amount: u64,
        total_tips: u64,
        tip_count: u64,
    }

    /// Runs once on publish: creates TipJar, shares it, and gives OwnerCap to publisher.
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let jar = TipJar {
            id: object::new(ctx),
            owner: sender,
            total_tips: 0,
            tip_count: 0,
            vault: option::none(),
        };
        event::emit(TipCreatedEvent { owner: sender });
        transfer::share_object(jar);
        let cap = OwnerCap { id: object::new(ctx) };
        transfer::public_transfer(cap, sender);
    }

    /// Send a tip in SUI; forwards immediately to the owner and updates stats.
    public entry fun send_tip(jar: &mut TipJar, tip: Coin<SUI>, ctx: &mut TxContext) {
        let amount = coin::value(&tip);
        assert!(amount > 0, E_ZERO_TIP);

        transfer::public_transfer(tip, jar.owner);

        jar.total_tips = jar.total_tips + amount;
        jar.tip_count = jar.tip_count + 1;

        event::emit(TipSentEvent {
            tipper: tx_context::sender(ctx),
            amount,
            total_tips: jar.total_tips,
            tip_count: jar.tip_count,
        });
    }

    /// Owner can withdraw any residual funds stored in the vault (typically empty).
    public entry fun withdraw(jar: &mut TipJar, _cap: &OwnerCap) {
        if (!option::is_some(&jar.vault)) {
            assert!(false, E_NOTHING_TO_WITHDRAW);
        };
        let coin = option::extract(&mut jar.vault);
        transfer::public_transfer(coin, jar.owner);
        jar.vault = option::none();
    }

    /// View helper to check ownership.
    public fun is_owner(jar: &TipJar, addr: address): bool {
        addr == jar.owner
    }
}