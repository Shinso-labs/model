module hello_world::hello_world{

    use std::string;
    
    public struct Hello has key, store {
        id: UID,
        text: string::String
    }
        
    entry fun mint_hello_world(ctx: &mut TxContext) {
    // Mint an object that contains an ID and "Hello World" text
        let hello_object = Hello {
            id: object::new(ctx),
            text: string::utf8(b"Hello World!")
        };
        // Transfer the object to initializer address
        transfer::public_transfer(hello_object, tx_context::sender(ctx));
    }
}