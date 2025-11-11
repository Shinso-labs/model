module counter::counter {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    /// The Counter NFT object
    /// This is an NFT that can be owned by an address.
    /// It has a unique ID and a value that can be incremented by anyone.
    /// Only the owner can set the value to an arbitrary number.
    public struct CounterNFT has key {
        id: UID,
        value: u64,
    }

    /// Event emitted when a new counter NFT is created
    public struct CounterCreatedEvent {
        token_id: u64,
        owner: address,
    }

    /// Event emitted when the counter is incremented
    public struct IncrementedEvent {
        token_id: u64,
        new_value: u64,
    }

    /// Event emitted when the counter value is set
    public struct ValueSetEvent {
        token_id: u64,
        new_value: u64,
    }

    /// Initialize the module (runs once on package publish)
    /// This function is not called by users, but is required for the module.
    /// It can be used to set up initial state if needed.
    public fun init(ctx: &mut TxContext) {
        // No initialization needed for this module.
        // The module is ready to use.
    }

    /// Create a new Counter NFT and mint it to the caller.
    /// This function is an entry function, so it can be called from a transaction.
    /// @param ctx The transaction context (provided by the Sui runtime)
    /// @return The newly created CounterNFT object, which is transferred to the caller
    public entry fun create(ctx: &mut TxContext) {
        // Create a new CounterNFT object with value 0
        let counter = CounterNFT {
            id: object::new(ctx),
            value: 0,
        };

        // Transfer the object to the signer (caller)
        transfer::transfer(counter, tx_context::sender(ctx));

        // Emit the CounterCreated event
        event::emit(CounterCreatedEvent {
            token_id: object::id(&counter).id,
            owner: tx_context::sender(ctx),
        });
    }

    /// Increment the counter value by 1.
    /// Anyone can call this function, as long as they have a mutable reference to the CounterNFT.
    /// @param counter A mutable reference to the CounterNFT object
    public entry fun increment(counter: &mut CounterNFT) {
        // Increment the value
        counter.value = counter.value + 1;

        // Emit the Incremented event
        event::emit(IncrementedEvent {
            token_id: object::id(counter).id,
            new_value: counter.value,
        });
    }

    /// Set the counter value to an arbitrary number.
    /// Only the owner of the CounterNFT can call this function.
    /// @param counter A mutable reference to the CounterNFT object
    /// @param new_value The new value to set
    public entry fun setValue(counter: &mut CounterNFT, new_value: u64) {
        // Check that the caller is the owner of the object
        // The owner is the address that currently owns the object
        // We can get the owner by checking the signer of the transaction
        let owner = tx_context::sender(ctx);

        // We need to check if the owner of the object is the same as the signer
        // But note: in Sui, the object's owner is stored in the object itself? 
        // Actually, in Sui, the object's owner is determined by the transaction context.
        // The object is owned by the address that created it or transferred it.
        // We can get the owner of the object by using the object's owner field? 
        // But our CounterNFT struct doesn't store the owner.

        // Correction: In Sui, the ownership of an object is determined by the transaction context.
        // The object is owned by the address that signed the transaction that created or transferred it.
        // However, we cannot directly access the owner of an object from within the object.
        // Instead, we must rely on the fact that the transaction signer is the owner.

        // But wait: the `tx_context::sender()` returns the signer of the transaction.
        // And the `counter` object is passed as a mutable reference, which means the signer must be the owner.

        // However, the Sui runtime ensures that only the owner can mutate an object.
        // So if the signer is not the owner, the transaction will fail at the transaction level.

        // Therefore, we don't need to check the owner in the Move code.
        // The Sui runtime will prevent non-owners from calling entry functions that take mutable references.

        // So we can simply set the value.

        counter.value = new_value;

        // Emit the ValueSet event
        event::emit(ValueSetEvent {
            token_id: object::id(counter).id,
            new_value: new_value,
        });
    }

    /// Read the current value of the counter.
    /// @param counter A reference to the CounterNFT object
    /// @return The current value
    public fun getValue(counter: &CounterNFT): u64 {
        counter.value
    }
}