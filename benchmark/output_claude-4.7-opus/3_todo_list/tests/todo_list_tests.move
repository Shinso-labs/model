#[test_only]
module todo_list::todo_list_tests {
    use todo_list::todo_list::{Self, TodoList};
    use std::string::{Self, String};
    use sui::test_scenario::{Self as ts};

    #[test]
    /// Test that new creates an empty todo list
    fun test_new_creates_empty_list() {
        let mut scenario = ts::begin(@0xA);
        {
            let list = todo_list::new(ts::ctx(&mut scenario));
            assert!(todo_list::length(&list) == 0, 0);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that add increases list length
    fun test_add_increases_length() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Buy groceries"));
            assert!(todo_list::length(&list) == 1, 1);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that multiple items can be added
    fun test_add_multiple_items() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Task 1"));
            todo_list::add(&mut list, string::utf8(b"Task 2"));
            todo_list::add(&mut list, string::utf8(b"Task 3"));
            assert!(todo_list::length(&list) == 3, 2);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that remove decreases list length
    fun test_remove_decreases_length() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Task 1"));
            todo_list::add(&mut list, string::utf8(b"Task 2"));
            let _removed = todo_list::remove(&mut list, 0);
            assert!(todo_list::length(&list) == 1, 3);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that remove returns the correct item
    fun test_remove_returns_correct_item() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            let task_text = string::utf8(b"Important task");
            todo_list::add(&mut list, task_text);
            let removed = todo_list::remove(&mut list, 0);
            assert!(removed == task_text, 4);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that remove from middle works correctly
    fun test_remove_from_middle() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Task 1"));
            todo_list::add(&mut list, string::utf8(b"Task 2"));
            todo_list::add(&mut list, string::utf8(b"Task 3"));
            let removed = todo_list::remove(&mut list, 1);
            assert!(removed == string::utf8(b"Task 2"), 5);
            assert!(todo_list::length(&list) == 2, 6);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that adding empty string works
    fun test_add_empty_string() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b""));
            assert!(todo_list::length(&list) == 1, 7);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that adding long string works
    fun test_add_long_string() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            let long_task = string::utf8(b"This is a very long task description that contains many words and should still work correctly");
            todo_list::add(&mut list, long_task);
            assert!(todo_list::length(&list) == 1, 8);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that delete works on empty list
    fun test_delete_empty_list() {
        let mut scenario = ts::begin(@0xA);
        {
            let list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that delete works on non-empty list
    fun test_delete_non_empty_list() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Task 1"));
            todo_list::add(&mut list, string::utf8(b"Task 2"));
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test adding and removing all items results in empty list
    fun test_add_remove_all() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Task 1"));
            todo_list::add(&mut list, string::utf8(b"Task 2"));
            todo_list::add(&mut list, string::utf8(b"Task 3"));
            let _r1 = todo_list::remove(&mut list, 0);
            let _r2 = todo_list::remove(&mut list, 0);
            let _r3 = todo_list::remove(&mut list, 0);
            assert!(todo_list::length(&list) == 0, 9);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that length is accurate after multiple operations
    fun test_length_after_operations() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            assert!(todo_list::length(&list) == 0, 10);
            todo_list::add(&mut list, string::utf8(b"Task 1"));
            assert!(todo_list::length(&list) == 1, 11);
            todo_list::add(&mut list, string::utf8(b"Task 2"));
            assert!(todo_list::length(&list) == 2, 12);
            let _removed = todo_list::remove(&mut list, 0);
            assert!(todo_list::length(&list) == 1, 13);
            todo_list::add(&mut list, string::utf8(b"Task 3"));
            assert!(todo_list::length(&list) == 2, 14);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test adding special characters in task
    fun test_add_special_characters() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Task with !@#$%^&*()"));
            assert!(todo_list::length(&list) == 1, 15);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test removing from end of list
    fun test_remove_from_end() {
        let mut scenario = ts::begin(@0xA);
        {
            let mut list = todo_list::new(ts::ctx(&mut scenario));
            todo_list::add(&mut list, string::utf8(b"Task 1"));
            todo_list::add(&mut list, string::utf8(b"Task 2"));
            todo_list::add(&mut list, string::utf8(b"Task 3"));
            let removed = todo_list::remove(&mut list, 2);
            assert!(removed == string::utf8(b"Task 3"), 16);
            assert!(todo_list::length(&list) == 2, 17);
            todo_list::delete(list);
        };
        ts::end(scenario);
    }
}
