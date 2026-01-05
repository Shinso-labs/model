module hello_world::hello_world {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::event;
    use std::string::{Self, String};

    /// Hello object that stores the greeting message
    /// Equivalent to the Hello struct in Solidity
    public struct Hello has key, store {
        id: UID,
        owner: address,
        text: String,
    }

    /// Event emitted when a new Hello object is minted
    /// Equivalent to the HelloMinted event in Solidity
    public struct HelloMintedEvent has copy, drop {
        id: ID,
        owner: address,
        text: String,
    }

    /// Module initializer - runs once when package is published
    /// Equivalent to the Solidity constructor
    fun init(ctx: &mut TxContext) {
        // In Sui Move, we don't need to initialize a counter like in Solidity
        // because each Hello object has its own UID
    }

    /// Mints a new Hello object with the text "Hello World!"
    /// Equivalent to mintHelloWorld() in Solidity
    public fun mint_hello_world(ctx: &mut TxContext) {
        // Create new Hello object with unique UID
        let hello = Hello {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            text: string::utf8(b"Hello World!"),
        };

        // Emit event (similar to Solidity's emit)
        event::emit(HelloMintedEvent {
            id: object::id(&hello),
            owner: tx_context::sender(ctx),
            text: string::utf8(b"Hello World!"),
        });

        // Transfer the object to the sender
        transfer::public_transfer(hello, tx_context::sender(ctx));
    }

    /// Returns data for a specific Hello object
    /// Equivalent to getHello() in Solidity
    public fun get_hello(hello: &Hello): (address, String) {
        (hello.owner, hello.text)
    }

    /// Returns the ID of a Hello object
    /// Helper function to get the object ID
    public fun get_hello_id(hello: &Hello): ID {
        object::id(hello)
    }
}