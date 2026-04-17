//// A module for working with associative lists (a.k.a `Pairs`).
////
//// While any function that works on `List` also works on `Pairs`, this module provides some extra helpers
//// that are specifically tailored to working with associative lists. Fundamentally, a `Pairs<key, value>` is
//// a type-alias to `List<Pair<key, value>>`.
////
//// > [!CAUTION]
//// >
//// > Unlike dictionaries (a.k.a. [`Dict`](./dict.html#Dict), associative lists make no assumption
//// > about the ordering of elements within the list. As a result, lookup
//// > functions do traverse the entire list when invoked. They are also not _sets_,
//// > and thus allow for duplicate keys. This is reflected in the functions used
//// > to interact with them.

use aiken/builtin
use aiken/primitive/bytearray

const fixture_bench =
  [
    Pair("a", 1), Pair("b", 2), Pair("c", 3), Pair("d", 4), Pair("e", 5),
    Pair("f", 6), Pair("g", 7), Pair("h", 8), Pair("i", 9), Pair("j", 10),
    Pair("k", 11),
  ]

// ## Inspecting

/// Get all values in the alist associated with a given key.
///
/// ```aiken
/// pairs.get_all([], "a") == []
/// pairs.get_all([Pair("a", 1)], "a") == [1]
/// pairs.get_all([Pair("a", 1), Pair("b", 2)], "a") == [1]
/// pairs.get_all([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [1, 3]
/// ```
pub fn get_all(self: Pairs<key, value>, key k: key) -> List<value> {
  when self is {
    [] -> []
    [Pair(k2, _) as head, ..tail] ->
      if k == k2 {
        [head.2nd, ..get_all(tail, k)]
      } else {
        get_all(tail, k)
      }
  }
}

test get_all_1() {
  get_all([], "a") == []
}

test get_all_2() {
  get_all([Pair("a", 1)], "a") == [1]
}

test get_all_3() {
  get_all([Pair("a", 1), Pair("b", 2)], "a") == [1]
}

test get_all_4() {
  get_all([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [1, 3]
}

test get_all_5() {
  get_all([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") == []
}

/// Get the value in the alist by its key.
/// If multiple values with the same key exist, only the first one is returned.
///
/// ```aiken
/// pairs.get_first([], "a") == None
/// pairs.get_first([Pair("a", 1)], "a") == Some(1)
/// pairs.get_first([Pair("a", 1), Pair("b", 2)], "a") == Some(1)
/// pairs.get_first([Pair("a", 1), Pair("b", 2)], "c") == None
/// pairs.get_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == Some(1)
/// ```
pub fn get_first(self: Pairs<key, value>, key k: key) -> Option<value> {
  when self is {
    [] -> None
    [Pair(k2, _) as head, ..tail] ->
      if k == k2 {
        Some(head.2nd)
      } else {
        get_first(tail, k)
      }
  }
}

test get_first_1() {
  get_first([], "a") == None
}

test get_first_2() {
  get_first([Pair("a", 1)], "a") == Some(1)
}

test get_first_3() {
  get_first([Pair("a", 1), Pair("b", 2)], "a") == Some(1)
}

test get_first_4() {
  get_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == Some(1)
}

test get_first_5() {
  get_first([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") == None
}

test get_first_bench() {
  and {
    get_first(fixture_bench, "a") == Some(1),
    get_first(fixture_bench, "f") == Some(6),
    get_first(fixture_bench, "k") == Some(11),
  }
}

/// Get the value in the alist by its key.
/// If multiple values with the same key exist, only the last one is returned.
///
/// ```aiken
/// pairs.get_last([], "a") == None
/// pairs.get_last([Pair("a", 1)], "a") == Some(1)
/// pairs.get_last([Pair("a", 1), Pair("b", 2)], "a") == Some(1)
/// pairs.get_last([Pair("a", 1), Pair("b", 2)], "c") == None
/// pairs.get_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == Some(3)
/// ```
pub fn get_last(self: Pairs<key, value>, key k: key) -> Option<value> {
  do_get_last(self, k, None)
}

fn do_get_last(
  self: Pairs<key, value>,
  key k: key,
  last: Option<value>,
) -> Option<value> {
  when self is {
    [] -> last
    [Pair(k2, _) as head, ..tail] ->
      do_get_last(
        tail,
        k,
        if k == k2 {
          Some(head.2nd)
        } else {
          last
        },
      )
  }
}

test get_last_1() {
  get_last([], "a") == None
}

test get_last_2() {
  get_last([Pair("a", 1)], "a") == Some(1)
}

test get_last_3() {
  get_last([Pair("a", 1), Pair("b", 2)], "a") == Some(1)
}

test get_last_4() {
  get_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == Some(3)
}

test get_last_5() {
  get_last([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") == None
}

test get_last_bench() {
  and {
    get_last(fixture_bench, "a") == Some(1),
    get_last(fixture_bench, "f") == Some(6),
    get_last(fixture_bench, "k") == Some(11),
  }
}

/// Finds all keys in the alist associated with a given value.
///
/// ```aiken
/// pairs.find_all([], 1) == []
/// pairs.find_all([Pair("a", 1)], 1) == ["a"]
/// pairs.find_all([Pair("a", 1), Pair("b", 2)], 1) == ["a"]
/// pairs.find_all([Pair("a", 1), Pair("b", 2)], 3) == []
/// pairs.find_all([Pair("a", 1), Pair("b", 2), Pair("c", 1)], 1) == ["a", "c"]
/// ```
pub fn find_all(self: Pairs<key, value>, value v: value) -> List<key> {
  when self is {
    [] -> []
    [Pair(_, v2) as head, ..tail] ->
      if v == v2 {
        [head.1st, ..find_all(tail, v)]
      } else {
        find_all(tail, v)
      }
  }
}

test find_all_1() {
  find_all([], "a") == []
}

test find_all_2() {
  find_all([Pair("a", 14)], 14) == ["a"]
}

test find_all_3() {
  find_all([Pair("a", 14)], 42) == []
}

test find_all_4() {
  find_all([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == ["a", "c"]
}

/// Finds the first key in the alist associated with a given value, if any.
///
/// ```aiken
/// pairs.find_first([], 1) == None
/// pairs.find_first([Pair("a", 1)], 1) == Some("a")
/// pairs.find_first([Pair("a", 1), Pair("b", 2)], 1) == Some("a")
/// pairs.find_first([Pair("a", 1), Pair("b", 2)], 3) == None
/// pairs.find_first([Pair("a", 1), Pair("b", 2), Pair("c", 1)], 1) == Some("a")
/// ```
pub fn find_first(self: Pairs<key, value>, value v: value) -> Option<key> {
  when self is {
    [] -> None
    [Pair(_, v2) as head, ..tail] ->
      if v == v2 {
        Some(head.1st)
      } else {
        find_first(tail, v)
      }
  }
}

test find_first_1() {
  find_first([], "a") == None
}

test find_first_2() {
  find_first([Pair("a", 14)], 14) == Some("a")
}

test find_first_3() {
  find_first([Pair("a", 14)], 42) == None
}

test find_first_4() {
  find_first([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == Some("a")
}

test find_first_bench() {
  and {
    find_first(fixture_bench, 1) == Some("a"),
    find_first(fixture_bench, 6) == Some("f"),
    find_first(fixture_bench, 11) == Some("k"),
  }
}

/// Finds the last key in the alist associated with a given value, if any.
///
/// ```aiken
/// pairs.find_last([], 1) == None
/// pairs.find_last([Pair("a", 1)], 1) == Some("a")
/// pairs.find_last([Pair("a", 1), Pair("b", 2)], 1) == Some("a")
/// pairs.find_last([Pair("a", 1), Pair("b", 2)], 3) == None
/// pairs.find_last([Pair("a", 1), Pair("b", 2), Pair("c", 1)], 1) == Some("c")
/// ```
pub fn find_last(self: Pairs<key, value>, value v: value) -> Option<key> {
  do_find_last(self, v, None)
}

fn do_find_last(
  self: Pairs<key, value>,
  value v: value,
  last: Option<key>,
) -> Option<key> {
  when self is {
    [] -> last
    [Pair(_, v2) as head, ..tail] ->
      do_find_last(
        tail,
        v,
        if v == v2 {
          Some(head.1st)
        } else {
          last
        },
      )
  }
}

test find_last_1() {
  find_last([], "a") == None
}

test find_last_2() {
  find_last([Pair("a", 14)], 14) == Some("a")
}

test find_last_3() {
  find_last([Pair("a", 14)], 42) == None
}

test find_last_4() {
  find_last([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == Some("c")
}

test find_last_bench() {
  and {
    find_last(fixture_bench, 1) == Some("a"),
    find_last(fixture_bench, 6) == Some("f"),
    find_last(fixture_bench, 11) == Some("k"),
  }
}

/// Check if a key exists in the pairs.
///
/// ```aiken
/// pairs.has_key([], "a") == False
/// pairs.has_key([Pair("a", 1)], "a") == True
/// pairs.has_key([Pair("a", 1), Pair("b", 2)], "a") == True
/// pairs.has_key([Pair("a", 1), Pair("b", 2)], "c") == False
/// pairs.has_key([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == True
/// ```
pub fn has_key(self: Pairs<key, value>, key k: key) -> Bool {
  when self is {
    [] -> False
    [Pair(k2, _), ..tail] -> k == k2 || has_key(tail, k)
  }
}

test has_key_1() {
  !has_key([], "a")
}

test has_key_2() {
  has_key([Pair("a", 14)], "a")
}

test has_key_3() {
  !has_key([Pair("a", 14)], "b")
}

test has_key_4() {
  has_key([Pair("a", 14), Pair("b", 42)], "b")
}

test has_key_5() {
  has_key([Pair("a", 14), Pair("b", 42), Pair("a", 42)], "a")
}

test has_key_bench() {
  and {
    has_key(fixture_bench, "a"),
    has_key(fixture_bench, "f"),
    has_key(fixture_bench, "k"),
  }
}

/// Extract all the keys present in a given `Pairs`.
///
/// ```aiken
/// pairs.keys([]) == []
/// pairs.keys([Pair("a", 1)]) == ["a"]
/// pairs.keys([Pair("a", 1), Pair("b", 2)]) == ["a", "b"]
/// pairs.keys([Pair("a", 1), Pair("b", 2), Pair("a", 3)]) == ["a", "b", "a"]
/// ```
pub fn keys(self: Pairs<key, value>) -> List<key> {
  when self is {
    [] -> []
    [Pair(k, _), ..tail] -> [k, ..keys(tail)]
  }
}

test keys_1() {
  keys([]) == []
}

test keys_2() {
  keys([Pair("a", 0)]) == ["a"]
}

test keys_3() {
  keys([Pair("a", 0), Pair("b", 0)]) == ["a", "b"]
}

/// Extract all the values present in a given `Pairs`.
///
/// ```aiken
/// pairs.values([]) == []
/// pairs.values([Pair("a", 1)]) == [1]
/// pairs.values([Pair("a", 1), Pair("b", 2)]) == [1, 2]
/// pairs.values([Pair("a", 1), Pair("b", 2), Pair("a", 3)]) == [1, 2, 3]
/// ```
pub fn values(self: Pairs<key, value>) -> List<value> {
  when self is {
    [] -> []
    [Pair(_, v), ..tail] -> [v, ..values(tail)]
  }
}

test values_1() {
  values([]) == []
}

test values_2() {
  values([Pair("a", 1)]) == [1]
}

test values_3() {
  values([Pair("a", 1), Pair("b", 2)]) == [1, 2]
}

test values_4() {
  values([Pair("a", 1), Pair("b", 2), Pair("a", 3)]) == [1, 2, 3]
}

// ## Inspecting Forcibly

/// More efficient version of [`get_first`](#get_first) which fails if no key is found.
///
/// ```aiken
/// pairs.expect_get_first([], "a") → 💥
/// pairs.expect_get_first([Pair("a", 1)], "a") == 1
/// pairs.expect_get_first([Pair("a", 1), Pair("b", 2)], "a") == 1
/// pairs.expect_get_first([Pair("a", 1), Pair("b", 2)], "c") == → 💥
/// pairs.expect_get_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == 1
/// ```
pub fn expect_get_first(self: Pairs<key, value>, key k: key) -> value {
  let Pair(k2, _) as head = builtin.head_list(self)
  if k == k2 {
    head.2nd
  } else {
    expect_get_first(builtin.tail_list(self), k)
  }
}

test expect_get_first_1() fail {
  let x = expect_get_first([], "a")
  x == x
}

test expect_get_first_2() {
  expect_get_first([Pair("a", 1)], "a") == 1
}

test expect_get_first_3() {
  expect_get_first([Pair("a", 1), Pair("b", 2)], "a") == 1
}

test expect_get_first_4() {
  expect_get_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == 1
}

test expect_get_first_5() fail {
  let x = expect_get_first([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d")
  x == x
}

test expect_get_first_bench() {
  and {
    expect_get_first(fixture_bench, "a") == 1,
    expect_get_first(fixture_bench, "f") == 6,
    expect_get_first(fixture_bench, "k") == 11,
  }
}

/// More efficient version of [`get_last`](#get_last) which fails if no key is found.
///
/// ```aiken
/// pairs.expect_get_last([], "a") → 💥
/// pairs.expect_get_last([Pair("a", 1)], "a") == 1
/// pairs.expect_get_last([Pair("a", 1), Pair("b", 2)], "a") == 1
/// pairs.expect_get_last([Pair("a", 1), Pair("b", 2)], "c") → 💥
/// pairs.expect_get_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == 3
/// ```
pub fn expect_get_last(self: Pairs<key, value>, key k: key) -> value {
  do_expect_get_last(
    self,
    k,
    fn() {
      fail @"expect_get_last: not found"
    },
  )
}

fn do_expect_get_last(
  self: Pairs<key, value>,
  key k: key,
  yield: fn() -> value,
) -> value {
  when self is {
    [] -> yield()
    [Pair(k2, _) as head, ..tail] ->
      do_expect_get_last(
        tail,
        k,
        if k == k2 {
          fn() { head.2nd }
        } else {
          yield
        },
      )
  }
}

test expect_get_last_1() fail {
  let x = expect_get_last([], "a")
  x == x
}

test expect_get_last_2() {
  expect_get_last([Pair("a", 1)], "a") == 1
}

test expect_get_last_3() {
  expect_get_last([Pair("a", 1), Pair("b", 2)], "a") == 1
}

test expect_get_last_4() {
  expect_get_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == 3
}

test expect_get_last_5() fail {
  let x = expect_get_last([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d")
  x == x
}

test expect_get_last_bench() {
  and {
    expect_get_last(fixture_bench, "a") == 1,
    expect_get_last(fixture_bench, "f") == 6,
    expect_get_last(fixture_bench, "k") == 11,
  }
}

/// More efficient version of [`find_first`](#find_first) which fails if no element is found.
///
/// ```aiken
/// pairs.expect_find_first([], 1) → 💥
/// pairs.expect_find_first([Pair("a", 1)], 1) == "a"
/// pairs.expect_find_first([Pair("a", 1), Pair("b", 2)], 1) == "a"
/// pairs.expect_find_first([Pair("a", 1), Pair("b", 2)], 3) → 💥
/// pairs.expect_find_first([Pair("a", 1), Pair("b", 2), Pair("c", 1)], 1) == "a"
/// ```
pub fn expect_find_first(self: Pairs<key, value>, value v: value) -> key {
  let Pair(_, v2) as head = builtin.head_list(self)
  if v == v2 {
    head.1st
  } else {
    expect_find_first(builtin.tail_list(self), v)
  }
}

test expect_find_first_1() fail {
  let x = expect_find_first([], "a")
  x == x
}

test expect_find_first_2() {
  expect_find_first([Pair("a", 14)], 14) == "a"
}

test expect_find_first_3() fail {
  let x = expect_find_first([Pair("a", 14)], 42)
  x == x
}

test expect_find_first_4() {
  expect_find_first([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == "a"
}

test expect_find_first_bench() {
  and {
    expect_find_first(fixture_bench, 1) == "a",
    expect_find_first(fixture_bench, 6) == "f",
    expect_find_first(fixture_bench, 11) == "k",
  }
}

/// More efficient version of [`find_last`](#find_last) which fails if no element is found.
///
/// ```aiken
/// pairs.expect_find_last([], 1) → 💥
/// pairs.expect_find_last([Pair("a", 1)], 1) == "a"
/// pairs.expect_find_last([Pair("a", 1), Pair("b", 2)], 1) == "a"
/// pairs.expect_find_last([Pair("a", 1), Pair("b", 2)], 3) → 💥
/// pairs.expect_find_last([Pair("a", 1), Pair("b", 2), Pair("c", 1)], 1) == "c"
/// ```
pub fn expect_find_last(self: Pairs<key, value>, value v: value) -> key {
  do_expect_find_last(
    self,
    v,
    fn() {
      fail @"expect_find_last: not found"
    },
  )
}

fn do_expect_find_last(
  self: Pairs<key, value>,
  value v: value,
  yield: fn() -> key,
) -> key {
  when self is {
    [] -> yield()
    [Pair(_, v2) as head, ..tail] ->
      do_expect_find_last(
        tail,
        v,
        if v == v2 {
          fn() { head.1st }
        } else {
          yield
        },
      )
  }
}

test expect_find_last_1() fail {
  let x = expect_find_last([], "a")
  x == x
}

test expect_find_last_2() {
  expect_find_last([Pair("a", 14)], 14) == "a"
}

test expect_find_last_3() fail {
  let x = expect_find_last([Pair("a", 14)], 42)
  x == x
}

test expect_find_last_4() {
  expect_find_last([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == "c"
}

test expect_find_last_bench() {
  and {
    expect_find_last(fixture_bench, 1) == "a",
    expect_find_last(fixture_bench, 6) == "f",
    expect_find_last(fixture_bench, 11) == "k",
  }
}

/// More efficient version of [`has_key`](#has_key), which fails if the key isn't present in the associative list.
///
/// ```aiken
/// pairs.expect_has_key([], "a") → 💥
/// pairs.expect_has_key([Pair("a", 1)], "a") → ✅
/// pairs.expect_has_key([Pair("a", 1), Pair("b", 2)], "a") → ✅
/// pairs.expect_has_key([Pair("a", 1), Pair("b", 2)], "c") → 💥
/// pairs.expect_has_key([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") → ✅
/// ```
pub fn expect_has_key(self: Pairs<key, value>, key k: key) -> Void {
  let Pair(k2, _) = builtin.head_list(self)
  if k2 == k {
    Void
  } else {
    expect_has_key(builtin.tail_list(self), k)
  }
}

test expect_has_key_1() fail {
  expect_has_key([], "a")
}

test expect_has_key_2() {
  expect_has_key([Pair("a", 14)], "a")
}

test expect_has_key_3() fail {
  expect_has_key([Pair("a", 14)], "b")
}

test expect_has_key_4() {
  expect_has_key([Pair("a", 14), Pair("b", 42)], "b")
}

test expect_has_key_5() {
  expect_has_key([Pair("a", 14), Pair("b", 42), Pair("a", 42)], "a")
}

test expect_has_key_bench() {
  expect_has_key(fixture_bench, "a")
  expect_has_key(fixture_bench, "f")
  expect_has_key(fixture_bench, "k")
}

// ## Modifying

/// Remove all key-value pairs matching the key from the Pairs. If the key is not found, no changes are made.
///
/// ```aiken
/// pairs.delete_all([], "a") == []
/// pairs.delete_all([Pair("a", 1)], "a") == []
/// pairs.delete_all([Pair("a", 1), Pair("b", 2)], "a") == [Pair("b", 2)]
/// pairs.delete_all([Pair("a", 1), Pair("b", 2)], "c") == [Pair("a", 1), Pair("b", 2)]
/// pairs.delete_all([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [Pair("b", 2)]
/// ```
pub fn delete_all(self: Pairs<key, value>, key k: key) -> Pairs<key, value> {
  when self is {
    [] -> []
    [Pair(k2, v2), ..tail] ->
      if k == k2 {
        delete_all(tail, k)
      } else {
        [Pair(k2, v2), ..delete_all(tail, k)]
      }
  }
}

test delete_all_1() {
  delete_all([], "a") == []
}

test delete_all_2() {
  delete_all([Pair("a", 14)], "a") == []
}

test delete_all_3() {
  let fixture = [Pair("a", 14)]
  delete_all(fixture, "b") == fixture
}

test delete_all_4() {
  let fixture = [Pair("a", 1), Pair("b", 2), Pair("a", 3)]
  delete_all(fixture, "a") == [Pair("b", 2)]
}

/// Remove a single key-value pair from the `Pairs`. If the key is not found, no changes are made.
/// Duplicate keys are not deleted. Only the **first** key found is deleted.
///
/// ```aiken
/// pairs.delete_first([], "a") == []
/// pairs.delete_first([Pair("a", 1)], "a") == []
/// pairs.delete_first([Pair("a", 1), Pair("b", 2)], "a") == [Pair("b", 2)]
/// pairs.delete_first([Pair("a", 1), Pair("b", 2)], "c") == [Pair("a", 1), Pair("b", 2)]
/// pairs.delete_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [Pair("b", 2), Pair("a", 3)]
/// ```
pub fn delete_first(self: Pairs<key, value>, key k: key) -> Pairs<key, value> {
  when self is {
    [] -> []
    [Pair(k2, _) as head, ..tail] ->
      if k == k2 {
        tail
      } else {
        [head, ..delete_first(tail, k)]
      }
  }
}

test delete_first_1() {
  delete_first([], "a") == []
}

test delete_first_2() {
  delete_first([Pair("a", 14)], "a") == []
}

test delete_first_3() {
  let fixture = [Pair("a", 14)]
  delete_first(fixture, "b") == fixture
}

test delete_first_4() {
  let fixture = [Pair("a", 1), Pair("b", 2), Pair("a", 3)]
  delete_first(fixture, "a") == [Pair("b", 2), Pair("a", 3)]
}

/// Remove a single key-value pair from the Pairs. If the key is not found, no changes are made.
/// Duplicate keys are not deleted. Only the **last** key found is deleted.
///
/// ```aiken
/// pairs.delete_last([], "a") == []
/// pairs.delete_last([Pair("a", 1)], "a") == []
/// pairs.delete_last([Pair("a", 1), Pair("b", 2)], "a") == [Pair("b", 2)]
/// pairs.delete_last([Pair("a", 1), Pair("b", 2)], "c") == [Pair("a", 1), Pair("b", 2)]
/// pairs.delete_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [Pair("a", 1), Pair("b", 2)]
/// ```
pub fn delete_last(self: Pairs<key, value>, key k: key) -> Pairs<key, value> {
  when self is {
    [] -> []
    [Pair(k2, _) as head, ..tail] ->
      if k == k2 {
        let new_tail = delete_last(tail, k)
        if tail == new_tail {
          tail
        } else {
          [head, ..new_tail]
        }
      } else {
        [head, ..delete_last(tail, k)]
      }
  }
}

test delete_last_1() {
  delete_last([], "a") == []
}

test delete_last_2() {
  delete_last([Pair("a", 14)], "a") == []
}

test delete_last_3() {
  let fixture = [Pair("a", 14)]
  delete_last(fixture, "b") == fixture
}

test delete_last_4() {
  let fixture = [Pair("a", 1), Pair("b", 2), Pair("a", 3)]
  delete_last(fixture, "a") == [Pair("a", 1), Pair("b", 2)]
}

/// Insert a value in the `Pairs` at a given key. If the key already exists,
/// the value is added in front.
///
/// > [!CAUTION]
/// > The list is only traversed up to the given key and the traversal
/// > stops as soon as a higher key is encountered. Said differently, the list
/// > is assumed to **be ordered by ascending keys**! If it is not, expect the
/// > unexpected.
///
/// ```aiken
/// use aiken/primitive/bytearray
///
/// [Pair("bar", 2), Pair("foo", 3), Pair("foo", 1)] == ([]
///   |> pairs.insert_by_ascending_key(key: "foo", value: 1, compare: bytearray.compare)
///   |> pairs.insert_by_ascending_key(key: "bar", value: 2, compare: bytearray.compare)
///   |> pairs.insert_by_ascending_key(key: "foo", value: 3, compare: bytearray.compare)
/// )
/// ```
pub fn insert_by_ascending_key(
  self: Pairs<key, value>,
  key k: key,
  value v: value,
  compare: fn(key, key) -> Ordering,
) -> Pairs<key, value> {
  when self is {
    [] -> [Pair(k, v)]
    [Pair(k2, _) as head, ..tail] ->
      if Less == compare(k, k2) {
        [Pair(k, v), ..self]
      } else {
        if k == k2 {
          [Pair(k, v), ..self]
        } else {
          [head, ..insert_by_ascending_key(tail, k, v, compare)]
        }
      }
  }
}

test insert_by_ascending_key_1() {
  let m = []
    |> insert_by_ascending_key("foo", 42, bytearray.compare)
    |> insert_by_ascending_key("foo", 14, bytearray.compare)

  m == [Pair("foo", 14), Pair("foo", 42)]
}

test insert_by_ascending_key_2() {
  let m = []
    |> insert_by_ascending_key("foo", 42, bytearray.compare)
    |> insert_by_ascending_key("bar", 14, bytearray.compare)
    |> insert_by_ascending_key("baz", 1337, bytearray.compare)

  m == [Pair("bar", 14), Pair("baz", 1337), Pair("foo", 42)]
}

/// Like [`insert_by_ascending_key`](#insert_by_ascending_key) but specifies
/// how to combine two values on a key conflict.
///
/// > [!CAUTION]
/// > The list is only traversed up to the given key and the traversal
/// > stops as soon as a higher key is encountered. Said differently, the list
/// > is assumed to **be ordered by ascending keys**! If it is not, expect the
/// > unexpected.
///
/// ```aiken
/// use aiken/primitive/bytearray
///
/// let add_integer = fn(x, y) { x + y }
///
/// [Pair("bar", 2), Pair("foo", 4)] == ([]
///     |> pairs.insert_with_by_ascending_key(key: "foo", value: 1, compare: bytearray.compare, with: add_integer)
///     |> pairs.insert_with_by_ascending_key(key: "bar", value: 2, compare: bytearray.compare, with: add_integer)
///     |> pairs.insert_with_by_ascending_key(key: "foo", value: 3, compare: bytearray.compare, with: add_integer)
/// )
/// ```
pub fn insert_with_by_ascending_key(
  self: Pairs<key, value>,
  key k: key,
  value v: value,
  compare: fn(key, key) -> Ordering,
  with: fn(value, value) -> value,
) -> Pairs<key, value> {
  when self is {
    [] -> [Pair(k, v)]
    [Pair(k2, _) as head, ..tail] ->
      if Less == compare(k, k2) {
        [Pair(k, v), ..self]
      } else {
        if k == k2 {
          [Pair(k, with(v, head.2nd)), ..tail]
        } else {
          [head, ..insert_with_by_ascending_key(tail, k, v, compare, with)]
        }
      }
  }
}

test insert_with_by_ascending_key_1() {
  let compare_un_b_data = fn(l, r) {
    bytearray.compare(l |> builtin.un_b_data, r |> builtin.un_b_data)
  }

  let m = []
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        42,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        14,
        compare_un_b_data,
        builtin.add_integer,
      )

  m == [Pair("foo" |> builtin.b_data, 56)]
}

test insert_with_by_ascending_key_2() {
  let compare_un_b_data = fn(l, r) {
    bytearray.compare(l |> builtin.un_b_data, r |> builtin.un_b_data)
  }

  let m = []
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        42,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "bar" |> builtin.b_data,
        14,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "baz" |> builtin.b_data,
        1337,
        compare_un_b_data,
        builtin.add_integer,
      )

  m == [
    Pair("bar" |> builtin.b_data, 14),
    Pair("baz" |> builtin.b_data, 1337),
    Pair("foo" |> builtin.b_data, 42),
  ]
}

test insert_with_by_ascending_key_3() {
  let compare_un_b_data = fn(l, r) {
    bytearray.compare(l |> builtin.un_b_data, r |> builtin.un_b_data)
  }

  let result = []
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        1,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "bar" |> builtin.b_data,
        2,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        3,
        compare_un_b_data,
        builtin.add_integer,
      )

  result == [Pair("bar" |> builtin.b_data, 2), Pair("foo" |> builtin.b_data, 4)]
}

/// Apply a function to all key-value pairs in a alist, replacing the values.
///
/// ```aiken
/// [Pair("a", 200), Pair("b", 400)] == ([Pair("a", 100), Pair("b", 200)]
///   |> pairs.map(, fn(_k, v) { v * 2 })
/// )
/// ```
pub fn map(
  self: Pairs<key, value>,
  with: fn(key, value) -> result,
) -> Pairs<key, result> {
  when self is {
    [] -> []
    [Pair(k, v), ..tail] -> [Pair(k, with(k, v)), ..map(tail, with)]
  }
}

test map_1() {
  let fixture = [Pair("a", 1), Pair("b", 2)]

  map(fixture, with: fn(k, _) { k }) == [Pair("a", "a"), Pair("b", "b")]
}

test map_2() {
  let fixture = [Pair("a", 1), Pair("b", 2)]

  map(fixture, with: fn(_, v) { v + 1 }) == [Pair("a", 2), Pair("b", 3)]
}

/// Drop elements from an associative list until a predicate is satisfied.
/// Returns the first key/value pair that satisfies the predicate, and the rest
/// of the list after that key/value pair.
///
/// ```aiken
/// let predicate = fn(k, v) { k == "a" && v > 1 }
///
/// expect (None, []) = pairs.pop_until([], predicate)
/// expect (None, []) = pairs.pop_until([Pair("a", 1), Pair("b", 2)], predicate)
/// expect (Some(Pair("a", 3), []) = pairs.pop_until([Pair("a", 1), Pair("b", 2), Pair("a", 3)], predicate)
/// ```
pub fn pop_until(
  self: Pairs<key, value>,
  until: fn(key, value) -> Bool,
) -> (Option<Pair<key, value>>, Pairs<key, value>) {
  when self is {
    [] -> (None, self)
    [Pair(k, v) as head, ..tail] ->
      if until(k, v) {
        (Some(head), tail)
      } else {
        pop_until(tail, until)
      }
  }
}

test pop_until_1() {
  pop_until([], fn(k, _) { k == "a" }) == (None, [])
}

test pop_until_2() {
  pop_until([Pair("a", 1), Pair("b", 2)], fn(k, _) { k == "a" }) == (
    Some(Pair("a", 1)),
    [Pair("b", 2)],
  )
}

test pop_until_3() {
  pop_until([Pair("a", 1), Pair("b", 2), Pair("c", 3)], fn(k, _) { k == "c" }) == (
    Some(Pair("c", 3)),
    [],
  )
}

test pop_until_4() {
  pop_until([Pair("a", 1), Pair("b", 2), Pair("c", 3)], fn(_, _) { False }) == (
    None,
    [],
  )
}

test pop_until_bench() {
  and {
    pop_until(fixture_bench, fn(k, _) { k == "a" }).1st == Some(Pair("a", 1)),
    pop_until(fixture_bench, fn(k, _) { k == "f" }).1st == Some(Pair("f", 6)),
    pop_until(fixture_bench, fn(k, _) { k == "k" }).1st == Some(Pair("k", 11)),
  }
}

/// Like [`pop_until`](#pop_until) but leverages backpassing.
///
/// ```aiken
/// let predicate = fn(k, v) { k == "a" && v > 1 }
///
/// expect None, [] <- pairs.pop_until_and_then([], predicate)
/// expect None, [] <- pairs.pop_until_and_then([Pair("a", 1), Pair("b", 2)], predicate)
/// expect Some(Pair("a", 3), [] <- pairs.pop_until_and_then([Pair("a", 1), Pair("b", 2), Pair("a", 3)], predicate)
/// ```
pub fn pop_until_and_then(
  self: Pairs<key, value>,
  until: fn(key, value) -> Bool,
  return: fn(Option<Pair<key, value>>, Pairs<key, value>) -> result,
) -> result {
  when self is {
    [] -> return(None, self)
    [Pair(k, v) as head, ..tail] ->
      if until(k, v) {
        return(Some(head), tail)
      } else {
        pop_until_and_then(tail, until, return)
      }
  }
}

test pop_until_and_then_1() {
  expect None, [] <- pop_until_and_then([], fn(k, _) { k == "a" })
  Void
}

test pop_until_and_then_2() {
  expect Some(Pair("a", 1)), [Pair("b", 2)] <- pop_until_and_then(
    [Pair("a", 1), Pair("b", 2)],
    fn(k, _) { k == "a" },
  )
  Void
}

test pop_until_and_then_3() {
  expect Some(Pair("c", 3)), [] <- pop_until_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(k, _) { k == "c" },
  )
  Void
}

test pop_until_and_then_4() {
  expect None, [] <- pop_until_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(_, _) { False },
  )
  Void
}

test pop_until_and_then_bench() {
  and {
    pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "a" },
      fn(kv, _) { kv == Some(Pair("a", 1)) },
    ),
    pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "f" },
      fn(kv, _) { kv == Some(Pair("f", 6)) },
    ),
    pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "k" },
      fn(kv, _) { kv == Some(Pair("k", 11)) },
    ),
  }
}

/// Drop elements from an associative list until a given key is encountered.
/// Returns the first value at that key (if any), and the rest of the list after
/// that key/value pair.
///
/// ```aiken
/// expect (None, []) = pairs.pop_until_key([], "a")
/// expect (Some(1), [Pair("b", 2)]) = pairs.pop_until_key([Pair("a", 1), Pair("b", 2)], "a")
/// expect (Some(3), []) = pairs.pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c")
/// expect (None, []) = pairs.pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "")
/// ```
pub fn pop_until_key(
  self: Pairs<key, value>,
  until: key,
) -> (Option<value>, Pairs<key, value>) {
  when self is {
    [] -> (None, self)
    [Pair(k, _) as head, ..tail] ->
      if until == k {
        (Some(head.2nd), tail)
      } else {
        pop_until_key(tail, until)
      }
  }
}

test pop_until_key_1() {
  pop_until_key([], "a") == (None, [])
}

test pop_until_key_2() {
  pop_until_key([Pair("a", 1), Pair("b", 2)], "a") == (Some(1), [Pair("b", 2)])
}

test pop_until_key_3() {
  pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c") == (
    Some(3),
    [],
  )
}

test pop_until_key_4() {
  pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "") == (None, [])
}

test pop_until_key_bench() {
  and {
    pop_until_key(fixture_bench, "a").1st == Some(1),
    pop_until_key(fixture_bench, "f").1st == Some(6),
    pop_until_key(fixture_bench, "k").1st == Some(11),
  }
}

/// A version of [`pop_until_key`](#pop_until_key) which leverages backpassing.
///
/// ```aiken
/// expect None, [] <- pairs.pop_until_key_and_then([], "a")
/// expect Some(1), [Pair("b", 2)] <- pairs.pop_until_key_and_then([Pair("a", 1), Pair("b", 2)], "a")
/// expect Some(3), [] <- pairs.pop_until_key_and_then([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c")
/// expect None, [] <- pairs.pop_until_key_and_then([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "")
/// ```
pub fn pop_until_key_and_then(
  self: Pairs<key, value>,
  until: key,
  return: fn(Option<value>, Pairs<key, value>) -> result,
) -> result {
  when self is {
    [] -> return(None, self)
    [Pair(k, _) as head, ..tail] ->
      if until == k {
        return(Some(head.2nd), tail)
      } else {
        pop_until_key_and_then(tail, until, return)
      }
  }
}

test pop_until_key_and_then_1() {
  expect None, [] <- pop_until_key_and_then([], "a")
  Void
}

test pop_until_key_and_then_2() {
  expect Some(1), [Pair("b", 2)] <- pop_until_key_and_then(
    [Pair("a", 1), Pair("b", 2)],
    "a",
  )
  Void
}

test pop_until_key_and_then_3() {
  expect Some(3), [] <- pop_until_key_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    "c",
  )
  Void
}

test pop_until_key_and_then_4() {
  expect None, [] <- pop_until_key_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    "",
  )
  Void
}

test pop_until_key_and_then_bench() {
  and {
    pop_until_key_and_then(fixture_bench, "a", fn(k, _) { k == Some(1) }),
    pop_until_key_and_then(fixture_bench, "f", fn(k, _) { k == Some(6) }),
    pop_until_key_and_then(fixture_bench, "k", fn(k, _) { k == Some(11) }),
  }
}

/// Insert a value in the `Pairs` at a given key. If the key already exists,
/// its value is replaced.
///
/// > [!CAUTION]
/// > The list is only traversed up to the given key and the traversal
/// > stops as soon as a higher key is encountered. Said differently, the list
/// > is assumed to **be ordered by ascending keys**! If it is not, expect the
/// > unexpected.
///
/// ```aiken
/// use aiken/primitive/bytearray
///
/// [Pair("bar", 2), Pair("foo", 3)] == ([]
///   |> pairs.repsert_by_ascending_key(key: "foo", value: 1, compare: bytearray.compare)
///   |> pairs.repsert_by_ascending_key(key: "bar", value: 2, compare: bytearray.compare)
///   |> pairs.repsert_by_ascending_key(key: "foo", value: 3, compare: bytearray.compare)
/// )
/// ```
pub fn repsert_by_ascending_key(
  self: Pairs<key, value>,
  key k: key,
  value v: value,
  compare: fn(key, key) -> Ordering,
) -> Pairs<key, value> {
  when self is {
    [] -> [Pair(k, v)]
    [Pair(k2, v2), ..tail] ->
      if compare(k, k2) == Less {
        [Pair(k, v), ..self]
      } else {
        if k == k2 {
          [Pair(k, v), ..tail]
        } else {
          [Pair(k2, v2), ..repsert_by_ascending_key(tail, k, v, compare)]
        }
      }
  }
}

test repsert_by_ascending_key_1() {
  let m = []
    |> repsert_by_ascending_key("foo", 42, bytearray.compare)
    |> repsert_by_ascending_key("foo", 14, bytearray.compare)

  m == [Pair("foo", 14)]
}

test repsert_by_ascending_key_2() {
  let m = []
    |> repsert_by_ascending_key("foo", 42, bytearray.compare)
    |> repsert_by_ascending_key("bar", 14, bytearray.compare)
    |> repsert_by_ascending_key("baz", 1337, bytearray.compare)

  m == [Pair("bar", 14), Pair("baz", 1337), Pair("foo", 42)]
}

// ## Modifying Forcibly

/// More efficient version of [`delete_first`](#delete_first), which fails if
/// there's no matching element to delete.
///
/// ```aiken
/// pairs.expect_delete_first([], "a") → 💥
/// pairs.expect_delete_first([Pair("a", 1)], "a") == []
/// pairs.expect_delete_first([Pair("a", 1), Pair("b", 2)], "a") == [Pair("b", 2)]
/// pairs.expect_delete_first([Pair("a", 1), Pair("b", 2)], "c") → 💥
/// pairs.expect_delete_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [Pair("b", 2), Pair("a", 3)]
/// ```
pub fn expect_delete_first(
  self: Pairs<key, value>,
  key k: key,
) -> Pairs<key, value> {
  expect [Pair(k2, _) as head, ..tail] = self
  if k == k2 {
    tail
  } else {
    [head, ..expect_delete_first(tail, k)]
  }
}

test expect_delete_first_1() fail {
  let x = expect_delete_first([], "a")
  x == x
}

test expect_delete_first_2() {
  expect_delete_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [
    Pair("b", 2), Pair("a", 3),
  ]
}

test expect_delete_first_3() fail {
  let x = expect_delete_first([Pair("a", 14)], "b")
  x == x
}

/// More efficient version of [`delete_last`](#delete_last), which fails if
/// there's no matching element to delete.
///
/// ```aiken
/// pairs.expect_delete_last([], "a") → 💥
/// pairs.expect_delete_last([Pair("a", 1)], "a") == []
/// pairs.expect_delete_last([Pair("a", 1), Pair("b", 2)], "a") == [Pair("b", 2)]
/// pairs.expect_delete_last([Pair("a", 1), Pair("b", 2)], "c") → 💥
/// pairs.expect_delete_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [Pair("a", 1), Pair("b", 2)]
/// ```
pub fn expect_delete_last(
  self: Pairs<key, value>,
  key k: key,
) -> Pairs<key, value> {
  expect [Pair(k2, _) as head, ..tail] = self
  if k == k2 {
    tail
  } else {
    [head, ..expect_delete_first(tail, k)]
  }
}

/// More efficient version of [`pop_until`](#pop_until), which fails if there's
/// no element matching the predicate.
///
/// ```aiken
/// let predicate = fn(k, v) { k == "a" && v > 1 }
///
/// 💥 = pairs.expect_pop_until([], predicate)
/// 💥 = pairs.expect_pop_until([Pair("a", 1), Pair("b", 2)], predicate)
/// expect (Pair("a", 3), []) = pairs.expect_pop_until([Pair("a", 1), Pair("b", 2), Pair("a", 3)], predicate)
/// ```
pub fn expect_pop_until(
  self: Pairs<key, value>,
  until: fn(key, value) -> Bool,
) -> (Pair<key, value>, Pairs<key, value>) {
  let Pair(k, v) as head = builtin.head_list(self)
  if until(k, v) {
    (head, builtin.tail_list(self))
  } else {
    expect_pop_until(builtin.tail_list(self), until)
  }
}

test expect_pop_until_1() fail {
  let x = expect_pop_until([], fn(k, _) { k == "a" })
  x == x
}

test expect_pop_until_2() {
  expect_pop_until([Pair("a", 1), Pair("b", 2)], fn(k, _) { k == "a" }) == (
    Pair("a", 1),
    [Pair("b", 2)],
  )
}

test expect_pop_until_3() {
  expect_pop_until(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(k, _) { k == "c" },
  ) == (Pair("c", 3), [])
}

test expect_pop_until_4() fail {
  let x = expect_pop_until(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(_, _) { False },
  )
  x == x
}

test expect_pop_until_bench() {
  and {
    expect_pop_until(fixture_bench, fn(k, _) { k == "a" }).1st == Pair("a", 1),
    expect_pop_until(fixture_bench, fn(k, _) { k == "f" }).1st == Pair("f", 6),
    expect_pop_until(fixture_bench, fn(k, _) { k == "k" }).1st == Pair("k", 11),
  }
}

/// A version of [`expect_pop_until`](#expect_pop_until) which leverages backpassing.
///
/// ```aiken
/// let predicate = fn(k, v) { k == "a" && v > 1 }
///
/// 💥 <- pairs.expect_pop_until_and_then([], predicate)
/// 💥 <- pairs.expect_pop_until([Pair("a", 1), Pair("b", 2)], predicate)
/// expect Pair("a", 3), [] <- pairs.expect_pop_until_and_then([Pair("a", 1), Pair("b", 2), Pair("a", 3)], predicate)
/// ```
pub fn expect_pop_until_and_then(
  self: Pairs<key, value>,
  until: fn(key, value) -> Bool,
  return: fn(Pair<key, value>, Pairs<key, value>) -> result,
) -> result {
  let Pair(k, v) as head = builtin.head_list(self)
  if until(k, v) {
    return(head, builtin.tail_list(self))
  } else {
    expect_pop_until_and_then(builtin.tail_list(self), until, return)
  }
}

test expect_pop_until_and_then_1() fail {
  let x, _ <- expect_pop_until_and_then([], fn(k, _) { k == "a" })
  x == x
}

test expect_pop_until_and_then_2() {
  expect Pair("a", 1), [Pair("b", 2)] <- expect_pop_until_and_then(
    [Pair("a", 1), Pair("b", 2)],
    fn(k, _) { k == "a" },
  )
  Void
}

test expect_pop_until_and_then_3() {
  expect Pair("c", 3), [] <- expect_pop_until_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(k, _) { k == "c" },
  )
  Void
}

test expect_pop_until_and_then_4() fail {
  let x, _ <- expect_pop_until_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(_, _) { False },
  )
  x == x
}

test expect_pop_until_and_then_bench() {
  and {
    expect_pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "a" },
      fn(kv, _) { kv == Pair("a", 1) },
    ),
    expect_pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "f" },
      fn(kv, _) { kv == Pair("f", 6) },
    ),
    expect_pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "k" },
      fn(kv, _) { kv == Pair("k", 11) },
    ),
  }
}

/// More efficient version of [`pop_until_key`](#pop_until_key) which fails if the key isn't found.
///
/// ```aiken
/// 💥 = pairs.expect_pop_until_key([], "a")
/// expect (1, [Pair("b", 2)]) = pairs.expect_pop_until_key([Pair("a", 1), Pair("b", 2)], "a")
/// expect (3, []) = pairs.expect_pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c")
/// 💥 = pairs.expect_pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "")
/// ```
pub fn expect_pop_until_key(
  self: Pairs<key, value>,
  until: key,
) -> (value, Pairs<key, value>) {
  let head = builtin.head_list(self)
  if until == head.1st {
    (head.2nd, builtin.tail_list(self))
  } else {
    expect_pop_until_key(builtin.tail_list(self), until)
  }
}

test expect_pop_until_key_1() fail {
  let x = expect_pop_until_key([], "a")
  x == x
}

test expect_pop_until_key_2() {
  expect_pop_until_key([Pair("a", 1), Pair("b", 2)], "a") == (1, [Pair("b", 2)])
}

test expect_pop_until_key_3() {
  expect_pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c") == (
    3,
    [],
  )
}

test expect_pop_until_key_4() fail {
  let x = expect_pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "")
  x == x
}

test expect_pop_until_key_bench() {
  and {
    expect_pop_until_key(fixture_bench, "a").1st == 1,
    expect_pop_until_key(fixture_bench, "f").1st == 6,
    expect_pop_until_key(fixture_bench, "k").1st == 11,
  }
}

/// A version of [`expect_pop_until_key`](#expect_pop_until_key) which leverages backpassing.
///
/// ```aiken
/// 💥 <- pairs.expect_pop_until_key_and_then([], "a")
/// expect 1, [Pair("b", 2)] <- pairs.expect_pop_until_key_and_then([Pair("a", 1), Pair("b", 2)], "a")
/// expect 3, [] <- pairs.expect_pop_until_key_and_then([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c")
/// 💥 <- pairs.expect_pop_until_key_and_then([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "")
/// ```
pub fn expect_pop_until_key_and_then(
  self: Pairs<key, value>,
  until: key,
  return: fn(value, Pairs<key, value>) -> result,
) -> result {
  let head = builtin.head_list(self)
  if until == head.1st {
    return(head.2nd, builtin.tail_list(self))
  } else {
    expect_pop_until_key_and_then(builtin.tail_list(self), until, return)
  }
}

test expect_pop_until_key_and_then_1() fail {
  expect x, y <- expect_pop_until_key_and_then([], "a")
  x == x && y == y
}

test expect_pop_until_key_and_then_2() {
  expect 1, [Pair("b", 2)] <- expect_pop_until_key_and_then(
    [Pair("a", 1), Pair("b", 2)],
    "a",
  )
  Void
}

test expect_pop_until_key_and_then_3() {
  expect 3, [] <- expect_pop_until_key_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    "c",
  )
  Void
}

test expect_pop_until_key_and_then_4() fail {
  expect x, y <- expect_pop_until_key_and_then(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    "",
  )
  x == x && y == y
}

test expect_pop_until_key_and_then_bench() {
  and {
    expect_pop_until_key_and_then(fixture_bench, "a", fn(k, _) { k == 1 }),
    expect_pop_until_key_and_then(fixture_bench, "f", fn(k, _) { k == 6 }),
    expect_pop_until_key_and_then(fixture_bench, "k", fn(k, _) { k == 11 }),
  }
}

// ## Transforming

/// Fold over the key-value pairs in a pairs. The fold direction follows keys
/// in ascending order and is done from left-to-right.
///
/// ```aiken
/// 1400 == ([Pair(1, 100), Pair(2, 200), Pair(3, 300)]
///   |> pairs.foldl(0, fn(k, v, result) { k * v + result })
/// )
///
/// use aiken/primitive/bytearray.{concat}
///
/// "a1b2c3" == ([Pair("a", "1"), Pair("b", "2"), Pair("c", "3")]
///   |> pairs.foldl("", fn(k, v, str) { concat(str, concat(k, v)) })
/// )
/// ```
pub fn foldl(
  self: Pairs<key, value>,
  zero: result,
  with: fn(key, value, result) -> result,
) -> result {
  when self is {
    [] -> zero
    [Pair(k, v), ..tail] -> foldl(tail, with(k, v, zero), with)
  }
}

test foldl_1() {
  foldl([], 14, fn(_, _, _) { 42 }) == 14
}

test foldl_2() {
  foldl(
    [Pair("a", 42), Pair("b", 14)],
    zero: 0,
    with: fn(_, v, total) { v + total },
  ) == 56
}

test foldl_3() {
  "a1b2c3" == (
    [Pair("a", "1"), Pair("b", "2"), Pair("c", "3")]
      |> foldl(
          "",
          fn(k, v, str) { bytearray.concat(str, bytearray.concat(k, v)) },
        )
  )
}

/// Fold over the key-value pairs in a Pairs. The fold direction follows the
/// order of elements in the Pairs and is done from right-to-left.
///
/// ```aiken
/// 1400 == ([Pair(1, 100), Pair(2, 200), Pair(3, 300)]
///   |> pairs.foldr(0, fn(k, v, result) { k * v + result })
/// )
///
/// use aiken/primitive/bytearray.{concat}
///
/// "c3b2a1" == ([Pair("a", "1"), Pair("b", "2"), Pair("c", "3")]
///   |> pairs.foldr("", fn(k, v, str) { concat(str, concat(k, v)) })
/// )
/// ```
pub fn foldr(
  self: Pairs<key, value>,
  zero: result,
  with: fn(key, value, result) -> result,
) -> result {
  when self is {
    [] -> zero
    [Pair(k, v), ..tail] -> with(k, v, foldr(tail, zero, with))
  }
}

test foldr_1() {
  foldr([], 14, fn(_, _, _) { 42 }) == 14
}

test foldr_2() {
  foldr(
    [Pair("a", 42), Pair("b", 14)],
    zero: 0,
    with: fn(_, v, total) { v + total },
  ) == 56
}

test foldr_3() {
  let fixture = [Pair(1, 100), Pair(2, 200), Pair(3, 300)]

  foldr(fixture, 0, fn(k, v, result) { k * v + result }) == 1400
}

test foldr_4() {
  "c3b2a1" == (
    [Pair("a", "1"), Pair("b", "2"), Pair("c", "3")]
      |> foldr(
          "",
          fn(k, v, str) { bytearray.concat(str, bytearray.concat(k, v)) },
        )
  )
}
