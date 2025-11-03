// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GuestBook
/// @notice Minimal guestbook: anyone can post a short message (<= 200 bytes).
/// @dev Mirrors the Sui Move example: Message{sender, content}, vector<Message>, length check.
contract GuestBook {
    // == Constants ==
    uint256 public constant MAX_MESSAGE_LENGTH = 200;

    // == Errors ==
    error InvalidLength();

    // == Types ==
    struct Message {
        address sender;
        string content;
    }

    // == Storage ==
    Message[] private messages;

    // == Events ==
    event MessagePosted(address indexed sender, uint256 indexed index, string content);

    // == External API ==

    /// @notice Post a new message to the guestbook.
    /// @param message_ The message content (<= 200 bytes).
    function postMessage(string calldata message_) external {
        // Solidity strings are UTF-8; we enforce length in BYTES to approximate Move's length guard.
        if (bytes(message_).length > MAX_MESSAGE_LENGTH) revert InvalidLength();

        messages.push(Message({sender: msg.sender, content: message_}));
        emit MessagePosted(msg.sender, messages.length - 1, message_);
    }

    /// @notice Number of messages in the guestbook (Move's `no_of_messages`).
    function messageCount() external view returns (uint256) {
        return messages.length;
    }

    /// @notice Read a single message by index (since returning an array of strings is heavy on-chain).
    /// @param index The zero-based index into the messages array.
    /// @return sender The address that posted the message.
    /// @return content The message text.
    function getMessage(uint256 index) external view returns (address sender, string memory content) {
        Message storage m = messages[index];
        return (m.sender, m.content);
    }
}