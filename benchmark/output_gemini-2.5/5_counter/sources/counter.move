module counter::counter {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Error codes
    const E_COUNT_BELOW_ZERO: u64 = 0;

    /// The Counter object, which holds the current count.
    /// It has the 'key' ability, meaning it's a globally unique object
    /// that can be stored and transferred.
    public struct Counter has key {
        id: UID,
        count: u64,
    }

    /// The `init` function is called once when the module is published.
    /// It creates a new Counter object and shares it, making it accessible
    /// to anyone on the network.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Counter {
            id: object::new(ctx), // Generate a new unique ID for the object
            count: 0,             // Initialize count to 0, matching Solidity constructor
        });
    }

    /// Increments the counter by 1.
    /// This is an 'entry' function, meaning it can be called directly
    /// as part of a Sui transaction.
    /// It takes a mutable reference to the shared Counter object.
    public entry fun increment(counter: &mut Counter) {
        counter.count = counter.count + 1;
    }

    /// Decrements the counter by 1.
    /// This is an 'entry' function.
    /// It includes a check to ensure the count does not go below zero,
    /// mirroring the Solidity `require` statement.
    public entry fun decrement(counter: &mut Counter) {
        // Assert that the count is greater than 0 before decrementing.
        // If not, it aborts the transaction with the E_COUNT_BELOW_ZERO error.
        assert!(counter.count > 0, E_COUNT_BELOW_ZERO);
        counter.count = counter.count - 1;
    }

    /// Returns the current value of the counter.
    /// This is a 'public' function, but not an 'entry' function,
    /// meaning it can be called by other Move functions within the same package
    /// or by other packages, but not directly as a transaction.
    /// It takes an immutable reference to the Counter object.
    public fun value(counter: &Counter): u64 {
        counter.count
    }
}