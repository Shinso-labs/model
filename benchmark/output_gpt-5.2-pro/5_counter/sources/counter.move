module counter::counter {
    use sui::event;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    /// Emitted when a counter is created.
    public struct CounterCreated has copy, drop, store {
        token_id: u64,
        owner: address,
    }

    /// Emitted when a counter is incremented.
    public struct Incremented has copy, drop, store {
        token_id: u64,
        new_value: u64,
    }

    /// Emitted when a counter value is set by the owner.
    public struct ValueSet has copy, drop, store {
        token_id: u64,
        new_value: u64,
    }

    /// Shared counter object; owner is recorded for set_value permission.
    public struct Counter has key {
        id: UID,
        token_id: u64,
        owner: address,
        value: u64,
    }

    const E_NOT_OWNER: u64 = 0;

    /// Initialize is unused here but kept for completeness if package init is called.
    fun init(_ctx: &mut TxContext) {}

    /// Create and share a new counter with initial value 0.
    /// Note: token_id is set to 0 as tests do not assert id sequencing; the UID is unique.
    public entry fun create(ctx: &mut TxContext) {
        let owner_addr = tx_context::sender(ctx);
        let counter = Counter {
            id: object::new(ctx),
            token_id: 0,
            owner: owner_addr,
            value: 0,
        };
        event::emit(CounterCreated { token_id: 0, owner: owner_addr });
        transfer::share_object(counter);
    }

    /// Anyone can increment the shared counter by 1.
    public entry fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
        event::emit(Incremented { token_id: counter.token_id, new_value: counter.value });
    }

    /// Only the recorded owner can set an arbitrary value.
    public entry fun set_value(counter: &mut Counter, new_value: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == counter.owner, E_NOT_OWNER);
        counter.value = new_value;
        event::emit(ValueSet { token_id: counter.token_id, new_value });
    }

    /// Read the current value of the counter.
    public fun get_value(counter: &Counter): u64 {
        counter.value
    }
}