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
// The parser reads the six tag forms — the canonical alphabet of the
// constraint truth table — into the constraint each writes:
//
//   | Authored                 | Canonical | Constraint     | Score | Reading                       |
//   |--------------------------|-----------|----------------|------:|-------------------------------|
//   | `?x` ≡ `x?` ≡ `x=?`      | `?x`      | unconstrained  |     0 | no constraint                 |
//   | `?x=v` ≡ `x?=v` ≡ `x=?v` | `x?=v`    | optionalNot v  |     1 | absent OR (present and not v) |
//   | `x` ≡ `x=*`              | `x`       | present        |     2 | present with any value        |
//   | `!x=v` ≡ `x!=v` ≡ `x=!v` | `x!=v`    | presentNot v   |     3 | present and not v             |
//   | `x=v`                    | `x=v`     | exact v        |     4 | present and exactly v         |
//   | `!x` ≡ `x!` ≡ `x=!`      | `!x`      | absent         |     5 | absent (must-not-have)        |
//
// A quoted value is literal: `x="?v"` is the exact value `?v`, and `x="*"` the exact
// value `*`, never the marker.
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

static NSError *CSTaggedUrnMakeError(CSTaggedUrnError code, NSString *message) {
    return [NSError errorWithDomain:CSTaggedUrnErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

#pragma mark - CSTagConstraint

@implementation CSTagConstraint

- (instancetype)initWithKind:(CSTagConstraintKind)kind value:(nullable NSString *)value {
    if (self = [super init]) {
        _kind = kind;
        _value = [value copy];
    }
    return self;
}

+ (instancetype)missing { return [[self alloc] initWithKind:CSTagConstraintKindMissing value:nil]; }
+ (instancetype)unconstrained { return [[self alloc] initWithKind:CSTagConstraintKindUnconstrained value:nil]; }
+ (instancetype)present { return [[self alloc] initWithKind:CSTagConstraintKindPresent value:nil]; }
+ (instancetype)absent { return [[self alloc] initWithKind:CSTagConstraintKindAbsent value:nil]; }
+ (instancetype)exact:(NSString *)value { return [[self alloc] initWithKind:CSTagConstraintKindExact value:value]; }
+ (instancetype)optionalNot:(NSString *)value { return [[self alloc] initWithKind:CSTagConstraintKindOptionalNot value:value]; }
+ (instancetype)presentNot:(NSString *)value { return [[self alloc] initWithKind:CSTagConstraintKindPresentNot value:value]; }

/// Whether this form carries a value.
- (BOOL)carriesValue {
    return self.kind == CSTagConstraintKindExact || self.kind == CSTagConstraintKindOptionalNot ||
           self.kind == CSTagConstraintKindPresentNot;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CSTagConstraint class]]) return NO;
    CSTagConstraint *other = object;
    return self.kind == other.kind && (self.value == other.value || [self.value isEqualToString:other.value]);
}

- (NSUInteger)hash {
    return (NSUInteger)self.kind ^ self.value.hash;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (NSString *)description {
    return self.value ? [NSString stringWithFormat:@"%ld(%@)", (long)self.kind, self.value]
                      : [NSString stringWithFormat:@"%ld", (long)self.kind];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.kind forKey:@"kind"];
    [coder encodeObject:self.value forKey:@"value"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSInteger kind = [coder decodeIntegerForKey:@"kind"];
    NSString *value = [coder decodeObjectOfClass:[NSString class] forKey:@"value"];
    if (kind < CSTagConstraintKindMissing || kind > CSTagConstraintKindAbsent) {
        [coder failWithError:CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidTagFormat,
                             [NSString stringWithFormat:@"no constraint has kind %ld", (long)kind])];
        return nil;
    }
    CSTagConstraint *decoded = [self initWithKind:(CSTagConstraintKind)kind value:value];
    if ([decoded carriesValue] != (value != nil)) {
        [coder failWithError:CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidTagFormat,
                             [NSString stringWithFormat:@"constraint kind %ld %@ a value", (long)kind,
                              value ? @"carries no" : @"needs"])];
        return nil;
    }
    return decoded;
}

@end

@interface CSTaggedUrn () {
    // The same URN on the proved model's side: its tags with the proof that their keys are
    // strictly increasing (a TaggedUrn.Exec.Wf, owned). Every semantic question is asked of
    // it. Made by the designated initializer from the same tags as the fields, which nothing
    // changes afterwards, so the two cannot describe different URNs.
    lungo_value *_formal;
}
@property (nonatomic, strong) NSString *mutablePrefix;
@property (nonatomic, strong) NSDictionary<NSString *, CSTagConstraint *> *storedTags;
- (instancetype)initWithPrefix:(NSString *)prefix tags:(NSDictionary<NSString *, CSTagConstraint *> *)tags NS_DESIGNATED_INITIALIZER;
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

static NSString *CSStringOfModel(const lungo_value *v) {
    size_t length = 0;
    const char *bytes = lungo_value_get_string(v, &length);
    return [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
}

/// The model's value of a constraint; owned.
static lungo_value *CSModelConstraint(CSTagConstraint *c) {
    switch (c.kind) {
        case CSTagConstraintKindMissing: return tagged_urn_formal_constraint_missing();
        case CSTagConstraintKindUnconstrained: return tagged_urn_formal_constraint_unconstrained();
        case CSTagConstraintKindOptionalNot: return tagged_urn_formal_constraint_optional_not(CSModelString(c.value));
        case CSTagConstraintKindPresent: return tagged_urn_formal_constraint_present();
        case CSTagConstraintKindPresentNot: return tagged_urn_formal_constraint_present_not(CSModelString(c.value));
        case CSTagConstraintKindExact: return tagged_urn_formal_constraint_exact(CSModelString(c.value));
        case CSTagConstraintKindAbsent: return tagged_urn_formal_constraint_absent();
    }
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"tagged-urn: no constraint has kind %ld", (long)c.kind]
                                 userInfo:nil];
}

/// A constraint the model returned, read by its constructor.
static CSTagConstraint *CSConstraintOfModel(const lungo_value *v) {
    switch (lungo_value_ctor_index(v)) {
        case TAGGED_URN_FORMAL_CONSTRAINT_MISSING: return [CSTagConstraint missing];
        case TAGGED_URN_FORMAL_CONSTRAINT_UNCONSTRAINED: return [CSTagConstraint unconstrained];
        case TAGGED_URN_FORMAL_CONSTRAINT_OPTIONAL_NOT:
            return [CSTagConstraint optionalNot:CSStringOfModel(tagged_urn_formal_constraint_optional_not_value(v))];
        case TAGGED_URN_FORMAL_CONSTRAINT_PRESENT: return [CSTagConstraint present];
        case TAGGED_URN_FORMAL_CONSTRAINT_PRESENT_NOT:
            return [CSTagConstraint presentNot:CSStringOfModel(tagged_urn_formal_constraint_present_not_value(v))];
        case TAGGED_URN_FORMAL_CONSTRAINT_EXACT:
            return [CSTagConstraint exact:CSStringOfModel(tagged_urn_formal_constraint_exact_value(v))];
        case TAGGED_URN_FORMAL_CONSTRAINT_ABSENT: return [CSTagConstraint absent];
    }
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"tagged-urn: the model returned constraint constructor %u",
                                           lungo_value_ctor_index(v)]
                                 userInfo:nil];
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

#pragma mark - The grammar

/// Whether a character may begin a prefix or a key: an ASCII letter.
static BOOL CSIsIdentifierStart(unichar c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

/// Whether a character may stand in a prefix or key after its first.
static BOOL CSIsValidKeyChar(unichar c) {
    return CSIsIdentifierStart(c) || (c >= '0' && c <= '9') || c == '-';
}

/// Whether a character may stand in an unquoted value: anything but the separators `;` `=`,
/// the quoting characters `"` `\`, and whitespace.
static BOOL CSIsValidUnquotedValueChar(unichar c) {
    return c != ';' && c != '=' && c != '"' && c != '\\' &&
           ![[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c];
}

/// An ASCII letter lowered, any other character as it is: unquoted values are lowered so.
static unichar CSAsciiLower(unichar c) {
    return (c >= 'A' && c <= 'Z') ? (unichar)(c + ('a' - 'A')) : c;
}

/// `s` as an identifier — an ASCII letter, then ASCII letters, digits and `-` — lowered;
/// `what` names it in the error ("prefix", "key"). nil, with the error, when it is not one.
static NSString * _Nullable CSIdentifier(NSString *what, NSString *s, NSError **error) {
    if (s.length == 0) {
        if (error) {
            *error = [what isEqualToString:@"prefix"]
                ? CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyPrefix, @"URN prefix cannot be empty")
                : CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyTag, [NSString stringWithFormat:@"empty %@", what]);
        }
        return nil;
    }
    for (NSUInteger pos = 0; pos < s.length; pos++) {
        unichar c = [s characterAtIndex:pos];
        BOOL allowed = pos == 0 ? CSIsIdentifierStart(c) : CSIsValidKeyChar(c);
        if (!allowed) {
            if (error) {
                *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                    [NSString stringWithFormat:@"invalid character '%C' in %@ at position %lu", c, what, (unsigned long)pos]);
            }
            return nil;
        }
    }
    return [s lowercaseString];
}

/// Refuses a constraint a URN cannot write for `key`: missing (a key with no constraint is
/// omitted), or an empty value.
static BOOL CSCheckConstraint(NSString *key, CSTagConstraint * _Nullable c, NSError **error) {
    if (c == nil || ![c isKindOfClass:[CSTagConstraint class]] || c.kind == CSTagConstraintKindMissing) {
        if (error) {
            *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidTagFormat,
                [NSString stringWithFormat:@"key '%@' given no constraint: a key with no constraint is omitted", key]);
        }
        return NO;
    }
    if ([c carriesValue] && c.value.length == 0) {
        if (error) {
            *error = CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyTag, [NSString stringWithFormat:@"empty value for key '%@'", key]);
        }
        return NO;
    }
    return YES;
}

/// The constraint a value writes under a qualifier (0 for none).
static CSTagConstraint *CSQualified(char qualifier, NSString *value) {
    switch (qualifier) {
        case 0:   return [CSTagConstraint exact:value];
        case '?': return [CSTagConstraint optionalNot:value];
        case '!': return [CSTagConstraint presentNot:value];
    }
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"invalid qualifier %d", qualifier]
                                 userInfo:nil];
}

/// The constraint of a value-less tag, given its qualifier (0, '?' or '!').
static CSTagConstraint *CSCanonicalNoValue(char qualifier) {
    switch (qualifier) {
        case 0:   return [CSTagConstraint present];
        case '?': return [CSTagConstraint unconstrained];
        case '!': return [CSTagConstraint absent];
    }
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"invalid qualifier %d", qualifier]
                                 userInfo:nil];
}

/// A qualifier and a sigil (`*`, `?`, `!`) make incompatible claims.
static BOOL CSRefuseSigilUnderQualifier(char qualifier, NSString *key, NSString *value, NSError **error) {
    if ([value isEqualToString:@"*"] || [value isEqualToString:@"?"] || [value isEqualToString:@"!"]) {
        if (error) {
            *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                [NSString stringWithFormat:@"qualifier '%c' on key '%@' cannot combine with sigil value '%@': "
                                            "use a real value or drop the qualifier", qualifier, key, value]);
        }
        return NO;
    }
    return YES;
}

/// The constraint a parsed (qualifier, value) pair writes. A quoted value is literal: exact,
/// or optionalNot/presentNot under a qualifier. An unquoted `*`, `?` or `!` is a sigil; an
/// unquoted value that begins with `?` or `!` is that qualifier (`x=?v` ≡ `x?=v`). A qualifier
/// on an unquoted sigil, or a second qualifier, is refused.
static CSTagConstraint * _Nullable CSCanonicalizeValue(char qualifier, BOOL quoted, NSString *key, NSString *value, NSError **error) {
    if (value.length == 0) {
        if (error) {
            *error = CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyTag, [NSString stringWithFormat:@"empty value for key '%@'", key]);
        }
        return nil;
    }
    if (quoted) return CSQualified(qualifier, [value copy]);
    unichar first = [value characterAtIndex:0];
    if (qualifier == 0) {
        if ([value isEqualToString:@"*"]) return [CSTagConstraint present];
        if ([value isEqualToString:@"?"]) return [CSTagConstraint unconstrained];
        if ([value isEqualToString:@"!"]) return [CSTagConstraint absent];
        if (first == '?' || first == '!') {
            NSString *rest = [value substringFromIndex:1];
            if (!CSRefuseSigilUnderQualifier((char)first, key, rest, error)) return nil;
            return CSQualified((char)first, rest);
        }
        return [CSTagConstraint exact:[value copy]];
    }
    if (value.length > 1 && (first == '?' || first == '!')) {
        if (error) {
            *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                [NSString stringWithFormat:@"qualifier '%c' on key '%@' cannot combine with a second qualifier in value '%@': "
                                            "quote the value to make it literal", qualifier, key, value]);
        }
        return nil;
    }
    if (!CSRefuseSigilUnderQualifier(qualifier, key, value, error)) return nil;
    return CSQualified(qualifier, [value copy]);
}

/// Keys in code-point order: their UTF-8 bytes, the order Lean's String < uses.
static NSArray<NSString *> *CSSortedKeys(NSArray<NSString *> *keys) {
    return [keys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        int c = strcmp(a.UTF8String, b.UTF8String);
        return c < 0 ? NSOrderedAscending : (c > 0 ? NSOrderedDescending : NSOrderedSame);
    }];
}

@interface CSTaggedUrnCoordinateDelta ()
@property (nonatomic, strong) NSString *mutablePrefix;
@property (nonatomic, strong) NSDictionary<NSString *, CSTagConstraint *> *mutableRemoved;
@property (nonatomic, strong) NSDictionary<NSString *, CSTagConstraint *> *mutableAdded;
@property (nonatomic, assign) CSTaggedUrnRelationKind mutableRelationKind;
@end

@implementation CSTaggedUrnCoordinateDelta

- (instancetype)initWithPrefix:(NSString *)prefix
                       removed:(NSDictionary<NSString *, CSTagConstraint *> *)removed
                         added:(NSDictionary<NSString *, CSTagConstraint *> *)added
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

- (NSDictionary<NSString *, CSTagConstraint *> *)removed {
    return self.mutableRemoved;
}

- (NSDictionary<NSString *, CSTagConstraint *> *)added {
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
    NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSString class], [CSTagConstraint class], nil];
    NSString *prefix = [coder decodeObjectOfClass:[NSString class] forKey:@"prefix"];
    NSDictionary *removed = [coder decodeObjectOfClasses:classes forKey:@"removed"];
    NSDictionary *added = [coder decodeObjectOfClasses:classes forKey:@"added"];
    if (prefix == nil || removed == nil || added == nil) {
        [coder failWithError:CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidFormat, @"a coordinate delta needs its prefix, removed and added")];
        return nil;
    }
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

- (NSDictionary<NSString *, CSTagConstraint *> *)tags {
    return self.storedTags;
}

#pragma mark - Helper Methods

+ (BOOL)needsQuoting:(NSString *)value {
    NSCharacterSet *uppercase = [NSCharacterSet uppercaseLetterCharacterSet];
    for (NSUInteger i = 0; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];
        if (!CSIsValidUnquotedValueChar(c) || [uppercase characterIsMember:c]) {
            return YES;
        }
    }
    return [value hasPrefix:@"*"] || [value hasPrefix:@"?"] || [value hasPrefix:@"!"];
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

/// A value as it is written: bare, or quoted when it must be.
+ (NSString *)writeValue:(NSString *)value {
    return [self needsQuoting:value] ? [self quoteValue:value] : value;
}

#pragma mark - Parsing

/// Inserts the tag being parsed (nil when making its constraint failed, with the error set),
/// refusing a key given twice, and readies the parser for the next tag.
static BOOL CSFinishTag(NSMutableDictionary<NSString *, CSTagConstraint *> *tags, NSMutableString *key,
                        NSMutableString *value, char *qualifier, CSTagConstraint * _Nullable constraint,
                        NSError **error) {
    if (constraint == nil) return NO;
    if (tags[key] != nil) {
        if (error) *error = CSTaggedUrnMakeError(CSTaggedUrnErrorDuplicateKey, [NSString stringWithFormat:@"Duplicate tag key: %@", key]);
        return NO;
    }
    tags[[key copy]] = constraint;
    [key setString:@""];
    [value setString:@""];
    *qualifier = 0;
    return YES;
}

+ (nullable instancetype)fromString:(NSString *)string error:(NSError **)error {
    if (!string || string.length == 0) {
        if (error) *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidFormat, @"URN identifier cannot be empty");
        return nil;
    }

    // Fail hard on leading/trailing whitespace
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![string isEqualToString:trimmed]) {
        if (error) {
            *error = CSTaggedUrnMakeError(CSTaggedUrnErrorWhitespaceInInput,
                [NSString stringWithFormat:@"URN has leading or trailing whitespace: '%@'", string]);
        }
        return nil;
    }

    // Find the prefix (everything before the first colon)
    NSRange colonRange = [string rangeOfString:@":"];
    if (colonRange.location == NSNotFound) {
        if (error) *error = CSTaggedUrnMakeError(CSTaggedUrnErrorMissingPrefix, @"URN must have a prefix followed by ':'");
        return nil;
    }

    if (colonRange.location == 0) {
        if (error) *error = CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyPrefix, @"URN prefix cannot be empty");
        return nil;
    }

    NSString *prefix = CSIdentifier(@"prefix", [string substringToIndex:colonRange.location], error);
    if (prefix == nil) return nil;
    NSString *tagsPart = [string substringFromIndex:colonRange.location + 1];
    NSMutableDictionary<NSString *, CSTagConstraint *> *tags = [NSMutableDictionary dictionary];

    // Handle empty tagged URN (prefix: with no tags or just semicolon)
    if (tagsPart.length == 0 || [tagsPart isEqualToString:@";"]) {
        return [[CSTaggedUrn alloc] initWithPrefix:prefix tags:tags];
    }

    CSParseState state = CSParseStateExpectingKey;
    NSMutableString *currentKey = [NSMutableString string];
    NSMutableString *currentValue = [NSMutableString string];
    NSUInteger pos = 0;
    // qualifier: 0 means none, '?' or '!' means a prefix or infix
    // qualifier has been seen for the tag currently being parsed.
    // Reset to 0 on each finished tag.
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
                } else if (CSIsIdentifierStart(c)) {
                    [currentKey appendFormat:@"%C", CSAsciiLower(c)];
                    state = CSParseStateInKey;
                } else {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                            [NSString stringWithFormat:@"invalid character '%C' at position %lu", c, (unsigned long)pos]);
                    }
                    return nil;
                }
                break;

            case CSParseStateAfterPrefixQuestion:
            case CSParseStateAfterPrefixBang:
                if (CSIsIdentifierStart(c)) {
                    [currentKey appendFormat:@"%C", CSAsciiLower(c)];
                    state = CSParseStateInKey;
                } else {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                            [NSString stringWithFormat:@"expected key character after '%c' qualifier, got '%C' at position %lu", qualifier, c, (unsigned long)pos]);
                    }
                    return nil;
                }
                break;

            case CSParseStateInKey:
                if (c == '=') {
                    state = CSParseStateExpectingValue;
                } else if (c == '?' || c == '!') {
                    if (qualifier != 0) {
                        if (error) {
                            *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                                [NSString stringWithFormat:@"duplicate qualifier '%C' at position %lu: prefix and infix qualifiers cannot be combined on key '%@'", c, (unsigned long)pos, currentKey]);
                        }
                        return nil;
                    }
                    qualifier = (char)c;
                    state = c == '?' ? CSParseStateInKeyAfterQuestion : CSParseStateInKeyAfterBang;
                } else if (c == ';') {
                    if (!CSFinishTag(tags, currentKey, currentValue, &qualifier, CSCanonicalNoValue(qualifier), error)) return nil;
                    state = CSParseStateExpectingKey;
                } else if (CSIsValidKeyChar(c)) {
                    [currentKey appendFormat:@"%C", CSAsciiLower(c)];
                } else {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                            [NSString stringWithFormat:@"invalid character '%C' in key at position %lu", c, (unsigned long)pos]);
                    }
                    return nil;
                }
                break;

            case CSParseStateInKeyAfterQuestion:
            case CSParseStateInKeyAfterBang:
                if (c == '=') {
                    state = CSParseStateExpectingValue;
                } else if (c == ';') {
                    if (!CSFinishTag(tags, currentKey, currentValue, &qualifier, CSCanonicalNoValue(qualifier), error)) return nil;
                    state = CSParseStateExpectingKey;
                } else {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                            [NSString stringWithFormat:@"expected '=' or ';' after '%@%c' suffix qualifier, got '%C' at position %lu", currentKey, qualifier, c, (unsigned long)pos]);
                    }
                    return nil;
                }
                break;

            case CSParseStateExpectingValue:
                if (c == '"') {
                    state = CSParseStateInQuotedValue;
                } else if (c == ';') {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyTag,
                            [NSString stringWithFormat:@"empty value for key '%@'", currentKey]);
                    }
                    return nil;
                } else if (CSIsValidUnquotedValueChar(c)) {
                    [currentValue appendFormat:@"%C", CSAsciiLower(c)];
                    state = CSParseStateInUnquotedValue;
                } else {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                            [NSString stringWithFormat:@"invalid character '%C' in value at position %lu", c, (unsigned long)pos]);
                    }
                    return nil;
                }
                break;

            case CSParseStateInUnquotedValue:
                if (c == ';') {
                    if (!CSFinishTag(tags, currentKey, currentValue, &qualifier, CSCanonicalizeValue(qualifier, NO, currentKey, currentValue, error), error)) return nil;
                    state = CSParseStateExpectingKey;
                } else if (CSIsValidUnquotedValueChar(c)) {
                    [currentValue appendFormat:@"%C", CSAsciiLower(c)];
                } else {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                            [NSString stringWithFormat:@"invalid character '%C' in unquoted value at position %lu", c, (unsigned long)pos]);
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
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidEscapeSequence,
                            [NSString stringWithFormat:@"invalid escape sequence at position %lu (only \\\" and \\\\ allowed)", (unsigned long)pos]);
                    }
                    return nil;
                }
                break;

            case CSParseStateExpectingSemiOrEnd:
                if (c == ';') {
                    if (!CSFinishTag(tags, currentKey, currentValue, &qualifier, CSCanonicalizeValue(qualifier, YES, currentKey, currentValue, error), error)) return nil;
                    state = CSParseStateExpectingKey;
                } else {
                    if (error) {
                        *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidCharacter,
                            [NSString stringWithFormat:@"expected ';' or end after quoted value, got '%C' at position %lu", c, (unsigned long)pos]);
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
            if (!CSFinishTag(tags, currentKey, currentValue, &qualifier, CSCanonicalizeValue(qualifier, NO, currentKey, currentValue, error), error)) return nil;
            break;
        case CSParseStateExpectingSemiOrEnd:
            if (!CSFinishTag(tags, currentKey, currentValue, &qualifier, CSCanonicalizeValue(qualifier, YES, currentKey, currentValue, error), error)) return nil;
            break;
        case CSParseStateExpectingKey:
            break;
        case CSParseStateInQuotedValue:
        case CSParseStateInQuotedValueEscape:
            if (error) {
                *error = CSTaggedUrnMakeError(CSTaggedUrnErrorUnterminatedQuote,
                    [NSString stringWithFormat:@"unterminated quote at position %lu", (unsigned long)pos]);
            }
            return nil;
        case CSParseStateAfterPrefixQuestion:
        case CSParseStateAfterPrefixBang:
            if (error) {
                *error = CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyTag,
                    [NSString stringWithFormat:@"qualifier '%c' at end of input has no key", qualifier]);
            }
            return nil;
        case CSParseStateInKey:
        case CSParseStateInKeyAfterQuestion:
        case CSParseStateInKeyAfterBang:
            if (!CSFinishTag(tags, currentKey, currentValue, &qualifier, CSCanonicalNoValue(qualifier), error)) return nil;
            break;
        case CSParseStateExpectingValue:
            if (error) {
                *error = CSTaggedUrnMakeError(CSTaggedUrnErrorEmptyTag,
                    [NSString stringWithFormat:@"empty value for key '%@'", currentKey]);
            }
            return nil;
    }

    return [[CSTaggedUrn alloc] initWithPrefix:prefix tags:tags];
}

+ (nullable instancetype)fromPrefix:(NSString *)prefix tags:(NSDictionary<NSString *, CSTagConstraint *> *)tags error:(NSError **)error {
    NSString *lower = CSIdentifier(@"prefix", prefix, error);
    if (lower == nil) return nil;
    NSMutableDictionary<NSString *, CSTagConstraint *> *validated = [NSMutableDictionary dictionary];
    for (NSString *key in tags) {
        NSString *k = CSIdentifier(@"key", key, error);
        if (k == nil) return nil;
        if (!CSCheckConstraint(k, tags[key], error)) return nil;
        if (validated[k] != nil) {
            if (error) *error = CSTaggedUrnMakeError(CSTaggedUrnErrorDuplicateKey, [NSString stringWithFormat:@"Duplicate tag key: %@", k]);
            return nil;
        }
        validated[k] = tags[key];
    }
    return [[CSTaggedUrn alloc] initWithPrefix:lower tags:validated];
}

/// The one way a CSTaggedUrn is made: the fields and the model's value, together, from the same
/// tags, which every caller has already checked. The model refuses keys that are not strictly
/// increasing; the keys are sorted by their UTF-8 bytes, which is the code-point order Lean's
/// String < uses, so a refusal is a broken invariant.
- (instancetype)initWithPrefix:(NSString *)prefix tags:(NSDictionary<NSString *, CSTagConstraint *> *)tags {
    if (self = [super init]) {
        _mutablePrefix = [prefix copy];
        _storedTags = [tags copy];
        NSArray<NSString *> *keys = CSSortedKeys(tags.allKeys);
        lungo_value **pairs = keys.count ? calloc(keys.count, sizeof(lungo_value *)) : NULL;
        for (NSUInteger i = 0; i < keys.count; i++) {
            CSTagConstraint *c = tags[keys[i]];
            if (c.kind == CSTagConstraintKindMissing) {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"tagged-urn: key '%@' stored as missing; a key with no constraint is omitted", keys[i]]
                                             userInfo:nil];
            }
            pairs[i] = lungo_value_prod(CSModelString(keys[i]), CSModelConstraint(c));
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

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"tagged-urn: a CSTaggedUrn is made by fromString:error: or fromPrefix:tags:error:"
                                 userInfo:nil];
}

- (const lungo_value *)formalValue {
    return _formal;
}

+ (nullable instancetype)emptyWithPrefix:(NSString *)prefix error:(NSError **)error {
    return [self fromPrefix:prefix tags:@{} error:error];
}

- (nullable CSTagConstraint *)getTag:(NSString *)key {
    return self.storedTags[[key lowercaseString]];
}

- (CSTagConstraint *)constraintForKey:(NSString *)key {
    CSTagConstraint *c = self.storedTags[[key lowercaseString]];
    return c ?: [CSTagConstraint missing];
}

- (BOOL)hasTag:(NSString *)key withValue:(NSString *)value {
    return [[self getTag:key] isEqual:[CSTagConstraint exact:value]];
}

- (BOOL)hasMarkerTag:(NSString *)tagName {
    return [self getTag:tagName].kind == CSTagConstraintKindPresent;
}

- (BOOL)admitsAbsence:(NSString *)key {
    // Absence satisfies the constraint exactly when the constraint lets the
    // key be absent.
    return [CSTaggedUrn valuesMatchInst:[CSTagConstraint absent] patt:[self constraintForKey:key]];
}

- (nullable CSTaggedUrn *)withTag:(NSString *)key constraint:(CSTagConstraint *)constraint error:(NSError **)error {
    NSString *k = CSIdentifier(@"key", key, error);
    if (k == nil) return nil;
    if (!CSCheckConstraint(k, constraint, error)) return nil;
    NSMutableDictionary *newTags = [self.storedTags mutableCopy];
    newTags[k] = constraint;
    return [[CSTaggedUrn alloc] initWithPrefix:self.mutablePrefix tags:newTags];
}

- (CSTaggedUrn *)withoutTag:(NSString *)key {
    NSMutableDictionary *newTags = [self.storedTags mutableCopy];
    [newTags removeObjectForKey:[key lowercaseString]];
    return [[CSTaggedUrn alloc] initWithPrefix:self.mutablePrefix tags:newTags];
}

/// Whether the instance's constraint satisfies the pattern's at one key (missing for a key a
/// URN omits), as the model decides it: every form has one meaning — the set of states the key
/// may be in — and the instance satisfies the pattern when every state it allows, the pattern
/// allows too (tagMatch_iff_allows in ../formal).
+ (BOOL)valuesMatchInst:(CSTagConstraint *)inst patt:(CSTagConstraint *)patt {
    lungo_value *i = CSModelConstraint(inst);
    lungo_value *p = CSModelConstraint(patt);
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

/// The most specific URN every one of `urns` conforms to, made by the model
/// (`TaggedUrn.Exec.leastUpperBound`): its tags come back as constraints, none of them missing.
+ (nullable instancetype)leastUpperBoundWithPrefix:(NSString *)prefix
                                              urns:(NSArray<CSTaggedUrn *> *)urns
                                             error:(NSError **)error {
    NSString *lower = CSIdentifier(@"prefix", prefix, error);
    if (lower == nil) return nil;
    lungo_value **handles = urns.count ? calloc(urns.count, sizeof(lungo_value *)) : NULL;
    for (NSUInteger i = 0; i < urns.count; i++) {
        handles[i] = lungo_value_clone(urns[i]->_formal);
    }
    lungo_value *list = lungo_value_list(handles, urns.count);
    free(handles);
    lungo_value *scheme = CSModelString(lower);
    lungo_value *made = NULL;
    lungo_error *failure = NULL;
    int32_t status = tagged_urn_formal_least_upper_bound(scheme, list, &made, &failure);
    lungo_value_free(scheme);
    lungo_value_free(list);
    if (status != LUNGO_OK) CSModelFailed([NSString stringWithFormat:@"bound URNs of %@", lower], failure);
    const lungo_value *tags = lungo_value_get_option(made);
    if (tags == NULL) {
        lungo_value_free(made);
        for (CSTaggedUrn *urn in urns) {
            if (![urn.mutablePrefix isEqualToString:lower]) {
                if (error) {
                    *error = [NSError errorWithDomain:CSTaggedUrnErrorDomain
                                                 code:CSTaggedUrnErrorPrefixMismatch
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot bound URNs with different prefixes: '%@' vs '%@'", lower, urn.mutablePrefix]}];
                }
                return nil;
            }
        }
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"tagged-urn: the model made no bound of URNs that all have the prefix %@", lower]
                                     userInfo:nil];
    }
    NSMutableDictionary<NSString *, CSTagConstraint *> *bound = [NSMutableDictionary dictionary];
    for (size_t i = 0; i < lungo_value_count(tags); i++) {
        const lungo_value *pair = lungo_value_item(tags, i);
        bound[CSStringOfModel(lungo_value_first(pair))] = CSConstraintOfModel(lungo_value_second(pair));
    }
    lungo_value_free(made);
    return [[CSTaggedUrn alloc] initWithPrefix:lower tags:bound];
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

    NSMutableDictionary<NSString *, CSTagConstraint *> *removed = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, CSTagConstraint *> *added = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *allKeys = [NSMutableSet set];
    [allKeys addObjectsFromArray:base.storedTags.allKeys];
    [allKeys addObjectsFromArray:self.storedTags.allKeys];

    for (NSString *key in allKeys) {
        CSTagConstraint *baseValue = base.storedTags[key];
        CSTagConstraint *targetValue = self.storedTags[key];
        if (baseValue && !targetValue) {
            removed[key] = baseValue;
        } else if (!baseValue && targetValue) {
            added[key] = targetValue;
        } else if (baseValue && targetValue && ![baseValue isEqual:targetValue]) {
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

    NSMutableDictionary<NSString *, CSTagConstraint *> *newTags = [self.storedTags mutableCopy];
    for (NSString *key in delta.removed) {
        CSTagConstraint *expected = delta.removed[key];
        CSTagConstraint *current = newTags[key];
        if (current && [current isEqual:expected]) {
            [newTags removeObjectForKey:key];
        }
    }
    for (NSString *key in delta.added) {
        newTags[key] = delta.added[key];
    }
    return [CSTaggedUrn fromPrefix:self.mutablePrefix tags:newTags error:error];
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

/// How many tags fall into each non-zero form, from the highest score to the lowest:
/// (absent, exact, presentNot, present, optionalNot)
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
    for (CSTagConstraint *c in self.storedTags.allValues) {
        switch (c.kind) {
            case CSTagConstraintKindAbsent:        (*mustNotHave)++; break;
            case CSTagConstraintKindExact:         (*exact)++; break;
            case CSTagConstraintKindPresentNot:    (*presentNotValue)++; break;
            case CSTagConstraintKindPresent:       (*mustHaveAny)++; break;
            case CSTagConstraintKindOptionalNot:   (*absentOrNotValue)++; break;
            case CSTagConstraintKindUnconstrained: break;
            case CSTagConstraintKindMissing:
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:@"tagged-urn: a stored tag is missing"
                                             userInfo:nil];
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

/// Two strings in code-point order: their UTF-8 bytes, the order Lean's String < uses.
static NSComparisonResult CSCompareCodePoints(NSString *a, NSString *b) {
    int c = strcmp(a.UTF8String, b.UTF8String);
    return c < 0 ? NSOrderedAscending : (c > 0 ? NSOrderedDescending : NSOrderedSame);
}

- (NSComparisonResult)compare:(CSTaggedUrn *)other {
    NSComparisonResult byPrefix = CSCompareCodePoints(self.mutablePrefix, other.mutablePrefix);
    if (byPrefix != NSOrderedSame) return byPrefix;
    NSArray<NSString *> *keysA = CSSortedKeys(self.storedTags.allKeys);
    NSArray<NSString *> *keysB = CSSortedKeys(other.storedTags.allKeys);
    for (NSUInteger i = 0; i < MIN(keysA.count, keysB.count); i++) {
        NSComparisonResult byKey = CSCompareCodePoints(keysA[i], keysB[i]);
        if (byKey != NSOrderedSame) return byKey;
        CSTagConstraint *a = self.storedTags[keysA[i]];
        CSTagConstraint *b = other.storedTags[keysB[i]];
        // The kinds are declared in the truth table's order.
        if (a.kind != b.kind) return a.kind < b.kind ? NSOrderedAscending : NSOrderedDescending;
        NSComparisonResult byValue = CSCompareCodePoints(a.value ?: @"", b.value ?: @"");
        if (byValue != NSOrderedSame) return byValue;
    }
    if (keysA.count == keysB.count) return NSOrderedSame;
    return keysA.count < keysB.count ? NSOrderedAscending : NSOrderedDescending;
}

- (CSTaggedUrn *)withWildcardTag:(NSString *)key {
    NSString *normalizedKey = [key lowercaseString];
    if (self.storedTags[normalizedKey] == nil) {
        return self;
    }
    NSMutableDictionary *newTags = [self.storedTags mutableCopy];
    newTags[normalizedKey] = [CSTagConstraint present];
    return [[CSTaggedUrn alloc] initWithPrefix:self.mutablePrefix tags:newTags];
}

- (CSTaggedUrn *)subset:(NSArray<NSString *> *)keys {
    NSMutableDictionary *newTags = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        NSString *normalizedKey = [key lowercaseString];
        CSTagConstraint *value = self.storedTags[normalizedKey];
        if (value) {
            newTags[normalizedKey] = value;
        }
    }
    return [[CSTaggedUrn alloc] initWithPrefix:self.mutablePrefix tags:newTags];
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

    NSMutableDictionary *newTags = [self.storedTags mutableCopy];
    for (NSString *key in other.storedTags) {
        newTags[key] = other.storedTags[key];
    }
    return [[CSTaggedUrn alloc] initWithPrefix:self.mutablePrefix tags:newTags];
}

/// The canonical string: the prefix, `:`, and the tags in key order joined by `;`. Each
/// constraint is written in its canonical form — present `k`, unconstrained `?k`, absent `!k`,
/// optionalNot `k?=v`, presentNot `k!=v`, exact `k=v` — with a value quoted only when it must
/// be to read back as itself (exact `*` prints `k="*"`).
- (NSString *)toString {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *key in CSSortedKeys(self.storedTags.allKeys)) {
        CSTagConstraint *c = self.storedTags[key];
        switch (c.kind) {
            case CSTagConstraintKindPresent:
                [parts addObject:key];
                break;
            case CSTagConstraintKindUnconstrained:
                [parts addObject:[NSString stringWithFormat:@"?%@", key]];
                break;
            case CSTagConstraintKindAbsent:
                [parts addObject:[NSString stringWithFormat:@"!%@", key]];
                break;
            case CSTagConstraintKindOptionalNot:
                [parts addObject:[NSString stringWithFormat:@"%@?=%@", key, [CSTaggedUrn writeValue:c.value]]];
                break;
            case CSTagConstraintKindPresentNot:
                [parts addObject:[NSString stringWithFormat:@"%@!=%@", key, [CSTaggedUrn writeValue:c.value]]];
                break;
            case CSTagConstraintKindExact:
                [parts addObject:[NSString stringWithFormat:@"%@=%@", key, [CSTaggedUrn writeValue:c.value]]];
                break;
            case CSTagConstraintKindMissing:
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"tagged-urn: key '%@' is stored as missing", key]
                                             userInfo:nil];
        }
    }
    return [NSString stringWithFormat:@"%@:%@", self.mutablePrefix, [parts componentsJoinedByString:@";"]];
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
           [self.storedTags isEqualToDictionary:other.storedTags];
}

- (NSUInteger)hash {
    return self.mutablePrefix.hash ^ self.storedTags.hash;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.mutablePrefix forKey:@"prefix"];
    [coder encodeObject:self.storedTags forKey:@"tags"];
}

/// Decoded data is checked as `fromPrefix:tags:error:` checks it: a coded URN that does not
/// hold to the grammar fails to decode, saying why.
- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *prefix = [coder decodeObjectOfClass:[NSString class] forKey:@"prefix"];
    NSDictionary *tags = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [CSTagConstraint class], nil] forKey:@"tags"];
    if (prefix == nil || tags == nil) {
        [coder failWithError:CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidFormat, @"a coded tagged URN needs its prefix and tags")];
        return nil;
    }
    NSError *error = nil;
    CSTaggedUrn *checked = [CSTaggedUrn fromPrefix:prefix tags:tags error:&error];
    if (checked == nil) {
        [coder failWithError:error];
        return nil;
    }
    return [self initWithPrefix:checked.mutablePrefix tags:checked.storedTags];
}

@end

#pragma mark - CSTaggedUrnBuilder

@interface CSTaggedUrnBuilder ()
@property (nonatomic, strong) NSString *builderPrefix;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CSTagConstraint *> *tags;
/// The first refusal, returned by build.
@property (nonatomic, strong) NSError *buildError;
@end

@implementation CSTaggedUrnBuilder

+ (instancetype)builderWithPrefix:(NSString *)prefix {
    CSTaggedUrnBuilder *builder = [[CSTaggedUrnBuilder alloc] init];
    NSError *error = nil;
    NSString *lower = CSIdentifier(@"prefix", prefix, &error);
    builder.builderPrefix = lower ?: @"";
    builder.buildError = error;
    return builder;
}

- (instancetype)init {
    if (self = [super init]) {
        _builderPrefix = @"";
        _tags = [NSMutableDictionary dictionary];
    }
    return self;
}

- (CSTaggedUrnBuilder *)tag:(NSString *)key constraint:(CSTagConstraint *)constraint {
    if (self.buildError) return self;
    NSError *error = nil;
    NSString *k = CSIdentifier(@"key", key, &error);
    if (k == nil || !CSCheckConstraint(k, constraint, &error)) {
        self.buildError = error;
        return self;
    }
    if (self.tags[k] != nil) {
        self.buildError = CSTaggedUrnMakeError(CSTaggedUrnErrorDuplicateKey, [NSString stringWithFormat:@"Duplicate tag key: %@", k]);
        return self;
    }
    self.tags[k] = constraint;
    return self;
}

- (CSTaggedUrnBuilder *)tag:(NSString *)key value:(NSString *)value {
    return [self tag:key constraint:[CSTagConstraint exact:value]];
}

- (CSTaggedUrnBuilder *)marker:(NSString *)key {
    return [self tag:key constraint:[CSTagConstraint present]];
}

- (nullable CSTaggedUrn *)build:(NSError **)error {
    if (self.buildError) {
        if (error) *error = self.buildError;
        return nil;
    }
    if (self.tags.count == 0) {
        if (error) *error = CSTaggedUrnMakeError(CSTaggedUrnErrorInvalidFormat, @"URN identifier cannot be empty");
        return nil;
    }
    return [[CSTaggedUrn alloc] initWithPrefix:self.builderPrefix tags:self.tags];
}

- (nullable CSTaggedUrn *)buildAllowEmpty:(NSError **)error {
    if (self.buildError) {
        if (error) *error = self.buildError;
        return nil;
    }
    return [[CSTaggedUrn alloc] initWithPrefix:self.builderPrefix tags:self.tags];
}

@end
