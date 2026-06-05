/// Module: hello_world
/// Sui Move translation of the Solidity HelloWorld contract.
/// Each call to `mint_hello_world` creates a new `Hello` object owned by the caller.
module hello_world::hello_world {
    use std::string::{Self, String};
    use sui::event;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    // === Structs ===

    /// Hello object — each minted instance is its own Sui object owned by the minter.
    /// Has `key` so it can be a top-level Sui object, and `store` for flexibility.
    /// Note: Unlike Solidity, we don't need a sequential `id` counter because each
    /// Sui object already has a globally-unique `UID`. We keep the `owner` and
    /// `text` fields to mirror the original contract.
    public struct Hello has key, store {
        id: UID,
        owner: address,
        text: String,
    }

    // === Events ===

    /// Emitted when a new Hello is minted (mirrors Solidity's HelloMinted event).
    public struct HelloMinted has copy, drop {
        // The unique object ID of the minted Hello (replaces Solidity's uint256 id).
        hello_id: address,
        owner: address,
        text: String,
    }

    // === Entry Functions ===

    /// Mints a new Hello object with text "Hello World!" and transfers it
    /// to the caller.
    ///
    /// Translation note: The Solidity version maintained a global `nextId`
    /// counter in contract storage. In Sui, each object has its own globally
    /// unique `UID` provided by `object::new(ctx)`, so no shared counter is
    /// required. This makes the function self-contained and enables maximum
    /// parallel execution (no shared object contention).
    public entry fun mint_hello_world(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let uid = object::new(ctx);
        let hello_id = object::uid_to_address(&uid);

        let hello = Hello {
            id: uid,
            owner: sender,
            text: string::utf8(b"Hello World!"),
        };

        // Emit event mirroring Solidity's HelloMinted.
        event::emit(HelloMinted {
            hello_id,
            owner: sender,
            text: string::utf8(b"Hello World!"),
        });

        // Transfer ownership of the new Hello object to the caller.
        // In Sui's object model, ownership is explicit rather than recorded
        // in a mapping like Solidity's `mapping(uint256 => Hello)`.
        transfer::public_transfer(hello, sender);
    }

    // === View / Read Accessors ===

    /// Returns (owner, text) for a given Hello — equivalent to Solidity's `getHello`.
    /// Note: in Sui, off-chain clients can read object data directly via RPC,
    /// but we provide this for on-chain composability.
    public fun get_hello(hello: &Hello): (address, &String) {
        (hello.owner, &hello.text)
    }

    /// Accessor for the owner field.
    public fun owner(hello: &Hello): address {
        hello.owner
    }

    /// Accessor for the text field.
    public fun text(hello: &Hello): &String {
        &hello.text
    }
}
