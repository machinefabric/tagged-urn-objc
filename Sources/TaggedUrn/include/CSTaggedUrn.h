//
//  CSTaggedUrn.h
//  Flat Tag-Based URN Identifier System
//
//  This provides a flat, tag-based tagged URN system with configurable prefix,
//  pattern matching, and graded specificity comparison.
//
//  Special pattern values:
//    K=v  - Must have key K with exact value v
//    K=*  - Must have key K with any value (presence required)
//    K=!  - Must NOT have key K (absence required)
//    K=?  - No constraint on key K (explicit don't-care)
//    (missing) - Same as K=? - no constraint
//
//  Value-less tags (e.g., "flag") are parsed as "flag=*" (must-have-any).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CSTaggedUrnCoordinateDelta;

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

/// The tags that define this URN
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *tags;

/// This URN on the proved model's side: a value on lungo's runtime (its C API's
/// `lungo_value`), owned by this URN and alive as long as it is. A program generated
/// from a model that builds on tagged-urn's takes it wherever the model has a URN;
/// clone it (`lungo_value_clone`) to hand one over.
@property (nonatomic, readonly) const struct lungo_value *formalValue NS_RETURNS_INNER_POINTER;

/**
 * Create a tagged URN from a string
 * @param string The tagged URN string (e.g., "cap:generate")
 * @param error Error if the string format is invalid
 * @return A new CSTaggedUrn instance or nil if invalid
 */
+ (nullable instancetype)fromString:(NSString * _Nonnull)string error:(NSError * _Nullable * _Nullable)error;

/**
 * Create a tagged URN from tags with a specified prefix (required)
 * @param prefix The prefix for this URN (e.g., "cap", "myapp")
 * @param tags Dictionary of tag key-value pairs
 * @param error Error if tags are invalid
 * @return A new CSTaggedUrn instance or nil if invalid
 */
+ (nullable instancetype)fromPrefix:(NSString * _Nonnull)prefix tags:(NSDictionary<NSString *, NSString *> * _Nonnull)tags error:(NSError * _Nullable * _Nullable)error;

/**
 * Create an empty tagged URN with the specified prefix (required)
 * @param prefix The prefix for this URN
 * @return A new CSTaggedUrn instance
 */
+ (instancetype)emptyWithPrefix:(NSString * _Nonnull)prefix;

/**
 * Get the value of a specific tag
 * @param key The tag key
 * @return The tag value or nil if not found
 */
- (nullable NSString *)getTag:(NSString * _Nonnull)key;

/**
 * Check if this URN has a specific tag with a specific value
 * @param key The tag key
 * @param value The tag value to check
 * @return YES if the tag exists with the specified value
 */
- (BOOL)hasTag:(NSString * _Nonnull)key withValue:(NSString * _Nonnull)value;

/**
 * Check whether a marker tag (a tag whose value is "*") is present at the
 * given key. Equivalent to `[self hasTag:tagName withValue:@"*"]` but
 * expresses authorial intent: this tag is present as a marker (a
 * wildcard-valued tag that serializes as just the key), not as a key=value
 * pair. Example: `cap:constrained;...` has marker tag "constrained".
 * @param tagName The marker key
 * @return YES if the tag exists with value "*"
 */
- (BOOL)hasMarkerTag:(NSString * _Nonnull)tagName;

/**
 * Create a new tagged URN with an added or updated tag
 * @param key The tag key
 * @param value The tag value
 * @return A new CSTaggedUrn instance with the tag added/updated
 */
- (CSTaggedUrn * _Nonnull)withTag:(NSString * _Nonnull)key value:(NSString * _Nonnull)value;

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
 * search asks: `media:ext` (some ext) does not conform to `media:ext=pdf`, and is
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
 * Get the specificity score for URN matching.
 * Sum of per-tag truth-table scores. Per-tag ladder:
 *
 *     "?"            -> 0   (no constraint)
 *     starts "?="    -> 1   (absent or not v)
 *     "*"            -> 2   (must-have-any)
 *     starts "!="    -> 3   (present and not v)
 *     exact value    -> 4   (exact match)
 *     "!"            -> 5   (must-not-have)
 *
 * @return The specificity score
 */
- (NSUInteger)specificity;

/**
 * Per-tag truth-table specificity score, applied uniformly to any
 * stored tag value. Free function so callers in cap_urn / media_urn
 * can score values without a TaggedUrn instance.
 */
FOUNDATION_EXPORT NSUInteger CSTaggedUrnScoreTagValue(NSString *value);

/**
 * Get specificity as a tuple for tie-breaking, ordered from highest
 * score to lowest.
 *
 * @param mustNotHave        Pointer to store !x count (score 5)
 * @param exact              Pointer to store exact-value count (score 4)
 * @param presentNotValue    Pointer to store x!=v count (score 3)
 * @param mustHaveAny        Pointer to store x=* count (score 2)
 * @param absentOrNotValue   Pointer to store x?=v count (score 1)
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
 * Create a new URN with a specific tag set to wildcard
 * @param key The tag key to set to wildcard
 * @return A new CSTaggedUrn instance with the tag set to wildcard
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
 * Check if a value needs quoting for serialization
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
 * Per-key truth-table cell evaluation for the six canonical
 * constraint forms (plus implicit Missing). Both arguments are stored
 * tag values (or nil to mean "key absent"). Returns YES iff the
 * instance value satisfies the pattern's constraint at this key.
 *
 * Exposed for callers (e.g. CSCapUrn's y-axis matcher) that walk
 * tag sets themselves and need the same per-cell decision the
 * tagged-URN matcher uses internally.
 */
+ (BOOL)valuesMatchInst:(NSString * _Nullable)inst patt:(NSString * _Nullable)patt;

@end

typedef NS_ENUM(NSInteger, CSTaggedUrnRelationKind) {
    CSTaggedUrnRelationKindEquivalent,
    CSTaggedUrnRelationKindComparable,
    CSTaggedUrnRelationKindIncomparable,
};

@interface CSTaggedUrnCoordinateDelta : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, readonly) NSString *prefix;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *removed;
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *added;
@property (nonatomic, readonly) CSTaggedUrnRelationKind relationKind;

- (instancetype)initWithPrefix:(NSString * _Nonnull)prefix
                       removed:(NSDictionary<NSString *, NSString *> * _Nonnull)removed
                         added:(NSDictionary<NSString *, NSString *> * _Nonnull)added
                  relationKind:(CSTaggedUrnRelationKind)relationKind;

- (BOOL)isEmpty;

@end

/// Error domain for tagged URN errors
FOUNDATION_EXPORT NSErrorDomain const CSTaggedUrnErrorDomain;

/// Error codes for tagged URN operations
typedef NS_ERROR_ENUM(CSTaggedUrnErrorDomain, CSTaggedUrnError) {
    CSTaggedUrnErrorInvalidFormat = 1,
    CSTaggedUrnErrorEmptyTag = 2,
    CSTaggedUrnErrorInvalidCharacter = 3,
    CSTaggedUrnErrorInvalidTagFormat = 4,
    CSTaggedUrnErrorMissingPrefix = 5,
    CSTaggedUrnErrorDuplicateKey = 6,
    CSTaggedUrnErrorNumericKey = 7,
    CSTaggedUrnErrorUnterminatedQuote = 8,
    CSTaggedUrnErrorInvalidEscapeSequence = 9,
    CSTaggedUrnErrorEmptyPrefix = 10,
    CSTaggedUrnErrorPrefixMismatch = 11,
    CSTaggedUrnErrorWhitespaceInInput = 12
};

/**
 * Builder for creating tagged URNs fluently
 */
@interface CSTaggedUrnBuilder : NSObject

/**
 * Create a new builder with a specified prefix (required)
 * @param prefix The prefix for the URN
 * @return A new CSTaggedUrnBuilder instance
 */
+ (instancetype)builderWithPrefix:(NSString * _Nonnull)prefix;

/**
 * Add or update a tag
 * @param key The tag key
 * @param value The tag value
 * @return This builder instance for chaining
 */
- (CSTaggedUrnBuilder * _Nonnull)tag:(NSString * _Nonnull)key value:(NSString * _Nonnull)value;

/**
 * Add a marker tag (a wildcard-valued tag that serializes as just the key).
 * Equivalent to [self tag:key value:@"*"] but expresses authorial intent:
 * this tag is present as a marker, not a key=value pair.
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
 * @return A new CSTaggedUrn instance
 */
- (CSTaggedUrn * _Nonnull)buildAllowEmpty;

@end

NS_ASSUME_NONNULL_END
