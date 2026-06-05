// sources/sui_guestbook.move

module guestbook::sui_guestbook {
    /// Maximum message length in bytes.
    ///
    /// Solidity equivalent:
    /// `uint256 public constant MAX_MESSAGE_LENGTH = 200;`
    const MAX_MESSAGE_LENGTH: u64 = 200;

    /// Equivalent to Solidity custom error `InvalidLength()`.
    const EInvalidLength: u64 = 0;

    /// Explicit bounds error for indexed reads.
    const EIndexOutOfBounds: u64 = 1;

    /// A single guestbook message.
    ///
    /// Solidity:
    ///
