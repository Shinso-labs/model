module todo_list::todo_list {
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    // Event definitions
    struct ListCreated has copy, drop {
        id: ID,
        owner: address
    }

    struct ItemAdded has copy, drop {
        id: ID,
        item: String
    }

    struct ItemRemoved has copy, drop {
        id: ID,
        index: u64,
        item: String
    }

    struct ListDeleted has copy, drop {
        id: ID,
        owner: address
    }

    // Main TodoList object - each user can own multiple of these
    public struct TodoList has key {
        id: UID,
        owner: address,
        items: vector<String>
    }

    // Create a new todo list
    public entry fun new(ctx: &mut TxContext): TodoList {
        let list = TodoList {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            items: vector[]
        };

        // Emit event
        event::emit(ListCreated {
            id: object::uid_to_inner(&list.id),
            owner: tx_context::sender(ctx)
        });

        list
    }

    // Add a new item to the list
    public entry fun add(list: &mut TodoList, item: String, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == list.owner, 0); // Only owner can add
        vector::push_back(&mut list.items, item);

        // Emit event
        event::emit(ItemAdded {
            id: object::uid_to_inner(&list.id),
            item
        });
    }

    // Remove an item by index
    public entry fun remove(list: &mut TodoList, index: u64, ctx: &TxContext): String {
        assert!(tx_context::sender(ctx) == list.owner, 0); // Only owner can remove
        assert!(index < vector::length(&list.items), 1); // Check bounds

        let removed_item = vector::remove(&mut list.items, index);

        // Emit event
        event::emit(ItemRemoved {
            id: object::uid_to_inner(&list.id),
            index,
            item: removed_item
        });

        removed_item
    }

    // Delete the entire list (transfer to sender for deletion)
    public entry fun delete(list: TodoList, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == list.owner, 0); // Only owner can delete
        
        let list_id = object::uid_to_inner(&list.id);
        let owner = list.owner;
        
        // Emit event before destroying the object
        event::emit(ListDeleted {
            id: list_id,
            owner
        });
        
        let TodoList { id, owner: _, items: _ } = list;
        object::delete(id);
    }

    // Get the number of items in the list
    public fun length(list: &TodoList): u64 {
        vector::length(&list.items)
    }

    // Get a specific item by index
    public fun get_item(list: &TodoList, index: u64): &String {
        assert!(index < vector::length(&list.items), 1); // Check bounds
        vector::borrow(&list.items, index)
    }

    // Get the owner of the list
    public fun owner(list: &TodoList): address {
        list.owner
    }

    // Get all items (for viewing)
    public fun items(list: &TodoList): &vector<String> {
        &list.items
    }
}