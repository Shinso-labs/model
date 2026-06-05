/// Counter NFT module — shared increment, owner-settable.
///
/// Translation notes:
/// - Each Counter is its own Sui object (object-centric model).
/// - "Anyone can increment" => Counter is a *shared* object; `increment`
///   doesn't even need the `TxContext` because it performs no sender check.
/// - "Only owner can set value" => `owner` field + sender check in `set_value`.
/// - Unlike the Solidity version, we don't maintain a global sequential id
///   counter (which would require a shared registry passed into `create`).
///   Instead each Counter's identity *is* its Sui object id; we additionally
///   expose a `token_id: address` (the inner UID address) for convenience.
/// - Reentrancy is not a concern in Move: no arbitrary external calls.
module counter::counter {
    use sui::event;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    // ===== Errors =====
    const ENotOwner: u64 = 1;

    // ===== Structs =====

    /// A Counter NFT. `key` => first-class Sui object.
    /// Shared so any sender can increment it; only `owner` can set value.
    public struct Counter has key {
        id: UID,
        token_id: address,
        value: u64,
        owner: address,
    }

    // ===== Events =====

    public struct CounterCreated has copy, drop {
        token_id: address,
        owner: address,
    }

    public struct Incremented has copy, drop {
        token_id: address,
        new_value: u64,
    }

    public struct ValueSet has copy, drop {
        token_id: address,
        new_value: u64,
    }

    // ===== Entry functions =====

    /// Create a new Counter NFT with initial value 0.
    /// The Counter is shared so anyone can increment it; only `owner` can set value.
    public entry fun create(ctx: &mut TxContext) {
        let uid = object::new(ctx);
        let token_id = object::uid_to_address(&uid);
        let sender = tx_context::sender(ctx);

        let counter = Counter {
            id: uid,
            token_id,
            value: 0,
            owner: sender,
        };

        event::emit(CounterCreated { token_id, owner: sender });

        // Share so any address can call `increment`.
        transfer::share_object(counter);
    }

    /// Anyone can increment the counter by 1 (shared access).
    /// No `TxContext` needed — there's no sender-based check here, and the
    /// shared-object permission model already allows any caller.
    public entry fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
        event::emit(Incremented {
            token_id: counter.token_id,
            new_value: counter.value,
        });
    }

    /// Set the counter to an arbitrary value. Only the recorded `owner` may call.
    public entry fun set_value(counter: &mut Counter, new_value: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == counter.owner, ENotOwner);
        counter.value = new_value;
        event::emit(ValueSet {
            token_id: counter.token_id,
            new_value,
        });
    }

    // ===== View functions =====

    /// Read current value. Equivalent to Solidity's `getValue`.
    public fun get_value(counter: &Counter): u64 {
        counter.value
    }

    /// Read the owner address.
    public fun owner_of(counter: &Counter): address {
        counter.owner
    }

    /// Read the token id (the Counter object's address).
    public fun token_id(counter: &Counter): address {
        counter.token_id
    }
}
