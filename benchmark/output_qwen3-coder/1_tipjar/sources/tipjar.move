module tipjar::tipjar {
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;

    /// TipJar object that stores the state of the contract
    public struct TipJar has key {
        id: UID,
        owner: address,
        total_tips_received: u64,
        tip_count: u64
    }

    /// Capability for admin operations (owner-only functions)
    public struct AdminCap has key, store {
        id: UID
    }

    /// Event emitted when TipJar is created
    public struct TipCreated has copy, drop {
        owner: address
    }

    /// Event emitted when a tip is sent
    public struct TipSent has copy, drop {
        tipper: address,
        amount: u64,
        total_tips: u64,
        tip_count: u64
    }

    /// Error codes
    const EInvalidTipAmount: u64 = 0;

    /// Initialize the TipJar and create AdminCap
    fun init(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);
        
        // Create AdminCap for the owner
        let admin_cap = AdminCap {
            id: object::new(ctx)
        };
        
        // Transfer AdminCap to the owner
        transfer::public_transfer(admin_cap, owner);
        
        // Create and share the TipJar object
        let tip_jar = TipJar {
            id: object::new(ctx),
            owner,
            total_tips_received: 0,
            tip_count: 0
        };
        
        transfer::share_object(tip_jar);
        
        // Emit TipCreated event
        event::emit(TipCreated { owner });
    }

    /// Send a tip to the owner (public function that anyone can call)
    public entry fun send_tip(tip_jar: &mut TipJar, tip_coin: Coin<SUI>, ctx: &mut TxContext) {
        let tip_amount = coin::value(&tip_coin);
        assert!(tip_amount > 0, EInvalidTipAmount);
        
        // Get the owner address
        let owner = tip_jar.owner;
        
        // Transfer the tip to the owner
        transfer::public_transfer(tip_coin, owner);
        
        // Update state
        tip_jar.total_tips_received = tip_jar.total_tips_received + tip_amount;
        tip_jar.tip_count = tip_jar.tip_count + 1;
        
        // Emit TipSent event
        event::emit(TipSent {
            tipper: tx_context::sender(ctx),
            amount: tip_amount,
            total_tips: tip_jar.total_tips_received,
            tip_count: tip_jar.tip_count
        });
    }

    /// Owner can withdraw any leftover funds
    public entry fun withdraw(_tip_jar: &mut TipJar, _ctx: &mut TxContext) {
        // In Sui, coins are transferred directly, so there shouldn't be leftover funds
        // in the contract itself. This function is kept for compatibility but 
        // doesn't do anything in the typical case.
    }

    /// Check if a given address is the owner
    public fun is_owner(tip_jar: &TipJar, addr: address): bool {
        tip_jar.owner == addr
    }

    /// Get the owner address
    public fun get_owner(tip_jar: &TipJar): address {
        tip_jar.owner
    }

    /// Get total tips received
    public fun get_total_tips(tip_jar: &TipJar): u64 {
        tip_jar.total_tips_received
    }

    /// Get tip count
    public fun get_tip_count(tip_jar: &TipJar): u64 {
        tip_jar.tip_count
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}

