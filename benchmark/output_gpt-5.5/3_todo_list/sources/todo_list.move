module todo_list::todo_list;

use std::string::String;

// Sui-native TodoList object.
//
// This module exposes the API expected by the tests:
//
// - todo_list::new(ctx)
// - todo_list::add(&mut list, item)
// - todo_list::remove(&mut list, index)
// - todo_list::length(&list)
// - todo_list::delete(list)
//
// Each list is an owned Sui object. Sui object ownership controls who can pass
// the object by value or mutable reference in a transaction.
public struct TodoList has key, store {
    id: UID,
    items: vector<String>,
}

// Create a new empty todo list.
public fun new(ctx: &mut TxContext): TodoList {
    TodoList {
        id: object::new(ctx),
        items: vector::empty<String>(),
    }
}

// Add a new todo item.
public fun add(list: &mut TodoList, item: String) {
    vector::push_back(&mut list.items, item);
}

// Remove an item by index and return it.
//
// This uses swap-remove semantics, matching the Solidity implementation:
//
// list.items[index] = list.items[list.items.length - 1];
// list.items.pop();
//
// Removal is efficient but does not preserve ordering.
public fun remove(list: &mut TodoList, index: u64): String {
    assert!(index < vector::length(&list.items), 0);
    vector::swap_remove(&mut list.items, index)
}

// Delete the todo list object.
//
// Consumes the object and deletes its UID. The vector of strings is dropped.
public fun delete(list: TodoList) {
    let TodoList { id, items: _ } = list;
    object::delete(id);
}

// Return the number of todo items.
public fun length(list: &TodoList): u64 {
    vector::length(&list.items)
}

// Return a copy of an item by index.
public fun get_item(list: &TodoList, index: u64): String {
    assert!(index < vector::length(&list.items), 0);
    *vector::borrow(&list.items, index)
}

// Compatibility alias for callers using Solidity-style naming.
public fun delete_list(list: TodoList) {
    delete(list);
}
