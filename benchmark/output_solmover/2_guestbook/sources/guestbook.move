module guestbook::guestbook {
    use sui::object::{Self, UID, share_object};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::event::{Self, emit};
    use sui::address::Self;

    // == Constants ==
    const MAX_MESSAGE_LENGTH: u64 = 200;

    // == Structs ==

    /// A message in the guestbook.
    struct Message {
        sender: address,
        content: vector<u8>,
    }

    /// The guestbook state: holds a table of messages and a count.
    /// This object is shared and can be accessed by anyone.
    public struct GuestBook has key {
        id: UID,
        messages: Table<u64, Message>,
        count: u64,
    }

    // == Events ==

    /// Event emitted when a message is posted.
    struct MessagePostedEvent {
        sender: address,
        index: u64,
        content: vector<u8>,
    }

    // == Initialization ==

    /// Initialize the guestbook by creating a new shared object.
    /// This function is called once when the package is published.
    fun init(ctx: &mut TxContext) {
        // Create a new UID for the guestbook object
        let id = object::new(ctx);
        // Create a new table for messages
        let messages = Table::new(ctx);
        // Create the guestbook object and share it
        share_object(GuestBook {
            id,
            messages,
            count: 0,
        });
    }

    // == Entry Functions ==

    /// Post a new message to the guestbook.
    /// Anyone can call this function.
    /// @param message_ The message content (<= 200 bytes).
    public entry fun post_message(message_: vector<u8>, ctx: &mut TxContext) {
        // Check the length of the message
        let len = vector::length(&message_);
        assert!(len <= MAX_MESSAGE_LENGTH, 1001, "Message too long");

        // Get the shared guestbook object
        let guestbook = borrow_global_mut<GuestBook>(@guestbook);

        // Create a new message
        let message = Message {
            sender: tx_context::sender(ctx),
            content: message_,
        };

        // Insert the message into the table at index = count
        Table::insert(&mut guestbook.messages, guestbook.count, message);

        // Increment the count
        guestbook.count = guestbook.count + 1;

        // Emit an event
        emit(MessagePostedEvent {
            sender: tx_context::sender(ctx),
            index: guestbook.count - 1,
            content: message_.clone(),
        });
    }

    /// Get the number of messages in the guestbook.
    /// @return The count of messages.
    public entry fun message_count(ctx: &mut TxContext): u64 {
        let guestbook = borrow_global<GuestBook>(@guestbook);
        guestbook.count
    }

    /// Get a message by index.
    /// @param index The zero-based index of the message.
    /// @return The sender and content of the message.
    public entry fun get_message(index: u64, ctx: &mut TxContext): (address, vector<u8>) {
        let guestbook = borrow_global<GuestBook>(@guestbook);
        // Check if the index is valid
        assert!(index < guestbook.count, 1002, "Index out of bounds");

        // Get the message from the table
        let message = Table::borrow(&guestbook.messages, index);
        (message.sender, message.content.clone())
    }
}