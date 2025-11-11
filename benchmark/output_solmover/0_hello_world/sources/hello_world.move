module hello_world::hello_world {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{Self, emit};
    use sui::table::{Self, Table};
    use sui::transfer;

    // == Types ==

    /// A Hello object representing a "Hello World!" message.
    /// This is a resource that can be owned and transferred.
    public struct Hello has key {
        id: UID,
        owner: address,
        text: vector<u8>, // Using vector<u8> for string-like data
    }

    // == Storage ==

    // Table to store Hello objects by ID
    // This replaces the Solidity mapping(uint256 => Hello)
    // The table is owned by the module and can be accessed via entry functions
    const HELLO_TABLE: &str = "hello_table";

    // == Events ==

    /// Event emitted when a new Hello is minted.
    public struct HelloMintedEvent has drop {
        id: u64,
        owner: address,
        text: vector<u8>,
    }

    // == Module Initialization ==

    /// Initialize the module and create the table for storing Hello objects.
    /// This function is called once when the package is published.
    fun init(ctx: &mut TxContext) {
        // Create and store the table under the module's address
        // The table is owned by the module and can be accessed via the module's address
        let table = Table::new(ctx);
        Table::save(table, HELLO_TABLE);
    }

    // == Entry Functions ==

    /// Mints a new Hello object with the text "Hello World!".
    /// @param ctx The transaction context.
    /// @return The ID of the newly minted Hello object.
    /// @dev Equivalent to Solidity's `mintHelloWorld()`.
    public entry fun mint_hello_world(ctx: &mut TxContext) {
        // Generate a new ID (simple incrementing counter)
        // In a real app, you might use a more sophisticated ID generation
        let id = next_id(ctx);

        // Create the new Hello object
        let new_hello = Hello {
            id,
            owner: tx_context::sender(ctx),
            text: b"Hello World!",
        };

        // Store the Hello object in the table
        let table = Table::borrow_mut(HELLO_TABLE);
        Table::insert(table, id, new_hello);

        // Emit the HelloMinted event
        emit(HelloMintedEvent {
            id,
            owner: tx_context::sender(ctx),
            text: b"Hello World!",
        });
    }

    /// Returns data for a specific Hello object.
    /// @param id The ID of the Hello object.
    /// @return The owner and text of the Hello object.
    /// @dev Equivalent to Solidity's `getHello()`.
    public fun get_hello(id: u64): (address, vector<u8>) {
        let table = Table::borrow(HELLO_TABLE);
        let hello = Table::borrow(&table, id)
            .expect("Hello object with this ID does not exist");

        (hello.owner, hello.text)
    }

    /// Returns the total number of Hello objects ever minted.
    /// @return The total count of minted Hello objects.
    /// @dev Equivalent to Solidity's `totalMinted()`.
    public fun total_minted(): u64 {
        let table = Table::borrow(HELLO_TABLE);
        Table::len(&table)
    }

    // == Helper Functions ==

    /// Returns the next available ID.
    /// This is a simple incrementing counter stored in the table.
    /// In a real app, you might want to use a more sophisticated ID generation.
    fun next_id(ctx: &mut TxContext) : u64 {
        let table = Table::borrow_mut(HELLO_TABLE);
        let current_id = Table::get(&table, "next_id")
            .unwrap_or_else(|| 1u64);

        // Update the next_id counter
        Table::insert(&mut table, "next_id", current_id + 1);

        current_id
    }
}