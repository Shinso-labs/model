/// Module: sui_guestbook
/// Minimal guestbook: anyone can post a short message (<= 200 bytes).
/// Translated from the Solidity `GuestBook` contract.
module guestbook::sui_guestbook {
    use std::string::String;
    use sui::event;

    // === Constants ===

    /// Maximum allowed message length, in bytes.
    const MAX_MESSAGE_LENGTH: u64 = 200;

    // === Errors ===

    /// Posted message exceeded `MAX_MESSAGE_LENGTH`.
    const EInvalidLength: u64 = 0;

    /// Index out of bounds when reading a message.
    const EIndexOutOfBounds: u64 = 1;

    // === Types ===

    /// A single guestbook entry.
    /// Has `store` so it can be embedded in the shared `GuestBook` object's vector,
    /// and `copy`/`drop` since it carries no resource semantics (just data).
    public struct Message has store, copy, drop {
        sender: address,
        content: String,
    }

    /// The shared guestbook object. There is exactly one of these per package
    /// publication, created in `init` and shared so anyone can post to it.
    public struct GuestBook has key {
        id: UID,
        messages: vector<Message>,
    }

    // === Events ===

    /// Emitted when a new message is posted.
    public struct MessagePosted has copy, drop {
        sender: address,
        index: u64,
        content: String,
    }

    // === Init ===

    /// Module initializer — runs exactly once when the package is published.
    fun init(ctx: &mut TxContext) {
        let book = GuestBook {
            id: object::new(ctx),
            messages: vector::empty<Message>(),
        };
        transfer::share_object(book);
    }

    /// Test-only initializer that mirrors `init` for use in scenarios.
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    // === Message Construction ===

    /// Build a `Message` from a UTF-8 `String` content.
    /// Aborts with `EInvalidLength` if the content exceeds 200 bytes.
    public fun create_message(content: String, ctx: &TxContext): Message {
        assert!(content.length() <= MAX_MESSAGE_LENGTH, EInvalidLength);
        Message {
            sender: tx_context::sender(ctx),
            content,
        }
    }

    // === Entry-style Functions ===

    /// Append a pre-built `Message` to the guestbook and emit an event.
    public fun post_message(book: &mut GuestBook, msg: Message) {
        let sender = msg.sender;
        let content = msg.content;

        vector::push_back(&mut book.messages, msg);
        let index = vector::length(&book.messages) - 1;

        event::emit(MessagePosted {
            sender,
            index,
            content,
        });
    }

    /// Convenience entry function: build + post in one call from raw bytes.
    public entry fun post_message_bytes(
        book: &mut GuestBook,
        message_bytes: vector<u8>,
        ctx: &TxContext,
    ) {
        assert!(vector::length(&message_bytes) <= MAX_MESSAGE_LENGTH, EInvalidLength);
        let content = std::string::utf8(message_bytes);
        let msg = create_message(content, ctx);
        post_message(book, msg);
    }

    // === View Functions ===

    /// Number of messages in the guestbook.
    public fun message_count(book: &GuestBook): u64 {
        vector::length(&book.messages)
    }

    /// Read a single message by index. Returns `(sender, content)`.
    public fun get_message(book: &GuestBook, index: u64): (address, String) {
        assert!(index < vector::length(&book.messages), EIndexOutOfBounds);
        let m = vector::borrow(&book.messages, index);
        (m.sender, m.content)
    }

    /// Accessor for the sender of a `Message`.
    public fun message_sender(m: &Message): address {
        m.sender
    }

    /// Accessor for the content of a `Message`.
    public fun message_content(m: &Message): String {
        m.content
    }

    /// Expose the max length constant.
    public fun max_message_length(): u64 {
        MAX_MESSAGE_LENGTH
    }
}
