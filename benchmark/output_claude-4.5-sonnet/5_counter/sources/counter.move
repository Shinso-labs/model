module counter::counter {
    use sui::event;
    use sui::object::{ID, UID, id, new};
    use sui::transfer::share_object;
    use sui::tx_context::{TxContext, sender};

    /// Counter object represents the NFT-like asset.
    /// It is shared so anyone can increment, but only `owner` may set arbitrary values.
    public struct Counter has key, store {
        id: UID,
        owner: address,
        value: u64,
    }

    /// Emitted when a counter is created.
    public struct CounterCreated has copy, drop, store {
        id: ID,
        owner: address,
    }

    /// Emitted when a counter is incremented.
    public struct Incremented has copy, drop, store {
        id: ID,
        new_value: u64,
    }

    /// Emitted when a counter value is set by the owner.
    public struct ValueSet has copy, drop, store {
        id: ID,
        new_value: u64,
    }

    /// Create and share a new counter initialized to 0, owned by the sender.
    public fun create(ctx: &mut TxContext) {
        let sender_addr = sender(ctx);
        let counter = Counter {
            id: new(ctx),
            owner: sender_addr,
            value: 0,
        };
        let counter_id = id(&counter);
        event::emit(CounterCreated { id: counter_id, owner: sender_addr });
        share_object(counter);
    }

    /// Anyone can increment a counter by 1.
    public fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
        event::emit(Incremented {
            id: id(counter),
            new_value: counter.value,
        });
    }

    /// Only the recorded owner can set the counter to an arbitrary value.
    public fun set_value(counter: &mut Counter, new_value: u64, ctx: &mut TxContext) {
        let sender_addr = sender(ctx);
        assert!(sender_addr == counter.owner, 0);
        counter.value = new_value;
        event::emit(ValueSet {
            id: id(counter),
            new_value,
        });
    }

    /// Read the current value.
    public fun value(counter: &Counter): u64 {
        counter.value
    }
}
