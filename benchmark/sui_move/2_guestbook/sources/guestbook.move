module guestbook::sui_guestbook;

use std::string::String;

const MAX_MESSAGE_LENGTH: u64 = 200;
const EInvalidLength: u64 = 0;

public struct Message has store {
    sender: address,
    content: String,
}

public struct GuestBook has key, store {
    id: UID,
    messages: vector<Message>,
    no_of_messages: u64,
}

fun init(ctx: &mut TxContext) {
    let guestbook = GuestBook {
        id: object::new(ctx),
        messages: vector::empty<Message>(),
        no_of_messages: 0,
    };
    sui::transfer::share_object(guestbook);
}

public fun post_message(guestbook: &mut GuestBook, message: Message) {
    vector::push_back(&mut guestbook.messages, message);
    guestbook.no_of_messages = guestbook.no_of_messages+1;
}

public fun create_message(message: String, ctx: &mut TxContext): Message {
    assert!(std::string::length(&message) <= MAX_MESSAGE_LENGTH, EInvalidLength);
    Message {
        sender: ctx.sender(),
        content: message,
    }
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}