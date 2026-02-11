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

/**
 * A tagged URN using flat, ordered tags with a configurable prefix
 *
 * Examples:
 *   cap:op=generate;ext=pdf;output=binary;target=thumbnail
 *   cap:format=*;debug=!  (format required, debug forbidden)
 *   myapp:key="Value With Spaces"
 */
@interface CSTaggedUrn : NSObject <NSCopying, NSSecureCoding>

/// The prefix for this URN (e.g., "cap", "myapp", "custom")
@property (nonatomic, readonly) NSString *prefix;

/// The tags that define this URN
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *tags;

/**
 * Create a tagged URN from a string
 * @param string The tagged URN string (e.g., "cap:op=generate")
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
 * Get the specificity score for URN matching
 * Graded scoring:
 * - K=v (exact value): 3 points (most specific)
 * - K=* (must-have-any): 2 points
 * - K=! (must-not-have): 1 point
 * - K=? (unspecified): 0 points (least specific)
 * @return The specificity score
 */
- (NSUInteger)specificity;

/**
 * Get specificity as a tuple for tie-breaking
 * @param exact Pointer to store exact value count
 * @param mustHaveAny Pointer to store must-have-any count
 * @param mustNot Pointer to store must-not count
 */
- (void)specificityTupleExact:(NSUInteger *)exact mustHaveAny:(NSUInteger *)mustHaveAny mustNot:(NSUInteger *)mustNot;

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
