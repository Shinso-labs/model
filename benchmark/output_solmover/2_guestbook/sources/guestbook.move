module guestbook::sui_guestbook {

    use std::string::String;
    
    /// Maximum allowed message length in characters
    const MAX_MESSAGE_LENGTH: u64 = 200;
    /// Error code for messages exceeding max length
    const EInvalidLength: u64 = 0;
    
    /// Individual message entry with sender and content
    public struct Message has store {
        sender: address,
        content: String,
    }
    
    /// Shared guestbook containing all messages
    public struct GuestBook has key, store {
        id: UID,
        messages: vector<Message>,      // All messages posted
        no_of_messages: u64,             // Total message count
    }
    
    /// Creates and shares a new empty guestbook
    fun init(ctx: &mut TxContext) {
        let guestbook = GuestBook {
            id: object::new(ctx),
            messages: vector::empty<Message>(),
            no_of_messages: 0,
        };
        sui::transfer::share_object(guestbook);
    }
    
    /// Adds a message to the guestbook and increments counter
    public fun post_message(guestbook: &mut GuestBook, message: Message) {
        vector::push_back(&mut guestbook.messages, message);
        guestbook.no_of_messages = guestbook.no_of_messages + 1;
    }
    
    /// Creates a new message with length validation
    public fun create_message(message: String, ctx: &mut TxContext): Message {
        assert!(std::string::length(&message) <= MAX_MESSAGE_LENGTH, EInvalidLength);
        Message {
            sender: ctx.sender(),
            content: message,
        }
    }
    
    /// Test-only function to initialize guestbook in tests
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}