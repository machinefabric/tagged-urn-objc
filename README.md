# Tagged URN - Objective-C Implementation

Objective-C implementation of Tagged URN with strict validation, pattern matching, and Swift compatibility.

## Features

- **Strict Rule Enforcement** - Follows exact same rules as Rust, Go, and JavaScript implementations
- **Tag Forms** - exact `k=v`, present `k`, absent `!k`, unconstrained `?k`, `k?=v` (absent or not v), `k!=v` (present and not v), and sets of values: `k=a|b` (one of), `k!=a|b` (none of), `k?=a|b` (absent or none of), `k=a|b|!` (absent or one of)
- **Typed Tags** - Each tag is stored as the constraint it writes (`CSTagConstraint`, the proved model's constraint: whether the key may be absent, and the values it may have, `oneOf`, or may not, `noneOf`)
- **Identifiers** - The prefix and every key are an ASCII letter followed by ASCII letters, digits and `-`
- **Case Insensitive** - The prefix, keys and unquoted values are lowered; quoted values keep their case
- **Literal Quoting** - A quoted value is always the literal value: `x="*"` is the exact value `*`
- **Tag Order Independent** - Canonical alphabetical sorting
- **Graded Specificity** - `?k` 0, `k?=v` and `k=v|!` 1, `k` 2, `k!=v` and `k=a|b` 3, `k=v` 4, `!k` 5
- **Swift Compatible** - Full Swift interoperability via Objective-C bridge
- **NSSecureCoding** - Secure serialization support

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/machinefabric/tagged-urn-objc.git", from: "1.0.0")
]
```

### Manual

Add the `Sources/TaggedUrn` directory to your Xcode project.

## Quick Start

### Objective-C

```objc
#import <TaggedUrn/CSTaggedUrn.h>

// Parse a URN
NSError *error = nil;
CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
if (urn) {
    NSLog(@"Has generate marker: %@", [urn hasMarkerTag:@"generate"] ? @"YES" : @"NO");
    NSLog(@"Canonical: %@", [urn toString]);  // "cap:ext=pdf;generate"
}

// Build a URN
CSTaggedUrn *built = [[[[[CSTaggedUrnBuilder builderWithPrefix:@"cap"]
    marker:@"extract"]
    tag:@"format" value:@"pdf"]
    tag:@"debug" constraint:[CSTagConstraint absent]]
    build:&error];
// [built toString] is "cap:!debug;extract;format=pdf"
// [built getTag:@"format"] is [CSTagConstraint exact:@"pdf"], whose exactValue is @"pdf"
// [[CSTaggedUrn fromString:@"media:ext=png|jpeg" error:&error] getTag:@"ext"]
//   is [CSTagConstraint oneOf:@[@"jpeg", @"png"] orAbsent:NO]

// Check matching
CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:generate" error:&error];
if ([urn conformsTo:pattern error:&error]) {
    NSLog(@"URN conforms to pattern");
}
```

### Swift

```swift
import TaggedUrn

// Parse a URN
do {
    let urn = try CSTaggedUrn.fromString("cap:generate;ext=pdf")
    print("Has generate marker: \(urn.hasMarkerTag("generate"))")   // true
    print("ext: \(urn.getTag("ext")?.exactValue ?? "nil")")          // "pdf"
    print("Canonical: \(urn.toString())")                            // "cap:ext=pdf;generate"
} catch {
    print("Parse error: \(error)")
}

// Build a URN
let built = try CSTaggedUrnBuilder.builder(withPrefix: "cap")
    .marker("extract")
    .tag("format", value: "pdf")
    .build()

// Check matching
let pattern = try CSTaggedUrn.fromString("cap:generate")
if try urn.conforms(to: pattern) {
    print("URN conforms to pattern")
}
```

## API Reference

### CSTaggedUrn

| Method | Description |
|--------|-------------|
| `+fromString:error:` | Parse URN from string |
| `+fromPrefix:tags:error:` | Create from prefix and a dictionary of constraints (checked) |
| `+emptyWithPrefix:error:` | Create empty URN with prefix |
| `-getTag:` | The constraint for a key, or nil |
| `-constraintForKey:` | The constraint for a key, missing when it is not mentioned |
| `-hasTag:withValue:` | Whether the URN writes the exact value `key=value` |
| `-hasMarkerTag:` | Whether the URN writes the marker `key` |
| `-withTag:constraint:error:` | Return new URN with tag added/replaced (checked) |
| `-withoutTag:` | Return new URN with tag removed |
| `-conformsTo:error:` | Check if URN conforms to a pattern |
| `-accepts:error:` | Check if URN (as pattern) accepts an instance |
| `-specificity` | Get graded specificity score |
| `-isMoreSpecificThan:error:` | Compare specificity with another URN |
| `-compare:` | Order by parts: prefix, then each tag by key, constraint form, values |
| `+writeValue:` | A value as a tag writes it: bare, or quoted when it must be |
| `+leastUpperBoundWithPrefix:urns:error:` | The most specific URN every one of `urns` conforms to, made by the proved model |
| `-toString` | Get canonical string representation |

### CSTaggedUrnBuilder

| Method | Description |
|--------|-------------|
| `+builderWithPrefix:` | Create builder with prefix |
| `-tag:value:` | Add the exact value, taken literally (chainable) |
| `-marker:` | Add a marker (chainable) |
| `-tag:constraint:` | Add a tag of any form (chainable) |
| `-build:` | Build the URN (nil with the first error a tag met) |
| `-buildAllowEmpty:` | Build URN allowing empty tags |

### CSTagConstraint

The proved model's constraint for one key: `kind` (`Missing`, for a key a URN does not
mention and never stored, or `Written`), `absent` (whether the key may be absent),
`valuesKind` (`OneOf`: the values it may have; `NoneOf`: the values it may not) and
`values` (each once, in increasing code-point order).

| Text | Constraint |
|------|------------|
| `k` | `[CSTagConstraint present]`, none of no values |
| `?k` | `[CSTagConstraint unconstrained]`, absent or none of no values |
| `!k` | `[CSTagConstraint absent]`, absent or one of no values |
| `k=v` | `[CSTagConstraint exact:v]`, one of `v` |
| `k!=v` | `[CSTagConstraint presentNot:v]`, none of `v` |
| `k?=v` | `[CSTagConstraint optionalNot:v]`, absent or none of `v` |
| `k=a\|b` | `[CSTagConstraint oneOf:@[a, b] orAbsent:NO]` |
| `k=a\|b\|!` | `[CSTagConstraint oneOf:@[a, b] orAbsent:YES]` |
| `k!=a\|b` | `[CSTagConstraint noneOf:@[a, b] orAbsent:NO]` |
| `k?=a\|b` | `[CSTagConstraint noneOf:@[a, b] orAbsent:YES]` |

`exactValue` is the value of `k=v`, and nil for any other form.

## Matching Semantics

Every form means the set of states its key may be in, on either side of a
comparison, and two URNs are compared by those sets. Three questions:

| Question | Objective-C |
|---|---|
| Is everything `a` describes described by `b`? (a guarantee) | `[a conformsTo:b error:&e]` |
| Could `a` and `b` be about the same thing? (a possibility) | `[a meets:b error:&e]` |
| Does `a`, a complete thing — what it does not mention it does not have — fit `b`? | `[a satisfies:b error:&e]` |

What an instance must say to be guaranteed to fit a pattern:

| Pattern | Instance omits K | Instance `K=v` | Instance `K=x` (x≠v) | Instance `K` (any value) |
|---------|------------------|----------------|----------------------|--------------------------|
| (missing) or `?K` | fits | fits | fits | fits |
| `!K` | no — an omission promises nothing | no | no | no |
| `K` (=`K=*`) | no | fits | fits | fits |
| `K=v` | no | fits | no | no — "some value" is not `v` |

A complete thing that omits `K` does fit `!K`: use `satisfies:` where the
left side is what something is — a value's media, a cap's own tags — rather than
what something is declared to take or give. "Some value" could be `v`:
`meets:` says so, and is the answer a search wants; a route is only ever
taken on a guarantee.

The rules are proved in `../formal` (Lean), and this package runs code generated
from them.

## Graded Specificity

Each tag scores by what it allows:

| What the key allows | e.g. | Score |
|---------------------|------|-------|
| Absence and every value, or the key is missing | `?K` | 0 |
| Absence and some values, not every value | `K?=v`, `K=v\|!` | 1 |
| Every value | `K` | 2 |
| Two or more values, not every value | `K!=v`, `K=a\|b` | 3 |
| Exactly one value | `K=v` | 4 |
| Only absence | `!K` | 5 |

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 1 | InvalidFormat | Empty or malformed URN |
| 2 | EmptyTag | Empty key or value component |
| 3 | InvalidCharacter | Disallowed character in prefix, key or value |
| 4 | InvalidTagFormat | A tag given no constraint, or one no text writes |
| 5 | MissingPrefix | URN does not start with prefix |
| 6 | DuplicateKey | Same key appears twice |
| 8 | UnterminatedQuote | Quoted value never closed |
| 9 | InvalidEscapeSequence | Invalid escape in quoted value |
| 10 | EmptyPrefix | Prefix is empty |
| 11 | PrefixMismatch | Prefixes don't match in comparison |
| 12 | WhitespaceInInput | Input has leading or trailing whitespace |
| 13 | DuplicateValue | A value given twice in one tag's set of values |

## Testing

```bash
swift test
```

## Cross-Language Compatibility

This Objective-C implementation produces identical results to:
- [Rust implementation](https://github.com/machinefabric/tagged-urn-rs)
- [Go implementation](https://github.com/machinefabric/tagged-urn-go)
- [JavaScript implementation](https://github.com/machinefabric/tagged-urn-js)

All implementations pass the same test cases and follow identical rules. See [Tagged URN RULES.md](https://github.com/machinefabric/tagged-urn-rs/blob/main/docs/RULES.md) for the complete specification.
