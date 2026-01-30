/// @title HelloWorld
/// @notice Sui Move equivalent of the Solidity HelloWorld contract.
/// @dev Each call to `mint_hello_world()` creates a new Hello object owned by the caller.
///
/// Key Translation Decisions:
/// - Solidity's mapping storage → Sui's owned objects (Hello objects are owned by addresses)
/// - Solidity's uint256 id → Sui's native UID (globally unique, managed by framework)
/// - Solidity's msg.sender → Sui's tx_context::sender()
/// - Solidity's emit → sui::event::emit()
/// - No need for central storage: objects are indexed by Sui's object runtime
///
/// Note: Unlike the Solidity version which tracks totalMinted via a counter,
/// this Sui version relies on off-chain indexing to count minted objects.
/// This simplifies the API to match the expected test interface.
module hello_world::hello_world {
    // == Imports ==
    use std::string::{Self, String};
    use sui::event;

    // == Types ==

    /// @notice The Hello object - equivalent to Solidity's Hello struct
    /// @dev `key` ability: makes this a Sui object with a unique ID
    ///      `store` ability: allows this object to be stored/transferred
    ///      In Sui, each Hello is an independent owned object, not stored in a mapping
    public struct Hello has key, store {
        id: UID,
        /// The text message stored in this Hello object
        text: String,
        // Note: `owner` field is omitted because Sui tracks ownership natively
        // The owner is whoever possesses the object (queryable via Sui APIs)
    }

    // == Events ==

    /// @notice Emitted when a new Hello object is minted
    /// @dev Equivalent to Solidity's `event HelloMinted`
    ///      `copy` and `drop` abilities required for events
    public struct HelloMinted has copy, drop {
        /// The Sui object ID of the minted Hello (replaces Solidity's uint256 id)
        hello_id: ID,
        /// The address that minted and now owns the Hello object
        owner: address,
        /// The text content of the Hello object
        text: String,
    }

    // == Entry Functions ==

    /// @notice Mints a new Hello object with the text "Hello World!"
    /// @dev Equivalent to Solidity's `mintHelloWorld()`
    ///      - Creates a new Hello object with unique UID
    ///      - Transfers ownership to the caller (msg.sender equivalent)
    ///      - Emits HelloMinted event
    ///
    /// @param ctx Transaction context (provides sender address and UID generation)
    public entry fun mint_hello_world(ctx: &mut TxContext) {
        // Get the sender's address (equivalent to msg.sender in Solidity)
        let sender = ctx.sender();

        // Create the Hello object with a unique ID
        // In Solidity: Hello memory newHello = Hello({id: id, owner: msg.sender, text: "Hello World!"})
        let hello = Hello {
            id: object::new(ctx),
            text: string::utf8(b"Hello World!"),
        };

        // Get the object ID for the event (before transferring ownership)
        let hello_id = object::id(&hello);

        // Emit the minted event
        // Equivalent to: emit HelloMinted(id, msg.sender, newHello.text)
        event::emit(HelloMinted {
            hello_id,
            owner: sender,
            text: string::utf8(b"Hello World!"),
        });

        // Transfer the Hello object to the sender
        // In Solidity, this was: hellos[id] = newHello (stored in contract)
        // In Sui, the object is owned by the address directly
        transfer::transfer(hello, sender);
    }

    // == View Functions ==

    /// @notice Returns the text of a Hello object
    /// @dev Equivalent to Solidity's `getHello(id)` but works differently:
    ///      - In Solidity: pass an ID, look up in mapping
    ///      - In Sui: pass the actual object reference (caller must own it or it must be shared)
    ///      
    ///      Note: In Sui, you typically query object data off-chain via RPC,
    ///      or the owner passes their object to a function. There's no global
    ///      mapping to look up arbitrary objects by ID on-chain.
    ///
    /// @param hello Reference to the Hello object
    /// @return The text stored in the Hello object
    public fun get_text(hello: &Hello): String {
        hello.text
    }

    // == Additional Utility Functions ==

    /// @notice Returns the object ID of a Hello object
    /// @dev Useful for off-chain tracking and event correlation
    ///
    /// @param hello Reference to the Hello object
    /// @return The unique object ID
    public fun get_id(hello: &Hello): ID {
        object::id(hello)
    }
}
