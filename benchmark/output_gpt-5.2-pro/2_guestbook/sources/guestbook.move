module guestbook::guestbook {
    use sui::event;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::vector;

    /// Max message length in bytes (matches Solidity's 200-byte guard).
    const MAX_MESSAGE_LENGTH: u64 = 200;
    /// Abort code when message is too long.
    const E_TOO_LONG: u64 = 1;

    /// Stored message (sender + raw bytes of the content).
    struct Message has store, drop {
        sender: address,
        content: vector<u8>,
    }

    /// Event emitted on every posted message.
    struct MessagePosted has store, drop {
        sender: address,
        index: u64,
        content: vector<u8>,
    }

    /// Shared guestbook object holding all messages.
    public struct GuestBook has key {
        id: UID,
        messages: vector<Message>,
    }

    /// Initialize and share an empty guestbook. Runs once at publish time.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(GuestBook {
            id: object::new(ctx),
            messages: vector::empty<Message>(),
        });
    }

    /// Post a new message (anyone can call). Fails if content exceeds 200 bytes.
    public entry fun post_message(guestbook: &mut GuestBook, content: vector<u8>, ctx: &mut TxContext) {
        let len = vector::length(&content);
        assert!(len <= MAX_MESSAGE_LENGTH, E_TOO_LONG);

        let sender = tx_context::sender(ctx);
        let index = vector::length(&guestbook.messages);

        // Store the message and emit an event (clone so we keep a copy for the event).
        let content_for_event = vector::clone(&content);
        vector::push_back(&mut guestbook.messages, Message { sender, content });
        event::emit(MessagePosted { sender, index, content: content_for_event });
    }

    /// Number of messages (matches Solidity's messageCount).
    public fun message_count(guestbook: &GuestBook): u64 {
        vector::length(&guestbook.messages)
    }

    /// Read a message by index, returning a copy of sender + content bytes.
    public fun get_message(guestbook: &GuestBook, index: u64): MessageView {
        let m = vector::borrow(&guestbook.messages, index);
        MessageView { sender: m.sender, content: vector::clone(&m.content) }
    }

    /// Lightweight view type for reads (avoids exposing internal storage).
    public struct MessageView has store, drop {
        sender: address,
        content: vector<u8>,
    }
}