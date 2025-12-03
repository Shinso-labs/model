module guestbook::sui_guestbook {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::string::{Self, String};
    use sui::vector;

    /// Error codes for the GuestBook module.
    const EInvalidLength: u64 = 0;
    const EIndexOutOfRange: u64 = 1;

    /// The maximum allowed length for a message in bytes.
    const MAX_MESSAGE_LENGTH: u64 = 200;

    /// Represents a single message posted in the guestbook.
    /// It has `store` ability, meaning it can be stored inside other structs.
    public struct Message has store {
        sender: address,
        content: String,
    }

    /// The main GuestBook object, which holds all messages.
    /// It has `key` ability, making it a first-class Sui object, and `store` ability.
    /// This object will be shared, allowing anyone to interact with it.
    public struct GuestBook has key, store {
        id: UID,
        messages: vector<Message>,
    }

    /// Event emitted when a new message is posted.
    /// It has `drop, copy, store` abilities, which are standard for event structs.
    public struct MessagePosted has drop, copy, store {
        sender: address,
        index: u64,
        content: String,
    }

    /// Initializes the GuestBook module. This function is called once when the package is published.
    /// It creates a new `GuestBook` object and shares it, making it accessible to all users.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(GuestBook {
            id: object::new(ctx),
            messages: vector::empty(),
        });
    }

    /// Posts a new message to the guestbook.
    /// This is an `entry` function, meaning it can be called directly as a transaction.
    /// It takes a mutable reference to the `GuestBook` object, allowing it to modify its state.
    public entry fun post_message(
        guestbook: &mut GuestBook,
        message_content: vector<u8>, // Input as vector<u8> for flexibility, converted to String
        ctx: &mut TxContext
    ) {
        // Convert vector<u8> to sui::string::String.
        // This conversion can fail if the bytes are not valid UTF-8, but for a simple guestbook,
        // we assume valid input or let the conversion panic if invalid.
        let content_string = string::utf8(message_content);

        // Check if the message length exceeds the maximum allowed.
        // `string::length_bytes` is used to match the Solidity `bytes(message_).length` behavior.
        assert!(string::length_bytes(&content_string) <= MAX_MESSAGE_LENGTH, EInvalidLength);

        // Create a new Message struct.
        let new_message = Message {
            sender: tx_context::sender(ctx),
            content: content_string,
        };

        // Add the new message to the guestbook's messages vector.
        let index = vector::length(&guestbook.messages);
        vector::push_back(&mut guestbook.messages, new_message);

        // Emit a `MessagePosted` event.
        event::emit(MessagePosted {
            sender: tx_context::sender(ctx),
            index: index,
            content: vector::pop_back(&mut vector::copy_vec(&guestbook.messages)), // Get the content of the newly added message for the event
        });
    }

    /// Returns the total number of messages in the guestbook.
    /// This is a `public` function, callable by other modules or for view queries.
    /// It takes an immutable reference to the `GuestBook` object as it does not modify its state.
    public fun message_count(guestbook: &GuestBook): u64 {
        vector::length(&guestbook.messages)
    }

    /// Reads a single message by its index.
    /// This is a `public` function, callable by other modules or for view queries.
    /// It takes an immutable reference to the `GuestBook` object.
    /// Returns the sender's address and the message content.
    public fun get_message(guestbook: &GuestBook, index: u64): (address, String) {
        // Ensure the index is within the bounds of the messages vector.
        assert!(index < vector::length(&guestbook.messages), EIndexOutOfRange);

        // Get an immutable reference to the message at the given index.
        let message_ref = vector::borrow(&guestbook.messages, index);

        // Return the sender and a copy of the content.
        (message_ref.sender, string::copy(&message_ref.content))
    }
}