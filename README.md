# Tagged URN - Objective-C Implementation

Objective-C implementation of Tagged URN with strict validation, pattern matching, and Swift compatibility.

## Features

- **Strict Rule Enforcement** - Follows exact same rules as Rust, Go, and JavaScript implementations
- **Case Insensitive** - All input normalized to lowercase (except quoted values)
- **Tag Order Independent** - Canonical alphabetical sorting
- **Special Pattern Values** - `*` (must-have-any), `?` (unspecified), `!` (must-not-have)
- **Value-less Tags** - Tags without values (`tag`) mean must-have-any (`tag=*`)
- **Graded Specificity** - Exact values score higher than wildcards
- **Swift Compatible** - Full Swift interoperability via Objective-C bridge
- **NSSecureCoding** - Secure serialization support

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/filegrind/tagged-urn-objc.git", from: "1.0.0")
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
CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
if (urn) {
    NSLog(@"Operation: %@", [urn getTag:@"op"]);  // "generate"
    NSLog(@"Canonical: %@", [urn toString]);       // "cap:ext=pdf;op=generate"
}

// Build a URN
CSTaggedUrn *built = [[[CSTaggedUrnBuilder builderWithPrefix:@"cap"]
    tag:@"op" value:@"extract"]
    tag:@"format" value:@"pdf"]
    build:&error];

// Check matching
CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
if ([urn conformsTo:pattern error:&error]) {
    NSLog(@"URN conforms to pattern");
}
```

### Swift

```swift
import TaggedUrn

// Parse a URN
do {
    let urn = try CSTaggedUrn.fromString("cap:op=generate;ext=pdf")
    print("Operation: \(urn.getTag("op") ?? "nil")")  // "generate"
    print("Canonical: \(urn.toString())")              // "cap:ext=pdf;op=generate"
} catch {
    print("Parse error: \(error)")
}

// Build a URN
let built = try CSTaggedUrnBuilder.builder(withPrefix: "cap")
    .tag("op", value: "extract")
    .tag("format", value: "pdf")
    .build()

// Check matching
let pattern = try CSTaggedUrn.fromString("cap:op=generate")
if try urn.conforms(to: pattern) {
    print("URN conforms to pattern")
}
```

## API Reference

### CSTaggedUrn

| Method | Description |
|--------|-------------|
| `+fromString:error:` | Parse URN from string |
| `+fromPrefix:tags:error:` | Create from prefix and tag dictionary |
| `+emptyWithPrefix:` | Create empty URN with prefix |
| `-getTag:` | Get value for a tag key |
| `-hasTag:withValue:` | Check if tag exists with value |
| `-withTag:value:` | Return new URN with tag added/updated |
| `-withoutTag:` | Return new URN with tag removed |
| `-conformsTo:error:` | Check if URN conforms to a pattern |
| `-accepts:error:` | Check if URN (as pattern) accepts an instance |
| `-specificity` | Get graded specificity score |
| `-isMoreSpecificThan:error:` | Compare specificity with another URN |
| `-toString` | Get canonical string representation |

### CSTaggedUrnBuilder

| Method | Description |
|--------|-------------|
| `+builderWithPrefix:` | Create builder with prefix |
| `-tag:value:` | Add or update a tag (chainable) |
| `-build:` | Build the URN (returns nil on error) |
| `-buildAllowEmpty` | Build URN allowing empty tags |

## Matching Semantics

| Pattern | Instance Missing | Instance=v | Instance=x (x≠v) |
|---------|------------------|------------|------------------|
| (missing) or `?` | Match | Match | Match |
| `K=!` | Match | No Match | No Match |
| `K=*` | No Match | Match | Match |
| `K=v` | No Match | Match | No Match |

## Graded Specificity

| Value Type | Score |
|------------|-------|
| Exact value (`K=v`) | 3 |
| Must-have-any (`K=*`) | 2 |
| Must-not-have (`K=!`) | 1 |
| Unspecified (`K=?`) or missing | 0 |

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 1 | InvalidFormat | Empty or malformed URN |
| 2 | EmptyTag | Empty key or value component |
| 3 | InvalidCharacter | Disallowed character in key/value |
| 4 | InvalidTagFormat | Tag not in key=value format |
| 5 | MissingPrefix | URN does not start with prefix |
| 6 | DuplicateKey | Same key appears twice |
| 7 | NumericKey | Key is purely numeric |
| 8 | UnterminatedQuote | Quoted value never closed |
| 9 | InvalidEscapeSequence | Invalid escape in quoted value |
| 10 | EmptyPrefix | Prefix is empty |
| 11 | PrefixMismatch | Prefixes don't match in comparison |

## Testing

```bash
swift test
```

## Cross-Language Compatibility

This Objective-C implementation produces identical results to:
- [Rust implementation](https://github.com/filegrind/tagged-urn-rs)
- [Go implementation](https://github.com/filegrind/tagged-urn-go)
- [JavaScript implementation](https://github.com/filegrind/tagged-urn-js)

All implementations pass the same test cases and follow identical rules. See [Tagged URN RULES.md](https://github.com/filegrind/tagged-urn-rs/blob/main/docs/RULES.md) for the complete specification.
