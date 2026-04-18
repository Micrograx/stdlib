use aiken/collection/dict.{Dict}
use aiken/collection/dict/strategy as dict_strategy
use aiken/collection/list
use aiken/fuzz
use cardano/assets.{AssetName}
use cardano/fuzz as cardano

type Tokens =
  Dict<AssetName, Int>

// -------------------------------------------------------------- fuzzers

fn any_tokens() -> Fuzzer<Tokens> {
  let tokens <- fuzz.map(fuzz.list_between(any_token(), 0, 3))
  dict.from_pairs(tokens)
}

fn any_token() -> Fuzzer<Pair<AssetName, Int>> {
  let asset_name <- fuzz.and_then(cardano.asset_name())
  let quantity <- fuzz.map(fuzz.int_between(0, 3))
  Pair(asset_name, quantity)
}

fn any_mutation() -> Fuzzer<Mutation> {
  let ix <- fuzz.and_then(fuzz.byte())
  let quantity <- fuzz.and_then(fuzz.int_between(1, 3))
  let name <- fuzz.and_then(cardano.asset_name())
  fuzz.one_of(
    [
      ReduceQuantity(ix, quantity),
      IncreaseQuantity(ix, quantity),
      InsertAsset(Pair(name, quantity)),
      DeleteAsset(ix),
    ],
  )
}

type Mutation {
  ReduceQuantity(Int, Int)
  IncreaseQuantity(Int, Int)
  InsertAsset(Pair<AssetName, Int>)
  DeleteAsset(Int)
}

// Invariant: assume 'tokens' is not empty.
fn apply_mutation(mutation: Mutation, tokens: Tokens) -> Tokens {
  let len = dict.size(tokens)
  when mutation is {
    ReduceQuantity(ix, n) | IncreaseQuantity(ix, n) -> {
      expect [Pair(name, quantity), ..] = list.drop(
        dict.to_pairs(tokens),
        ix % len,
      )
      let new_quantity = if mutation == ReduceQuantity(ix, n) {
        quantity - n
      } else {
        quantity + n
      }
      dict.insert(tokens, name, new_quantity)
    }
    InsertAsset(Pair(name, quantity)) ->
      dict.insert_with(tokens, name, quantity, dict_strategy.sum())
    DeleteAsset(ix) -> {
      expect [Pair(name, _), ..] = list.drop(dict.to_pairs(tokens), ix % len)
      dict.delete(tokens, name)
    }
  }
}

// ------------------------------------------------------------- contains

const fixture_asset_name: AssetName = #"746f6b656e"

const fixture_superset: Tokens = dict.singleton(fixture_asset_name, 100)

const fixture_superset_with_ada: Tokens =
  dict.singleton(fixture_asset_name, 100)

const fixture_subset: Tokens = dict.singleton(fixture_asset_name, 50)

test contains_exact_match() {
  assets.contains(fixture_superset, fixture_superset)
}

test contains_subset() {
  and {
    assets.contains(fixture_superset, fixture_subset)?,
    assets.contains(fixture_superset_with_ada, fixture_subset)?,
  }
}

test contains_insufficient() {
  !assets.contains(fixture_subset, fixture_superset)
}

test prop_contains_reflexive(tokens via any_tokens()) {
  assets.contains(tokens, tokens)
}

test prop_contains_monoid(tokens via any_tokens()) {
  assets.contains(tokens, dict.empty)
}

test prop_contains_subset_mutation(
  (superset, mutation) via fuzz.both(any_tokens(), any_mutation()),
) fail {
  if superset != dict.empty {
    let subset = apply_mutation(mutation, superset)
    when mutation is {
      IncreaseQuantity(..) -> {
        fuzz.label(@"non-empty superset, increase quantity")
        assets.contains(superset, subset)
      }
      InsertAsset(..) -> {
        fuzz.label(@"non-empty superset, insert new asset")
        assets.contains(superset, subset)
      }
      ReduceQuantity(..) -> {
        fuzz.label(@"non-empty superset, reduce quantity")
        !assets.contains(superset, subset)
      }
      DeleteAsset(..) -> {
        fuzz.label(@"non-empty superset, remove asset")
        !assets.contains(superset, subset)
      }
    }
  } else {
    fuzz.label(@"empty superset, skipped")
    False
  }
}

test prop_contains_superset_mutation(
  (subset, mutation) via fuzz.both(any_tokens(), any_mutation()),
) fail {
  if dict.empty != subset {
    let superset = apply_mutation(mutation, subset)
    when mutation is {
      IncreaseQuantity(..) -> {
        fuzz.label(@"non-empty subset, increase quantity")
        !assets.contains(superset, subset)
      }
      InsertAsset(..) -> {
        fuzz.label(@"non-empty subset, insert new asset")
        !assets.contains(superset, subset)
      }
      ReduceQuantity(..) -> {
        fuzz.label(@"non-empty subset, reduce quantity")
        assets.contains(superset, subset)
      }
      DeleteAsset(..) -> {
        fuzz.label(@"non-empty subset, remove asset")
        assets.contains(superset, subset)
      }
    }
  } else {
    fuzz.label(@"empty subset, skipped")
    False
  }
}
