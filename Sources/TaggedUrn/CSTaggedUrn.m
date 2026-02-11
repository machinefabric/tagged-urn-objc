//
//  CSTaggedUrn.m
//  Flat Tag-Based URN Identifier Implementation
//

#import "CSTaggedUrn.h"

NSErrorDomain const CSTaggedUrnErrorDomain = @"CSTaggedUrnErrorDomain";

// Parser states for state machine
typedef NS_ENUM(NSInteger, CSParseState) {
    CSParseStateExpectingKey,
    CSParseStateInKey,
    CSParseStateExpectingValue,
    CSParseStateInUnquotedValue,
    CSParseStateInQuotedValue,
    CSParseStateInQuotedValueEscape,
    CSParseStateExpectingSemiOrEnd
};

@interface CSTaggedUrn ()
@property (nonatomic, strong) NSString *mutablePrefix;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mutableTags;
@end

@implementation CSTaggedUrn

- (NSString *)prefix {
    return self.mutablePrefix;
}

- (NSDictionary<NSString *, NSString *> *)tags {
    return [self.mutableTags copy];
}

#pragma mark - Helper Methods

+ (BOOL)isValidKeyChar:(unichar)c {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
           c == '_' || c == '-' || c == '/' || c == ':' || c == '.';
}

+ (BOOL)isValidUnquotedValueChar:(unichar)c {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
           c == '_' || c == '-' || c == '/' || c == ':' || c == '.' || c == '*' || c == '?' || c == '!';
}

+ (BOOL)isPurelyNumeric:(NSString *)s {
    if (s.length == 0) return NO;
    NSCharacterSet *numericSet = [NSCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *nonNumericSet = [numericSet invertedSet];
    return [s rangeOfCharacterFromSet:nonNumericSet].location == NSNotFound;
}

+ (BOOL)needsQuoting:(NSString *)value {
    for (NSUInteger i = 0; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];
        if (c == ';' || c == '=' || c == '"' || c == '\\' || c == ' ') {
            return YES;
        }
        // Check for uppercase letter
        if (c >= 'A' && c <= 'Z') {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)quoteValue:(NSString *)value {
    NSMutableString *result = [NSMutableString stringWithString:@"\""];
    for (NSUInteger i = 0; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];
        if (c == '"' || c == '\\') {
            [result appendString:@"\\"];
        }
        [result appendFormat:@"%C", c];
    }
    [result appendString:@"\""];
    return result;
}

#pragma mark - Parsing

+ (nullable instancetype)fromString:(NSString *)string error:(NSError **)error {
    if (!string || string.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"URN identifier cannot be empty"}];
        }
        return nil;
    }

    // Fail hard on leading/trailing whitespace
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![string isEqualToString:trimmed]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorWhitespaceInInput
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"URN has leading or trailing whitespace: '%@'", string]}];
        }
        return nil;
    }

    // Find the prefix (everything before the first colon)
    NSRange colonRange = [string rangeOfString:@":"];
    if (colonRange.location == NSNotFound) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorMissingPrefix
                                     userInfo:@{NSLocalizedDescriptionKey: @"URN must have a prefix followed by ':'"}];
        }
        return nil;
    }

    if (colonRange.location == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorEmptyPrefix
                                     userInfo:@{NSLocalizedDescriptionKey: @"URN prefix cannot be empty"}];
        }
        return nil;
    }

    NSString *prefix = [[string substringToIndex:colonRange.location] lowercaseString];
    NSString *tagsPart = [string substringFromIndex:colonRange.location + 1];
    NSMutableDictionary<NSString *, NSString *> *tags = [NSMutableDictionary dictionary];

    // Handle empty tagged URN (prefix: with no tags or just semicolon)
    if (tagsPart.length == 0 || [tagsPart isEqualToString:@";"]) {
        return [self fromPrefix:prefix tagsInternal:tags error:error];
    }

    CSParseState state = CSParseStateExpectingKey;
    NSMutableString *currentKey = [NSMutableString string];
    NSMutableString *currentValue = [NSMutableString string];
    NSUInteger pos = 0;

    while (pos < tagsPart.length) {
        unichar c = [tagsPart characterAtIndex:pos];

        switch (state) {
            case CSParseStateExpectingKey:
                if (c == ';') {
                    // Empty segment, skip
                    pos++;
                    continue;
                } else if ([self isValidKeyChar:c]) {
                    [currentKey appendFormat:@"%c", tolower(c)];
                    state = CSParseStateInKey;
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidCharacter
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"invalid character '%C' at position %lu", c, (unsigned long)pos]}];
                    }
                    return nil;
                }
                break;

            case CSParseStateInKey:
                if (c == '=') {
                    if (currentKey.length == 0) {
                        if (error) {
                            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                         code:CSTaggedUrnErrorEmptyTag
                                                     userInfo:@{NSLocalizedDescriptionKey: @"empty key"}];
                        }
                        return nil;
                    }
                    state = CSParseStateExpectingValue;
                } else if (c == ';') {
                    // Value-less tag: treat as wildcard
                    if (currentKey.length == 0) {
                        if (error) {
                            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                         code:CSTaggedUrnErrorEmptyTag
                                                     userInfo:@{NSLocalizedDescriptionKey: @"empty key"}];
                        }
                        return nil;
                    }
                    [currentValue setString:@"*"];
                    if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    [currentKey setString:@""];
                    [currentValue setString:@""];
                    state = CSParseStateExpectingKey;
                } else if ([self isValidKeyChar:c]) {
                    [currentKey appendFormat:@"%c", tolower(c)];
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidCharacter
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"invalid character '%C' in key at position %lu", c, (unsigned long)pos]}];
                    }
                    return nil;
                }
                break;

            case CSParseStateExpectingValue:
                if (c == '"') {
                    state = CSParseStateInQuotedValue;
                } else if (c == ';') {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorEmptyTag
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"empty value for key '%@'", currentKey]}];
                    }
                    return nil;
                } else if ([self isValidUnquotedValueChar:c]) {
                    [currentValue appendFormat:@"%c", tolower(c)];
                    state = CSParseStateInUnquotedValue;
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidCharacter
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"invalid character '%C' in value at position %lu", c, (unsigned long)pos]}];
                    }
                    return nil;
                }
                break;

            case CSParseStateInUnquotedValue:
                if (c == ';') {
                    if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    [currentKey setString:@""];
                    [currentValue setString:@""];
                    state = CSParseStateExpectingKey;
                } else if ([self isValidUnquotedValueChar:c]) {
                    [currentValue appendFormat:@"%c", tolower(c)];
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidCharacter
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"invalid character '%C' in unquoted value at position %lu", c, (unsigned long)pos]}];
                    }
                    return nil;
                }
                break;

            case CSParseStateInQuotedValue:
                if (c == '"') {
                    state = CSParseStateExpectingSemiOrEnd;
                } else if (c == '\\') {
                    state = CSParseStateInQuotedValueEscape;
                } else {
                    // Any character allowed in quoted value, preserve case
                    [currentValue appendFormat:@"%C", c];
                }
                break;

            case CSParseStateInQuotedValueEscape:
                if (c == '"' || c == '\\') {
                    [currentValue appendFormat:@"%C", c];
                    state = CSParseStateInQuotedValue;
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidEscapeSequence
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"invalid escape sequence at position %lu (only \\\" and \\\\ allowed)", (unsigned long)pos]}];
                    }
                    return nil;
                }
                break;

            case CSParseStateExpectingSemiOrEnd:
                if (c == ';') {
                    if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    [currentKey setString:@""];
                    [currentValue setString:@""];
                    state = CSParseStateExpectingKey;
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidCharacter
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"expected ';' or end after quoted value, got '%C' at position %lu", c, (unsigned long)pos]}];
                    }
                    return nil;
                }
                break;
        }

        pos++;
    }

    // Handle end of input
    switch (state) {
        case CSParseStateInUnquotedValue:
        case CSParseStateExpectingSemiOrEnd:
            if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                return nil;
            }
            break;
        case CSParseStateExpectingKey:
            // Valid - trailing semicolon or empty input after prefix
            break;
        case CSParseStateInQuotedValue:
        case CSParseStateInQuotedValueEscape:
            if (error) {
                *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                             code:CSTaggedUrnErrorUnterminatedQuote
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"unterminated quote at position %lu", (unsigned long)pos]}];
            }
            return nil;
        case CSParseStateInKey:
            // Value-less tag at end: treat as wildcard
            if (currentKey.length == 0) {
                if (error) {
                    *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                 code:CSTaggedUrnErrorEmptyTag
                                             userInfo:@{NSLocalizedDescriptionKey: @"empty key"}];
                }
                return nil;
            }
            [currentValue setString:@"*"];
            if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                return nil;
            }
            break;
        case CSParseStateExpectingValue:
            if (error) {
                *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                             code:CSTaggedUrnErrorEmptyTag
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"empty value for key '%@'", currentKey]}];
            }
            return nil;
    }

    return [self fromPrefix:prefix tagsInternal:tags error:error];
}

+ (BOOL)finishTag:(NSMutableDictionary *)tags key:(NSString *)key value:(NSString *)value error:(NSError **)error {
    if (key.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorEmptyTag
                                     userInfo:@{NSLocalizedDescriptionKey: @"empty key"}];
        }
        return NO;
    }
    if (value.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorEmptyTag
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"empty value for key '%@'", key]}];
        }
        return NO;
    }

    // Check for duplicate keys
    if (tags[key] != nil) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorDuplicateKey
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Duplicate tag key: %@", key]}];
        }
        return NO;
    }

    // Validate key cannot be purely numeric
    if ([self isPurelyNumeric:key]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorNumericKey
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Tag key cannot be purely numeric: %@", key]}];
        }
        return NO;
    }

    // Copy strings to prevent mutation after storage
    tags[[key copy]] = [value copy];
    return YES;
}

+ (nullable instancetype)fromPrefix:(NSString *)prefix tags:(NSDictionary<NSString *, NSString *> *)tags error:(NSError **)error {
    if (!tags) {
        tags = @{};
    }

    // Normalize keys to lowercase; values preserved as-is
    NSMutableDictionary<NSString *, NSString *> *normalizedTags = [NSMutableDictionary dictionary];
    for (NSString *key in tags) {
        NSString *value = tags[key];
        normalizedTags[[key lowercaseString]] = value;
    }

    return [self fromPrefix:prefix tagsInternal:normalizedTags error:error];
}

+ (nullable instancetype)fromPrefix:(NSString *)prefix tagsInternal:(NSDictionary<NSString *, NSString *> *)tags error:(NSError **)error {
    CSTaggedUrn *instance = [[CSTaggedUrn alloc] init];
    instance.mutablePrefix = [prefix lowercaseString];
    instance.mutableTags = [tags mutableCopy];
    return instance;
}

+ (instancetype)emptyWithPrefix:(NSString *)prefix {
    return [self fromPrefix:prefix tagsInternal:@{} error:nil];
}

- (instancetype)init {
    if (self = [super init]) {
        _mutablePrefix = @"";
        _mutableTags = [NSMutableDictionary dictionary];
    }
    return self;
}

- (nullable NSString *)getTag:(NSString *)key {
    return self.mutableTags[[key lowercaseString]];
}

- (BOOL)hasTag:(NSString *)key withValue:(NSString *)value {
    NSString *tagValue = self.mutableTags[[key lowercaseString]];
    // Case-sensitive value comparison
    return tagValue && [tagValue isEqualToString:value];
}

- (CSTaggedUrn *)withTag:(NSString *)key value:(NSString *)value {
    NSMutableDictionary *newTags = [self.mutableTags mutableCopy];
    // Key lowercase, value preserved
    newTags[[key lowercaseString]] = value;
    return [CSTaggedUrn fromPrefix:self.mutablePrefix tagsInternal:newTags error:nil];
}

- (CSTaggedUrn *)withoutTag:(NSString *)key {
    NSMutableDictionary *newTags = [self.mutableTags mutableCopy];
    [newTags removeObjectForKey:[key lowercaseString]];
    return [CSTaggedUrn fromPrefix:self.mutablePrefix tagsInternal:newTags error:nil];
}

/// Check if instance value matches pattern constraint
/// See Rust implementation for full truth table
+ (BOOL)valuesMatchInst:(NSString *)inst patt:(NSString *)patt {
    // Pattern has no constraint (no entry or explicit ?)
    if (patt == nil || [patt isEqualToString:@"?"]) {
        return YES;
    }

    // Instance doesn't care (explicit ?)
    if ([inst isEqualToString:@"?"]) {
        return YES;
    }

    // Pattern: must-not-have (!)
    if ([patt isEqualToString:@"!"]) {
        if (inst == nil) {
            return YES; // Instance absent, pattern wants absent
        }
        if ([inst isEqualToString:@"!"]) {
            return YES; // Both say absent
        }
        return NO; // Instance has value, pattern wants absent
    }

    // Instance: must-not-have conflicts with pattern wanting value
    if ([inst isEqualToString:@"!"]) {
        return NO; // Conflict: absent vs value or present
    }

    // Pattern: must-have-any (*)
    if ([patt isEqualToString:@"*"]) {
        if (inst == nil) {
            return NO; // Instance missing, pattern wants present
        }
        return YES; // Instance has value, pattern wants any
    }

    // Pattern: exact value
    if (inst == nil) {
        return NO; // Instance missing, pattern wants value
    }
    if ([inst isEqualToString:@"*"]) {
        return YES; // Instance accepts any, pattern's value is fine
    }
    return [inst isEqualToString:patt]; // Both have values, must match exactly
}

/// Check if this URN (instance) satisfies the pattern's constraints.
/// Equivalent to [pattern accepts:self error:error].
- (BOOL)conformsTo:(CSTaggedUrn *)pattern error:(NSError **)error {
    if (!pattern) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot match against nil pattern"}];
        }
        return NO;
    }
    return [CSTaggedUrn checkMatchInstanceTags:self.mutableTags
                                instancePrefix:self.mutablePrefix
                                   patternTags:pattern.mutableTags
                                 patternPrefix:pattern.mutablePrefix
                                         error:error];
}

/// Check if this URN (pattern) accepts the given instance.
/// Equivalent to [instance conformsTo:self error:error].
- (BOOL)accepts:(CSTaggedUrn *)instance error:(NSError **)error {
    if (!instance) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot match against nil instance"}];
        }
        return NO;
    }
    return [CSTaggedUrn checkMatchInstanceTags:instance.mutableTags
                                instancePrefix:instance.mutablePrefix
                                   patternTags:self.mutableTags
                                 patternPrefix:self.mutablePrefix
                                         error:error];
}

/// Core matching: does instance satisfy pattern's constraints?
+ (BOOL)checkMatchInstanceTags:(NSDictionary<NSString *, NSString *> *)instanceTags
                instancePrefix:(NSString *)instancePrefix
                   patternTags:(NSDictionary<NSString *, NSString *> *)patternTags
                 patternPrefix:(NSString *)patternPrefix
                         error:(NSError **)error {
    if (![instancePrefix isEqualToString:patternPrefix]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorPrefixMismatch
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot compare URNs with different prefixes: '%@' vs '%@'", instancePrefix, patternPrefix]}];
        }
        return NO;
    }

    NSMutableSet<NSString *> *allKeys = [NSMutableSet setWithArray:instanceTags.allKeys];
    [allKeys addObjectsFromArray:patternTags.allKeys];

    for (NSString *key in allKeys) {
        NSString *inst = instanceTags[key];
        NSString *patt = patternTags[key];

        if (![CSTaggedUrn valuesMatchInst:inst patt:patt]) {
            return NO;
        }
    }
    return YES;
}

/// Calculate specificity score for URN matching
/// Graded scoring:
/// - K=v (exact value): 3 points (most specific)
/// - K=* (must-have-any): 2 points
/// - K=! (must-not-have): 1 point
/// - K=? (unspecified): 0 points (least specific)
- (NSUInteger)specificity {
    NSUInteger score = 0;
    for (NSString *value in self.mutableTags.allValues) {
        if ([value isEqualToString:@"?"]) {
            score += 0;
        } else if ([value isEqualToString:@"!"]) {
            score += 1;
        } else if ([value isEqualToString:@"*"]) {
            score += 2;
        } else {
            score += 3; // exact value
        }
    }
    return score;
}

/// Get specificity as a tuple for tie-breaking
/// Returns (exact_count, must_have_any_count, must_not_count)
- (void)specificityTupleExact:(NSUInteger *)exact mustHaveAny:(NSUInteger *)mustHaveAny mustNot:(NSUInteger *)mustNot {
    *exact = 0;
    *mustHaveAny = 0;
    *mustNot = 0;
    for (NSString *value in self.mutableTags.allValues) {
        if ([value isEqualToString:@"?"]) {
            // 0 points, not counted
        } else if ([value isEqualToString:@"!"]) {
            (*mustNot)++;
        } else if ([value isEqualToString:@"*"]) {
            (*mustHaveAny)++;
        } else {
            (*exact)++;
        }
    }
}

- (BOOL)isMoreSpecificThan:(CSTaggedUrn *)other error:(NSError **)error {
    if (!other) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot compare against nil URN"}];
        }
        return NO;
    }

    // First check prefix
    if (![self.mutablePrefix isEqualToString:other.mutablePrefix]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorPrefixMismatch
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot compare URNs with different prefixes: '%@' vs '%@'", self.mutablePrefix, other.mutablePrefix]}];
        }
        return NO;
    }

    return self.specificity > other.specificity;
}

- (CSTaggedUrn *)withWildcardTag:(NSString *)key {
    if (self.mutableTags[[key lowercaseString]]) {
        return [self withTag:key value:@"*"];
    }
    return self;
}

- (CSTaggedUrn *)subset:(NSArray<NSString *> *)keys {
    NSMutableDictionary *newTags = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        NSString *normalizedKey = [key lowercaseString];
        NSString *value = self.mutableTags[normalizedKey];
        if (value) {
            newTags[normalizedKey] = value;
        }
    }
    return [CSTaggedUrn fromPrefix:self.mutablePrefix tagsInternal:newTags error:nil];
}

- (nullable CSTaggedUrn *)merge:(CSTaggedUrn *)other error:(NSError **)error {
    if (!other) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot merge with nil URN"}];
        }
        return nil;
    }

    if (![self.mutablePrefix isEqualToString:other.mutablePrefix]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorPrefixMismatch
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot merge URNs with different prefixes: '%@' vs '%@'", self.mutablePrefix, other.mutablePrefix]}];
        }
        return nil;
    }

    NSMutableDictionary *newTags = [self.mutableTags mutableCopy];
    for (NSString *key in other.mutableTags) {
        newTags[key] = other.mutableTags[key];
    }
    return [CSTaggedUrn fromPrefix:self.mutablePrefix tagsInternal:newTags error:nil];
}

- (NSString *)toString {
    if (self.mutableTags.count == 0) {
        return [NSString stringWithFormat:@"%@:", self.mutablePrefix];
    }

    // Sort keys for canonical representation
    NSArray<NSString *> *sortedKeys = [self.mutableTags.allKeys sortedArrayUsingSelector:@selector(compare:)];

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        NSString *value = self.mutableTags[key];
        if ([value isEqualToString:@"*"]) {
            // Valueless sugar: key
            [parts addObject:key];
        } else if ([value isEqualToString:@"?"]) {
            // Explicit: key=?
            [parts addObject:[NSString stringWithFormat:@"%@=?", key]];
        } else if ([value isEqualToString:@"!"]) {
            // Explicit: key=!
            [parts addObject:[NSString stringWithFormat:@"%@=!", key]];
        } else if ([CSTaggedUrn needsQuoting:value]) {
            [parts addObject:[NSString stringWithFormat:@"%@=%@", key, [CSTaggedUrn quoteValue:value]]];
        } else {
            [parts addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
        }
    }

    NSString *tagsString = [parts componentsJoinedByString:@";"];
    return [NSString stringWithFormat:@"%@:%@", self.mutablePrefix, tagsString];
}

- (NSString *)description {
    return [self toString];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CSTaggedUrn class]]) {
        return NO;
    }

    CSTaggedUrn *other = (CSTaggedUrn *)object;
    return [self.mutablePrefix isEqualToString:other.mutablePrefix] &&
           [self.mutableTags isEqualToDictionary:other.mutableTags];
}

- (NSUInteger)hash {
    return self.mutablePrefix.hash ^ self.mutableTags.hash;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return [CSTaggedUrn fromPrefix:self.mutablePrefix tagsInternal:self.tags error:nil];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.mutablePrefix forKey:@"prefix"];
    [coder encodeObject:self.mutableTags forKey:@"tags"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _mutablePrefix = [coder decodeObjectOfClass:[NSString class] forKey:@"prefix"];
        if (!_mutablePrefix) {
            _mutablePrefix = @"";
        }
        _mutableTags = [[coder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"tags"] mutableCopy];
        if (!_mutableTags) {
            _mutableTags = [NSMutableDictionary dictionary];
        }
    }
    return self;
}

@end

#pragma mark - CSTaggedUrnBuilder

@interface CSTaggedUrnBuilder ()
@property (nonatomic, strong) NSString *builderPrefix;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *tags;
@end

@implementation CSTaggedUrnBuilder

+ (instancetype)builderWithPrefix:(NSString *)prefix {
    CSTaggedUrnBuilder *builder = [[CSTaggedUrnBuilder alloc] init];
    builder.builderPrefix = [prefix lowercaseString];
    return builder;
}

- (instancetype)init {
    if (self = [super init]) {
        _builderPrefix = @"";
        _tags = [NSMutableDictionary dictionary];
    }
    return self;
}

- (CSTaggedUrnBuilder *)tag:(NSString *)key value:(NSString *)value {
    // Key lowercase, value preserved
    self.tags[[key lowercaseString]] = value;
    return self;
}

- (nullable CSTaggedUrn *)build:(NSError **)error {
    if (self.tags.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"URN identifier cannot be empty"}];
        }
        return nil;
    }

    return [CSTaggedUrn fromPrefix:self.builderPrefix tagsInternal:self.tags error:error];
}

- (CSTaggedUrn *)buildAllowEmpty {
    return [CSTaggedUrn fromPrefix:self.builderPrefix tagsInternal:self.tags error:nil];
}

@end
