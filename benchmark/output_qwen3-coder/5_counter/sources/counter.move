module counter::counter {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::dynamic_field as df;

    /// Counter NFT object - represents a single counter instance
    /// Uses dynamic fields to store the counter value for flexibility
    public struct Counter has key {
        id: UID,
    }

    /// Event emitted when a new counter is created
    public struct CounterCreated has copy, drop {
        token_id: ID,
        owner: address,
    }

    /// Event emitted when a counter is incremented
    public struct Incremented has copy, drop {
        token_id: ID,
        new_value: u64,
    }

    /// Event emitted when a counter value is set
    public struct ValueSet has copy, drop {
        token_id: ID,
        new_value: u64,
    }

    /// Initialize the module (runs once on package publish)
    fun init(ctx: &mut TxContext) {
        // No initialization needed for this simple contract
    }

    /// Create and mint a new counter NFT to the caller with initial value 0
    /// Returns the newly created Counter object
    public entry fun create(ctx: &mut TxContext) {
        let counter = Counter {
            id: object::new(ctx),
        };

        // Initialize counter value to 0 using dynamic field
        df::add(&mut counter.id, b"value", 0u64);

        // Emit creation event
        event::emit(CounterCreated {
            token_id: object::id(&counter),
            owner: tx_context::sender(ctx),
        });

        // Transfer the counter to the sender
        transfer::public_transfer(counter, tx_context::sender(ctx));
    }

    /// Anyone can increment a counter by 1 (shared access)
    /// Uses mutable reference to modify the counter
    public entry fun increment(counter: &mut Counter) {
        // Get current value from dynamic field
        let current_value = df::borrow_mut(&mut counter.id, b"value");
        *current_value = *current_value + 1;

        // Emit increment event
        event::emit(Incremented {
            token_id: object::id(counter),
            new_value: *current_value,
        });
    }

    /// Set the counter to an arbitrary value (only owner)
    /// In Sui, we check if the sender owns the object by requiring they pass it
    public entry fun set_value(counter: &mut Counter, new_value: u64) {
        // Get mutable reference to value field
        let value_ref = df::borrow_mut(&mut counter.id, b"value");
        *value_ref = new_value;

        // Emit value set event
        event::emit(ValueSet {
            token_id: object::id(counter),
            new_value: new_value,
        });
    }

    /// Read current value (view function)
    /// Returns the current counter value
    public fun get_value(counter: &Counter): u64 {
        *df::borrow(&counter.id, b"value")
    }
}