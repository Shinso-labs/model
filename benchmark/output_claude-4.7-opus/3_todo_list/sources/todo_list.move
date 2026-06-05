// sources/todo_list.move
/// A Todo List module — Sui Move translation of the Solidity TodoList contract.
///
/// Translation decisions:
/// - Each `List` in Solidity becomes an owned `TodoList` object in Sui.
/// - The `mapping(uint256 => List) lists` is unnecessary: Sui objects have
///   built-in unique IDs (`UID`) and are indexed by the network.
/// - The `mapping(address => uint256[]) ownerLists` is unnecessary: Sui
///   tracks owned objects per address natively, queryable via RPC/indexers.
/// - Owner authorization (`_requireOwner`) is implicit: only the address that
///   owns a `TodoList` object can pass it to a function as `&mut`.
/// - Strings use Sui's `std::string::String` (UTF-8 validated) instead of `vector<u8>`.
/// - Reentrancy is impossible in Move: no arbitrary external calls + linear types.
/// - Functions are `public` (not `public entry`) for full PTB composability.
module todo_list::todo_list;

use std::string::String;
use sui::event;

// === Errors ===

/// Index passed to `remove` or `get_item` is out of bounds.
const EIndexOutOfBounds: u64 = 0;

// === Structs ===

/// A user-owned Todo List. The `key` ability makes it a first-class Sui object;
/// `store` is intentionally omitted so it can only live as a top-level owned object
/// (mirroring the Solidity model where lists aren't transferable into other structs).
public struct TodoList has key {
    id: UID,
    owner: address,
    items: vector<String>,
}

// === Events ===

/// Emitted when a new TodoList is created.
public struct ListCreated has copy, drop {
    id: ID,
    owner: address,
}

/// Emitted when an item is added.
public struct ItemAdded has copy, drop {
    id: ID,
    item: String,
}

/// Emitted when an item is removed.
public struct ItemRemoved has copy, drop {
    id: ID,
    index: u64,
    item: String,
}

/// Emitted when a list is deleted.
public struct ListDeleted has copy, drop {
    id: ID,
    owner: address,
}

// === Public Functions ===

/// Create a new todo list. Equivalent to Solidity `newList()`.
///
/// Returns the `TodoList` object directly so the caller can decide whether
/// to transfer it, share it, or pass it to other functions in the same PTB.
/// This matches the conventional Sui Move pattern (e.g., `object::new`).
public fun new(ctx: &mut TxContext): TodoList {
    let owner = ctx.sender();
    let uid = object::new(ctx);
    let id = uid.to_inner();

    event::emit(ListCreated { id, owner });

    TodoList {
        id: uid,
        owner,
        items: vector::empty<String>(),
    }
}

/// Convenience wrapper: creates a list and transfers it to the sender.
/// Useful for direct CLI/SDK calls that don't compose further.
public fun create_and_transfer(ctx: &mut TxContext) {
    let list = new(ctx);
    transfer::transfer(list, ctx.sender());
}

/// Add a new todo item to the list.
/// Equivalent to Solidity `add(listId, item)`.
///
/// Note: Owner check is implicit — only the owner of the object can pass
/// `&mut TodoList` because Sui only delivers owned objects to their owner.
public fun add(list: &mut TodoList, item: String) {
    list.items.push_back(item);
    event::emit(ItemAdded {
        id: list.id.to_inner(),
        item,
    });
}

/// Remove an item by index using swap_remove (O(1), matches Solidity's
/// "swap with last + pop" pattern).
/// Equivalent to Solidity `remove(listId, index)`.
public fun remove(list: &mut TodoList, index: u64): String {
    assert!(index < list.items.length(), EIndexOutOfBounds);
    let removed = list.items.swap_remove(index);
    event::emit(ItemRemoved {
        id: list.id.to_inner(),
        index,
        item: removed,
    });
    removed
}

/// Delete the entire list, destroying the object.
/// Equivalent to Solidity `deleteList(listId)`.
///
/// Takes `TodoList` by value, ensuring it is consumed (cannot be used again).
public fun delete(list: TodoList) {
    let TodoList { id, owner, items: _ } = list;
    let inner_id = id.to_inner();
    event::emit(ListDeleted { id: inner_id, owner });
    id.delete();
}

// === View Functions ===

/// Number of items in the list. Equivalent to Solidity `length(listId)`.
public fun length(list: &TodoList): u64 {
    list.items.length()
}

/// View a specific item by index. Equivalent to Solidity `getItem(listId, index)`.
public fun get_item(list: &TodoList, index: u64): &String {
    assert!(index < list.items.length(), EIndexOutOfBounds);
    &list.items[index]
}

/// Returns the recorded owner address of the list.
public fun owner(list: &TodoList): address {
    list.owner
}

/// Returns the object ID of the list.
public fun id(list: &TodoList): ID {
    list.id.to_inner()
}
