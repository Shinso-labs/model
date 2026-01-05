module guestbook::guestbook {
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::event;
    use sui::tx_context::{Self, TxContext};
    use sui::vec::{Self, Vec};

    // == Constants ==
    const MAX_MESSAGE_LENGTH: u64 = 200;

    // == Errors ==
    const EInvalidLength: u64 = 0;

    // == Types ==
    public struct Message has copy, drop, store {
        sender: address,
        content: String
    }

    public struct GuestBook has key {
        id: UID,
        messages: Vec<Message>
    }

    public struct MessagePosted has copy, drop {
        sender: address,
        index: u64,
        content: String
    }

    // == Initialization ==
    public fun init(ctx: &mut TxContext) {
        let guestbook = GuestBook {
            id: object::new(ctx),
            messages: vec::empty<Message>()
        };
        transfer::public_transfer(guestbook, tx_context::sender(ctx));
    }

    // == Public API ==
    /// Post a new message to the guestbook
    public entry fun post_message(guestbook: &mut GuestBook, content: String, ctx: &TxContext) {
        // Check message length (in bytes)
        let content_length = string::length(&content);
        if (content_length > MAX_MESSAGE_LENGTH) {
            abort EInvalidLength
        };

        let sender = tx_context::sender(ctx);
        let message = Message { sender, content };
        let index = vec::length(&guestbook.messages);
        
        vec::push_back(&mut guestbook.messages, message);
        
        // Emit event
        event::emit(MessagePosted { sender, index, content });
    }

    /// Get the number of messages in the guestbook
    public fun message_count(guestbook: &GuestBook): u64 {
        vec::length(&guestbook.messages)
    }

    /// Read a single message by index
    public fun get_message(guestbook: &GuestBook, index: u64): &Message {
        vec::borrow(&guestbook.messages, index)
    }

    /// Get sender of a message
    public fun message_sender(message: &Message): address {
        message.sender
    }

    /// Get content of a message
    public fun message_content(message: &Message): &String {
        &message.content
    }
}