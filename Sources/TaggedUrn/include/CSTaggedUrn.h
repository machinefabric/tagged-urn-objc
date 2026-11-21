//
//  CSTaggedUrn.h
//  Flat Tag-Based URN Identifier System
//
//  This provides a flat, tag-based tagged URN system with configurable prefix,
//  pattern matching, and graded specificity comparison.
//
//  Each tag is stored as the constraint it writes (CSTagConstraint), one of the
//  proved model's forms:
//    K=v   - exact: must have key K with exact value v
//    K     - present: must have key K with any value (K=* is the same)
//    !K    - absent: must NOT have key K
//    ?K    - unconstrained: no constraint on key K
//    K?=v  - optionalNot: absent, or present and not v
//    K!=v  - presentNot: present and not v
//    (missing) - no constraint; never stored
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CSTaggedUrnCoordinateDelta;

/// The model's forms, numbered as the model numbers its constructors.
typedef NS_ENUM(NSInteger, CSTagConstraintKind) {
    CSTagConstraintKindMissing = 0,
    CSTagConstraintKindUnconstrained = 1,
    CSTagConstraintKindOptionalNot = 2,
    CSTagConstraintKindPresent = 3,
    CSTagConstraintKindPresentNot = 4,
    CSTagConstraintKindExact = 5,
    CSTagConstraintKindAbsent = 6,
};

/**
 * What a tag writes about its key: one of the proved model's seven forms, and
 * the value for the three that carry one. Immutable. Missing stands for a key a
 * URN omits and is never stored.
 */
@interface CSTagConstraint : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, readonly) CSTagConstraintKind kind;
/// The value of an exact, optionalNot or presentNot constraint; nil for the others.
@property (nonatomic, readonly, nullable) NSString *value;

+ (instancetype)missing;
+ (instancetype)unconstrained;
+ (instancetype)present;
+ (instancetype)absent;
+ (instancetype)exact:(NSString *)value;
+ (instancetype)optionalNot:(NSString *)value;
+ (instancetype)presentNot:(NSString *)value;

- (instancetype)init NS_UNAVAILABLE;

@end

/**
 * A tagged URN using flat, ordered tags with a configurable prefix
 *
 * Examples:
 *   cap:generate;ext=pdf;output=binary;target=thumbnail
 *   cap:format=*;debug=!  (format required, debug forbidden)
 *   myapp:key="Value With Spaces"
 */
@interface CSTaggedUrn : NSObject <NSCopying, NSSecureCoding>

/// The prefix for this URN (e.g., "cap", "myapp", "custom")
@property (nonatomic, readonly) NSString *prefix;

/// The tags that define this URN, each as the constraint it writes
@property (nonatomic, readonly) NSDictionary<NSString *, CSTagConstraint *> *tags;

/// This URN on the proved model's side: a value on lungo's runtime (its C API's
/// `lungo_value`), owned by this URN and alive as long as it is. A program generated
/// from a model that builds on tagged-urn's takes it wherever the model has a URN;
/// clone it (`lungo_value_clone`) to hand one over.
@property (nonatomic, readonly) const struct lungo_value *formalValue NS_RETURNS_INNER_POINTER;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Create a tagged URN from a string
 * @param string The tagged URN string (e.g., "cap:generate")
 * @param error Error if the string format is invalid
 * @return A new CSTaggedUrn instance or nil if invalid
 */
+ (nullable instancetype)fromString:(NSString * _Nonnull)string error:(NSError * _Nullable * _Nullable)error;

/**
 * Create a tagged URN from a prefix and its tags. The prefix and every key must be
 * identifiers (an ASCII letter, then ASCII letters, digits and `-`) and are lowered;
 * every constraint must be one a URN can write (not missing, no empty value).
 * @param prefix The prefix for this URN (e.g., "cap", "myapp")
 * @param tags Each key's constraint
 * @param error Error naming the prefix, key or constraint refused
 * @return A new CSTaggedUrn instance or nil if invalid
 */
+ (nullable instancetype)fromPrefix:(NSString * _Nonnull)prefix tags:(NSDictionary<NSString *, CSTagConstraint *> * _Nonnull)tags error:(NSError * _Nullable * _Nullable)error;

/**
 * Create an empty tagged URN with the specified prefix (required), which must be an identifier
 * @param prefix The prefix for this URN
 * @param error Error if the prefix is not an identifier
 * @return A new CSTaggedUrn instance or nil if invalid
 */
+ (nullable instancetype)emptyWithPrefix:(NSString * _Nonnull)prefix error:(NSError * _Nullable * _Nullable)error;

/**
 * The constraint the URN writes for a key, or nil when it does not mention it.
 * Key is normalized to lowercase for lookup.
 */
- (nullable CSTagConstraint *)getTag:(NSString * _Nonnull)key;

/**
 * The constraint the URN writes for a key, missing when it does not mention it:
 * the model's form of the key.
 */
- (CSTagConstraint *)constraintForKey:(NSString * _Nonnull)key;

/**
 * Whether this URN writes the exact value `value` for `key` (`key=value`).
 * Key is normalized to lowercase; value comparison is case-sensitive.
 */
- (BOOL)hasTag:(NSString * _Nonnull)key withValue:(NSString * _Nonnull)value;

/**
 * Whether `tagName` is present as a marker (present, written as just the key).
 * Example: `cap:constrained;...` has marker tag "constrained".
 */
- (BOOL)hasMarkerTag:(NSString * _Nonnull)tagName;

/**
 * A new tagged URN with an added or replaced tag. The key must be an identifier and is
 * lowered; the constraint must be one a URN can write.
 * @return The new URN, or nil with an error naming what was refused
 */
- (nullable CSTaggedUrn *)withTag:(NSString * _Nonnull)key
                       constraint:(CSTagConstraint * _Nonnull)constraint
                            error:(NSError * _Nullable * _Nullable)error;

/**
 * Create a new tagged URN with a tag removed
 * @param key The tag key to remove
 * @return A new CSTaggedUrn instance with the tag removed
 */
- (CSTaggedUrn * _Nonnull)withoutTag:(NSString * _Nonnull)key;

/**
 * Check if this URN (instance) satisfies the pattern's constraints.
 * Equivalent to [pattern accepts:self error:error].
 *
 * IMPORTANT: Both URNs must have the same prefix. Comparing URNs with
 * different prefixes is a programming error and will return NO with an error.
 *
 * @param pattern The pattern URN to match against
 * @param error Error if prefixes don't match
 * @return YES if this instance conforms to the pattern
 */
- (BOOL)conformsTo:(CSTaggedUrn * _Nonnull)pattern error:(NSError * _Nullable * _Nullable)error;

/**
 * Check if this URN (pattern) accepts the given instance.
 * Equivalent to [instance conformsTo:self error:error].
 *
 * @param instance The instance URN to test
 * @param error Error if prefixes don't match
 * @return YES if this pattern accepts the instance
 */
- (BOOL)accepts:(CSTaggedUrn * _Nonnull)instance error:(NSError * _Nullable * _Nullable)error;

/**
 * Whether this URN and `other` COULD be about the same thing: some thing is
 * described by both. Symmetric — neither is the instance.
 *
 * `conformsTo` is a guarantee: everything this URN describes, the pattern
 * describes. This is the other question the same meanings answer, and the one a
 * search asks: `media:ext` (some ext) does not conform to `media:document;ext=pdf`, and is
 * not excluded by it either — it meets it. Whatever conforms meets; what meets
 * need not conform, and meeting is not transitive. Decided by the proved model.
 *
 * @param other The URN to compare with
 * @param error Set when the prefixes differ or `other` is nil
 */
- (BOOL)meets:(CSTaggedUrn * _Nonnull)other error:(NSError * _Nullable * _Nullable)error;

/**
 * Whether this URN, read as a COMPLETE thing, satisfies `pattern`.
 *
 * A description that omits a key says nothing about it, which is how
 * `conformsTo` reads both sides. A thing that exists — a value with these tags,
 * a cap's own list of tags — omits a key because it does not have it. Read so, a
 * thing that does not mention `x` satisfies `!x`. Use this where the receiver is
 * what something IS; use `conformsTo` where it is what something is declared to
 * take or give. Decided by the proved model.
 *
 * @param pattern The pattern to satisfy
 * @param error Set when the prefixes differ or `pattern` is nil
 */
- (BOOL)satisfies:(CSTaggedUrn * _Nonnull)pattern error:(NSError * _Nullable * _Nullable)error;

/**
 * Whether this URN, read as a complete thing, COULD satisfy `pattern`:
 * `satisfies` is to this as `conformsTo` is to `meets`.
 *
 * @param pattern The pattern
 * @param error Set when the prefixes differ or `pattern` is nil
 */
- (BOOL)maySatisfy:(CSTaggedUrn * _Nonnull)pattern error:(NSError * _Nullable * _Nullable)error;

/**
 * The most specific URN every one of `urns` conforms to: their common denominator.
 *
 * Key by key, the bound allows every state some input allows. Where no single form
 * says exactly that, there is no least bound at all — `ext=png` and `ext=jpeg` are both
 * `ext`, both `ext!=pdf` and both `ext!=gif` — so the bound is the least among those
 * that exclude only values the inputs name: here `ext`. When one input holds all the
 * others, the bound is that input. The bound of no URNs is the URN with no tags.
 *
 * Made by the proved model (`TaggedUrn.Exec.leastUpperBound`), whose theorems say every
 * input conforms to the bound and the bound conforms to every such bound of them.
 *
 * @param prefix The prefix every URN must have
 * @param urns The URNs to bound
 * @param error Set when a URN has another prefix
 * @return The bound, or nil when a URN has another prefix
 */
+ (nullable instancetype)leastUpperBoundWithPrefix:(NSString * _Nonnull)prefix
                                              urns:(NSArray<CSTaggedUrn *> * _Nonnull)urns
                                             error:(NSError * _Nullable * _Nullable)error;

/**
 * Check if two URNs are equivalent (identical tag sets).
 *
 * From order theory: in the specialization partial order defined by
 * accepts/conformsTo, two elements are equivalent when each accepts
 * the other (antisymmetry: a ≤ b ∧ b ≤ a → a = b).
 *
 * This is stricter than isComparable — it requires the tag sets to
 * be identical, not just related by specialization.
 *
 * isEquivalent(other) ≡ accepts(other) && other.accepts(self)
 *
 * @param other The other URN to compare
 * @param error Error if prefixes don't match
 * @return YES if the URNs have identical tag sets
 */
- (BOOL)isEquivalentTo:(CSTaggedUrn * _Nonnull)other error:(NSError * _Nullable * _Nullable)error;

/**
 * Check if two URNs are comparable (one is a specialization of the other).
 *
 * From order theory: in a partial order, two elements are comparable
 * when one is ≤ the other. Elements that are NOT comparable are in
 * different branches of the specialization lattice.
 *
 * This is the weakest relation: it finds all URNs on the same
 * generalization/specialization chain.
 *
 * isComparable(other) ≡ accepts(other) || other.accepts(self)
 *
 * @param other The other URN to compare
 * @param error Error if prefixes don't match
 * @return YES if the URNs are on the same specialization chain
 */
- (BOOL)isComparableTo:(CSTaggedUrn * _Nonnull)other error:(NSError * _Nullable * _Nullable)error;

/**
 * Compute the directional coordinate delta from `base` to `self`.
 *
 * The two URNs must have the same prefix. The returned delta records:
 * - removed coordinates: exact key/value pairs present in `base` but not in `self`
 * - added coordinates: exact key/value pairs present in `self` but not in `base`
 * - relation kind: equivalent / comparable / incomparable under accepts
 *
 * @param base The base URN to subtract from this URN
 * @param error Error if prefixes do not match
 * @return A coordinate delta or nil on error
 */
- (nullable CSTaggedUrnCoordinateDelta *)deltaFrom:(CSTaggedUrn * _Nonnull)base error:(NSError * _Nullable * _Nullable)error;

/**
 * Apply a coordinate delta to this URN.
 *
 * Removed entries must match exactly when present. Added entries are then
 * written into the result. The delta prefix must match this URN's prefix.
 *
 * @param delta The coordinate delta to apply
 * @param error Error if prefixes do not match
 * @return A new tagged URN with the delta applied or nil on error
 */
- (nullable CSTaggedUrn *)applyDelta:(CSTaggedUrnCoordinateDelta * _Nonnull)delta error:(NSError * _Nullable * _Nullable)error;

/**
 * Get the specificity score for URN matching, as the model computes it.
 * Sum of per-tag truth-table scores. Per-tag ladder:
 *
 *     unconstrained  -> 0   (no constraint)
 *     optionalNot    -> 1   (absent or not v)
 *     present        -> 2   (must-have-any)
 *     presentNot     -> 3   (present and not v)
 *     exact          -> 4   (exact match)
 *     absent         -> 5   (must-not-have)
 *
 * @return The specificity score
 */
- (NSUInteger)specificity;

/**
 * How many tags fall into each non-zero form, from the highest score to the lowest.
 *
 * @param mustNotHave        Pointer to store the absent count (score 5)
 * @param exact              Pointer to store the exact count (score 4)
 * @param presentNotValue    Pointer to store the presentNot count (score 3)
 * @param mustHaveAny        Pointer to store the present count (score 2)
 * @param absentOrNotValue   Pointer to store the optionalNot count (score 1)
 */
- (void)specificityTupleMustNotHave:(NSUInteger *)mustNotHave
                              exact:(NSUInteger *)exact
                   presentNotValue:(NSUInteger *)presentNotValue
                       mustHaveAny:(NSUInteger *)mustHaveAny
                  absentOrNotValue:(NSUInteger *)absentOrNotValue;

/**
 * Check if this URN is more specific than another
 *
 * IMPORTANT: Both URNs must have the same prefix.
 *
 * @param other The other URN to compare specificity with
 * @param error Error if prefixes don't match
 * @return YES if this URN is more specific
 */
- (BOOL)isMoreSpecificThan:(CSTaggedUrn * _Nonnull)other error:(NSError * _Nullable * _Nullable)error;

/**
 * The order of URNs: by their parts, never their text. The prefix, then the
 * tags in key order, each by its key, then by its constraint's form in the
 * truth table's order (unconstrained, optionalNot, present, presentNot, exact,
 * absent), then by its value; a URN whose tags are the beginning of another's
 * stands first. Keys and values are ordered by code point. The text would
 * order `file;sample` after `file-path`, wherever one key is the beginning of
 * another.
 */
- (NSComparisonResult)compare:(CSTaggedUrn * _Nonnull)other;

/**
 * The same URN with `key`, where it has it, made a marker (present)
 * @param key The tag key
 * @return A new CSTaggedUrn instance
 */
- (CSTaggedUrn * _Nonnull)withWildcardTag:(NSString * _Nonnull)key;

/**
 * Create a new URN with only specified tags
 * @param keys Array of tag keys to include
 * @return A new CSTaggedUrn instance with only the specified tags
 */
- (CSTaggedUrn * _Nonnull)subset:(NSArray<NSString *> * _Nonnull)keys;

/**
 * Merge with another URN (other takes precedence for conflicts)
 *
 * IMPORTANT: Both URNs must have the same prefix.
 *
 * @param other The URN to merge with
 * @param error Error if prefixes don't match
 * @return A new CSTaggedUrn instance with merged tags or nil if error
 */
- (nullable CSTaggedUrn *)merge:(CSTaggedUrn * _Nonnull)other error:(NSError * _Nullable * _Nullable)error;

/**
 * Get the canonical string representation of this URN
 * @return The tagged URN as a string
 */
- (NSString *)toString;

#pragma mark - Utility Methods

/**
 * Whether a value must be quoted to read back as itself: it holds a character a bare
 * value cannot (`;`, `=`, `"`, `\`, whitespace), an uppercase letter (a bare value is
 * lowered), or begins with `*`, `?` or `!` (which a bare value reads as a sigil or a
 * qualifier).
 * @param value The value to check
 * @return YES if the value needs quoting
 */
+ (BOOL)needsQuoting:(NSString *)value;

/**
 * Quote a value for serialization
 * @param value The value to quote
 * @return The quoted value with proper escaping
 */
+ (NSString *)quoteValue:(NSString *)value;

/**
 * A value as a tag writes it: bare, or quoted when it must be to read back as itself.
 * @param value The value to write
 * @return The value as written
 */
+ (NSString *)writeValue:(NSString *)value;

/**
 * Per-key truth-table cell, as the model decides it: whether the instance's
 * constraint satisfies the pattern's at one key (missing for a key a URN omits,
 * as `constraintForKey:` gives it).
 *
 * Exposed for callers (e.g. CSCapUrn's y-axis matcher) that walk
 * tag sets themselves and need the same per-cell decision the
 * tagged-URN matcher uses internally.
 */
+ (BOOL)valuesMatchInst:(CSTagConstraint * _Nonnull)inst patt:(CSTagConstraint * _Nonnull)patt;

@end

typedef NS_ENUM(NSInteger, CSTaggedUrnRelationKind) {
    CSTaggedUrnRelationKindEquivalent,
    CSTaggedUrnRelationKindComparable,
    CSTaggedUrnRelationKindIncomparable,
};

@interface CSTaggedUrnCoordinateDelta : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, readonly) NSString *prefix;
@property (nonatomic, readonly) NSDictionary<NSString *, CSTagConstraint *> *removed;
@property (nonatomic, readonly) NSDictionary<NSString *, CSTagConstraint *> *added;
@property (nonatomic, readonly) CSTaggedUrnRelationKind relationKind;

- (instancetype)initWithPrefix:(NSString * _Nonnull)prefix
                       removed:(NSDictionary<NSString *, CSTagConstraint *> * _Nonnull)removed
                         added:(NSDictionary<NSString *, CSTagConstraint *> * _Nonnull)added
                  relationKind:(CSTaggedUrnRelationKind)relationKind;

- (BOOL)isEmpty;

@end

/// Error domain for tagged URN errors
FOUNDATION_EXPORT NSErrorDomain const CSTaggedUrnErrorDomain;

/// Error codes for tagged URN operations. Code 7 is not used.
typedef NS_ERROR_ENUM(CSTaggedUrnErrorDomain, CSTaggedUrnError) {
    CSTaggedUrnErrorInvalidFormat = 1,
    CSTaggedUrnErrorEmptyTag = 2,
    CSTaggedUrnErrorInvalidCharacter = 3,
    CSTaggedUrnErrorInvalidTagFormat = 4,
    CSTaggedUrnErrorMissingPrefix = 5,
    CSTaggedUrnErrorDuplicateKey = 6,
    CSTaggedUrnErrorUnterminatedQuote = 8,
    CSTaggedUrnErrorInvalidEscapeSequence = 9,
    CSTaggedUrnErrorEmptyPrefix = 10,
    CSTaggedUrnErrorPrefixMismatch = 11,
    CSTaggedUrnErrorWhitespaceInInput = 12
};

/**
 * Builder for creating tagged URNs fluently. The first error (a prefix or key that is
 * no identifier, a constraint a URN cannot write, a key given twice) is kept and
 * returned by build.
 */
@interface CSTaggedUrnBuilder : NSObject

/**
 * Create a new builder with a specified prefix (required), which must be an identifier
 * @param prefix The prefix for the URN
 * @return A new CSTaggedUrnBuilder instance
 */
+ (instancetype)builderWithPrefix:(NSString * _Nonnull)prefix;

/**
 * Add a tag of any form
 * @param key The tag key
 * @param constraint The tag's constraint
 * @return This builder instance for chaining
 */
- (CSTaggedUrnBuilder * _Nonnull)tag:(NSString * _Nonnull)key constraint:(CSTagConstraint * _Nonnull)constraint;

/**
 * Add the exact value `value` for `key` (`key=value`), taken literally:
 * `[builder tag:@"x" value:@"*"]` is the exact value `*`, not the marker.
 * @param key The tag key
 * @param value The exact value
 * @return This builder instance for chaining
 */
- (CSTaggedUrnBuilder * _Nonnull)tag:(NSString * _Nonnull)key value:(NSString * _Nonnull)value;

/**
 * Add `key` as a marker (present, written as just the key).
 * @param key The marker key
 * @return This builder instance for chaining
 */
- (CSTaggedUrnBuilder * _Nonnull)marker:(NSString * _Nonnull)key;

/**
 * Build the final TaggedUrn
 * @param error Error if build fails
 * @return A new CSTaggedUrn instance or nil if error
 */
- (nullable CSTaggedUrn *)build:(NSError * _Nullable * _Nullable)error;

/**
 * Build the final TaggedUrn, allowing empty tags
 * @param error Error if a tag was refused
 * @return A new CSTaggedUrn instance or nil if error
 */
- (nullable CSTaggedUrn *)buildAllowEmpty:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
