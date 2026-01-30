/// @title TodoList
/// @notice Sui Move implementation of a personal todo list manager.
/// @dev Each TodoList is an owned object. The owner is implicitly the transaction sender
/// who created it. Sui's object ownership model provides automatic access control.
module todo_list::todo_list {
    // === Imports ===
    use std::string::String;

    // === Errors ===
    /// Error code when attempting to access an item at an invalid index
    const EIndexOutOfBounds: u64 = 0;

    // === Structs ===

    /// A todo list owned by a single address.
    /// - `key`: Makes this a Sui object with a unique ID
    /// - `store`: Allows the object to be transferred and stored in other objects
    /// 
    /// Translation note: In Solidity, lists were stored in a contract mapping.
    /// In Sui, each list is an independent owned object, automatically tracked
    /// by the Sui runtime. No need for manual ID generation or owner mappings.
    public struct TodoList has key, store {
        id: UID,
        /// Dynamic array of todo items (replaces Solidity's string[] items)
        items: vector<String>,
    }

    // === Events ===
    
    /// Emitted when a new todo list is created
    /// Translation note: In Solidity, we emitted (id, owner). In Sui, the object ID
    /// is available from the transaction effects, and owner is the transaction sender.
    public struct ListCreated has copy, drop {
        /// The object ID of the newly created list
        list_id: ID,
    }

    /// Emitted when an item is added to a list
    public struct ItemAdded has copy, drop {
        /// The object ID of the list
        list_id: ID,
        /// The item text that was added
        item: String,
    }

    /// Emitted when an item is removed from a list
    public struct ItemRemoved has copy, drop {
        /// The object ID of the list
        list_id: ID,
        /// The index from which the item was removed
        index: u64,
        /// The item text that was removed
        item: String,
    }

    /// Emitted when a list is deleted
    public struct ListDeleted has copy, drop {
        /// The object ID of the deleted list
        list_id: ID,
    }

    // === Public Entry Functions ===

    /// Create a new empty todo list.
    /// 
    /// Translation note: In Solidity, this was `newList()` which stored the list
    /// in contract storage and tracked ownership via mappings. In Sui, we create
    /// an owned object that is automatically transferred to the transaction sender.
    /// 
    /// @param ctx: Transaction context (provides sender address and fresh UID)
    public fun new(ctx: &mut TxContext): TodoList {
        let list = TodoList {
            id: object::new(ctx),
            items: vector[],
        };

        // Emit creation event
        sui::event::emit(ListCreated {
            list_id: object::id(&list),
        });

        list
    }

    /// Create a new todo list and transfer it to the sender.
    /// 
    /// This is the entry point version that handles the transfer automatically.
    /// Equivalent to Solidity's `newList()` external function.
    entry fun create(ctx: &mut TxContext) {
        transfer::transfer(new(ctx), ctx.sender());
    }

    /// Add a new todo item to the list.
    /// 
    /// Translation note: In Solidity, we had `_requireOwner(listId)` to verify
    /// ownership. In Sui, ownership is enforced by the runtime—only the owner
    /// can pass their owned object to this function.
    /// 
    /// @param list: Mutable reference to the todo list (must be owned by sender)
    /// @param item: The todo text to add
    public fun add(list: &mut TodoList, item: String) {
        // Emit event before mutation for clarity
        sui::event::emit(ItemAdded {
            list_id: object::id(list),
            item, // String has copy ability
        });

        list.items.push_back(item);
    }

    /// Remove an item by index using swap-and-pop for efficiency.
    /// 
    /// Translation note: This preserves the Solidity implementation's gas-efficient
    /// swap-and-pop pattern. The last element is moved to fill the gap, then the
    /// vector is truncated. This is O(1) but does NOT preserve order.
    /// 
    /// @param list: Mutable reference to the todo list
    /// @param index: Zero-based index of the item to remove
    /// @return The removed item text
    public fun remove(list: &mut TodoList, index: u64): String {
        // Bounds check (equivalent to Solidity's require)
        assert!(index < list.items.length(), EIndexOutOfBounds);

        // Swap-and-pop: move last element to the removal index, then pop
        // This is the same pattern as the Solidity implementation
        let removed_item = list.items.swap_remove(index);

        // Emit event with removal details
        sui::event::emit(ItemRemoved {
            list_id: object::id(list),
            index,
            item: removed_item, // String has copy
        });

        removed_item
    }

    /// Delete an entire todo list.
    /// 
    /// Translation note: In Solidity, `delete lists[listId]` zeroed out storage.
    /// In Move, we must explicitly unpack and destroy the struct. The UID must
    /// be deleted via `object::delete()` to properly clean up the object.
    /// 
    /// @param list: The todo list to delete (consumed by this function)
    public fun delete(list: TodoList) {
        // Emit deletion event before destroying
        sui::event::emit(ListDeleted {
            list_id: object::id(&list),
        });

        // Unpack the struct - this is required in Move to consume a resource
        let TodoList { id, items: _ } = list;
        
        // Delete the UID (required for objects with `key` ability)
        object::delete(id);
        
        // `items` vector is automatically dropped (String and vector have drop)
    }

    // === View Functions ===

    /// Get the number of items in a list.
    /// 
    /// Translation note: In Solidity this was `length(listId) external view`.
    /// In Sui, we take an immutable reference to the object directly.
    /// 
    /// @param list: Immutable reference to the todo list
    /// @return The number of todo items
    public fun length(list: &TodoList): u64 {
        list.items.length()
    }

    /// Get a specific item by index.
    /// 
    /// Translation note: Equivalent to Solidity's `getItem(listId, index)`.
    /// Returns an immutable reference to avoid copying.
    /// 
    /// @param list: Immutable reference to the todo list
    /// @param index: Zero-based index of the item
    /// @return Immutable reference to the item text
    public fun get_item(list: &TodoList, index: u64): &String {
        assert!(index < list.items.length(), EIndexOutOfBounds);
        &list.items[index]
    }

    /// Get all items in the list.
    /// 
    /// @param list: Immutable reference to the todo list
    /// @return Immutable reference to the items vector
    public fun items(list: &TodoList): &vector<String> {
        &list.items
    }

    // === Note on getListsOf ===
    // 
    // The Solidity function `getListsOf(address user)` returned all list IDs owned
    // by a user. In Sui, this functionality is provided by the Sui RPC/indexer:
    // - Use `sui_getOwnedObjects` with a type filter for `TodoList`
    // - This is more efficient as it's handled at the infrastructure level
    // - No on-chain storage needed for owner → lists mapping
}
