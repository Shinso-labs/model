module todo_list::todo_list {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{Self, emit};
    use sui::table::{Self, Table};
    use sui::transfer;

    // == Types ==

    /// Represents a todo list owned by an address
    struct List has key {
        id: u64,
        owner: address,
        items: vector<u8>,
        exists: bool,
    }

    /// Shared storage for all lists and their mappings
    struct TodoListStore has key {
        next_id: u64,
        lists: Table<u64, List>,
        owner_lists: Table<address, vector<u64>>,
    }

    // == Events ==

    /// Emitted when a new list is created
    struct ListCreatedEvent {
        list_id: u64,
        owner: address,
    }

    /// Emitted when an item is added
    struct ItemAddedEvent {
        list_id: u64,
        item: vector<u8>,
    }

    /// Emitted when an item is removed
    struct ItemRemovedEvent {
        list_id: u64,
        index: u64,
        item: vector<u8>,
    }

    /// Emitted when a list is deleted
    struct ListDeletedEvent {
        list_id: u64,
        owner: address,
    }

    // == Initialization ==

    /// Initialize the TodoListStore (runs once on package publish)
    fun init(ctx: &mut TxContext) {
        let store = TodoListStore {
            next_id: 1,
            lists: Table::new(ctx),
            owner_lists: Table::new(ctx),
        };
        transfer::share_object(store);
    }

    // == Entry Functions ==

    /// Create a new todo list
    public entry fun new(ctx: &mut TxContext) {
        let store = transfer::borrow<TodoListStore>(@todo_list);
        let list_id = store.next_id;
        store.next_id = store.next_id + 1;

        let list = List {
            id: list_id,
            owner: tx_context::sender(ctx),
            items: vector::empty(),
            exists: true,
        };

        // Store list in global table
        Table::insert(&mut store.lists, list_id, list);

        // Add list ID to owner's list array
        let owner = tx_context::sender(ctx);
        let owner_list_ids = Table::get_or_else(&mut store.owner_lists, owner, || vector::empty());
        vector::push_back(&mut owner_list_ids, list_id);
        Table::insert(&mut store.owner_lists, owner, owner_list_ids);

        // Emit event
        emit(ListCreatedEvent {
            list_id,
            owner,
        });
    }

    /// Add a new todo item to a list
    public entry fun add(list_id: u64, item: vector<u8>) {
        let store = borrow_global_mut<TodoListStore>(@todo_list);
        let list = Table::borrow_mut(&mut store.lists, list_id)
            .expect("List not found");

        // Verify ownership
        assert!(list.owner == tx_context::sender(&mut TxContext::new()), "Not list owner");

        // Add item
        vector::push_back(&mut list.items, item);

        // Emit event
        emit(ItemAddedEvent {
            list_id,
            item,
        });
    }

    /// Remove an item by index
    public entry fun remove(list_id: u64, index: u64) {
        let store = borrow_global_mut<TodoListStore>(@todo_list);
        let list = Table::borrow_mut(&mut store.lists, list_id)
            .expect("List not found");

        // Verify ownership
        assert!(list.owner == tx_context::sender(&mut TxContext::new()), "Not list owner");

        // Check bounds
        assert!(index < vector::length(&list.items), "Index out of bounds");

        // Remove item
        let removed_item = vector::remove(&mut list.items, index);

        // Emit event
        emit(ItemRemovedEvent {
            list_id,
            index,
            item: removed_item,
        });
    }

    /// Delete an entire list
    public entry fun delete(list_id: u64) {
        let store = borrow_global_mut<TodoListStore>(@todo_list);
        let list = Table::remove(&mut store.lists, list_id)
            .expect("List not found");

        // Verify ownership
        assert!(list.owner == tx_context::sender(&mut TxContext::new()), "Not list owner");

        // Remove list ID from owner's list array
        let owner = list.owner;
        let owner_list_ids = Table::get_mut(&mut store.owner_lists, owner)
            .expect("Owner list not found");
        let index = vector::find_index(owner_list_ids, |id| *id == list_id)
            .expect("List not in owner's list");
        vector::remove(owner_list_ids, index);

        // Emit event
        emit(ListDeletedEvent {
            list_id,
            owner,
        });
    }

    // == View Functions ==

    /// Get the number of items in a list
    public fun length(list_id: u64): u64 {
        let store = borrow_global<TodoListStore>(@todo_list);
        let list = Table::borrow(&store.lists, list_id)
            .expect("List not found");
        vector::length(&list.items)
    }

    /// Get a specific item by index
    public fun get_item(list_id: u64, index: u64): vector<u8> {
        let store = borrow_global<TodoListStore>(@todo_list);
        let list = Table::borrow(&store.lists, list_id)
            .expect("List not found");
        assert!(index < vector::length(&list.items), "Index out of bounds");
        vector::borrow(&list.items, index).clone()
    }

    /// Get all list IDs owned by a user
    public fun get_lists_of(owner: address): vector<u64> {
        let store = borrow_global<TodoListStore>(@todo_list);
        Table::get(&store.owner_lists, owner)
            .unwrap_or_else(|| vector::empty())
    }
}