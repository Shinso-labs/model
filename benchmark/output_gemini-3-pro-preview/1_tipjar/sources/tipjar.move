module tipjar::tip_jar {
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// TipJar object that holds the state
    public struct TipJar has key {
        id: UID,
        owner: address,
        total_tips_received: u64,
        tip_count: u64,
    }

    /// Capability object for admin functions
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Event emitted when TipJar is created
    public struct TipCreated has copy, drop {
        owner: address,
    }

    /// Event emitted when a tip is sent
    public struct TipSent has copy, drop {
        tipper: address,
        amount: u64,
        total_tips: u64,
        tip_count: u64,
    }

    /// Initialize the TipJar and create AdminCap
    fun init(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);

        // Create and share the TipJar object
        let tip_jar = TipJar {
            id: object::new(ctx),
            owner,
            total_tips_received: 0,
            tip_count: 0,
        };

        // Create admin capability for owner
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        // Emit creation event
        event::emit(TipCreated { owner });

        // Transfer objects to sender
        transfer::share_object(tip_jar);
        transfer::transfer(admin_cap, owner);
    }

    /// Send a tip to the TipJar owner
    /// Requires a Coin<SUI> with the tip amount
    public entry fun send_tip(tip_jar: &mut TipJar, tip_coin: Coin<sui::sui::SUI>, ctx: &mut TxContext) {
        let tip_amount = coin::value(&tip_coin);
        assert!(tip_amount > 0, 1); // Invalid tip amount

        // Transfer the tip amount to owner
        let owner_coin = coin::split(&mut tip_coin, tip_amount);
        transfer::public_transfer(owner_coin, tip_jar.owner);

        // Update TipJar state
        tip_jar.total_tips_received = tip_jar.total_tips_received + tip_amount;
        tip_jar.tip_count = tip_jar.tip_count + 1;

        // Emit tip event
        event::emit(TipSent {
            tipper: tx_context::sender(ctx),
            amount: tip_amount,
            total_tips: tip_jar.total_tips_received,
            tip_count: tip_jar.tip_count,
        });

        // Return remaining coin (if any) to sender
        if (coin::value(&tip_coin) > 0) {
            transfer::public_transfer(tip_coin, tx_context::sender(ctx));
        }
    }

    /// Owner can withdraw any funds (though in Sui, funds are handled via coins)
    /// This function is mainly for demonstration of capability pattern
    public entry fun withdraw(_: &AdminCap, ctx: &mut TxContext) {
        // In Sui, withdrawal would typically be handled by the owner
        // transferring their own coins. This function demonstrates the
        // capability pattern for admin functions.
        assert!(true, 0); // Placeholder - actual withdrawal handled via coin transfers
    }

    /// Check if a given address is the owner
    public fun is_owner(tip_jar: &TipJar, addr: address): bool {
        addr == tip_jar.owner
    }

    /// Get total tips received
    public fun total_tips(tip_jar: &TipJar): u64 {
        tip_jar.total_tips_received
    }

    /// Get tip count
    public fun tip_count(tip_jar: &TipJar): u64 {
        tip_jar.tip_count
    }
}