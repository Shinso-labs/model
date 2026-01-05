module hello_world::hello_world {
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::string::{Self, String};
    use sui::transfer;
    use sui::tx_context::{self, TxContext};

    /// Stored per-mint object; ownership is tracked by Sui, so we only store the message text.
    public struct Hello has key, store {
        id: UID,
        text: String,
    }

    /// Shared state tracking total minted, replacing Solidity's nextId counter.
    public struct HelloGlobal has key {
        id: UID,
        total_minted: u64,
    }

    /// Event emitted on each mint to mirror the Solidity HelloMinted event.
    public struct HelloMinted has copy, drop, store {
        hello_id: ID,
        owner: address,
        text: String,
    }

    /// Initializes and shares the global counter; runs once on publish.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(HelloGlobal {
            id: object::new(ctx),
            total_minted: 0,
        });
    }

    /// Mint a new Hello object with text "Hello World!" to the caller and bump the total counter.
    entry fun mint_hello_world(global: &mut HelloGlobal, ctx: &mut TxContext) {
        let caller = tx_context::sender(ctx);
        let hello = Hello {
            id: object::new(ctx),
            text: string::utf8(b"Hello World!"),
        };
        event::emit(HelloMinted {
            hello_id: object::id(&hello.id),
            owner: caller,
            text: string::utf8(b"Hello World!"),
        });
        transfer::public_transfer(hello, caller);
        global.total_minted = global.total_minted + 1;
    }

    /// Return the message text for a Hello object (view helper).
    public fun get_text(hello: &Hello): &String {
        &hello.text
    }

    /// Return the total number of Hello objects ever minted.
    public fun total_minted(global: &HelloGlobal): u64 {
        global.total_minted
    }
}