/// @title Counter NFT (shared increment, owner-settable)
/// @notice A Sui Move translation of the Solidity Counter ERC721 contract.
/// Each Counter is a shared object that anyone can increment,
/// but only the owner can set to an arbitrary value.
module counter::counter {
    // ============ Imports ============
    use sui::event;

    // ============ Error Constants ============
    /// Error when caller is not the owner
    const ENotOwner: u64 = 0;

    // ============ Structs ============

    /// The Counter NFT object.
    /// - `key`: Makes it a Sui object with a unique ID
    /// - `store`: Allows it to be transferred and stored
    /// 
    /// We use a shared object model because anyone can increment.
    /// The `owner` field tracks who can call `set_value`.
    public struct Counter has key, store {
        id: UID,
        /// The current counter value
        value: u64,
        /// The owner who can set arbitrary values
        /// (tracked explicitly since shared objects don't have a single owner)
        owner: address,
    }

    // ============ Events ============

    /// Emitted when a new Counter NFT is created
    public struct CounterCreated has copy, drop {
        counter_id: ID,
        owner: address,
    }

    /// Emitted when a counter is incremented
    public struct Incremented has copy, drop {
        counter_id: ID,
        new_value: u64,
    }

    /// Emitted when a counter value is set by the owner
    public struct ValueSet has copy, drop {
        counter_id: ID,
        new_value: u64,
    }

    /// Emitted when ownership is transferred
    public struct OwnershipTransferred has copy, drop {
        counter_id: ID,
        previous_owner: address,
        new_owner: address,
    }

    // ============ Public Entry Functions ============

    /// Create and share a new Counter NFT with initial value 0.
    /// The caller becomes the owner (stored in the object).
    /// 
    /// Translation note: In Solidity, _safeMint gives ownership via ERC721.
    /// In Sui, we use a shared object with an explicit owner field,
    /// allowing anyone to call increment while restricting setValue.
    public entry fun create(ctx: &mut TxContext) {
        let sender = ctx.sender();
        
        let counter = Counter {
            id: object::new(ctx),
            value: 0,
            owner: sender,
        };

        // Emit creation event
        event::emit(CounterCreated {
            counter_id: object::id(&counter),
            owner: sender,
        });

        // Share the object so anyone can interact with it
        // This is necessary for the "anyone can increment" requirement
        transfer::share_object(counter);
    }

    /// Anyone can increment a counter by 1 (shared access).
    /// 
    /// Translation note: In Solidity, this required checking _exists().
    /// In Sui, if the object doesn't exist, the transaction fails
    /// before this function is even called (object resolution fails).
    public entry fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
        
        event::emit(Incremented {
            counter_id: object::id(counter),
            new_value: counter.value,
        });
    }

    /// Set the counter to an arbitrary value (only owner).
    /// 
    /// Translation note: Solidity used ownerOf(tokenId) == msg.sender.
    /// We check the stored owner field against tx sender.
    public entry fun set_value(
        counter: &mut Counter,
        new_value: u64,
        ctx: &TxContext,
    ) {
        // Only the owner can set arbitrary values
        assert!(counter.owner == ctx.sender(), ENotOwner);
        
        counter.value = new_value;
        
        event::emit(ValueSet {
            counter_id: object::id(counter),
            new_value,
        });
    }

    /// Transfer ownership of the Counter to a new address.
    /// This mimics ERC721 transfer functionality for the owner role.
    /// Only the current owner can transfer ownership.
    public entry fun transfer_ownership(
        counter: &mut Counter,
        new_owner: address,
        ctx: &TxContext,
    ) {
        assert!(counter.owner == ctx.sender(), ENotOwner);
        
        let previous_owner = counter.owner;
        counter.owner = new_owner;
        
        event::emit(OwnershipTransferred {
            counter_id: object::id(counter),
            previous_owner,
            new_owner,
        });
    }

    // ============ View Functions ============

    /// Read the current counter value.
    /// 
    /// Translation note: In Solidity this was a view function.
    /// In Move, we return the value directly. This can be called
    /// via devInspect or from other Move functions.
    public fun get_value(counter: &Counter): u64 {
        counter.value
    }

    /// Get the owner of the counter.
    public fun get_owner(counter: &Counter): address {
        counter.owner
    }

    /// Get the object ID of the counter.
    /// Equivalent to tokenId in the Solidity version.
    public fun get_id(counter: &Counter): ID {
        object::id(counter)
    }
}
