module counter::counter {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::dynamic_field as df;

    /// Counter NFT object that stores the current value
    /// Uses dynamic fields to store the value for each token
    public struct CounterNFT has key, store {
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

    /// Initialize the package
    fun init(ctx: &mut TxContext) {
        // No initialization needed for this simple contract
    }

    /// Create and mint a new counter NFT to the sender with initial value 0
    /// Returns the newly created CounterNFT object
    public entry fun create(ctx: &mut TxContext) {
        let counter = CounterNFT {
            id: object::new(ctx),
        };

        // Set initial value to 0 using dynamic field
        df::add(&mut counter.id, b"value", 0u64);

        // Emit creation event
        event::emit(CounterCreated {
            token_id: object::id(&counter),
            owner: tx_context::sender(ctx),
        });

        // Transfer to sender
        transfer::transfer(counter, tx_context::sender(ctx));
    }

    /// Anyone can increment a counter by 1 (shared access)
    /// Requires the CounterNFT object to be passed as mutable reference
    public entry fun increment(counter: &mut CounterNFT) {
        // Get current value
        let current_value = df::borrow_mut(&mut counter.id, b"value");
        *current_value = *current_value + 1;

        // Emit increment event
        event::emit(Incremented {
            token_id: object::id(counter),
            new_value: *current_value,
        });
    }

    /// Set the counter to an arbitrary value (only owner)
    /// In Sui, ownership is implicit - only the owner can pass the object
    public entry fun set_value(counter: &mut CounterNFT, new_value: u64) {
        // Set new value using dynamic field
        let value_field = df::borrow_mut(&mut counter.id, b"value");
        *value_field = new_value;

        // Emit value set event
        event::emit(ValueSet {
            token_id: object::id(counter),
            new_value: new_value,
        });
    }

    /// Read current value of a counter
    /// Returns the current value as u64
    public fun get_value(counter: &CounterNFT): u64 {
        *df::borrow(&counter.id, b"value")
    }

    /// Helper function to check if a counter exists
    /// In Sui, this is implicit - if you have the object, it exists
    public fun exists(_counter: &CounterNFT): bool {
        true // Object existence is guaranteed in Move
    }
}