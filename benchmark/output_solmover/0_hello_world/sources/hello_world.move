module hello_world::hello_world {

    use std::string;
    
    /// Object containing a text message
    /// `key` ability: can be owned/transferred
    /// `store` ability: can be stored in other objects
    public struct Hello has key, store {
        id: UID,
        text: string::String
    }
    
    /// Mints a Hello object with "Hello World!" text and sends it to the caller
    entry fun mint_hello_world(ctx: &mut TxContext) {
        // Create Hello object with unique ID and message
        let hello_object = Hello {
            id: object::new(ctx),
            text: string::utf8(b"Hello World!")
        };
        
        // Transfer to transaction sender
        transfer::public_transfer(hello_object, tx_context::sender(ctx));
    }
}