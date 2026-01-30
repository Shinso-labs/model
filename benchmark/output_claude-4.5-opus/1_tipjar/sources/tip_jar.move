/// TipJar Module - A Sui Move translation of the Solidity TipJar contract
/// 
/// This module allows users to send tips (in SUI) to a jar owner.
/// Tips are immediately forwarded to the owner's address.
/// The jar tracks total tips received and tip count for transparency.
module tipjar::tip_jar {
    // === Imports ===
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;

    // === Errors ===
    /// Error when someone other than the owner tries to perform owner-only actions
    const ENotOwner: u64 = 0;
    /// Error when tip amount is zero
    const EInvalidTipAmount: u64 = 1;
    /// Error when there's nothing to withdraw
    const ENothingToWithdraw: u64 = 2;

    // === Public Error Constants (for test assertions) ===
    public fun InvalidTipAmount(): u64 { EInvalidTipAmount }
    public fun NotOwner(): u64 { ENotOwner }
    public fun NothingToWithdraw(): u64 { ENothingToWithdraw }

    // === Structs ===

    /// The TipJar object - shared so anyone can send tips
    /// 
    /// Translation notes:
    /// - `key` ability: Makes this a Sui object with unique ID
    /// - `store` ability: Allows the object to be stored/transferred
    /// - Owner address stored directly (replaces Solidity's `owner` state variable)
    /// - Balance field holds any accumulated funds (for withdraw functionality)
    public struct TipJar has key, store {
        id: UID,
        /// The owner who receives tips
        owner: address,
        /// Running total of all tips received (in MIST, smallest SUI unit)
        total_tips_received: u64,
        /// Count of tips received
        tip_count: u64,
        /// Any leftover balance (tips that weren't immediately transferred)
        /// Using Balance<SUI> instead of Coin<SUI> for space efficiency
        balance: Balance<SUI>,
    }

    /// Capability object given to the owner for privileged operations
    /// 
    /// Translation note: This implements the Capability pattern for access control,
    /// replacing Solidity's `onlyOwner` modifier. Only the holder of this cap
    /// can perform admin operations.
    public struct OwnerCap has key, store {
        id: UID,
        /// Reference to the TipJar this capability controls
        tip_jar_id: ID,
    }

    // === Events ===

    /// Emitted when a new TipJar is created
    /// Equivalent to Solidity's `TipCreated` event
    public struct TipCreated has copy, drop {
        tip_jar_id: ID,
        owner: address,
    }

    /// Emitted when a tip is sent
    /// Equivalent to Solidity's `TipSent` event
    public struct TipSent has copy, drop {
        tipper: address,
        amount: u64,
        total_tips: u64,
        tip_count: u64,
    }

    // === Public Functions ===

    /// Creates a new TipJar
    /// 
    /// Translation notes:
    /// - Replaces Solidity constructor
    /// - Creates a shared object (anyone can interact)
    /// - Returns OwnerCap to the creator for admin access
    /// - `ctx.sender()` is equivalent to Solidity's `msg.sender`
    public fun new(ctx: &mut TxContext): (TipJar, OwnerCap) {
        let owner = ctx.sender();
        
        let tip_jar = TipJar {
            id: object::new(ctx),
            owner,
            total_tips_received: 0,
            tip_count: 0,
            // Initialize with zero balance
            balance: balance::zero<SUI>(),
        };

        let tip_jar_id = object::id(&tip_jar);

        let owner_cap = OwnerCap {
            id: object::new(ctx),
            tip_jar_id,
        };

        // Emit creation event
        event::emit(TipCreated {
            tip_jar_id,
            owner,
        });

        (tip_jar, owner_cap)
    }

    /// Entry function to create and share a TipJar
    /// 
    /// This is the main way to deploy a new TipJar.
    /// The TipJar becomes a shared object, and the OwnerCap is sent to the creator.
    entry fun create(ctx: &mut TxContext) {
        let (tip_jar, owner_cap) = new(ctx);
        // Share the TipJar so anyone can send tips
        transfer::share_object(tip_jar);
        // Transfer OwnerCap to the creator
        transfer::transfer(owner_cap, ctx.sender());
    }

    /// Send a tip to the TipJar owner
    /// 
    /// Translation notes:
    /// - `tip: Coin<SUI>` replaces Solidity's `msg.value`
    /// - In Sui, coins must be explicitly passed as arguments
    /// - The tip is immediately transferred to the owner
    /// - No reentrancy risk: Move's resource model ensures the coin is consumed exactly once
    entry fun send_tip(
        tip_jar: &mut TipJar,
        tip: Coin<SUI>,
        ctx: &TxContext,
    ) {
        let tip_amount = coin::value(&tip);
        
        // Validate tip amount (equivalent to Solidity's require)
        assert!(tip_amount > 0, EInvalidTipAmount);

        // Update state BEFORE transfer (Checks-Effects-Interactions pattern)
        // Note: In Move, this is less critical since there's no reentrancy,
        // but it's still good practice
        tip_jar.total_tips_received = tip_jar.total_tips_received + tip_amount;
        tip_jar.tip_count = tip_jar.tip_count + 1;

        // Transfer tip directly to owner
        // This is equivalent to Solidity's `owner.call{value: tipAmount}("")`
        transfer::public_transfer(tip, tip_jar.owner);

        // Emit event
        event::emit(TipSent {
            tipper: ctx.sender(),
            amount: tip_amount,
            total_tips: tip_jar.total_tips_received,
            tip_count: tip_jar.tip_count,
        });
    }

    /// Owner withdraws any leftover funds from the TipJar
    /// 
    /// Translation notes:
    /// - Requires OwnerCap (replaces Solidity's `onlyOwner` modifier)
    /// - In normal operation, balance should be 0 since tips are forwarded immediately
    /// - This is a safety mechanism for edge cases
    entry fun withdraw(
        tip_jar: &mut TipJar,
        owner_cap: &OwnerCap,
        ctx: &mut TxContext,
    ) {
        // Verify the OwnerCap matches this TipJar
        assert!(owner_cap.tip_jar_id == object::id(tip_jar), ENotOwner);

        let balance_value = tip_jar.balance.value();
        assert!(balance_value > 0, ENothingToWithdraw);

        // Extract all funds from the balance
        let withdrawn_balance = tip_jar.balance.withdraw_all();
        let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);
        
        // Transfer to owner
        transfer::public_transfer(withdrawn_coin, tip_jar.owner);
    }

    // === View Functions ===

    /// Check if a given address is the owner
    /// Equivalent to Solidity's `isOwner` function
    public fun is_owner(tip_jar: &TipJar, addr: address): bool {
        tip_jar.owner == addr
    }

    /// Get the owner address
    public fun owner(tip_jar: &TipJar): address {
        tip_jar.owner
    }

    /// Get the owner address (alias for compatibility)
    public fun get_owner(tip_jar: &TipJar): address {
        tip_jar.owner
    }

    /// Get total tips received
    public fun total_tips_received(tip_jar: &TipJar): u64 {
        tip_jar.total_tips_received
    }

    /// Get total tips received (alias for compatibility)
    public fun get_total_tips(tip_jar: &TipJar): u64 {
        tip_jar.total_tips_received
    }

    /// Get tip count
    public fun tip_count(tip_jar: &TipJar): u64 {
        tip_jar.tip_count
    }

    /// Get tip count (alias for compatibility)
    public fun get_tip_count(tip_jar: &TipJar): u64 {
        tip_jar.tip_count
    }

    /// Get current balance in the jar
    public fun balance(tip_jar: &TipJar): u64 {
        tip_jar.balance.value()
    }

    /// Get current balance in the jar (alias for compatibility)
    public fun get_balance(tip_jar: &TipJar): u64 {
        tip_jar.balance.value()
    }

    /// Get the TipJar ID that an OwnerCap controls
    public fun owner_cap_tip_jar_id(cap: &OwnerCap): ID {
        cap.tip_jar_id
    }

    // === Test-only Functions ===

    #[test_only]
    /// Initialize for testing - creates and shares a TipJar
    public fun init_for_testing(ctx: &mut TxContext) {
        create(ctx);
    }
}
