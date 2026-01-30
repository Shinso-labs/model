/// @title GuestBook
/// @notice Minimal guestbook: anyone can post a short message (<= 200 bytes).
/// @dev Sui Move implementation using a shared object to store messages.
module guestbook::sui_guestbook {
    // === Imports ===
    use std::string::String;
    use sui::event;

    // === Constants ===
    /// Maximum allowed message length in bytes
    const MAX_MESSAGE_LENGTH: u64 = 200;

    // === Errors ===
    /// Error code when message exceeds maximum length
    const EInvalidLength: u64 = 0;
    /// Error code when message index is out of bounds
    const EIndexOutOfBounds: u64 = 1;

    // === Structs ===

    /// A single message in the guestbook
    /// Using `store` ability so it can be stored inside the GuestBook vector
    /// Using `copy` and `drop` for convenience when reading messages
    public struct Message has store, copy, drop {
        sender: address,
        content: String,
    }

    /// The GuestBook shared object that stores all messages
    /// `key` ability makes it a Sui object
    /// `store` ability allows it to be transferred/wrapped if needed
    public struct GuestBook has key, store {
        id: UID,
        messages: vector<Message>,
    }

    // === Events ===

    /// Emitted when a new message is posted
    /// Mirrors Solidity's MessagePosted event
    public struct MessagePosted has copy, drop {
        sender: address,
        index: u64,
        content: String,
    }

    // === Init Function ===

    /// Module initializer - creates and shares the GuestBook
    /// This runs exactly once when the module is published
    /// The GuestBook becomes a shared object so anyone can post messages
    fun init(ctx: &mut TxContext) {
        let guestbook = GuestBook {
            id: object::new(ctx),
            messages: vector::empty<Message>(),
        };
        // Share the object so it's accessible to all users
        // This is analogous to deploying the Solidity contract
        transfer::share_object(guestbook);
    }

    // === Public Functions ===

    /// Create a new Message struct
    /// @param content - The message content (must be <= 200 bytes)
    /// @param ctx - Transaction context to get sender address
    /// @return The created Message struct
    public fun create_message(content: String, ctx: &TxContext): Message {
        // Validate message length in bytes (mirrors Solidity's bytes().length check)
        let message_bytes = content.as_bytes();
        assert!(message_bytes.length() <= MAX_MESSAGE_LENGTH, EInvalidLength);

        Message {
            sender: ctx.sender(),
            content,
        }
    }

    /// Post a message to the guestbook
    /// @param guestbook - Mutable reference to the shared GuestBook object
    /// @param message - The Message struct to post
    /// 
    /// Note: Move's resource safety provides implicit reentrancy protection.
    /// The mutable borrow of `guestbook` prevents concurrent modifications.
    public fun post_message(
        guestbook: &mut GuestBook,
        message: Message,
    ) {
        let index = guestbook.messages.length();

        // Emit event (equivalent to Solidity's emit MessagePosted(...))
        event::emit(MessagePosted {
            sender: message.sender,
            index,
            content: message.content,
        });

        // Store the message
        guestbook.messages.push_back(message);
    }

    // === Entry Functions ===

    /// Entry function to post a new message to the guestbook
    /// @param guestbook - Mutable reference to the shared GuestBook object
    /// @param content - The message content (must be <= 200 bytes)
    /// 
    /// This combines create_message and post_message for convenience
    public entry fun post(
        guestbook: &mut GuestBook,
        content: String,
        ctx: &TxContext,
    ) {
        let message = create_message(content, ctx);
        post_message(guestbook, message);
    }

    // === View Functions ===

    /// Returns the number of messages in the guestbook
    /// Equivalent to Solidity's messageCount()
    public fun message_count(guestbook: &GuestBook): u64 {
        guestbook.messages.length()
    }

    /// Read a single message by index
    /// @param guestbook - Reference to the GuestBook object
    /// @param index - Zero-based index into the messages array
    /// @return Tuple of (sender address, message content)
    /// 
    /// Note: Unlike Solidity which would revert on out-of-bounds,
    /// we explicitly check and abort with a clear error code.
    public fun get_message(guestbook: &GuestBook, index: u64): (address, String) {
        assert!(index < guestbook.messages.length(), EIndexOutOfBounds);
        let msg = &guestbook.messages[index];
        (msg.sender, msg.content)
    }

    /// Get the sender of a message at the given index
    public fun get_message_sender(guestbook: &GuestBook, index: u64): address {
        assert!(index < guestbook.messages.length(), EIndexOutOfBounds);
        guestbook.messages[index].sender
    }

    /// Get the content of a message at the given index
    public fun get_message_content(guestbook: &GuestBook, index: u64): String {
        assert!(index < guestbook.messages.length(), EIndexOutOfBounds);
        guestbook.messages[index].content
    }

    // === Message Accessors ===

    /// Get the sender from a Message
    public fun message_sender(message: &Message): address {
        message.sender
    }

    /// Get the content from a Message
    public fun message_content(message: &Message): String {
        message.content
    }

    // === Constants Accessor ===

    /// Returns the maximum message length constant
    /// Equivalent to Solidity's public constant MAX_MESSAGE_LENGTH
    public fun max_message_length(): u64 {
        MAX_MESSAGE_LENGTH
    }

    // === Test-only Functions ===

    #[test_only]
    /// Initialize for testing - creates and shares a GuestBook
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    /// Create a GuestBook for testing purposes (returns owned, not shared)
    public fun create_for_testing(ctx: &mut TxContext): GuestBook {
        GuestBook {
            id: object::new(ctx),
            messages: vector::empty<Message>(),
        }
    }

    #[test_only]
    /// Destroy a GuestBook after testing
    public fun destroy_for_testing(guestbook: GuestBook) {
        let GuestBook { id, messages: _ } = guestbook;
        object::delete(id);
    }
}
