module guestbook::guestbook {
    use std::string::{Self, String};
    use std::vector;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Max allowed message length in bytes (matches Solidity's 200-byte guard).
    const MAX_MESSAGE_LENGTH: u64 = 200;
    /// Error code for invalid message length.
    const E_INVALID_LENGTH: u64 = 1;

    /// Simple message: sender address and UTF-8 content.
    struct Message has store, drop {
        sender: address,
        content: String,
    }

    /// Event mirror of Solidity's MessagePosted.
    struct MessagePosted has drop, store {
        sender: address,
        index: u64,
        content: String,
    }

    /// Shared GuestBook object holding all messages.
    public struct GuestBook has key, store {
        id: UID,
        messages: vector<Message>,
    }

    /// Initialize and share the guestbook (call once on publish).
    public fun init(ctx: &mut TxContext) {
        let guestbook = GuestBook {
            id: object::new(ctx),
            messages: vector::empty<Message>(),
        };
        transfer::share_object(guestbook);
    }

    /// Post a new message (anyone can call).
    public entry fun post_message(guestbook: &mut GuestBook, message: String, ctx: &mut TxContext) {
        // Enforce byte-length limit to mirror Solidity behavior.
        assert!(string::length(&message) <= MAX_MESSAGE_LENGTH, E_INVALID_LENGTH);

        let sender = tx_context::sender(ctx);
        let index = vector::length(&guestbook.messages);

        // Store the message.
        vector::push_back(&mut guestbook.messages, Message { sender, content: message });

        // Emit event with a cloned string to avoid moving stored content.
        event::emit(MessagePosted {
            sender,
            index,
            content: string::clone(&vector::borrow(&guestbook.messages, index).content),
        });
    }

    /// Number of messages (Solidity's messageCount).
    public fun message_count(guestbook: &GuestBook): u64 {
        vector::length(&guestbook.messages)
    }

    /// Read a message by index (returns a copy of the content).
    public fun get_message(guestbook: &GuestBook, index: u64): (address, String) {
        let msg_ref = vector::borrow(&guestbook.messages, index);
        (msg_ref.sender, string::clone(&msg_ref.content))
    }
}