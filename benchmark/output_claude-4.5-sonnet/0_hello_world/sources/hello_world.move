module hello_world::hello_world {
    use std::string;
    use sui::object;
    use sui::transfer;
    use sui::tx_context;

    /// Simple Hello object with key and store abilities.
    public struct Hello has key, store {
        id: object::UID,
        text: string::String,
    }

    /// Mint a Hello object with text "Hello World!" and transfer to sender.
    entry fun mint_hello_world(ctx: &mut tx_context::TxContext) {
        let hello = Hello {
            id: object::new(ctx),
            text: string::utf8(b"Hello World!"),
        };
        transfer::public_transfer(hello, tx_context::sender(ctx));
    }

    /// Accessors (optional helpers).
    public fun hello_id(hello: &Hello): &object::UID {
        &hello.id
    }

    public fun hello_text(hello: &Hello): &string::String {
        &hello.text
    }
}