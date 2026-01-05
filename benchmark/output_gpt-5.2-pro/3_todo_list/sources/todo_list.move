module todo_list::todo_list {
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vector;
    use sui::string::{Self, String};

    const E_INDEX_OUT_OF_BOUNDS: u64 = 0;
    const E_OWNER_HAS_NO_LISTS: u64 = 1;

    /// Shared registry mapping owner addresses to their list IDs.
    public struct Registry has key {
        id: UID,
        lists_by_owner: Table<address, vector<ID>>,
    }

    /// Per-user todo list object (owned by the creator).
    public struct TodoList has key, store {
        id: UID,
        items: vector<String>,
    }

    /// Event equivalents of the Solidity contract.
    struct ListCreated has copy, drop, store { list_id: ID, owner: address }
    struct ItemAdded has copy, drop, store { list_id: ID, item: String }
    struct ItemRemoved has copy, drop, store { list_id: ID, index: u64, item: String }
    struct ListDeleted has copy, drop, store { list_id: ID, owner: address }

    /// Initialize and share the registry (runs on package publish).
    public entry fun init(ctx: &mut TxContext) {
        let registry = Registry {
            id: object::new(ctx),
            lists_by_owner: table::new(ctx),
        };
        transfer::share_object(registry);
    }

    /// Create a new todo list for the sender; returns the new list ID.
    public entry fun new_list(registry: &mut Registry, ctx: &mut TxContext): ID {
        let sender = tx_context::sender(ctx);
        let list = TodoList { id: object::new(ctx), items: vector::empty<String>() };
        let list_id = object::id(&list);
        add_list_to_owner(registry, sender, list_id);
        event::emit(ListCreated { list_id, owner: sender });
        transfer::transfer(list, sender);
        list_id
    }

    /// Add a todo item; caller must own the list object.
    public entry fun add(list: &mut TodoList, item: String, ctx: &mut TxContext) {
        let copy_for_event = string::clone(&item);
        vector::push_back(&mut list.items, item);
        event::emit(ItemAdded { list_id: object::id(list), item: copy_for_event });
    }

    /// Remove a todo item by index (swap-remove) and return the removed text.
    public entry fun remove(list: &mut TodoList, index: u64, ctx: &mut TxContext): String {
        assert!(index < vector::length(&list.items), E_INDEX_OUT_OF_BOUNDS);
        let removed = vector::swap_remove(&mut list.items, index);
        event::emit(ItemRemoved { list_id: object::id(list), index, item: string::clone(&removed) });
        removed
    }

    /// Delete an entire list the caller owns and drop it from the registry.
    public entry fun delete_list(registry: &mut Registry, list: TodoList, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let TodoList { id, items } = list;
        let list_id = object::id_from_uid(&id);
        remove_list_from_owner(registry, sender, list_id);
        event::emit(ListDeleted { list_id, owner: sender });
        drop(items);
        object::delete(id);
    }

    /// Read the number of items in a list.
    public fun length(list: &TodoList): u64 {
        vector::length(&list.items)
    }

    /// Read a specific item by index (cloned to return).
    public fun get_item(list: &TodoList, index: u64): String {
        assert!(index < vector::length(&list.items), E_INDEX_OUT_OF_BOUNDS);
        string::clone(vector::borrow(&list.items, index))
    }

    /// View all list IDs owned by a user (borrowed reference to stored vector).
    public fun lists_of(registry: &Registry, owner: address): &vector<ID> {
        assert!(table::contains(&registry.lists_by_owner, owner), E_OWNER_HAS_NO_LISTS);
        table::borrow(&registry.lists_by_owner, owner)
    }

    /// Internal: add list ID to owner’s registry entry (creates entry if absent).
    fun add_list_to_owner(registry: &mut Registry, owner: address, list_id: ID) {
        if (table::contains(&registry.lists_by_owner, owner)) {
            let lists = table::borrow_mut(&mut registry.lists_by_owner, owner);
            vector::push_back(lists, list_id);
        } else {
            table::add(&mut registry.lists_by_owner, owner, vector::singleton(list_id));
        }
    }

    /// Internal: remove list ID from owner’s registry entry via swap-remove.
    fun remove_list_from_owner(registry: &mut Registry, owner: address, list_id: ID) {
        assert!(table::contains(&registry.lists_by_owner, owner), E_OWNER_HAS_NO_LISTS);
        let lists = table::borrow_mut(&mut registry.lists_by_owner, owner);
        let len = vector::length(lists);
        let mut i = 0;
        while (i < len) {
            if (*vector::borrow(lists, i) == list_id) {
                vector::swap_remove(lists, i);
                return;
            };
            i = i + 1;
        };
    }
}