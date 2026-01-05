module guestbook::guestbook {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use std::string::{Self, String};
    use std::vector;

    /// Maximum message length in bytes (mirrors Solidity constant)
    const MAX_MESSAGE_LENGTH: u64 = 200;

    /// Error codes for guestbook operations
    const EInvalidLength: u64 = 1;
    const EInvalidIndex: u64 = 2;

    /// Message struct - represents a single guestbook message
    /// Uses 'key' and 'store' abilities to make it a first-class object on Sui
    public struct Message has key, store {
        id: UID,
        sender: address,
        content: String,
    }

    /// GuestBook struct - the main guestbook object
    /// Uses 'key' ability and contains a vector of Message objects
    public struct GuestBook has key {
        id: UID,
        messages: vector<Message>,
    }

    /// Event emitted when a new message is posted
    public struct MessagePosted has copy, drop {
        sender: address,
        index: u64,
        content: vector<u8>,
    }

    /// Initialize the guestbook (runs once when package is published)
    fun init(ctx: &mut TxContext) {
        transfer::share_object(GuestBook {
            id: object::new(ctx),
            messages: vector::empty(),
        });
    }

    /// Initialize for testing purposes
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        transfer::share_object(GuestBook {
            id: object::new(ctx),
            messages: vector::empty(),
        });
    }

    /// Create a new message object
    public fun create_message(content: String, ctx: &mut TxContext): Message {
        assert!(string::length(&content) <= MAX_MESSAGE_LENGTH, EInvalidLength);

        Message {
            id: object::new(ctx),
            sender: tx_context::sender(ctx),
            content,
        }
    }

    /// Post a message to the guestbook
    public fun post_message(
        guestbook: &mut GuestBook,
        message: Message,
        ctx: &mut TxContext
    ) {
        vector::push_back(&mut guestbook.messages, message);

        let index = vector::length(&guestbook.messages) - 1;
        let content_bytes = string::bytes(&guestbook.messages[index].content);
        event::emit(MessagePosted {
            sender: tx_context::sender(ctx),
            index,
            content: *content_bytes,
        });
    }

    /// Get the total number of messages in the guestbook
    public fun message_count(guestbook: &GuestBook): u64 {
        vector::length(&guestbook.messages)
    }

    /// Get a specific message by index
    public fun get_message(guestbook: &GuestBook, index: u64): (&address, &String) {
        assert!(index < vector::length(&guestbook.messages), EInvalidIndex);

        let message = &guestbook.messages[index];
        (&message.sender, &message.content)
    }

    /// Helper function to get all messages (for testing/debugging)
    #[test_only]
    public fun get_all_messages(guestbook: &GuestBook): &vector<Message> {
        &guestbook.messages
    }
}