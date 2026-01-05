module todo_list::todo_list {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use std::string::{Self, String};
    use std::vector;

    /// TodoList object that represents a user's todo list
    /// Uses 'key' ability to make it a first-class object
    /// Uses 'store' ability to allow it to be stored in other objects
    public struct TodoList has key, store {
        id: UID,
        owner: address,
        items: vector<String>,
    }

    /// Event emitted when a new list is created
    public struct ListCreated has copy, drop {
        id: UID,
        owner: address,
    }

    /// Event emitted when an item is added to a list
    public struct ItemAdded has copy, drop {
        id: UID,
        item: String,
    }

    /// Event emitted when an item is removed from a list
    public struct ItemRemoved has copy, drop {
        id: UID,
        index: u64,
        item: String,
    }

    /// Event emitted when a list is deleted
    public struct ListDeleted has copy, drop {
        id: UID,
        owner: address,
    }

    /// Initialize the module (runs once when package is published)
    fun init(ctx: &mut TxContext) {
        // No initialization needed for this simple module
    }

    /// Create a new todo list
    /// Returns a new TodoList object that is owned by the sender
    public entry fun new(ctx: &mut TxContext) {
        let list = TodoList {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            items: vector::empty(),
        };

        // Emit creation event
        event::emit(ListCreated {
            id: object::uid_to_inner(&list.id),
            owner: list.owner,
        });

        // Transfer the list to the sender
        transfer::transfer(list, tx_context::sender(ctx));
    }

    /// Add a new todo item to a list
    /// The list object must be passed as a mutable reference
    public entry fun add(list: &mut TodoList, item: String) {
        // Only the owner can add items
        assert!(list.owner == tx_context::sender(tx_context::new()), 0);

        vector::push_back(&mut list.items, item);

        // Emit item added event
        event::emit(ItemAdded {
            id: object::uid_to_inner(&list.id),
            item: string::utf8(item),
        });
    }

    /// Remove an item by index from a list
    /// Returns the removed item as a String
    public entry fun remove(list: &mut TodoList, index: u64): String {
        // Only the owner can remove items
        assert!(list.owner == tx_context::sender(tx_context::new()), 0);

        // Check bounds
        assert!(index < vector::length(&list.items), 1);

        // Get the item to remove
        let removed_item = *vector::borrow(&list.items, index);

        // Remove the item by swapping with last element and popping
        // This is more efficient than shifting all elements
        let last_index = vector::length(&list.items) - 1;
        if (index != last_index) {
            let last_item = *vector::borrow(&list.items, last_index);
            vector::swap(&mut list.items, index, last_index);
            vector::pop_back(&mut list.items);
            vector::push_back(&mut list.items, last_item);
        } else {
            vector::pop_back(&mut list.items);
        }

        // Emit item removed event
        event::emit(ItemRemoved {
            id: object::uid_to_inner(&list.id),
            index: index,
            item: string::utf8(removed_item),
        });

        removed_item
    }

    /// Delete an entire list
    /// The list object is consumed and destroyed
    public entry fun delete(list: TodoList) {
        // Only the owner can delete the list
        assert!(list.owner == tx_context::sender(tx_context::new()), 0);

        // Emit deletion event
        event::emit(ListDeleted {
            id: object::uid_to_inner(&list.id),
            owner: list.owner,
        });

        // The list object is destroyed when this function ends
        // No explicit deletion needed in Move
    }

    /// Get the number of items in a list
    public fun length(list: &TodoList): u64 {
        vector::length(&list.items)
    }

    /// Get a specific item by index
    /// Returns the item as a String
    public fun get_item(list: &TodoList, index: u64): String {
        assert!(index < vector::length(&list.items), 1);
        *vector::borrow(&list.items, index)
    }

    /// Get all list IDs owned by a user
    /// In Sui, this would typically be handled by querying the user's owned objects
    /// rather than maintaining a separate mapping like in Solidity
    public fun get_lists_of(owner: address): vector<UID> {
        // In a real implementation, this would query the user's owned TodoList objects
        // For this translation, we return an empty vector as a placeholder
        vector::empty()
    }
}