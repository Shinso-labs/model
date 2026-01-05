module tipjar::tip_jar {
    use sui::coin::{Self as coin, Coin};
    use sui::event;
    use sui::object;
    use sui::object::UID;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context;
    use sui::tx_context::TxContext;

    /// Abort code for zero-amount tips.
    const InvalidTipAmount: u64 = 1;
    const ENOT_OWNER: u64 = 2;
    const ENOTHING_TO_WITHDRAW: u64 = 3;

    /// Shared TipJar object holding owner and aggregate stats.
    public struct TipJar has key {
        id: UID,
        owner: address,
        total_tips_received: u64,
        tip_count: u64,
    }

    /// Emitted once at init.
    public struct TipCreated has copy, drop, store {
        owner: address,
    }

    /// Emitted for each successful tip.
    public struct TipSent has copy, drop, store {
        tipper: address,
        amount: u64,
        total_tips: u64,
        tip_count: u64,
    }

    /// Runs on publish: creates and shares the jar owned by the publisher.
    fun init(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);
        let jar = TipJar {
            id: object::new(ctx),
            owner,
            total_tips_received: 0,
            tip_count: 0,
        };
        event::emit(TipCreated { owner });
        transfer::share_object(jar);
    }

    /// Test-only wrapper to allow init inside test_scenario.
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    /// Send a tip in SUI; forwards funds immediately to the owner and updates stats.
    entry fun send_tip(jar: &mut TipJar, tip: Coin<SUI>, ctx: &mut TxContext) {
        let amount = coin::value(&tip);
        assert!(amount > 0, InvalidTipAmount);

        jar.total_tips_received = jar.total_tips_received + amount;
        jar.tip_count = jar.tip_count + 1;

        event::emit(
            TipSent {
                tipper: tx_context::sender(ctx),
                amount,
                total_tips: jar.total_tips_received,
                tip_count: jar.tip_count,
            },
        );

        transfer::public_transfer(tip, jar.owner);
    }

    /// Owner-only withdrawal hook; aborts if the jar does not hold any coins (typical path, since tips are auto-forwarded).
    entry fun withdraw(jar: &TipJar, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == jar.owner, ENOT_OWNER);
        // No coins are retained in the jar; mirror Solidity's "Nothing to withdraw" revert.
        assert!(false, ENOTHING_TO_WITHDRAW);
    }

    /// Pure helper mirroring the Solidity isOwner view.
    public fun is_owner(jar: &TipJar, addr: address): bool {
        addr == jar.owner
    }

    /// Getter for tip count (used in tests).
    public fun get_tip_count(jar: &TipJar): u64 {
        jar.tip_count
    }

    /// Getter for total tips (used in tests).
    public fun get_total_tips(jar: &TipJar): u64 {
        jar.total_tips_received
    }

    /// Getter for owner (used in tests).
    public fun get_owner(jar: &TipJar): address {
        jar.owner
    }
}