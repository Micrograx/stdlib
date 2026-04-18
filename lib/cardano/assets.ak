use aiken/builtin
use aiken/collection/dict.{Dict}
use aiken/collection/dict/strategy as dict_strategy
use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{Blake2b_224, Hash, Script}
use cardano/assets/strategy.{FlattenStrategy}

/// Lovelace is now a type wrapper for Int.
pub type Lovelace =
  Int

/// A type-alias for a `PolicyId`. A `PolicyId` is always 28-byte long
pub type PolicyId =
  Hash<Blake2b_224, Script>

/// Ada, the native currency, isn't associated with any `PolicyId` (it's not
/// possible to mint Ada!).
///
/// By convention, it is an empty `ByteArray`.
pub const ada_policy_id = ""

/// A type-alias for 'AssetName`, which are free-form byte-arrays between
/// 0 and 32 bytes.
pub type AssetName =
  ByteArray

/// Ada, the native currency, isn't associated with any `AssetName` (it's not
/// possible to mint Ada!).
///
/// By convention, it is an empty `ByteArray`.
pub const ada_asset_name = ""

/// A multi-asset output `Value`. Contains tokens indexed by [PolicyId](#PolicyId) and [AssetName](#AssetName).
///
/// > [!IMPORTANT]
/// > This type maintain some invariants by construction; in particular, a `Value` will never contain a
/// zero quantity of a particular token.
pub opaque type Value {
  inner: Dict<PolicyId, Dict<AssetName, Int>>,
}

// ## Constructing

/// Construct a `Value` from an asset identifier (i.e. `PolicyId` + `AssetName`)
/// and a given quantity.
pub fn from_asset(
  policy_id: PolicyId,
  asset_name: AssetName,
  quantity: Int,
) -> Value {
  if 0 == quantity {
    zero
  } else {
    dict.singleton(policy_id, dict.singleton(asset_name, quantity))
      |> Value
  }
}

pub fn from_ascending_pairs(xs: Pairs<PolicyId, Dict<AssetName, Int>>) -> Value {
  xs
    |> dict.from_ascending_pairs_with(
        fn(inner) {
          and {
            dict.empty != inner,
            dict.foldl(
              inner,
              True,
              fn(_, quantity, is_non_zero) { is_non_zero && 0 != quantity },
            ),
          }
        },
      )
    |> Value
}

test from_ascending_pairs_1() {
  let v = from_ascending_pairs([])
  v == zero
}

test from_ascending_pairs_2() fail {
  from_ascending_pairs([Pair(#"33", dict.empty)])
    |> tautology
}

test from_ascending_pairs_3() fail {
  from_ascending_pairs([Pair(#"33", dict.singleton("", 0))])
    |> tautology
}

test from_ascending_pairs_4() {
  let v = from_ascending_pairs([Pair(#"33", dict.singleton(#"", 1))])
  flatten(v) == [(#"33", #"", 1)]
}

test from_ascending_pairs_5() {
  let v = from_ascending_pairs(
    [Pair(#"33", dict.from_ascending_pairs([Pair(#"", 1), Pair(#"33", 1)]))],
  )
  flatten(v) == [(#"33", #"", 1), (#"33", #"33", 1)]
}

test from_ascending_pairs_6() fail {
  from_ascending_pairs(
    [
      Pair(#"33", dict.from_ascending_pairs([Pair(#"", 1), Pair(#"33", 1)])),
      Pair(#"33", dict.from_ascending_pairs([Pair(#"", 1), Pair(#"33", 1)])),
    ],
  )
    |> tautology
}

test from_ascending_pairs_7() fail {
  from_ascending_pairs(
    [
      Pair(#"33", dict.from_ascending_pairs([Pair(#"", 1), Pair(#"33", 1)])),
      Pair(#"34", dict.from_ascending_pairs([Pair(#"", 1), Pair(#"", 1)])),
    ],
  )
    |> tautology
}

test from_ascending_pairs_8() {
  let v = from_ascending_pairs(
    [
      Pair(#"33", dict.from_ascending_pairs([Pair(#"", 1), Pair(#"33", 1)])),
      Pair(#"34", dict.singleton(#"31", 1)),
      Pair(#"35", dict.singleton("", 1)),
    ],
  )
  flatten(v) == [
    (#"33", #"", 1), (#"33", #"33", 1), (#"34", #"31", 1), (#"35", #"", 1),
  ]
}

test from_ascending_pairs_9() fail {
  from_ascending_pairs(
    [
      Pair(#"35", dict.singleton("", 1)),
      Pair(#"33", dict.from_ascending_pairs([Pair(#"", 1), Pair(#"33", 1)])),
      Pair(#"34", dict.singleton(#"31", 1)),
    ],
  )
    |> tautology
}

test from_ascending_pairs_10() fail {
  from_ascending_pairs(
    [Pair(#"", dict.singleton("", 1)), Pair(#"", dict.singleton("", -1))],
  )
    |> tautology
}

/// Promote an arbitrary list of assets into a `Value`. This function fails
/// (i.e. halts the program execution) if:
///
/// - there's any duplicate amongst `PolicyId`;
/// - there's any duplicate amongst `AssetName`;
/// - the `AssetName` aren't sorted in ascending lexicographic order; or
/// - any asset quantity is null.
///
/// This function is meant to turn arbitrary user-defined `Data` into safe `Value`,
/// while checking for internal invariants.
pub fn from_asset_list(xs: Pairs<PolicyId, Pairs<AssetName, Int>>) -> Value {
  xs
    |> list.foldr(
        dict.empty,
        fn(inner, acc) {
          expect Pair(p, [_, ..] as x) = inner
          x
            |> dict.from_ascending_pairs_with(fn(v) { 0 != v })
            |> dict.insert_with(acc, p, _, dict_strategy.expect_no_duplicate())
        },
      )
    |> Value
}

test from_asset_list_1() {
  let v = from_asset_list([])
  v == zero
}

test from_asset_list_2() fail {
  from_asset_list([Pair(#"33", [])]) |> tautology
}

test from_asset_list_3() fail {
  from_asset_list([Pair(#"33", [Pair(#"", 0)])]) |> tautology
}

test from_asset_list_4() {
  let v = from_asset_list([Pair(#"33", [Pair(#"", 1)])])
  flatten(v) == [(#"33", #"", 1)]
}

test from_asset_list_5() {
  let v = from_asset_list([Pair(#"33", [Pair(#"", 1), Pair(#"33", 1)])])
  flatten(v) == [(#"33", #"", 1), (#"33", #"33", 1)]
}

test from_asset_list_6() fail {
  from_asset_list(
    [
      Pair(#"33", [Pair(#"", 1), Pair(#"33", 1)]),
      Pair(#"33", [Pair(#"", 1), Pair(#"33", 1)]),
    ],
  )
    |> tautology
}

test from_asset_list_7() fail {
  from_asset_list(
    [
      Pair(#"33", [Pair(#"", 1), Pair(#"33", 1)]),
      Pair(#"34", [Pair(#"", 1), Pair(#"", 1)]),
    ],
  )
    |> tautology
}

test from_asset_list_8() {
  let v = from_asset_list(
    [
      Pair(#"33", [Pair(#"", 1), Pair(#"33", 1)]), Pair(#"34", [Pair(#"31", 1)]),
      Pair(#"35", [Pair(#"", 1)]),
    ],
  )
  flatten(v) == [
    (#"33", #"", 1), (#"33", #"33", 1), (#"34", #"31", 1), (#"35", #"", 1),
  ]
}

test from_asset_list_9() {
  let v = from_asset_list(
    [
      Pair(#"35", [Pair(#"", 1)]), Pair(#"33", [Pair(#"", 1), Pair(#"33", 1)]),
      Pair(#"34", [Pair(#"31", 1)]),
    ],
  )
  flatten(v) == [
    (#"33", #"", 1), (#"33", #"33", 1), (#"34", #"31", 1), (#"35", #"", 1),
  ]
}

test from_asset_list_10() fail {
  from_asset_list([Pair(#"", [Pair(#"", 1)]), Pair(#"", [Pair(#"", -1)])])
    |> tautology
}

test from_asset_list_11() fail {
  from_asset_list([Pair(#"", [Pair(#"", 1), Pair(#"", -1)])]) |> tautology
}

/// Construct a `Value` from a lovelace quantity.
///
/// Friendly reminder: 1 Ada = 1.000.000 Lovelace
pub fn from_lovelace(quantity: Int) -> Value {
  from_asset(ada_policy_id, ada_asset_name, quantity)
}

/// Construct an empty `Value` with nothing in it.
pub const zero: Value = Value { inner: dict.empty }

// ## Inspecting

/// Check whether some tokens list is contained within another. This is a
/// specialised version of [`dict.{contains}`](../aiken/collection/dict.html#contains).
pub fn contains(
  self: Dict<AssetName, Int>,
  subset: Dict<AssetName, Int>,
) -> Bool {
  do_contains(dict.to_pairs(self), dict.to_pairs(subset))
}

fn do_contains(
  self: Pairs<AssetName, Int>,
  subset: Pairs<AssetName, Int>,
) -> Bool {
  when subset is {
    [] -> True
    [head_subset, ..tail_subset] -> {
      let head_superset, tail_superset <- pairs.pop_until_key_and_then(
        self,
        head_subset.1st,
      )
      and {
        when head_superset is {
          None -> False
          Some(head_superset) -> head_superset >= head_subset.2nd
        },
        do_contains(tail_superset, tail_subset),
      }
    }
  }
}

/// Check whether a `Value` carries any NFT from the given policy. Other assets are tolerated.
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///    |> assets.add("bar", "asset#2", 14)
///
/// assets.has_any_nft(value, "foo") == True
/// assets.has_any_nft(value, "bar") == False
/// assets.has_any_nft(value, "baz") == False
/// ```
pub fn has_any_nft(self: Value, policy: PolicyId) -> Bool {
  tokens(self, policy)
    |> dict.foldr(False, fn(_, quantity, result) { result || 1 == quantity })
}

/// Check whether a `Value` carries any NFT from the given policy. Other assets (other than
/// Ada) aren't tolerated. Said differently, the check succeeds if and only if
/// the value contains no assets other than the expected NFT or Ada.
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///    |> assets.add("bar", "asset#2", 14)
///
/// assets.has_any_nft_strict(value, "foo") == False
/// assets.has_any_nft_strict(value, "bar") == False
/// assets.has_any_nft_strict(value, "baz") == False
/// ```
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///
/// assets.has_any_nft_strict(value, "foo") == True
/// assets.has_any_nft_strict(value, "bar") == False
/// ```
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///    |> assets.add("foo", "asset#2", 1)
///
/// assets.has_any_nft_strict(value, "foo") == False
/// assets.has_any_nft_strict(value, "bar") == False
/// ```
pub fn has_any_nft_strict(self: Value, policy: PolicyId) -> Bool {
  let check_inner = fn(p, inner) {
    and {
      policy == p,
      when inner |> dict.to_pairs is {
        [Pair(_, 1)] -> True
        _ -> False
      },
    }
  }

  when self.inner |> dict.to_pairs is {
    [Pair(p1, _), Pair(p2, inner)] -> and {
        p1 == ada_policy_id,
        check_inner(p2, inner),
      }

    [Pair(p, inner)] -> check_inner(p, inner)

    _ -> False
  }
}

/// Check whether a `Value` carries a specific NFT. Other assets are tolerated.
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///    |> assets.add("bar", "asset#2", 14)
///
/// assets.has_nft(value, "foo", "asset#1") == True
/// assets.has_nft(value, "foo", "asset#2") == False
/// assets.has_nft(value, "bar", "asset#2") == False
/// assets.has_nft(value, "baz", "asset#3") == False
/// ```
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///    |> assets.add("foo", "asset#2", 1)
///
/// assets.has_nft(value, "foo", "asset#1") == True
/// assets.has_nft(value, "foo", "asset#2") == True
/// assets.has_nft(value, "bar", "asset#2") == False
/// ```
pub fn has_nft(self: Value, policy: PolicyId, asset_name: AssetName) -> Bool {
  1 == quantity_of(self, policy, asset_name)
}

/// Check whether a `Value` carries a specific NFT. Other assets (other than
/// Ada) aren't tolerated. Said differently, the check succeeds if and only if
/// the value contains no assets other than the expected NFT or Ada.
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///    |> assets.add("bar", "asset#2", 14)
///
/// assets.has_nft_strict(value1, "foo", "asset#1") == False
/// assets.has_nft_strict(value1, "bar", "asset#2") == False
/// assets.has_nft_strict(value1, "baz", "asset#3") == False
/// ```
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///
/// assets.has_nft_strict(value, "foo", "asset#1") == True
/// assets.has_nft_strict(value, "foo", "asset#2") == False
/// assets.has_nft_strict(value, "bar", "asset#2") == False
/// ```
///
/// ```aiken
/// let value = assets.from_lovelace(42)
///    |> assets.add("foo", "asset#1", 1)
///    |> assets.add("foo", "asset#2", 1)
///
/// assets.has_nft_strict(value3, "foo", "asset#1") == False
/// assets.has_nft_strict(value3, "foo", "asset#2") == False
/// ```
pub fn has_nft_strict(
  self: Value,
  policy: PolicyId,
  asset_name: AssetName,
) -> Bool {
  match(
    self,
    builtin.map_data(
      [
        builtin.new_pair(
          policy,
          builtin.map_data([builtin.new_pair(asset_name, 1)]),
        ),
      ],
    ),
    fn(_, _) { True },
  )
}

const has_nft_fixture_1: Value =
  from_lovelace(42)
    |> add("foo", "asset#1", 1)
    |> add("bar", "asset#2", 14)

const has_nft_fixture_2: Value =
  from_lovelace(42)
    |> add("foo", "asset#1", 1)

const has_nft_fixture_3: Value =
  from_lovelace(42)
    |> add("foo", "asset#1", 1)
    |> add("foo", "asset#2", 1)
    |> add("bar", "asset#2", 14)

test has_nft_with_fixture_1() {
  and {
    // has_any_nft
    has_any_nft(has_nft_fixture_1, "foo")?,
    (!has_any_nft(has_nft_fixture_1, "bar"))?,
    (!has_any_nft(has_nft_fixture_1, "baz"))?,
    // has_any_nft_strict
    (!has_any_nft_strict(has_nft_fixture_1, "foo"))?,
    (!has_any_nft_strict(has_nft_fixture_1, "bar"))?,
    (!has_any_nft_strict(has_nft_fixture_1, "baz"))?,
    // has_nft
    has_nft(has_nft_fixture_1, "foo", "asset#1")?,
    (!has_nft(has_nft_fixture_1, "foo", "asset#2"))?,
    (!has_nft(has_nft_fixture_1, "bar", "asset#2"))?,
    (!has_nft(has_nft_fixture_1, "baz", "asset#1"))?,
    // has_nft_strict
    (!has_nft_strict(has_nft_fixture_1, "foo", "asset#1"))?,
    (!has_nft_strict(has_nft_fixture_1, "foo", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_1, "bar", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_1, "baz", "asset#1"))?,
  }
}

test has_nft_with_fixture_1_without_lovelace() {
  let has_nft_fixture_1 = without_lovelace(has_nft_fixture_1)
  and {
    // has_any_nft
    has_any_nft(has_nft_fixture_1, "foo")?,
    (!has_any_nft(has_nft_fixture_1, "bar"))?,
    (!has_any_nft(has_nft_fixture_1, "baz"))?,
    // has_any_nft_strict
    (!has_any_nft_strict(has_nft_fixture_1, "foo"))?,
    (!has_any_nft_strict(has_nft_fixture_1, "bar"))?,
    (!has_any_nft_strict(has_nft_fixture_1, "baz"))?,
    // has_nft
    has_nft(has_nft_fixture_1, "foo", "asset#1")?,
    (!has_nft(has_nft_fixture_1, "foo", "asset#2"))?,
    (!has_nft(has_nft_fixture_1, "bar", "asset#2"))?,
    (!has_nft(has_nft_fixture_1, "baz", "asset#1"))?,
    // has_nft_strict
    (!has_nft_strict(has_nft_fixture_1, "foo", "asset#1"))?,
    (!has_nft_strict(has_nft_fixture_1, "foo", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_1, "bar", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_1, "baz", "asset#1"))?,
  }
}

test has_nft_with_fixture_2() {
  and {
    // has_any_nft
    has_any_nft(has_nft_fixture_2, "foo")?,
    (!has_any_nft(has_nft_fixture_2, "bar"))?,
    (!has_any_nft(has_nft_fixture_2, "baz"))?,
    // has_any_nft_strict
    has_any_nft_strict(has_nft_fixture_2, "foo")?,
    (!has_any_nft_strict(has_nft_fixture_2, "bar"))?,
    (!has_any_nft_strict(has_nft_fixture_2, "baz"))?,
    // has_nft
    has_nft(has_nft_fixture_2, "foo", "asset#1")?,
    (!has_nft(has_nft_fixture_2, "foo", "asset#2"))?,
    (!has_nft(has_nft_fixture_2, "bar", "asset#2"))?,
    (!has_nft(has_nft_fixture_2, "baz", "asset#1"))?,
    // has_nft_strict
    has_nft_strict(has_nft_fixture_2, "foo", "asset#1")?,
    (!has_nft_strict(has_nft_fixture_2, "foo", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_2, "bar", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_2, "baz", "asset#1"))?,
  }
}

test has_nft_with_fixture_2_without_lovelace() {
  let has_nft_fixture_2 = without_lovelace(has_nft_fixture_2)
  and {
    // has_any_nft
    has_any_nft(has_nft_fixture_2, "foo")?,
    (!has_any_nft(has_nft_fixture_2, "bar"))?,
    (!has_any_nft(has_nft_fixture_2, "baz"))?,
    // has_any_nft_strict
    has_any_nft_strict(has_nft_fixture_2, "foo")?,
    (!has_any_nft_strict(has_nft_fixture_2, "bar"))?,
    (!has_any_nft_strict(has_nft_fixture_2, "baz"))?,
    // has_nft
    has_nft(has_nft_fixture_2, "foo", "asset#1")?,
    (!has_nft(has_nft_fixture_2, "foo", "asset#2"))?,
    (!has_nft(has_nft_fixture_2, "bar", "asset#2"))?,
    (!has_nft(has_nft_fixture_2, "baz", "asset#1"))?,
    // has_nft_strict
    has_nft_strict(has_nft_fixture_2, "foo", "asset#1")?,
    (!has_nft_strict(has_nft_fixture_2, "foo", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_2, "bar", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_2, "baz", "asset#1"))?,
  }
}

test has_nft_with_fixture_3() {
  and {
    // has_any_nft
    has_any_nft(has_nft_fixture_3, "foo")?,
    (!has_any_nft(has_nft_fixture_3, "bar"))?,
    (!has_any_nft(has_nft_fixture_3, "baz"))?,
    // has_any_nft_strict
    (!has_any_nft_strict(has_nft_fixture_3, "foo"))?,
    (!has_any_nft_strict(has_nft_fixture_3, "bar"))?,
    (!has_any_nft_strict(has_nft_fixture_3, "baz"))?,
    // has_nft
    has_nft(has_nft_fixture_3, "foo", "asset#1")?,
    has_nft(has_nft_fixture_3, "foo", "asset#2")?,
    (!has_nft(has_nft_fixture_3, "bar", "asset#2"))?,
    (!has_nft(has_nft_fixture_3, "baz", "asset#1"))?,
    // has_nft_strict
    (!has_nft_strict(has_nft_fixture_3, "foo", "asset#1"))?,
    (!has_nft_strict(has_nft_fixture_3, "foo", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_3, "bar", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_3, "baz", "asset#1"))?,
  }
}

test has_nft_with_fixture_3_without_lovelace() {
  let has_nft_fixture_3 = without_lovelace(has_nft_fixture_3)
  and {
    // has_any_nft
    has_any_nft(has_nft_fixture_3, "foo")?,
    (!has_any_nft(has_nft_fixture_3, "bar"))?,
    (!has_any_nft(has_nft_fixture_3, "baz"))?,
    // has_any_nft_strict
    (!has_any_nft_strict(has_nft_fixture_3, "foo"))?,
    (!has_any_nft_strict(has_nft_fixture_3, "bar"))?,
    (!has_any_nft_strict(has_nft_fixture_3, "baz"))?,
    // has_nft
    has_nft(has_nft_fixture_3, "foo", "asset#1")?,
    has_nft(has_nft_fixture_3, "foo", "asset#2")?,
    (!has_nft(has_nft_fixture_3, "bar", "asset#2"))?,
    (!has_nft(has_nft_fixture_3, "baz", "asset#1"))?,
    // has_nft_strict
    (!has_nft_strict(has_nft_fixture_3, "foo", "asset#1"))?,
    (!has_nft_strict(has_nft_fixture_3, "foo", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_3, "bar", "asset#2"))?,
    (!has_nft_strict(has_nft_fixture_3, "baz", "asset#1"))?,
  }
}

/// Check is a `Value` is zero. That is, it has no assets and holds no Ada/Lovelace.
pub fn is_zero(self: Value) -> Bool {
  zero == self
}

/// Efficiently compare two values together, allowing a custom behaviour for Ada/Lovelace.
/// The second parameter is provided as `Data`, allowing to conveniently compare serialized
/// datums or similar structurually equivalent types (such as `Pairs<PolicyId, Pairs<AssetName, Lovelace>>`).
///
/// The third argument is a callback function to assert the left and right lovelace
/// quantities. Its first argument refers to the quantity of the first argument of
/// `match`, and the second argument of the callback to the quantity of the second
/// argument of `match`. In the absence of lovelace in any value, it defaults to `0`.
///
/// ```aiken
/// const value: Value =
///   assets.from_lovelace(30)
///     |> assets.add("foo", "bar", 1)
///     |> assets.add("foo", "baz", 42)
///
/// const datum: Data =
///   assets.from_lovelace(20)
///     |> assets.add("foo", "bar", 1)
///     |> assets.add("foo", "baz", 42)
///
/// True == assets.match(value, datum, >=)
///
/// False == assets.match(value, datum, ==)
///
/// True == assets.match(value, datum, fn(value_lovelace, datum_lovelace) {
///   2 * datum_lovelace >= value_lovelace
/// })
///
/// False == assets.match(assets.zero, datum, fn(_, _) { True })
/// ```
pub fn match(
  left: Value,
  right: Data,
  assert_lovelace: fn(Lovelace, Lovelace) -> Bool,
) -> Bool {
  builtin.choose_data(
    right,
    False,
    expect_match(left, right, assert_lovelace),
    False,
    False,
    False,
  )
}

const fixture_match_value: Value =
  zero
    |> add(ada_policy_id, ada_asset_name, 42)
    |> add("foo", "01", 1)
    |> add("foo", "02", 1)
    |> add("bar", "01", 42)

const fixture_match_data: Data =
  zero
    |> add(ada_policy_id, ada_asset_name, 14)
    |> add("foo", "01", 1)
    |> add("foo", "02", 1)
    |> add("bar", "01", 42)

const fixture_match_data_missing_foo_02: Data =
  zero
    |> add(ada_policy_id, ada_asset_name, 14)
    |> add("foo", "01", 1)
    |> add("bar", "01", 42)

const fixture_match_data_altered_foo_01: Data =
  zero
    |> add(ada_policy_id, ada_asset_name, 14)
    |> add("foo", "01", 14)
    |> add("foo", "02", 1)
    |> add("bar", "01", 42)

const fixture_match_data_missing_bar: Data =
  zero
    |> add(ada_policy_id, ada_asset_name, 14)
    |> add("foo", "01", 1)
    |> add("foo", "02", 1)

const fixture_match_data_extra_policy: Data =
  zero
    |> add(ada_policy_id, ada_asset_name, 14)
    |> add("foo", "01", 1)
    |> add("foo", "02", 1)
    |> add("bar", "01", 42)
    |> add("baz", "01", 1)

const fixture_match_data_extra_asset: Data =
  zero
    |> add(ada_policy_id, ada_asset_name, 14)
    |> add("foo", "01", 1)
    |> add("foo", "02", 1)
    |> add("foo", "03", 1)
    |> add("bar", "01", 42)

const fixture_match_data_no_assets: Data =
  zero
    |> add(ada_policy_id, ada_asset_name, 14)

test match_1() {
  match(fixture_match_value, fixture_match_data, fn(_, _) { True })
}

test match_2() {
  !match(
    fixture_match_value,
    fixture_match_data,
    fn(source, target) { source == target },
  )
}

test match_3() {
  !match(
    fixture_match_value,
    fixture_match_data_missing_foo_02,
    fn(_, _) { True },
  )
}

test match_4() {
  !match(fixture_match_value, fixture_match_data_missing_bar, fn(_, _) { True })
}

test match_5() {
  !match(
    fixture_match_value,
    fixture_match_data_altered_foo_01,
    fn(_, _) { True },
  )
}

test match_6() {
  !match(
    fixture_match_value,
    fixture_match_data_extra_policy,
    fn(_, _) { True },
  )
}

test match_7() {
  !match(fixture_match_value, fixture_match_data_extra_asset, fn(_, _) { True })
}

test match_8() {
  !match(fixture_match_value, fixture_match_data_no_assets, fn(_, _) { True })
}

test match_9() {
  match(zero, zero, ==)
}

test match_10() {
  match(
    without_lovelace(fixture_match_value),
    without_lovelace(fixture_match_value),
    fn(left, right) { left == 0 && right == 0 },
  )
}

test match_11() {
  match(
    without_lovelace(fixture_match_value),
    fixture_match_value,
    fn(left, right) { left == 0 && right > 0 },
  )
}

test match_12() {
  match(
    fixture_match_value,
    without_lovelace(fixture_match_value),
    fn(left, right) { left > 0 && right == 0 },
  )
}

test match_13() {
  match(
    zero |> add(ada_policy_id, ada_asset_name, 42),
    zero,
    fn(left, right) { left == 42 && right == 0 },
  )
}

test match_14() {
  match(
    zero,
    zero |> add(ada_policy_id, ada_asset_name, 42),
    fn(left, right) { left == 0 && right == 42 },
  )
}

const fixture_match_benchmark_left: Value =
  zero
    |> add(ada_policy_id, ada_asset_name, 1337)
    |> add(
        #"0246a14d04c3a0e9b65f6b90a3d1aa5faee5d56ab1e30ec7e8b02f29",
        "MATTR",
        200,
      )
    |> add(
        #"0a9e126256cb38c4865cdac6eb2ada51c328ba0df2ebde22ae126c0d",
        "ProphecyPoster076",
        1,
      )
    |> add(
        #"1774343241680e4daef7cbfe3536fc857ce23fb66cd0b66320b2e3dd",
        "BISON",
        12_004_999_999,
      )
    |> add(
        #"279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f",
        "SNEK",
        1486,
      )
    |> add(
        #"651dfc074202423585996ffa717cb45237d307e705e2cc3dab1ccabd",
        "MAYZSilverFoundersEdition0035",
        1,
      )
    |> add(
        #"63df49056617dd14034986cf7c250bad6552fd2f0f9c71d797932008",
        "CardanoSpaceSession",
        20,
      )
    |> add(
        #"5b01968867e13432afaa2f814e1d15e332d6cd0aa77e350972b0967d",
        "ADAOGovernanceToken",
        1,
      )
    |> add(
        #"a0028f350aaabe0545fdcb56b039bfb08e4bb4d8c4d7c3c7d481c235",
        "HOSKY",
        400_001_000,
      )
    |> add(
        #"da8c30857834c6ae7203935b89278c532b3995245295456f993e1d24",
        "LQ",
        10_635_899,
      )
    |> add(
        #"95d9a98c2f7999a3d5e0f4d795cb1333837c09eb0f24835cd2ce954c",
        "GrandmasterAdventurer659",
        1,
      )
    |> add(
        #"702cbdb06a81ef2fa4f85f9e32159c03f502539d762a71194fc11eb3",
        "AdventurerOfThiolden8105",
        1,
      )
    |> add(
        #"d0112837f8f856b2ca14f69b375bc394e73d146fdadcc993bb993779",
        "DiscoSolaris3725",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld535",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld1213",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld1518",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld1537",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld4199",
        1,
      )
    |> add(
        #"8dd5717e7d4d993019dbd788c19837910e3fcf647ab282f828c80a7a",
        "CardaWorld3767",
        1,
      )
    |> add(
        #"7597444754551a8c17edbf7291cdaeca898ca02ee4e732b09a949396",
        "Algae1",
        1,
      )
    |> add(
        #"7597444754551a8c17edbf7291cdaeca898ca02ee4e732b09a949396",
        "Algae2",
        1,
      )

const fixture_match_benchmark_right: Data = fixture_match_benchmark_left

test match_bench() {
  match(fixture_match_benchmark_left, fixture_match_benchmark_right, ==)
}

test expect_match_bench() {
  expect_match(fixture_match_benchmark_left, fixture_match_benchmark_right, ==)
}

test match_assets_bench() {
  match_assets(fixture_match_benchmark_left, fixture_match_benchmark_right)
}

test expect_match_assets_bench() {
  expect_match_assets(
    fixture_match_benchmark_left,
    fixture_match_benchmark_right,
  )
}

test naive_match_bench() {
  let data: Data = fixture_match_benchmark_right
  expect pairs: Pairs<PolicyId, Pairs<AssetName, Int>> = data
  fixture_match_benchmark_left == from_asset_list(pairs)
}

/// A version of [`match`](#match) which simply ignores lovelace in either operands.
///
/// ```aiken
/// const value: Value =
///   assets.from_lovelace(30)
///     |> assets.add("foo", "bar", 1)
///     |> assets.add("foo", "baz", 42)
///
/// const datum: Data =
///   assets.from_lovelace(20)
///     |> assets.add("foo", "bar", 1)
///     |> assets.add("foo", "baz", 42)
///
/// True == assets.match(value, datum)
///
/// False == assets.match(assets.zero, datum)
/// ```
pub fn match_assets(left: Value, right: Data) -> Bool {
  builtin.choose_data(
    right,
    False,
    expect_match_assets(left, right),
    False,
    False,
    False,
  )
}

test match_assets_1() {
  match_assets(fixture_match_value, fixture_match_data)
}

test match_assets_2() {
  !match_assets(fixture_match_value, fixture_match_data_missing_foo_02)
}

test match_assets_3() {
  !match_assets(fixture_match_value, fixture_match_data_missing_bar)
}

test match_assets_4() {
  !match_assets(fixture_match_value, fixture_match_data_altered_foo_01)
}

test match_assets_5() {
  !match_assets(fixture_match_value, fixture_match_data_extra_policy)
}

test match_assets_6() {
  !match_assets(fixture_match_value, fixture_match_data_extra_asset)
}

test match_assets_7() {
  !match_assets(fixture_match_value, fixture_match_data_no_assets)
}

test match_assets_8() {
  match_assets(zero, zero)
}

test match_assets_9() {
  match_assets(
    without_lovelace(fixture_match_value),
    without_lovelace(fixture_match_value),
  )
}

test match_assets_10() {
  match_assets(without_lovelace(fixture_match_value), fixture_match_value)
}

test match_assets_11() {
  match_assets(fixture_match_value, without_lovelace(fixture_match_value))
}

test match_assets_12() {
  match_assets(zero |> add(ada_policy_id, ada_asset_name, 42), zero)
}

test match_assets_13() {
  match_assets(zero, zero |> add(ada_policy_id, ada_asset_name, 42))
}

/// A specialized version of `quantity_of` for the Ada currency.
pub fn lovelace_of(self: Value) -> Int {
  quantity_of(self, ada_policy_id, ada_asset_name)
}

const fixture_lovelace_of_1: Value =
  zero
    |> add("", "", 42)

const fixture_lovelace_of_2: Value =
  zero
    |> add("foo", "bar", 42)

test lovelace_of_0() {
  lovelace_of(zero) == 0
}

test lovelace_of_1() {
  lovelace_of(fixture_lovelace_of_1) == 42
}

test lovelace_of_2() {
  lovelace_of(fixture_lovelace_of_2) == 0
}

/// A list of all token policies in that Value with non-zero tokens.
pub fn policies(self: Value) -> List<PolicyId> {
  dict.keys(self.inner)
}

/// Extract the quantity of a given asset.
pub fn quantity_of(
  self: Value,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> Int {
  tokens(self, policy_id)
    |> dict.get_or_else(asset_name, fn() { 0 })
}

/// Get all tokens associated with a given policy.
pub fn tokens(self: Value, policy_id: PolicyId) -> Dict<AssetName, Int> {
  self.inner
    |> dict.get_or_else(policy_id, fn() { dict.empty })
}

// # Inspecting Forcibly

/// More efficient version of [`lovelace_of`](#lovelace_of), but fails when
/// there's no lovelace quantity in the [`Value`](#Value).
///
/// > [!TIP]
/// > It's worth noting that:
/// >
/// > - There's **always** some lovelace in values from **inputs** or **outputs**.
/// > - There's **never** any lovelace in values from **mint**.
pub fn expect_lovelace_of(self: Value) -> Int {
  expect Pair("", lovelaces) = self
    |> to_dict
    |> dict.to_pairs
    |> builtin.head_list
  lovelaces
    |> dict.to_pairs
    |> builtin.head_list
    |> builtin.snd_pair
}

test expect_lovelace_of_0() fail {
  expect_lovelace_of(zero) |> tautology
}

test expect_lovelace_of_1() {
  expect_lovelace_of(fixture_lovelace_of_1) == 42
}

test expect_lovelace_of_2() fail {
  expect_lovelace_of(fixture_lovelace_of_2) |> tautology
}

/// A slightly more efficient version of [`match`](#match) which fails if the
/// provided `Data` is not akin to a [`Value`](#Value).
pub fn expect_match(
  left: Value,
  right: Data,
  assert_lovelace: fn(Lovelace, Lovelace) -> Bool,
) -> Bool {
  let (left_lovelace, left_assets) = dict.pop(left.inner, ada_policy_id)
  let left_assets: Data = left_assets
  let left_lovelace = when left_lovelace is {
    Some(tokens) -> list.expect_head(dict.to_pairs(tokens)).2nd
    None -> 0
  }
  when builtin.un_map_data(right) is {
    [] -> left_assets == right && assert_lovelace(left_lovelace, 0)
    [first_asset, ..right_assets] ->
      if builtin.b_data(ada_policy_id) == first_asset.1st {
        and {
          assert_lovelace(
            left_lovelace,
            builtin.un_i_data(
              builtin.head_list(builtin.un_map_data(first_asset.2nd)).2nd,
            ),
          ),
          left_assets == builtin.map_data(right_assets),
        }
      } else {
        and {
          assert_lovelace(left_lovelace, 0),
          left_assets == right,
        }
      }
  }
}

/// A slightly more efficient version of [`match_assets`](#match_assets) which
/// fails if the provided `Data` is not akin to a [`Value`](#Value).
pub fn expect_match_assets(left: Value, right: Data) -> Bool {
  let (_, left_assets) = dict.pop(left.inner, ada_policy_id)
  when builtin.un_map_data(right) is {
    [] -> builtin.equals_data(left_assets, right)
    [first_asset, ..right_assets] ->
      builtin.equals_data(
        left_assets,
        if builtin.b_data(ada_policy_id) == first_asset.1st {
          builtin.map_data(right_assets)
        } else {
          right
        },
      )
  }
}

/// More efficient version of [`quantity_of`](#quantity_of), but fails if the
/// target policy and asset aren't present in the value.
pub fn expect_quantity_of(
  self: Value,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> Int {
  self.inner
    |> dict.expect_get(policy_id)
    |> dict.expect_get(asset_name)
}

// # Modifying

/// Negates quantities of all tokens (including Ada) in that `Value`.
///
/// ```
/// v1
///   |> assets.negate
///   |> assets.merge(v1)
///   |> assets.is_zero
/// // True
/// ```
pub fn negate(self: Value) -> Value {
  dict.map(self.inner, fn(_, a) { dict.map(a, fn(_, qty) { -qty }) })
    |> Value
}

/// Get a subset of the assets restricted to the given policies.
pub fn restricted_to(self: Value, mask: List<PolicyId>) -> Value {
  list.foldr(
    policies(self),
    zero,
    fn(policy_id, value) {
      if list.has(mask, policy_id) {
        dict.foldr(
          tokens(self, policy_id),
          value,
          fn(asset_name, quantity, value) {
            add(value, policy_id, asset_name, quantity)
          },
        )
      } else {
        value
      }
    },
  )
}

test restricted_to_1() {
  let self = from_lovelace(42) |> add("foo", "", 1)
  restricted_to(self, []) == zero
}

test restricted_to_2() {
  let self = from_lovelace(42) |> add("foo", "", 1)
  restricted_to(self, [ada_policy_id]) == from_lovelace(42)
}

test restricted_to_3() {
  let self = from_lovelace(42) |> add("foo", "", 1) |> add("bar", "", 1)
  restricted_to(self, ["foo", "bar"]) == without_lovelace(self)
}

test restricted_to_4() {
  let self = from_lovelace(42) |> add("foo", "bar", 1) |> add("foo", "baz", 1)
  restricted_to(self, ["foo"]) == without_lovelace(self)
}

test restricted_to_5() {
  let self = from_lovelace(42) |> add("foo", "bar", 1) |> add("foo", "baz", 1)
  restricted_to(self, [ada_policy_id, "foo"]) == self
}

/// Get a `Value` excluding Ada.
pub fn without_lovelace(self: Value) -> Value {
  dict.delete(self.inner, ada_policy_id)
    |> Value
}

test without_lovelace_1() {
  let v = from_lovelace(1000000)
  without_lovelace(v) == zero
}

test without_lovelace_2() {
  let v = from_lovelace(1000000)
  let v2 = from_lovelace(50000000)
  without_lovelace(v) == without_lovelace(v2)
}

test without_lovelace_3() {
  let v = from_asset(#"010203", #"040506", 100)
    |> add(ada_policy_id, ada_asset_name, 100000000)
  let v2 = from_asset(#"010203", #"040506", 100)
  without_lovelace(v) == without_lovelace(v2) && without_lovelace(v) == v2
}

// ## Modifying Forcibly

/// Removes the first policy id from a `Value`, but fails if the `Value` is
/// empty and contains no assets whatsoever.
///
/// This is useful to strip Ada forcibly out of values that are known to
/// contain Ada (e.g. inputs or outputs).
pub fn expect_tail(self: Value) -> Value {
  self.inner |> dict.expect_tail |> Value
}

// ## Combining

/// Add a (positive or negative) quantity of a single token to a assets.
/// This is more efficient than [`merge`](#merge) for a single asset.
pub fn add(
  self: Value,
  policy_id: PolicyId,
  asset_name: AssetName,
  quantity: Int,
) -> Value {
  if 0 == quantity {
    self
  } else {
    let helper = fn(_, left, _right, keep, discard) {
      let inner_result = dict.insert_with(
        left,
        asset_name,
        quantity,
        dict_strategy.sum_if_non_zero(),
      )

      if dict.empty == inner_result {
        discard()
      } else {
        keep(inner_result)
      }
    }

    Value(
      dict.insert_with(
        self.inner,
        policy_id,
        dict.singleton(asset_name, quantity),
        helper,
      ),
    )
  }
}

test add_1() {
  let v = zero
    |> add(#"acab", #"beef", 321)
    |> add(#"acab", #"beef", -321)
  v == zero
}

test add_2() {
  let v = from_lovelace(123)
    |> add(#"acab", #"beef", 321)
    |> add(#"acab", #"beef", -1 * 321)
  v == from_lovelace(123)
}

test add_3() {
  let v = from_lovelace(1)
    |> add(ada_policy_id, ada_asset_name, 2)
    |> add(ada_policy_id, ada_asset_name, 3)
  v == from_lovelace(6)
}

test add_4() {
  let v = zero
    |> add(#"acab", #"beef", 0)
  v == zero
}

test add_5() {
  let v = zero
    |> add(#"acab", #"beef", 0)
    |> add(#"acab", #"beef", 0)
  v == zero
}

pub fn difference(left v0: Value, right v1: Value) -> Value {
  Value(
    dict.difference_with(
      v0.inner,
      v1.inner,
      fn(_, a0, a1, keep, discard) {
        let result = dict.difference_with(
          a0,
          a1,
          dict_strategy.difference_if_non_zero(),
          dict_strategy.negate(),
        )
        if dict.empty == result {
          discard()
        } else {
          keep(result)
        }
      },
      fn(_k, right, keep, _discard) {
        keep(dict.map(right, fn(_, qty) { -qty }))
      },
    ),
  )
}

test difference_1() {
  let v0 = from_lovelace(5)
  let v1 = from_lovelace(3)

  let diff = from_lovelace(2)

  and {
    (difference(v0, v1) == diff)?,
    (merge(v0, negate(v1)) == diff)?,
  }
}

test difference_2() {
  let v = zero
    |> add(#"acab", #"beef", 321)
    |> add(#"f00d", #"cafe", 42)

  and {
    (difference(v, v) == zero)?,
    (merge(v, negate(v)) == zero)?,
  }
}

test difference_3() {
  let left = zero |> add(#"00", #"aa", 5)
  let right = zero |> add(#"01", #"bb", 3)

  let diff = [(#"00", #"aa", 5), (#"01", #"bb", -3)]

  and {
    (flatten(difference(left, right)) == diff)?,
    (flatten(merge(left, negate(right))) == diff)?,
  }
}

test difference_4() {
  let left = zero
    |> add(#"00", #"aa", 10)
    |> add(#"00", #"bb", 4)

  let right = zero
    |> add(#"00", #"aa", 10)
    |> add(#"00", #"bb", 1)

  let diff = [(#"00", #"bb", 3)]

  and {
    (flatten(difference(left, right)) == diff)?,
    (flatten(merge(left, negate(right))) == diff)?,
  }
}

/// Combine two `Value` together.
pub fn merge(left v0: Value, right v1: Value) -> Value {
  Value(
    dict.union_with(
      v0.inner,
      v1.inner,
      fn(_, a0, a1, keep, discard) {
        let result = dict.union_with(a0, a1, dict_strategy.sum_if_non_zero())
        if dict.empty == result {
          discard()
        } else {
          keep(result)
        }
      },
    ),
  )
}

test merge_1() {
  let v1 = from_lovelace(1)
  let v2 = from_lovelace(-1)
  merge(v1, v2) == zero
}

test merge_2() {
  let v1 = from_asset(#"00", #"", 1)
  let v2 = from_asset(#"01", #"", 2)
  let v3 = from_asset(#"02", #"", 3)
  let v = from_lovelace(42)
    |> merge(v3)
    |> merge(v1)
    |> merge(v2)

  flatten(v) == [
    (#"", #"", 42), (#"00", #"", 1), (#"01", #"", 2), (#"02", #"", 3),
  ]
}

test merge_3() {
  let v1 = from_asset(#"00", #"", 1)
  let v2 = from_asset(#"00", #"", -1)
  let v3 = from_asset(#"01", #"", 1)

  let v = zero
    |> merge(v1)
    |> merge(v2)
    |> merge(v3)

  flatten(v) == [(#"01", #"", 1)]
}

test merge_4() {
  let v1 = from_asset(#"00", #"", 1)
  let v2 = from_asset(#"00", #"", -1)

  merge(v1, v2) == zero
}

test merge_5() {
  let v = zero
    |> add(#"acab", #"beef", 0)

  merge(zero, v) == zero
}

// ## Transforming

/// Flatten a `Value` as list of 3-tuple `(PolicyId, AssetName, Quantity)`.
///
/// Handy to manipulate values as uniform lists.
///
/// > [!CAUTION]
/// > This function is quite expensive and really only viable in testing
/// > scenarios. If you need to traverse all elements in a `Value`, prefer
/// > [`reduce`](#reduce) or more bespoke functions for your use case.
pub fn flatten(self: Value) -> List<(PolicyId, AssetName, Int)> {
  dict.foldr(
    self.inner,
    [],
    fn(policy_id, asset_list, value) {
      dict.foldr(
        asset_list,
        value,
        fn(asset_name, quantity, xs) {
          [(policy_id, asset_name, quantity), ..xs]
        },
      )
    },
  )
}

/// Flatten a `Value` as a list of results, possibly discarding some along the way. In particular, we have:
///
/// ```aiken
/// flatten(value) == flatten_with(value, strategy.triple())
/// ```
pub fn flatten_with(self: Value, with: FlattenStrategy<result>) -> List<result> {
  dict.foldr(
    self.inner,
    [],
    fn(policy_id, asset_list, value) {
      dict.foldr(
        asset_list,
        value,
        fn(asset_name, quantity, xs) {
          with(
            policy_id,
            asset_name,
            quantity,
            fn(x) { [x, ..xs] },
            fn() { xs },
          )
        },
      )
    },
  )
}

test flatten_with_1() {
  flatten_with(zero, strategy.triple()) == []
}

test flatten_with_2() {
  let v = zero
    |> add("a", "1", 14)
    |> add("b", "", 42)
    |> add("a", "2", 42)

  flatten_with(
    v,
    fn(p, a, q, keep, discard) {
      if q == 42 {
        keep((p, a))
      } else {
        discard()
      }
    },
  ) == [("a", "2"), ("b", "")]
}

/// Reduce a value into a single result
///
/// ```
/// assets.zero
///  |> assets.add("a", "1", 10)
///  |> assets.add("b", "2", 20)
///  |> assets.reduce(v, 0, fn(_, _, quantity, acc) { acc + quantity })
///  // 30
/// ```
pub fn reduce(
  self: Value,
  start: result,
  with: fn(PolicyId, AssetName, Int, result) -> result,
) -> result {
  dict.foldr(
    self.inner,
    start,
    fn(policy_id, asset_list, result) {
      dict.foldr(asset_list, result, with(policy_id, _, _, _))
    },
  )
}

test reduce_1() {
  let v = zero
    |> add("a", "1", 10)
    |> add("b", "2", 20)
  let result = reduce(v, 0, fn(_, _, quantity, acc) { acc + quantity })
  result == 30
}

test reduce_2() {
  let v = zero
    |> add("a", "1", 5)
    |> add("a", "2", 15)
    |> add("b", "", 10)
  let result = reduce(
    v,
    [],
    fn(policy_id, asset_name, _, acc) { [(policy_id, asset_name), ..acc] },
  )
  result == [("a", "1"), ("a", "2"), ("b", "")]
}

test reduce_3() {
  let v = zero
  let result = reduce(v, 1, fn(_, _, quantity, acc) { acc + quantity })
  result == 1
}

/// Convert the value into a dictionary of dictionaries.
pub fn to_dict(self: Value) -> Dict<PolicyId, Dict<AssetName, Int>> {
  self.inner
}

/// Convert the value into an associative list of pairs.
pub fn to_pairs(self: Value) -> Pairs<PolicyId, Dict<AssetName, Int>> {
  self.inner |> dict.to_pairs
}

fn tautology(a: a) -> Bool {
  a == a
}
