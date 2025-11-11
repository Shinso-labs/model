module hello_world::hello_world {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::string::{Self, String};

    /// Represents a "Hello World!" message object.
    /// Each `Hello` object is a unique resource owned by an address.
    public struct Hello has key, store {
        id: UID,
        owner: address,
        text: String,
    }

    /// A shared object to keep track of the total number of Hello objects minted.
    /// This replaces the `nextId` private variable in the Solidity contract.
    public struct Counter has key {
        id: UID,
        count: u64,
    }

    /// Event emitted when a new Hello object is minted.
    /// This is equivalent to the `HelloMinted` event in Solidity.
    public struct HelloMintedEvent has copy, drop {
        id: ID,
        owner: address,
        text: String,
    }

    /// Module initializer. This function runs once when the package is published.
    /// It creates and shares the `Counter` object, making it accessible to all.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Counter {
            id: object::new(ctx),
            count: 0,
        });
    }

    /// Mints a new `Hello` object with the text "Hello World!" and transfers
    /// ownership to the transaction sender.
    /// This is equivalent to Solidity's `mintHelloWorld()` function.
    public entry fun mint_hello_world(counter: &mut Counter, ctx: &mut TxContext) {
        // Increment the global counter for minted objects
        counter.count = counter.count + 1;

        // Create a new Hello object
        let new_hello = Hello {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            text: string::utf8(b"Hello World!"),
        };

        // Emit an event to signal that a new Hello object has been minted
        event::emit(HelloMintedEvent {
            id: object::id(&new_hello),
            owner: new_hello.owner,
            text: new_hello.text,
        });

        // Transfer ownership of the new Hello object to the sender
        transfer::public_transfer(new_hello, tx_context::sender(ctx));
    }

    /// Returns the owner and text of a specific `Hello` object.
    /// In Sui, to query an owned object, you typically pass a reference to the object itself.
    /// The client would provide the object's UID to retrieve it.
    /// This is equivalent to Solidity's `getHello(uint256 id)` function.
    public fun get_hello(hello: &Hello): (address, String) {
        (hello.owner, hello.text)
    }

    /// Returns the total number of `Hello` objects ever minted.
    /// This reads the `count` from the shared `Counter` object.
    /// This is equivalent to Solidity's `totalMinted()` function.
    public fun total_minted(counter: &Counter): u64 {
        counter.count
    }
}