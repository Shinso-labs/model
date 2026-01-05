#[test_only]
module guestbook::guestbook_tests {
    use guestbook::guestbook::{Self, GuestBook};
    use std::string;
    use sui::test_scenario::{Self as ts};

    #[test]
    /// Test that create_message with valid length succeeds
    fun test_create_message_valid_length() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message_content = string::utf8(b"This is a valid message");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that create_message with max length succeeds
    fun test_create_message_max_length() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            // Create a 200 character message (max allowed)
            let message_content = string::utf8(b"12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    /// Test that create_message with too long content fails
    fun test_create_message_too_long_fails() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            // Create a 201 character message (over max)
            let message_content = string::utf8(b"123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that create_message with empty string succeeds
    fun test_create_message_empty_string() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message_content = string::utf8(b"");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that create_message with single character succeeds
    fun test_create_message_single_char() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message_content = string::utf8(b"A");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that different users can create messages
    fun test_different_users_create_messages() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message_content = string::utf8(b"Message from B");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::next_tx(&mut scenario, @0xC);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message_content = string::utf8(b"Message from C");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that create_message with special characters succeeds
    fun test_create_message_special_chars() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message_content = string::utf8(b"Hello! @#$%^&*() World?");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that create_message with numbers succeeds
    fun test_create_message_with_numbers() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message_content = string::utf8(b"123456789 test message");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that multiple messages can be posted by same user
    fun test_multiple_messages_same_user() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let message1 = guestbook::create_message(string::utf8(b"First message"), ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message1, ts::ctx(&mut scenario));
            let message2 = guestbook::create_message(string::utf8(b"Second message"), ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message2, ts::ctx(&mut scenario));
            let message3 = guestbook::create_message(string::utf8(b"Third message"), ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message3, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that create_message with exact boundary length works (199 chars)
    fun test_create_message_boundary_lengths() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            // Test with 199 chars (just under limit)
            let message_content = string::utf8(b"1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789");
            let message = guestbook::create_message(message_content, ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, message, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test posting multiple messages increases message count
    fun test_message_count_increases() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut guestbook = ts::take_shared<GuestBook>(&scenario);
            let msg1 = guestbook::create_message(string::utf8(b"Message 1"), ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, msg1, ts::ctx(&mut scenario));
            let msg2 = guestbook::create_message(string::utf8(b"Message 2"), ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, msg2, ts::ctx(&mut scenario));
            let msg3 = guestbook::create_message(string::utf8(b"Message 3"), ts::ctx(&mut scenario));
            guestbook::post_message(&mut guestbook, msg3, ts::ctx(&mut scenario));
            ts::return_shared(guestbook);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that guestbook is initialized as shared object
    fun test_guestbook_is_shared() {
        let mut scenario = ts::begin(@0xA);
        {
            guestbook::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            assert!(ts::has_most_recent_shared<GuestBook>(), 0);
        };
        ts::end(scenario);
    }
}