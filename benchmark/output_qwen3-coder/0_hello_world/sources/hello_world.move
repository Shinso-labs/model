module hello_world::hello_world {
    use std::string;
    use sui::object;
    use sui::transfer;
    use sui::tx_context;
    use sui::event;

    /// Struct representing a Hello object with ID, owner, and text
    /// In Sui, each object must have a UID for unique identification
    public struct Hello has key, store {
        id: object::UID,
        owner: address,
        text: string::String
    }

    /// Struct to track the next ID counter
    /// This is a shared object so all transactions can access and increment it
    public struct Counter has key {
        id: object::UID,
        next_id: u64
    }

    /// Event emitted when a Hello object is minted
    public struct HelloMinted has copy, drop {
        id: u64,
        owner: address,
        text: string::String
    }

    /// Module initializer - runs once when the module is published
    /// Creates and shares the Counter object
    fun init(ctx: &mut tx_context::TxContext) {
        // Create the counter with initial ID of 1 (matching Solidity behavior)
        let counter = Counter {
            id: object::new(ctx),
            next_id: 1
        };
        
        // Share the counter object so it can be accessed by all transactions
        transfer::share_object(counter);
    }

    /// Mint a new Hello object with the text "Hello World!"
    /// This is a public function that can be called directly by users
    public fun mint_hello_world(counter: &mut Counter, ctx: &mut tx_context::TxContext) {
        // Get the next ID and increment the counter
        let id = counter.next_id;
        counter.next_id = counter.next_id + 1;
        
        // Create the Hello object with "Hello World!" text
        let hello = Hello {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            text: string::utf8(b"Hello World!")
        };
        
        // Emit event (equivalent to Solidity's emit HelloMinted)
        event::emit(HelloMinted {
            id,
            owner: tx_context::sender(ctx),
            text: string::utf8(b"Hello World!")
        });
        
        // Transfer the Hello object to the sender (owner)
        transfer::public_transfer(hello, tx_context::sender(ctx));
    }

    /// Get the data for a specific Hello object
    /// This is a view function that returns the owner and text
    public fun get_hello(hello: &Hello): (address, &string::String) {
        (hello.owner, &hello.text)
    }

    /// Get the total number of Hello objects ever minted
    /// This reads the current value of the counter
    public fun total_minted(counter: &Counter): u64 {
        counter.next_id - 1
    }
}