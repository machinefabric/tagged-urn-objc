//
//  CSTaggedUrn.m
//  Flat Tag-Based URN Identifier Implementation
//

#import "CSTaggedUrn.h"
// What two URNs mean to each other is decided by the program generated from the proved model
// in ../formal (see ../lungo.toml), through its C API.
#import "tagged_urn_formal.h"

NSErrorDomain const CSTaggedUrnErrorDomain = @"CSTaggedUrnErrorDomain";

// Parser states for state machine.
//
// The parser handles six tag forms — the canonical alphabet of the
// constraint truth table:
//
//   | Authored                | Canonical | Stored value | Score | Reading                                  |
//   |-------------------------|-----------|--------------|------:|------------------------------------------|
//   | `?x` ≡ `x?`             | `?x`      | "?"          |     0 | no constraint                            |
//   | `?x=v` ≡ `x?=v`         | `x?=v`    | "?=v"        |     1 | absent OR (present and not v)            |
//   | `x` ≡ `x=*`             | `x`       | "*"          |     2 | present with any value                   |
//   | `!x=v` ≡ `x!=v`         | `x!=v`    | "!=v"        |     3 | present and not v                        |
//   | `x=v`                   | `x=v`     | "v"          |     4 | present and exactly v (`v ∉ {?, !, *}`)  |
//   | `!x` ≡ `x!`             | `!x`      | "!"          |     5 | absent (must-not-have)                   |
typedef NS_ENUM(NSInteger, CSParseState) {
    CSParseStateExpectingKey,
    CSParseStateAfterPrefixQuestion,
    CSParseStateAfterPrefixBang,
    CSParseStateInKey,
    CSParseStateInKeyAfterQuestion,
    CSParseStateInKeyAfterBang,
    CSParseStateExpectingValue,
    CSParseStateInUnquotedValue,
    CSParseStateInQuotedValue,
    CSParseStateInQuotedValueEscape,
    CSParseStateExpectingSemiOrEnd
};

@interface CSTaggedUrn () {
    // The same URN on the proved model's side: its tags with the proof that their keys are
    // strictly increasing (a TaggedUrn.Exec.Wf, owned). Every semantic question is asked of
    // it. Made by the designated initializer from the same tags as the fields, which nothing
    // changes afterwards, so the two cannot describe different URNs.
    lungo_value *_formal;
}
@property (nonatomic, strong) NSString *mutablePrefix;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mutableTags;
- (instancetype)initWithPrefix:(NSString *)prefix tags:(NSDictionary<NSString *, NSString *> *)tags NS_DESIGNATED_INITIALIZER;
@end

#pragma mark - The model

/// A model call that fails is a broken invariant — a URN the parser accepted that the model
/// cannot take, or a runtime that is not working — and there is no answer to give instead.
static void CSModelFailed(NSString *what, lungo_error *error) {
    NSString *reason = [NSString stringWithFormat:@"tagged-urn: the model could not %@: %s", what,
                        error ? lungo_error_message(error) : "no error was reported"];
    if (error) lungo_error_free(error);
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:nil];
}

static lungo_value *CSModelString(NSString *s) {
    NSData *utf8 = [s dataUsingEncoding:NSUTF8StringEncoding];
    return lungo_value_string(utf8.bytes, utf8.length);
}

/// The model's form of a stored tag value (nil is a key the URN omits); owned.
static lungo_value *CSConstraintOf(NSString * _Nullable value) {
    if (value == nil) return tagged_urn_formal_constraint_missing();
    if ([value isEqualToString:@"?"]) return tagged_urn_formal_constraint_unconstrained();
    if ([value isEqualToString:@"*"]) return tagged_urn_formal_constraint_present();
    if ([value isEqualToString:@"!"]) return tagged_urn_formal_constraint_absent();
    if ([value hasPrefix:@"?="]) return tagged_urn_formal_constraint_optional_not(CSModelString([value substringFromIndex:2]));
    if ([value hasPrefix:@"!="]) return tagged_urn_formal_constraint_present_not(CSModelString([value substringFromIndex:2]));
    return tagged_urn_formal_constraint_exact(CSModelString(value));
}

/// A Bool the model returned; frees it.
static BOOL CSModelBool(lungo_value *result) {
    BOOL answer = lungo_value_get_bool(result);
    lungo_value_free(result);
    return answer;
}

/// Runs a model relation of two URNs.
static BOOL CSModelRelation(int32_t (*relation)(const lungo_value *, const lungo_value *, lungo_value **, lungo_error **),
                            const lungo_value *a, const lungo_value *b, NSString *what) {
    lungo_value *result = NULL;
    lungo_error *error = NULL;
    if (relation(a, b, &result, &error) != LUNGO_OK) CSModelFailed(what, error);
    return CSModelBool(result);
}

@interface CSTaggedUrnCoordinateDelta ()
@property (nonatomic, strong) NSString *mutablePrefix;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *mutableRemoved;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *mutableAdded;
@property (nonatomic, assign) CSTaggedUrnRelationKind mutableRelationKind;
@end

@implementation CSTaggedUrnCoordinateDelta

- (instancetype)initWithPrefix:(NSString *)prefix
                       removed:(NSDictionary<NSString *,NSString *> *)removed
                         added:(NSDictionary<NSString *,NSString *> *)added
                  relationKind:(CSTaggedUrnRelationKind)relationKind {
    if (self = [super init]) {
        _mutablePrefix = [prefix lowercaseString];
        _mutableRemoved = [removed copy];
        _mutableAdded = [added copy];
        _mutableRelationKind = relationKind;
    }
    return self;
}

- (NSString *)prefix {
    return self.mutablePrefix;
}

- (NSDictionary<NSString *,NSString *> *)removed {
    return self.mutableRemoved;
}

- (NSDictionary<NSString *,NSString *> *)added {
    return self.mutableAdded;
}

- (CSTaggedUrnRelationKind)relationKind {
    return self.mutableRelationKind;
}

- (BOOL)isEmpty {
    return self.mutableRemoved.count == 0 && self.mutableAdded.count == 0;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.mutablePrefix forKey:@"prefix"];
    [coder encodeObject:self.mutableRemoved forKey:@"removed"];
    [coder encodeObject:self.mutableAdded forKey:@"added"];
    [coder encodeInteger:self.mutableRelationKind forKey:@"relationKind"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *prefix = [coder decodeObjectOfClass:[NSString class] forKey:@"prefix"] ?: @"";
    NSDictionary *removed = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"removed"] ?: @{};
    NSDictionary *added = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"added"] ?: @{};
    CSTaggedUrnRelationKind relationKind = [coder decodeIntegerForKey:@"relationKind"];
    return [self initWithPrefix:prefix removed:removed added:added relationKind:relationKind];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[CSTaggedUrnCoordinateDelta alloc] initWithPrefix:self.mutablePrefix
                                                      removed:self.mutableRemoved
                                                        added:self.mutableAdded
                                                 relationKind:self.mutableRelationKind];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CSTaggedUrnCoordinateDelta class]]) {
        return NO;
    }
    CSTaggedUrnCoordinateDelta *other = (CSTaggedUrnCoordinateDelta *)object;
    return [self.mutablePrefix isEqualToString:other.mutablePrefix]
        && [self.mutableRemoved isEqualToDictionary:other.mutableRemoved]
        && [self.mutableAdded isEqualToDictionary:other.mutableAdded]
        && self.mutableRelationKind == other.mutableRelationKind;
}

- (NSUInteger)hash {
    return self.mutablePrefix.hash ^ self.mutableRemoved.hash ^ self.mutableAdded.hash ^ self.mutableRelationKind;
}

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
    // qualifier: 0 means none, '?' or '!' means a prefix or infix
    // qualifier has been seen for the tag currently being parsed.
    // Reset to 0 on each finish_tag.
    char qualifier = 0;

    while (pos < tagsPart.length) {
        unichar c = [tagsPart characterAtIndex:pos];

        switch (state) {
            case CSParseStateExpectingKey:
                if (c == ';') {
                    pos++;
                    continue;
                } else if (c == '?') {
                    qualifier = '?';
                    state = CSParseStateAfterPrefixQuestion;
                } else if (c == '!') {
                    qualifier = '!';
                    state = CSParseStateAfterPrefixBang;
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

            case CSParseStateAfterPrefixQuestion:
            case CSParseStateAfterPrefixBang:
                if ([self isValidKeyChar:c]) {
                    [currentKey appendFormat:@"%c", tolower(c)];
                    state = CSParseStateInKey;
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidCharacter
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"expected key character after '%c' qualifier, got '%C' at position %lu", qualifier, c, (unsigned long)pos]}];
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
                } else if (c == '?') {
                    if (qualifier != 0) {
                        if (error) {
                            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                         code:CSTaggedUrnErrorInvalidCharacter
                                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"duplicate qualifier '?' at position %lu: prefix and infix qualifiers cannot be combined on key '%@'", (unsigned long)pos, currentKey]}];
                        }
                        return nil;
                    }
                    qualifier = '?';
                    state = CSParseStateInKeyAfterQuestion;
                } else if (c == '!') {
                    if (qualifier != 0) {
                        if (error) {
                            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                         code:CSTaggedUrnErrorInvalidCharacter
                                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"duplicate qualifier '!' at position %lu: prefix and infix qualifiers cannot be combined on key '%@'", (unsigned long)pos, currentKey]}];
                        }
                        return nil;
                    }
                    qualifier = '!';
                    state = CSParseStateInKeyAfterBang;
                } else if (c == ';') {
                    if (currentKey.length == 0) {
                        if (error) {
                            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                         code:CSTaggedUrnErrorEmptyTag
                                                     userInfo:@{NSLocalizedDescriptionKey: @"empty key"}];
                        }
                        return nil;
                    }
                    [currentValue setString:CSCanonicalNoValueForQualifier(qualifier)];
                    if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    [currentKey setString:@""];
                    [currentValue setString:@""];
                    qualifier = 0;
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

            case CSParseStateInKeyAfterQuestion:
            case CSParseStateInKeyAfterBang:
                if (c == '=') {
                    state = CSParseStateExpectingValue;
                } else if (c == ';') {
                    [currentValue setString:CSCanonicalNoValueForQualifier(qualifier)];
                    if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    [currentKey setString:@""];
                    [currentValue setString:@""];
                    qualifier = 0;
                    state = CSParseStateExpectingKey;
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                     code:CSTaggedUrnErrorInvalidCharacter
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"expected '=' or ';' after '%@%c' suffix qualifier, got '%C' at position %lu", currentKey, qualifier, c, (unsigned long)pos]}];
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
                    if (![self canonicalizeValueWithQualifier:qualifier key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    [currentKey setString:@""];
                    [currentValue setString:@""];
                    qualifier = 0;
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
                    if (![self canonicalizeValueWithQualifier:qualifier key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                        return nil;
                    }
                    [currentKey setString:@""];
                    [currentValue setString:@""];
                    qualifier = 0;
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
            if (![self canonicalizeValueWithQualifier:qualifier key:currentKey value:currentValue error:error]) {
                return nil;
            }
            if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                return nil;
            }
            break;
        case CSParseStateExpectingKey:
            break;
        case CSParseStateInQuotedValue:
        case CSParseStateInQuotedValueEscape:
            if (error) {
                *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                             code:CSTaggedUrnErrorUnterminatedQuote
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"unterminated quote at position %lu", (unsigned long)pos]}];
            }
            return nil;
        case CSParseStateAfterPrefixQuestion:
        case CSParseStateAfterPrefixBang:
            if (error) {
                *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                             code:CSTaggedUrnErrorEmptyTag
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"qualifier '%c' at end of input has no key", qualifier]}];
            }
            return nil;
        case CSParseStateInKey:
            if (currentKey.length == 0) {
                if (error) {
                    *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                 code:CSTaggedUrnErrorEmptyTag
                                             userInfo:@{NSLocalizedDescriptionKey: @"empty key"}];
                }
                return nil;
            }
            [currentValue setString:CSCanonicalNoValueForQualifier(qualifier)];
            if (![self finishTag:tags key:currentKey value:currentValue error:error]) {
                return nil;
            }
            break;
        case CSParseStateInKeyAfterQuestion:
        case CSParseStateInKeyAfterBang:
            [currentValue setString:CSCanonicalNoValueForQualifier(qualifier)];
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

// Helper: canonical stored value for a value-less tag, given its
// qualifier (0, '?' or '!').
static NSString *CSCanonicalNoValueForQualifier(char qualifier) {
    switch (qualifier) {
        case 0:   return @"*";
        case '?': return @"?";
        case '!': return @"!";
    }
    [NSException raise:NSInternalInconsistencyException
                format:@"invalid qualifier %d", qualifier];
    return nil;
}

// Helper: canonicalize a parsed value into the stored form per the
// qualifier. None: keep value. '?': encode as "?=v". '!': encode as
// "!=v". Combining a qualifier with a sigil-only value (`*`, `?`,
// `!`) is rejected.
+ (BOOL)canonicalizeValueWithQualifier:(char)qualifier
                                   key:(NSString *)key
                                 value:(NSMutableString *)value
                                 error:(NSError **)error {
    if (qualifier == 0) {
        return YES;
    }
    if ([value isEqualToString:@"*"] ||
        [value isEqualToString:@"?"] ||
        [value isEqualToString:@"!"]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidCharacter
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:
                 @"qualifier '%c' on key '%@' cannot combine with sigil value '%@': "
                  "use a real value or drop the qualifier",
                 qualifier, key, value]}];
        }
        return NO;
    }
    NSString *canonical = [NSString stringWithFormat:@"%c=%@", qualifier, value];
    [value setString:canonical];
    return YES;
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

    // Normalize keys to lowercase and validate each authored tag through
    // the same key/value rules the parser applies, so programmatic
    // construction cannot bypass numeric-key, duplicate-key, or empty-value
    // checks.
    NSMutableDictionary<NSString *, NSString *> *validatedTags = [NSMutableDictionary dictionary];
    for (NSString *key in tags) {
        NSString *value = tags[key];
        NSString *keyLower = [key lowercaseString];
        if (![self finishTag:validatedTags key:keyLower value:value ?: @"" error:error]) {
            return nil;
        }
    }

    return [self fromPrefix:prefix tagsInternal:validatedTags error:error];
}

+ (nullable instancetype)fromPrefix:(NSString *)prefix tagsInternal:(NSDictionary<NSString *, NSString *> *)tags error:(NSError **)error {
    return [[CSTaggedUrn alloc] initWithPrefix:[prefix lowercaseString] tags:tags];
}

/// The one way a CSTaggedUrn is made: the fields and the model's value, together, from the same
/// tags. The model refuses keys that are not strictly increasing; the keys are sorted by their
/// UTF-8 bytes, which is the code-point order Lean's String < uses, so a refusal is a broken
/// invariant.
- (instancetype)initWithPrefix:(NSString *)prefix tags:(NSDictionary<NSString *, NSString *> *)tags {
    if (self = [super init]) {
        _mutablePrefix = [prefix copy];
        _mutableTags = [tags mutableCopy];
        NSArray<NSString *> *keys = [tags.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            int c = strcmp(a.UTF8String, b.UTF8String);
            return c < 0 ? NSOrderedAscending : (c > 0 ? NSOrderedDescending : NSOrderedSame);
        }];
        lungo_value **pairs = keys.count ? calloc(keys.count, sizeof(lungo_value *)) : NULL;
        for (NSUInteger i = 0; i < keys.count; i++) {
            pairs[i] = lungo_value_prod(CSModelString(keys[i]), CSConstraintOf(tags[keys[i]]));
        }
        lungo_value *list = lungo_value_list(pairs, keys.count);
        free(pairs);
        lungo_value *scheme = CSModelString(_mutablePrefix);
        lungo_value *made = NULL;
        lungo_error *failure = NULL;
        int32_t status = tagged_urn_formal_make(scheme, list, &made, &failure);
        lungo_value_free(scheme);
        lungo_value_free(list);
        if (status != LUNGO_OK) CSModelFailed([NSString stringWithFormat:@"build %@", _mutablePrefix], failure);
        const lungo_value *wf = lungo_value_get_option(made);
        if (wf == NULL) {
            lungo_value_free(made);
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"tagged-urn: the model refused %@ with keys %@, which are sorted", _mutablePrefix, keys]
                                         userInfo:nil];
        }
        _formal = lungo_value_clone(wf);
        lungo_value_free(made);
    }
    return self;
}

- (void)dealloc {
    lungo_value_free(_formal);
}

- (const lungo_value *)formalValue {
    return _formal;
}

+ (instancetype)emptyWithPrefix:(NSString *)prefix {
    return [self fromPrefix:prefix tagsInternal:@{} error:nil];
}

- (instancetype)init {
    return [self initWithPrefix:@"" tags:@{}];
}

- (nullable NSString *)getTag:(NSString *)key {
    return self.mutableTags[[key lowercaseString]];
}

- (BOOL)hasTag:(NSString *)key withValue:(NSString *)value {
    NSString *tagValue = self.mutableTags[[key lowercaseString]];
    // Case-sensitive value comparison
    return tagValue && [tagValue isEqualToString:value];
}

- (BOOL)hasMarkerTag:(NSString *)tagName {
    NSString *tagValue = self.mutableTags[[tagName lowercaseString]];
    return tagValue && [tagValue isEqualToString:@"*"];
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

// One of the seven canonical forms a tag value can take (six
// explicit + missing). Used by the matcher and specificity scorer.
typedef NS_ENUM(NSInteger, CSFormKind) {
    CSFormMissing,
    CSFormNoConstraint,         // "?"
    CSFormAbsentOrNotValue,     // "?=v"
    CSFormMustHaveAny,          // "*"
    CSFormPresentNotValue,      // "!=v"
    CSFormExact,                // exact "v"
    CSFormMustNotHave,          // "!"
};

// Classify a stored value into (kind, raw value). raw is the inner
// v for ?=v and !=v, the literal value for exact, and nil for the
// sigil-only forms.
static CSFormKind CSClassifyForm(NSString * _Nullable value, NSString * _Nullable * _Nullable rawOut) {
    if (rawOut) *rawOut = nil;
    if (value == nil) return CSFormMissing;
    if ([value isEqualToString:@"?"]) return CSFormNoConstraint;
    if ([value isEqualToString:@"*"]) return CSFormMustHaveAny;
    if ([value isEqualToString:@"!"]) return CSFormMustNotHave;
    if ([value hasPrefix:@"?="]) {
        if (rawOut) *rawOut = [value substringFromIndex:2];
        return CSFormAbsentOrNotValue;
    }
    if ([value hasPrefix:@"!="]) {
        if (rawOut) *rawOut = [value substringFromIndex:2];
        return CSFormPresentNotValue;
    }
    if (rawOut) *rawOut = value;
    return CSFormExact;
}

/// Check if instance value matches pattern constraint (nil for a key the URN omits), as the
/// model decides it: every form has one meaning — the set of states the key may be in — and
/// the instance satisfies the pattern when every state it allows, the pattern allows too
/// (tagMatch_iff_allows in ../formal).
+ (BOOL)valuesMatchInst:(NSString *)inst patt:(NSString *)patt {
    lungo_value *i = CSConstraintOf(inst);
    lungo_value *p = CSConstraintOf(patt);
    lungo_value *result = NULL;
    lungo_error *error = NULL;
    int32_t status = tagged_urn_formal_values_match(i, p, &result, &error);
    lungo_value_free(i);
    lungo_value_free(p);
    if (status != LUNGO_OK) CSModelFailed(@"match one key", error);
    return CSModelBool(result);
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
    return [CSTaggedUrn checkMatchInstance:self pattern:pattern error:error];
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
    return [CSTaggedUrn checkMatchInstance:instance pattern:self error:error];
}

/// One of the model's relations between two URNs of one prefix, with the nil and
/// prefix refusals every such question shares.
- (BOOL)ask:(int32_t (*)(const lungo_value *, const lungo_value *, lungo_value **, lungo_error **))relation
         of:(CSTaggedUrn *)other
       what:(NSString *)what
      error:(NSError **)error {
    if (!other) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot compare with nil URN"}];
        }
        return NO;
    }
    if (![CSTaggedUrn samePrefix:self other:other error:error]) return NO;
    return CSModelRelation(relation, _formal, other->_formal, what);
}

/// Whether this URN and `other` COULD be about the same thing: some thing is described
/// by both. Symmetric — neither is the instance. `conformsTo` is a guarantee; this is the
/// other question the same meanings answer, and the one a search asks.
- (BOOL)meets:(CSTaggedUrn *)other error:(NSError **)error {
    return [self ask:tagged_urn_formal_meets of:other what:@"decide overlap" error:error];
}

/// Whether this URN, read as a COMPLETE thing — what it does not mention it does not
/// have — satisfies `pattern`.
- (BOOL)satisfies:(CSTaggedUrn *)pattern error:(NSError **)error {
    return [self ask:tagged_urn_formal_refines_closed of:pattern what:@"decide the complete reading" error:error];
}

/// Whether this URN, read as a complete thing, COULD satisfy `pattern`.
- (BOOL)maySatisfy:(CSTaggedUrn *)pattern error:(NSError **)error {
    return [self ask:tagged_urn_formal_meets_closed of:pattern what:@"decide the complete overlap" error:error];
}

- (BOOL)isEquivalentTo:(CSTaggedUrn *)other error:(NSError **)error {
    if (!other) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot compare with nil URN"}];
        }
        return NO;
    }

    if (![CSTaggedUrn samePrefix:self other:other error:error]) return NO;
    return CSModelRelation(tagged_urn_formal_equivalent, _formal, other->_formal, @"decide equivalence");
}

- (BOOL)isComparableTo:(CSTaggedUrn *)other error:(NSError **)error {
    if (!other) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot compare with nil URN"}];
        }
        return NO;
    }

    if (![CSTaggedUrn samePrefix:self other:other error:error]) return NO;
    return CSModelRelation(tagged_urn_formal_comparable, _formal, other->_formal, @"decide comparability");
}

- (nullable CSTaggedUrnCoordinateDelta *)deltaFrom:(CSTaggedUrn *)base error:(NSError **)error {
    if (!base) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot compute delta from nil URN"}];
        }
        return nil;
    }
    if (![[self.mutablePrefix lowercaseString] isEqualToString:[base.mutablePrefix lowercaseString]]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorPrefixMismatch
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot compute delta between URNs with different prefixes: '%@' vs '%@'", base.mutablePrefix, self.mutablePrefix]}];
        }
        return nil;
    }

    NSMutableDictionary<NSString *, NSString *> *removed = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *added = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *allKeys = [NSMutableSet set];
    [allKeys addObjectsFromArray:base.mutableTags.allKeys];
    [allKeys addObjectsFromArray:self.mutableTags.allKeys];

    for (NSString *key in allKeys) {
        NSString *baseValue = base.mutableTags[key];
        NSString *targetValue = self.mutableTags[key];
        if (baseValue && !targetValue) {
            removed[key] = baseValue;
        } else if (!baseValue && targetValue) {
            added[key] = targetValue;
        } else if (baseValue && targetValue && ![baseValue isEqualToString:targetValue]) {
            removed[key] = baseValue;
            added[key] = targetValue;
        }
    }

    NSError *relationError = nil;
    BOOL equivalent = [self isEquivalentTo:base error:&relationError];
    if (relationError) {
        if (error) *error = relationError;
        return nil;
    }
    CSTaggedUrnRelationKind relationKind;
    if (equivalent) {
        relationKind = CSTaggedUrnRelationKindEquivalent;
    } else {
        BOOL comparable = [self isComparableTo:base error:&relationError];
        if (relationError) {
            if (error) *error = relationError;
            return nil;
        }
        relationKind = comparable ? CSTaggedUrnRelationKindComparable : CSTaggedUrnRelationKindIncomparable;
    }

    return [[CSTaggedUrnCoordinateDelta alloc] initWithPrefix:self.mutablePrefix
                                                      removed:removed
                                                        added:added
                                                 relationKind:relationKind];
}

- (nullable CSTaggedUrn *)applyDelta:(CSTaggedUrnCoordinateDelta *)delta error:(NSError **)error {
    if (!delta) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorInvalidFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot apply nil delta"}];
        }
        return nil;
    }
    if (![[self.mutablePrefix lowercaseString] isEqualToString:[delta.prefix lowercaseString]]) {
        if (error) {
            *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                         code:CSTaggedUrnErrorPrefixMismatch
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot apply delta with prefix '%@' to URN prefix '%@'", delta.prefix, self.mutablePrefix]}];
        }
        return nil;
    }

    NSMutableDictionary<NSString *, NSString *> *newTags = [self.mutableTags mutableCopy];
    for (NSString *key in delta.removed) {
        NSString *expected = delta.removed[key];
        NSString *current = newTags[key];
        if (current && [current isEqualToString:expected]) {
            [newTags removeObjectForKey:key];
        }
    }
    for (NSString *key in delta.added) {
        newTags[key] = delta.added[key];
    }
    return [CSTaggedUrn fromPrefix:self.mutablePrefix tagsInternal:newTags error:error];
}

/// Core matching: does instance satisfy pattern's constraints? Decided by the model (refines,
/// proved to be refinement); only the prefix check is here, because comparing across prefixes
/// is a caller's error and says so.
+ (BOOL)checkMatchInstance:(CSTaggedUrn *)instance pattern:(CSTaggedUrn *)pattern error:(NSError **)error {
    if (![self samePrefix:instance other:pattern error:error]) return NO;
    return CSModelRelation(tagged_urn_formal_refines, instance->_formal, pattern->_formal, @"decide refinement");
}

/// Refuse a comparison of URNs with different prefixes.
+ (BOOL)samePrefix:(CSTaggedUrn *)a other:(CSTaggedUrn *)b error:(NSError **)error {
    if ([a.mutablePrefix isEqualToString:b.mutablePrefix]) return YES;
    if (error) {
        *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                     code:CSTaggedUrnErrorPrefixMismatch
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot compare URNs with different prefixes: '%@' vs '%@'", a.mutablePrefix, b.mutablePrefix]}];
    }
    return NO;
}

/// Per-tag truth-table specificity score, applied uniformly to any
/// stored tag value. Missing keys score 0; the caller filters them
/// out before calling.
///
///   "?"          -> 0   (no constraint)
///   starts "?="  -> 1   (absent or not v)
///   "*"          -> 2   (must-have-any)
///   starts "!="  -> 3   (present and not v)
///   "!"          -> 5   (must-not-have)
///   otherwise    -> 4   (exact value)
NSUInteger CSTaggedUrnScoreTagValue(NSString *value) {
    if ([value isEqualToString:@"?"]) return 0;
    if ([value isEqualToString:@"*"]) return 2;
    if ([value isEqualToString:@"!"]) return 5;
    if ([value hasPrefix:@"?="]) return 1;
    if ([value hasPrefix:@"!="]) return 3;
    return 4;
}

/// Calculate specificity score, as the model computes it: the sum of per-tag truth-table scores.
- (NSUInteger)specificity {
    lungo_value *result = NULL;
    lungo_error *error = NULL;
    if (tagged_urn_formal_specificity(_formal, &result, &error) != LUNGO_OK) CSModelFailed(@"score a URN", error);
    uint64_t score = 0;
    BOOL fits = lungo_value_get_nat(result, &score);
    lungo_value_free(result);
    if (!fits || score > NSUIntegerMax) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"tagged-urn: the specificity of %@ does not fit", [self toString]]
                                     userInfo:nil];
    }
    return (NSUInteger)score;
}

/// Get specificity as a tuple for tie-breaking, ordered from highest
/// score to lowest:
/// (must_not_have, exact, present_not_value, must_have_any, absent_or_not_value)
- (void)specificityTupleMustNotHave:(NSUInteger *)mustNotHave
                              exact:(NSUInteger *)exact
                   presentNotValue:(NSUInteger *)presentNotValue
                       mustHaveAny:(NSUInteger *)mustHaveAny
                  absentOrNotValue:(NSUInteger *)absentOrNotValue {
    *mustNotHave = 0;
    *exact = 0;
    *presentNotValue = 0;
    *mustHaveAny = 0;
    *absentOrNotValue = 0;
    for (NSString *value in self.mutableTags.allValues) {
        switch (CSClassifyForm(value, NULL)) {
            case CSFormMustNotHave:        (*mustNotHave)++; break;
            case CSFormExact:              (*exact)++; break;
            case CSFormPresentNotValue:    (*presentNotValue)++; break;
            case CSFormMustHaveAny:        (*mustHaveAny)++; break;
            case CSFormAbsentOrNotValue:   (*absentOrNotValue)++; break;
            case CSFormMissing:
            case CSFormNoConstraint:       break;
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

    // Build canonical serialization. Stored values map to:
    //   "*"           -> "k"           (bare key, must-have-any)
    //   "?"           -> "?k"          (prefix qualifier, no constraint)
    //   "!"           -> "!k"          (prefix qualifier, must-not-have)
    //   "?=v"         -> "k?=v"        (infix qualifier, absent or not v)
    //   "!=v"         -> "k!=v"        (infix qualifier, present and not v)
    //   exact "v"     -> "k=v" or "k=\"v\"" (with quoting if needed)
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        NSString *value = self.mutableTags[key];
        if ([value isEqualToString:@"*"]) {
            [parts addObject:key];
        } else if ([value isEqualToString:@"?"]) {
            [parts addObject:[NSString stringWithFormat:@"?%@", key]];
        } else if ([value isEqualToString:@"!"]) {
            [parts addObject:[NSString stringWithFormat:@"!%@", key]];
        } else if ([value hasPrefix:@"?="]) {
            NSString *raw = [value substringFromIndex:2];
            if ([CSTaggedUrn needsQuoting:raw]) {
                [parts addObject:[NSString stringWithFormat:@"%@?=%@", key, [CSTaggedUrn quoteValue:raw]]];
            } else {
                [parts addObject:[NSString stringWithFormat:@"%@?=%@", key, raw]];
            }
        } else if ([value hasPrefix:@"!="]) {
            NSString *raw = [value substringFromIndex:2];
            if ([CSTaggedUrn needsQuoting:raw]) {
                [parts addObject:[NSString stringWithFormat:@"%@!=%@", key, [CSTaggedUrn quoteValue:raw]]];
            } else {
                [parts addObject:[NSString stringWithFormat:@"%@!=%@", key, raw]];
            }
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
    NSString *prefix = [coder decodeObjectOfClass:[NSString class] forKey:@"prefix"];
    NSDictionary *tags = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], nil] forKey:@"tags"];
    return [self initWithPrefix:prefix ?: @"" tags:tags ?: @{}];
}

@end

#pragma mark - CSTaggedUrnBuilder

@interface CSTaggedUrnBuilder ()
@property (nonatomic, strong) NSString *builderPrefix;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *tags;
@property (nonatomic, strong) NSError *buildError; // Track errors from tag()
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
    // Validate empty value - matches Rust's Result error
    if (value.length == 0) {
        self.buildError = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                               code:CSTaggedUrnErrorEmptyTag
                                           userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Empty value for key '%@' (use '*' for wildcard)", key]}];
        return self; // Return self to maintain fluent API, but build() will fail
    }

    // Key lowercase, value preserved
    self.tags[[key lowercaseString]] = value;
    return self;
}

- (CSTaggedUrnBuilder *)marker:(NSString *)key {
    // Marker = wildcard-valued tag, stored as key="*", serialized as just
    // the key.
    self.tags[[key lowercaseString]] = @"*";
    return self;
}

- (nullable CSTaggedUrn *)build:(NSError **)error {
    // Check if tag() encountered an error
    if (self.buildError) {
        if (error) {
            *error = self.buildError;
        }
        return nil;
    }

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
