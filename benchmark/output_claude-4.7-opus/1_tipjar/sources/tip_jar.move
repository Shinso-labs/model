/// TipJar module — Sui Move translation of the Solidity TipJar contract.
///
/// Key translation decisions:
/// - `address public owner` → stored in the shared `TipJar` object plus an `OwnerCap`
///   capability object that grants admin rights (capability pattern instead of msg.sender check).
/// - Native ETH (`msg.value`) → `Coin<SUI>` passed in as a function argument.
/// - Forwarding the tip via `owner.call{value: ...}` → `transfer::public_transfer(coin, owner)`.
/// - Events via `emit` → `sui::event::emit`.
/// - Reentrancy is implicitly prevented by Move's resource semantics; no external
///   arbitrary calls exist in Sui.
module tipjar::tip_jar {
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // ===== Errors =====
    const EInvalidTipAmount: u64 = 0;

    // ===== Structs =====

    /// Shared object holding the global state of the TipJar.
    /// Shared so anyone can call `send_tip` against it.
    public struct TipJar has key {
        id: UID,
        owner: address,
        total_tips_received: u64,
        tip_count: u64,
    }

    /// Capability granting admin rights over the TipJar.
    /// Held by the owner; transferable. Replaces `onlyOwner` modifier.
    public struct OwnerCap has key, store {
        id: UID,
    }

    // ===== Events =====

    public struct TipCreated has copy, drop {
        owner: address,
    }

    public struct TipSent has copy, drop {
        tipper: address,
        amount: u64,
        total_tips: u64,
        tip_count: u64,
    }

    // ===== Init =====

    /// Module initializer — runs once on publish.
    /// Creates the shared TipJar object and gives the deployer the OwnerCap.
    fun init(ctx: &mut TxContext) {
        create_tip_jar(ctx);
    }

    /// Internal helper that creates and shares the TipJar object and transfers
    /// the OwnerCap to the sender. Used by both `init` and `init_for_testing`.
    fun create_tip_jar(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        let jar = TipJar {
            id: object::new(ctx),
            owner: sender,
            total_tips_received: 0,
            tip_count: 0,
        };

        let cap = OwnerCap {
            id: object::new(ctx),
        };

        event::emit(TipCreated { owner: sender });

        transfer::share_object(jar);
        transfer::public_transfer(cap, sender);
    }

    /// Test-only initializer — exposes `init` logic to test scenarios since
    /// the real `init` cannot be called directly outside of module publish.
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        create_tip_jar(ctx);
    }

    // ===== Public Functions =====

    /// Send a tip (in SUI) to the owner.
    /// Equivalent to Solidity's payable `sendTip()`.
    public fun send_tip(
        jar: &mut TipJar,
        payment: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let amount = coin::value(&payment);
        assert!(amount > 0, EInvalidTipAmount);

        let tipper = tx_context::sender(ctx);
        let owner = jar.owner;

        // Forward the tip directly to the owner (analogous to owner.call{value: ...}).
        transfer::public_transfer(payment, owner);

        // Update state.
        jar.total_tips_received = jar.total_tips_received + amount;
        jar.tip_count = jar.tip_count + 1;

        event::emit(TipSent {
            tipper,
            amount,
            total_tips: jar.total_tips_received,
            tip_count: jar.tip_count,
        });
    }

    /// Owner-only: transfer ownership to a new address.
    /// Possession of the `OwnerCap` proves authority (capability pattern).
    public fun set_owner(
        _cap: &OwnerCap,
        jar: &mut TipJar,
        new_owner: address,
    ) {
        jar.owner = new_owner;
    }

    // ===== View Functions =====

    /// Check if a given address is the recorded owner.
    public fun is_owner(jar: &TipJar, addr: address): bool {
        addr == jar.owner
    }

    public fun get_owner(jar: &TipJar): address {
        jar.owner
    }

    public fun get_total_tips(jar: &TipJar): u64 {
        jar.total_tips_received
    }

    public fun get_tip_count(jar: &TipJar): u64 {
        jar.tip_count
    }
}
