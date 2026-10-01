//
//  CSTaggedUrnTests.m
//  Tests for CSTaggedUrn tag-based system
//
//  NOTE: The `action` tag has been replaced with `op` in the new format.
//

#import <XCTest/XCTest.h>
@import TaggedUrn;

@interface CSTaggedUrnTests : XCTestCase
@end

@implementation CSTaggedUrnTests

// TEST0014: Tagged urn creation
- (void)test0014_TaggedUrnCreation {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:transform;format=json;data_processing" error:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);

    XCTAssertEqualObjects(taggedUrn.prefix, @"cap");
    // data_processing is a valueless tag, stored as * (must-have-any)
    XCTAssertEqualObjects([taggedUrn getTag:@"data_processing"], @"*");
    XCTAssertTrue([taggedUrn hasMarkerTag:@"transform"]);
    XCTAssertEqualObjects([taggedUrn getTag:@"format"], @"json");
}

// TEST0015: Custom prefix
- (void)test0015_CustomPrefix {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"myapp:generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects(urn.prefix, @"myapp");
    XCTAssertTrue([urn hasMarkerTag:@"generate"]);
    XCTAssertEqualObjects([urn toString], @"myapp:ext=pdf;generate");
}

// TEST0016: Prefix case insensitive
- (void)test0016_PrefixCaseInsensitive {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"CAP:test" error:&error];
    XCTAssertNotNil(urn1);
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:test" error:&error];
    XCTAssertNotNil(urn2);
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"Cap:test" error:&error];
    XCTAssertNotNil(urn3);

    XCTAssertEqualObjects(urn1.prefix, @"cap");
    XCTAssertEqualObjects(urn2.prefix, @"cap");
    XCTAssertEqualObjects(urn3.prefix, @"cap");
    XCTAssertEqualObjects(urn1, urn2);
    XCTAssertEqualObjects(urn2, urn3);
}

// TEST0017: Canonical string format
- (void)test0017_CanonicalStringFormat {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:generate;target=thumbnail;ext=pdf" error:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);

    // Should be sorted alphabetically: ext, op, target
    XCTAssertEqualObjects([taggedUrn toString], @"cap:ext=pdf;generate;target=thumbnail");
}

// TEST0018: Prefix required
- (void)test0018_PrefixRequired {
    NSError *error;
    // Missing prefix should fail
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"generate;ext=pdf" error:&error];
    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorMissingPrefix);

    // Empty prefix should fail
    error = nil;
    taggedUrn = [CSTaggedUrn fromString:@":generate" error:&error];
    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorEmptyPrefix);

    // Valid prefix should work
    error = nil;
    taggedUrn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);
    XCTAssertTrue([taggedUrn hasMarkerTag:@"generate"]);
}

// TEST0019: Trailing semicolon equivalence
- (void)test0019_TrailingSemicolonEquivalence {
    NSError *error;
    // Both with and without trailing semicolon should be equivalent
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn1);

    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:generate;ext=pdf;" error:&error];
    XCTAssertNotNil(urn2);

    // They should be equal
    XCTAssertEqualObjects(urn1, urn2);

    // They should have same hash
    XCTAssertEqual([urn1 hash], [urn2 hash]);

    // They should have same string representation (canonical form)
    XCTAssertEqualObjects([urn1 toString], [urn2 toString]);

    // They should match each other
    BOOL matches1 = [urn1 conformsTo:urn2 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches1);

    BOOL matches2 = [urn2 conformsTo:urn1 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches2);
}

// TEST0020: Invalid tagged urn
- (void)test0020_InvalidTaggedUrn {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"" error:&error];

    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidFormat);
}

// TEST0021: Valueless tag parsing
- (void)test0021_ValuelessTagParsing {
    // Value-less tag is now valid and treated as wildcard
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:optimize" error:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([taggedUrn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([taggedUrn toString], @"cap:optimize");
}

// TEST0022: Invalid characters
- (void)test0022_InvalidCharacters {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:type@invalid=value" error:&error];

    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidCharacter);
}

// TEST0023: Tag matching
- (void)test0023_TagMatching {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf;target=thumbnail;" error:&error];

    // Exact match
    CSTaggedUrn *request1 = [CSTaggedUrn fromString:@"cap:generate;ext=pdf;target=thumbnail;" error:&error];
    BOOL matches = [urn conformsTo:request1 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    // Subset match
    CSTaggedUrn *request2 = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    matches = [urn conformsTo:request2 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    // Wildcard request should match specific urn
    CSTaggedUrn *request3 = [CSTaggedUrn fromString:@"cap:ext=*" error:&error];
    matches = [urn conformsTo:request3 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    // No match - conflicting value
    CSTaggedUrn *request4 = [CSTaggedUrn fromString:@"cap:extract" error:&error];
    matches = [urn conformsTo:request4 error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches);
}

// TEST0024: Prefix mismatch error
- (void)test0024_PrefixMismatchError {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:test" error:&error];
    XCTAssertNotNil(urn1);
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"myapp:test" error:&error];
    XCTAssertNotNil(urn2);

    error = nil;
    [urn1 conformsTo:urn2 error:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorPrefixMismatch);
}

// TEST0025: Missing tag handling
- (void)test0025_MissingTagHandling {
    // NEW SEMANTICS: Missing tag in instance means the tag doesn't exist.
    // Pattern constraints must be satisfied by instance.
    NSError *error;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:generate" error:&error];

    // Pattern with tag that instance doesn't have: NO MATCH
    CSTaggedUrn *pattern1 = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error];
    BOOL matches = [instance conformsTo:pattern1 error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches); // Instance missing ext, pattern wants ext=pdf

    // Pattern missing tag = no constraint: MATCH
    CSTaggedUrn *instance2 = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    CSTaggedUrn *pattern2 = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    matches = [instance2 conformsTo:pattern2 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches); // Instance has ext=pdf, pattern doesn't constrain ext
}

// TEST0026: Specificity
- (void)test0026_Specificity {
    // Six-form ladder:
    //   ?x        : 0  (no constraint)
    //   x?=v      : 1  (absent OR not v)
    //   x (=x=*)  : 2  (must-have-any)
    //   x!=v      : 3  (present and not v)
    //   x=v       : 4  (must-have-this-value)
    //   !x        : 5  (must-not-have)
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op" error:&error];          // marker -> 2
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error];     // exact -> 4
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:op;ext=pdf" error:&error];  // 2 + 4 = 6

    XCTAssertEqual([urn1 specificity], 2);
    XCTAssertEqual([urn2 specificity], 4);
    XCTAssertEqual([urn3 specificity], 6);

    BOOL moreSpecific = [urn2 isMoreSpecificThan:urn1 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(moreSpecific); // exact(4) > marker(2)
}

// TEST0027: Directional accepts
- (void)test0027_DirectionalAccepts {
    NSError *error;
    // General pattern accepts specific instance
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(specific);

    BOOL result = [general accepts:specific error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result); // General pattern accepts specific instance

    // Specific does NOT accept general (missing ext in general)
    result = [specific accepts:general error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // Specific pattern requires ext=pdf, general doesn't have it

    // Different values never accept each other
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:extract;ext=pdf" error:&error];
    XCTAssertNotNil(urn3);
    result = [specific accepts:urn3 error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // op mismatch

    result = [urn3 accepts:specific error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // op mismatch
}

// TEST0028: Convenience methods
- (void)test0028_ConvenienceMethods {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf;output=binary;target=thumbnail" error:&error];

    XCTAssertTrue([urn hasMarkerTag:@"generate"]);
    XCTAssertEqualObjects([urn getTag:@"target"], @"thumbnail");
    XCTAssertEqualObjects([urn getTag:@"ext"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");

    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");
}

// TEST0029: Builder
- (void)test0029_Builder {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder marker:@"generate"];
    [builder tag:@"target" value:@"thumbnail"];
    [builder tag:@"ext" value:@"pdf"];
    [builder tag:@"output" value:@"binary"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertTrue([urn hasMarkerTag:@"generate"]);
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");
}

// TEST0030: Builder with custom prefix
- (void)test0030_BuilderWithCustomPrefix {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"custom"];
    [builder tag:@"key" value:@"value"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects(urn.prefix, @"custom");
    XCTAssertEqualObjects([urn toString], @"custom:key=value");
}

// TEST0031: With tag
- (void)test0031_WithTag {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    CSTaggedUrn *modified = [original withTag:@"ext" value:@"pdf"];

    // Alphabetical order: ext, op
    XCTAssertEqualObjects([modified toString], @"cap:ext=pdf;generate");

    // Original should be unchanged
    XCTAssertEqualObjects([original toString], @"cap:generate");
}

// TEST0032: Without tag
- (void)test0032_WithoutTag {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    CSTaggedUrn *modified = [original withoutTag:@"ext"];

    XCTAssertEqualObjects([modified toString], @"cap:generate");

    // Original should be unchanged - alphabetical order: ext, op
    XCTAssertEqualObjects([original toString], @"cap:ext=pdf;generate");
}

// TEST0033: Wildcard tag
- (void)test0033_WildcardTag {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error];
    CSTaggedUrn *wildcarded = [urn withWildcardTag:@"ext"];

    // Wildcard serializes as value-less tag
    XCTAssertEqualObjects([wildcarded toString], @"cap:ext");

    // Test that wildcarded urn can match more requests
    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:ext=jpg" error:&error];
    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches);

    CSTaggedUrn *wildcardRequest = [CSTaggedUrn fromString:@"cap:ext" error:&error];
    matches = [wildcarded conformsTo:wildcardRequest error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);
}

// TEST0034: Subset
- (void)test0034_Subset {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf;output=binary;target=thumbnail" error:&error];
    CSTaggedUrn *subset = [urn subset:@[@"type", @"ext"]];

    XCTAssertEqualObjects([subset toString], @"cap:ext=pdf");
}

// TEST0035: Merge
- (void)test0035_Merge {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:ext=pdf;output=binary" error:&error];
    CSTaggedUrn *merged = [urn1 merge:urn2 error:&error];

    XCTAssertNotNil(merged);
    XCTAssertNil(error);

    // Alphabetical order: ext, op, output
    XCTAssertEqualObjects([merged toString], @"cap:ext=pdf;generate;output=binary");
}

// TEST0036: Merge prefix mismatch
- (void)test0036_MergePrefixMismatch {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"myapp:ext=pdf" error:&error];

    error = nil;
    CSTaggedUrn *merged = [urn1 merge:urn2 error:&error];
    XCTAssertNil(merged);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorPrefixMismatch);
}

// TEST0037: Equality
- (void)test0037_Equality {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:generate" error:&error]; // different order
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:generate;image" error:&error];

    XCTAssertEqualObjects(urn1, urn2); // order doesn't matter
    XCTAssertNotEqualObjects(urn1, urn3);
    XCTAssertEqual([urn1 hash], [urn2 hash]);
}

// TEST0038: Equality different prefix
- (void)test0038_EqualityDifferentPrefix {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"myapp:generate" error:&error];

    XCTAssertNotEqualObjects(urn1, urn2);
}

// TEST0039: Coding
- (void)test0039_Coding {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    XCTAssertNotNil(original);
    XCTAssertNil(error);

    // Test NSCoding
    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:&archiveError];
    XCTAssertNil(archiveError, @"Archive should succeed");
    XCTAssertNotNil(data);

    NSError *unarchiveError = nil;
    CSTaggedUrn *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CSTaggedUrn class] fromData:data error:&unarchiveError];
    XCTAssertNil(unarchiveError, @"Unarchive should succeed");
    XCTAssertNotNil(decoded);
    XCTAssertEqualObjects(original, decoded);
}

// TEST0040: Coding with custom prefix
- (void)test0040_CodingWithCustomPrefix {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"myapp:key=value" error:&error];
    XCTAssertNotNil(original);
    XCTAssertNil(error);

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:&archiveError];
    XCTAssertNil(archiveError);
    XCTAssertNotNil(data);

    NSError *unarchiveError = nil;
    CSTaggedUrn *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CSTaggedUrn class] fromData:data error:&unarchiveError];
    XCTAssertNil(unarchiveError);
    XCTAssertNotNil(decoded);
    XCTAssertEqualObjects(original, decoded);
    XCTAssertEqualObjects(decoded.prefix, @"myapp");
}

// TEST0041: Copying
- (void)test0041_Copying {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    CSTaggedUrn *copy = [original copy];

    XCTAssertEqualObjects(original, copy);
    XCTAssertNotEqual(original, copy); // Different objects
}

#pragma mark - New Rule Tests

// TEST0042: Empty tagged urn
- (void)test0042_EmptyTaggedUrn {
    // Empty tagged URN is valid
    NSError *error = nil;
    CSTaggedUrn *empty = [CSTaggedUrn fromString:@"cap:" error:&error];
    XCTAssertNotNil(empty);
    XCTAssertNil(error);
    XCTAssertEqual(empty.tags.count, 0);
    XCTAssertEqualObjects([empty toString], @"cap:");

    // NEW SEMANTICS:
    // Empty PATTERN matches any INSTANCE (pattern has no constraints)
    // Empty INSTANCE only matches patterns that have no required tags
    error = nil;
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];

    // Empty instance vs specific pattern: NO MATCH
    BOOL matches = [empty conformsTo:specific error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches); // Empty instance doesn't match pattern with requirements

    // Specific instance vs empty pattern: MATCH
    matches = [specific conformsTo:empty error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches); // Instance matches empty pattern

    // Empty instance vs empty pattern: MATCH
    matches = [empty conformsTo:empty error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);
}

// TEST0043: Empty with custom prefix
- (void)test0043_EmptyWithCustomPrefix {
    NSError *error = nil;
    CSTaggedUrn *empty = [CSTaggedUrn fromString:@"myapp:" error:&error];
    XCTAssertNotNil(empty);
    XCTAssertNil(error);
    XCTAssertEqualObjects(empty.prefix, @"myapp");
    XCTAssertEqualObjects([empty toString], @"myapp:");
}

// TEST0044: Empty with prefix method
- (void)test0044_EmptyWithPrefixMethod {
    CSTaggedUrn *empty = [CSTaggedUrn emptyWithPrefix:@"custom"];
    XCTAssertNotNil(empty);
    XCTAssertEqualObjects(empty.prefix, @"custom");
    XCTAssertEqual(empty.tags.count, 0);
    XCTAssertEqualObjects([empty toString], @"custom:");
}

// TEST0045: Extended character support
- (void)test0045_ExtendedCharacterSupport {
    NSError *error = nil;
    // Test forward slashes and colons in tag components
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:url=https://example_org/api;path=/some/file" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"url"], @"https://example_org/api");
    XCTAssertEqualObjects([urn getTag:@"path"], @"/some/file");
}

// TEST0046: Wildcard restrictions
- (void)test0046_WildcardRestrictions {
    NSError *error = nil;
    // Wildcard should be rejected in keys
    CSTaggedUrn *invalidKey = [CSTaggedUrn fromString:@"cap:*=value" error:&error];
    XCTAssertNil(invalidKey);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidCharacter);

    // Reset error for next test
    error = nil;

    // Wildcard should be accepted in values
    CSTaggedUrn *validValue = [CSTaggedUrn fromString:@"cap:key=*" error:&error];
    XCTAssertNotNil(validValue);
    XCTAssertNil(error);
    XCTAssertEqualObjects([validValue getTag:@"key"], @"*");
}

// TEST0047: Duplicate key rejection
- (void)test0047_DuplicateKeyRejection {
    NSError *error = nil;
    // Duplicate keys should be rejected
    CSTaggedUrn *duplicate = [CSTaggedUrn fromString:@"cap:key=value1;key=value2" error:&error];
    XCTAssertNil(duplicate);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorDuplicateKey);
}

// TEST0048: Numeric key restriction
- (void)test0048_NumericKeyRestriction {
    NSError *error = nil;

    // Pure numeric keys should be rejected
    CSTaggedUrn *numericKey = [CSTaggedUrn fromString:@"cap:123=value" error:&error];
    XCTAssertNil(numericKey);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorNumericKey);

    // Reset error for next test
    error = nil;

    // Mixed alphanumeric keys should be allowed
    CSTaggedUrn *mixedKey1 = [CSTaggedUrn fromString:@"cap:key123=value" error:&error];
    XCTAssertNotNil(mixedKey1);
    XCTAssertNil(error);

    error = nil;
    CSTaggedUrn *mixedKey2 = [CSTaggedUrn fromString:@"cap:123key=value" error:&error];
    XCTAssertNotNil(mixedKey2);
    XCTAssertNil(error);

    error = nil;
    // Pure numeric values should be allowed
    CSTaggedUrn *numericValue = [CSTaggedUrn fromString:@"cap:key=123" error:&error];
    XCTAssertNotNil(numericValue);
    XCTAssertNil(error);
    XCTAssertEqualObjects([numericValue getTag:@"key"], @"123");
}

#pragma mark - Quoted Value Tests

// TEST0049: Unquoted values lowercased
- (void)test0049_UnquotedValuesLowercased {
    NSError *error = nil;
    // Unquoted values are normalized to lowercase
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:ext=pdf;generate;target=thumbnail;" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // Keys are always lowercase
    XCTAssertTrue([urn hasMarkerTag:@"generate"]);
    XCTAssertEqualObjects([urn getTag:@"ext"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"target"], @"thumbnail");

    // Key lookup is case-insensitive (uppercase variants of an existing key resolve correctly).
    XCTAssertEqualObjects([urn getTag:@"EXT"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"Ext"], @"pdf");

    // The same URN written with different case parses to the same canonical form.
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:Ext=PDF;Generate;Target=Thumbnail;" error:&error];
    XCTAssertEqualObjects([urn toString], [urn2 toString]);
    XCTAssertEqualObjects(urn, urn2);
}

// TEST0050: Quoted values preserve case
- (void)test0050_QuotedValuesPreserveCase {
    NSError *error = nil;
    // Quoted values preserve their case
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"Value With Spaces\"" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"key"], @"Value With Spaces");

    // Key is still lowercase
    error = nil;
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:KEY=\"Value With Spaces\"" error:&error];
    XCTAssertNotNil(urn2);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn2 getTag:@"key"], @"Value With Spaces");

    // Unquoted vs quoted case difference
    error = nil;
    CSTaggedUrn *unquoted = [CSTaggedUrn fromString:@"cap:key=UPPERCASE" error:&error];
    XCTAssertNotNil(unquoted);
    error = nil;
    CSTaggedUrn *quoted = [CSTaggedUrn fromString:@"cap:key=\"UPPERCASE\"" error:&error];
    XCTAssertNotNil(quoted);

    XCTAssertEqualObjects([unquoted getTag:@"key"], @"uppercase"); // lowercase
    XCTAssertEqualObjects([quoted getTag:@"key"], @"UPPERCASE"); // preserved
    XCTAssertNotEqualObjects(unquoted, quoted); // NOT equal
}

// TEST0051: Quoted value special chars
- (void)test0051_QuotedValueSpecialChars {
    NSError *error = nil;
    // Semicolons in quoted values
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"value;with;semicolons\"" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"key"], @"value;with;semicolons");

    // Equals in quoted values
    error = nil;
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:key=\"value=with=equals\"" error:&error];
    XCTAssertNotNil(urn2);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn2 getTag:@"key"], @"value=with=equals");

    // Spaces in quoted values
    error = nil;
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:key=\"hello world\"" error:&error];
    XCTAssertNotNil(urn3);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn3 getTag:@"key"], @"hello world");
}

// TEST0052: Quoted value escape sequences
- (void)test0052_QuotedValueEscapeSequences {
    NSError *error = nil;
    // Escaped quotes
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"value\\\"quoted\\\"\"" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"key"], @"value\"quoted\"");

    // Escaped backslashes
    error = nil;
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:key=\"path\\\\file\"" error:&error];
    XCTAssertNotNil(urn2);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn2 getTag:@"key"], @"path\\file");
}

// TEST0053: Mixed quoted unquoted
- (void)test0053_MixedQuotedUnquoted {
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:a=\"Quoted\";b=simple" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"a"], @"Quoted");
    XCTAssertEqualObjects([urn getTag:@"b"], @"simple");
}

// TEST0054: Unterminated quote error
- (void)test0054_UnterminatedQuoteError {
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"unterminated" error:&error];
    XCTAssertNil(urn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorUnterminatedQuote);
}

// TEST0055: Invalid escape sequence error
- (void)test0055_InvalidEscapeSequenceError {
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"bad\\n\"" error:&error];
    XCTAssertNil(urn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidEscapeSequence);
}

// TEST0056: Serialization smart quoting
- (void)test0056_SerializationSmartQuoting {
    NSError *error = nil;
    // Simple lowercase value - no quoting needed
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"key" value:@"simple"];
    CSTaggedUrn *urn = [builder build:&error];
    XCTAssertNotNil(urn);
    XCTAssertEqualObjects([urn toString], @"cap:key=simple");

    // Value with spaces - needs quoting
    builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"key" value:@"has spaces"];
    CSTaggedUrn *urn2 = [builder build:&error];
    XCTAssertNotNil(urn2);
    XCTAssertEqualObjects([urn2 toString], @"cap:key=\"has spaces\"");

    // Value with uppercase - needs quoting to preserve
    builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"key" value:@"HasUpper"];
    CSTaggedUrn *urn3 = [builder build:&error];
    XCTAssertNotNil(urn3);
    XCTAssertEqualObjects([urn3 toString], @"cap:key=\"HasUpper\"");

    // Value with quotes - needs quoting and escaping
    builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"key" value:@"has\"quote"];
    CSTaggedUrn *urn4 = [builder build:&error];
    XCTAssertNotNil(urn4);
    XCTAssertEqualObjects([urn4 toString], @"cap:key=\"has\\\"quote\"");
}

// TEST0057: Round trip simple
- (void)test0057_RoundTripSimple {
    NSError *error = nil;
    NSString *original = @"cap:generate;ext=pdf";
    CSTaggedUrn *urn = [CSTaggedUrn fromString:original error:&error];
    XCTAssertNotNil(urn);
    NSString *serialized = [urn toString];
    CSTaggedUrn *reparsed = [CSTaggedUrn fromString:serialized error:&error];
    XCTAssertNotNil(reparsed);
    XCTAssertEqualObjects(urn, reparsed);
}

// TEST0058: Round trip quoted
- (void)test0058_RoundTripQuoted {
    NSError *error = nil;
    NSString *original = @"cap:key=\"Value With Spaces\"";
    CSTaggedUrn *urn = [CSTaggedUrn fromString:original error:&error];
    XCTAssertNotNil(urn);
    NSString *serialized = [urn toString];
    CSTaggedUrn *reparsed = [CSTaggedUrn fromString:serialized error:&error];
    XCTAssertNotNil(reparsed);
    XCTAssertEqualObjects(urn, reparsed);
    XCTAssertEqualObjects([reparsed getTag:@"key"], @"Value With Spaces");
}

// TEST0059: Has tag case sensitive
- (void)test0059_HasTagCaseSensitive {
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"Value\"" error:&error];
    XCTAssertNotNil(urn);

    // Exact case match works
    XCTAssertTrue([urn hasTag:@"key" withValue:@"Value"]);

    // Different case does not match
    XCTAssertFalse([urn hasTag:@"key" withValue:@"value"]);
    XCTAssertFalse([urn hasTag:@"key" withValue:@"VALUE"]);

    // Key lookup is case-insensitive
    XCTAssertTrue([urn hasTag:@"KEY" withValue:@"Value"]);
    XCTAssertTrue([urn hasTag:@"Key" withValue:@"Value"]);
}

// TEST0060: Builder preserves case
- (void)test0060_BuilderPreservesCase {
    NSError *error = nil;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"KEY" value:@"ValueWithCase"];
    CSTaggedUrn *urn = [builder build:&error];
    XCTAssertNotNil(urn);

    // Key is lowercase
    XCTAssertEqualObjects([urn getTag:@"key"], @"ValueWithCase");

    // Value case preserved, so needs quoting
    XCTAssertEqualObjects([urn toString], @"cap:key=\"ValueWithCase\"");
}

// TEST0061: Semantic equivalence
- (void)test0061_SemanticEquivalence {
    NSError *error = nil;
    // Unquoted and quoted simple lowercase values are equivalent
    CSTaggedUrn *unquoted = [CSTaggedUrn fromString:@"cap:key=simple" error:&error];
    XCTAssertNotNil(unquoted);
    CSTaggedUrn *quoted = [CSTaggedUrn fromString:@"cap:key=\"simple\"" error:&error];
    XCTAssertNotNil(quoted);
    XCTAssertEqualObjects(unquoted, quoted);

    // Both serialize the same way (unquoted)
    XCTAssertEqualObjects([unquoted toString], @"cap:key=simple");
    XCTAssertEqualObjects([quoted toString], @"cap:key=simple");
}

// TEST0062: Matching different prefixes error
- (void)test0062_MatchingDifferentPrefixesError {
    NSError *error = nil;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:test" error:&error];
    XCTAssertNotNil(urn1);
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"other:test" error:&error];
    XCTAssertNotNil(urn2);

    error = nil;
    [urn1 conformsTo:urn2 error:&error];
    XCTAssertNotNil(error);

    error = nil;
    [urn1 accepts:urn2 error:&error];
    XCTAssertNotNil(error);

    error = nil;
    [urn1 isMoreSpecificThan:urn2 error:&error];
    XCTAssertNotNil(error);
}

#pragma mark - Matching Semantics Specification Tests

// ============================================================================
// These 9 tests verify the exact matching semantics from RULES.md Sections 12-17
// All implementations (Rust, Go, JS, ObjC) must pass these identically
// ============================================================================

- (void)test0063_MatchingSemantics_Test1_ExactMatch {
    // Test 1: Exact match
    // URN:     cap:generate;ext=pdf
    // Request: cap:generate;ext=pdf
    // Result:  MATCH
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 1: Exact match should succeed");
}

// TEST0064: Matching semantics  test2  instance missing tag
- (void)test0064_MatchingSemantics_Test2_InstanceMissingTag {
    // Test 2: Instance missing tag
    // Instance: cap:generate;in=media:;out=media:
    // Pattern:  cap:generate;ext=pdf
    // Result:   NO MATCH (pattern requires ext=pdf, instance doesn't have ext)
    //
    // NEW SEMANTICS: Missing tag in instance means it doesn't exist.
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(pattern);

    BOOL matches = [instance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 2: Instance missing tag should NOT match when pattern requires it");

    // To accept any ext (or missing), use pattern with ext=?
    CSTaggedUrn *patternOptional = [CSTaggedUrn fromString:@"cap:generate;ext=?" error:&error];
    XCTAssertNotNil(patternOptional);
    matches = [instance conformsTo:patternOptional error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Pattern with ext=? should match instance without ext");
}

// TEST0065: Matching semantics  test3  urn has extra tag
- (void)test0065_MatchingSemantics_Test3_UrnHasExtraTag {
    // Test 3: URN has extra tag
    // URN:     cap:generate;ext=pdf;version=2
    // Request: cap:generate;ext=pdf
    // Result:  MATCH (request doesn't constrain version)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf;version=2" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 3: URN with extra tag should match");
}

// TEST0066: Matching semantics  test4  request has wildcard
- (void)test0066_MatchingSemantics_Test4_RequestHasWildcard {
    // Test 4: Request has wildcard
    // URN:     cap:generate;ext=pdf
    // Request: cap:generate;ext=*
    // Result:  MATCH (request accepts any ext)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:generate;ext=*" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 4: Request wildcard should match");
}

// TEST0067: Matching semantics  test5  urn has wildcard
- (void)test0067_MatchingSemantics_Test5_UrnHasWildcard {
    // An instance's wildcard promises presence, not the value asked for:
    // "some ext" does not satisfy ext=pdf, and a pdf satisfies "some ext".
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=*" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"some ext does not satisfy ext=pdf");
    matches = [request conformsTo:urn error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"ext=pdf satisfies some ext");
}

// TEST0068: Matching semantics  test6  value mismatch
- (void)test0068_MatchingSemantics_Test6_ValueMismatch {
    // Test 6: Value mismatch
    // URN:     cap:generate;ext=pdf
    // Request: cap:generate;ext=docx
    // Result:  NO MATCH
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:generate;ext=docx" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 6: Value mismatch should not match");
}

// TEST0069: Matching semantics  test7  pattern has extra tag
- (void)test0069_MatchingSemantics_Test7_PatternHasExtraTag {
    // Test 7: Pattern has extra tag that instance doesn't have
    // Instance: cap:generate-thumbnail;out="media:binary"
    // Pattern:  cap:ext=wav;generate-thumbnail;out="media:binary"
    // Result:   NO MATCH (pattern requires ext=wav, instance doesn't have ext)
    //
    // NEW SEMANTICS: Pattern K=v requires instance to have K=v
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:generate-thumbnail;out=\"media:binary\"" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:ext=wav;generate-thumbnail;out=\"media:binary\"" error:&error];
    XCTAssertNotNil(pattern);

    BOOL matches = [instance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 7: Instance missing ext should NOT match when pattern requires ext=wav");
}

// TEST0070: Matching semantics  test8  empty pattern matches anything
- (void)test0070_MatchingSemantics_Test8_EmptyPatternMatchesAnything {
    // Test 8: Empty PATTERN matches any INSTANCE
    // Instance: cap:generate;ext=pdf
    // Pattern:  cap:
    // Result:   MATCH (pattern has no constraints)
    //
    // NEW SEMANTICS: Empty pattern = no constraints = matches any instance
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *emptyPattern = [CSTaggedUrn fromString:@"cap:" error:&error];
    XCTAssertNotNil(emptyPattern);

    BOOL matches = [instance conformsTo:emptyPattern error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 8: Any instance should match empty pattern");

    // Empty instance vs pattern with requirements: NO MATCH
    CSTaggedUrn *emptyInstance = [CSTaggedUrn fromString:@"cap:" error:&error];
    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    matches = [emptyInstance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Empty instance should NOT match pattern with requirements");
}

// TEST0071: Matching semantics  test9  cross dimension constraints
- (void)test0071_MatchingSemantics_Test9_CrossDimensionConstraints {
    // Test 9: Cross-dimension constraints
    // Instance: cap:generate;in=media:;out=media:
    // Pattern:  cap:ext=pdf
    // Result:   NO MATCH (pattern requires ext=pdf, instance doesn't have ext)
    //
    // NEW SEMANTICS: Pattern K=v requires instance to have K=v
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:generate" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error];
    XCTAssertNotNil(pattern);

    BOOL matches = [instance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 9: Instance without ext should NOT match pattern requiring ext");

    // Instance with ext vs pattern with different tag only: MATCH
    CSTaggedUrn *instance2 = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    CSTaggedUrn *pattern2 = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error];
    matches = [instance2 conformsTo:pattern2 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Instance with ext=pdf should match pattern requiring ext=pdf");
}

#pragma mark - Value-less Tag Tests

// ============================================================================
// VALUE-LESS TAG TESTS
// Value-less tags are equivalent to wildcard tags (key=*)
// ============================================================================

- (void)test0072_ValuelessTagParsingSingle {
    // Single value-less tag
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:optimize" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    // Serializes as value-less (no =*)
    XCTAssertEqualObjects([urn toString], @"cap:optimize");
}

// TEST0073: Valueless tag parsing multiple
- (void)test0073_ValuelessTagParsingMultiple {
    // Multiple value-less tags
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:fast;optimize;secure" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"fast"], @"*");
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([urn getTag:@"secure"], @"*");
    // Serializes alphabetically as value-less
    XCTAssertEqualObjects([urn toString], @"cap:fast;optimize;secure");
}

// TEST0074: Valueless tag mixed with valued
- (void)test0074_ValuelessTagMixedWithValued {
    // Mix of value-less and valued tags
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;optimize;ext=pdf;secure" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertTrue([urn hasMarkerTag:@"generate"]);
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([urn getTag:@"ext"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"secure"], @"*");
    // Serializes alphabetically
    XCTAssertEqualObjects([urn toString], @"cap:ext=pdf;generate;optimize;secure");
}

// TEST0075: Valueless tag at end
- (void)test0075_ValuelessTagAtEnd {
    // Value-less tag at the end (no trailing semicolon)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;optimize" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertTrue([urn hasMarkerTag:@"generate"]);
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([urn toString], @"cap:generate;optimize");
}

// TEST0076: Valueless tag equivalence to wildcard
- (void)test0076_ValuelessTagEquivalenceToWildcard {
    // Value-less tag is equivalent to explicit wildcard
    NSError *error = nil;
    CSTaggedUrn *valueless = [CSTaggedUrn fromString:@"cap:ext" error:&error];
    XCTAssertNotNil(valueless);
    CSTaggedUrn *wildcard = [CSTaggedUrn fromString:@"cap:ext=*" error:&error];
    XCTAssertNotNil(wildcard);
    XCTAssertEqualObjects(valueless, wildcard);
    // Both serialize to value-less form
    XCTAssertEqualObjects([valueless toString], @"cap:ext");
    XCTAssertEqualObjects([wildcard toString], @"cap:ext");
}

// TEST0077: Valueless tag matching
- (void)test0077_ValuelessTagMatching {
    // A valueless tag promises presence, not a value. Reading `ext` as
    // "whatever the pattern wants" made `ext` and `ext=pdf` equivalent and
    // refinement non-transitive; refinement is inclusion of what each form
    // allows (tagged-urn formal, `tagMatch_iff_allows`).
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:generate;ext" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *requestPdf = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    CSTaggedUrn *requestDocx = [CSTaggedUrn fromString:@"cap:generate;ext=docx" error:&error];

    BOOL matches;
    matches = [urn conformsTo:requestPdf error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"some ext is not a promise of pdf");

    matches = [urn conformsTo:requestDocx error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"some ext is not a promise of docx");

    matches = [requestPdf conformsTo:urn error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"a pdf is some ext");

    XCTAssertFalse([urn isEquivalentTo:requestPdf error:&error], @"ext and ext=pdf are different tag sets");
    XCTAssertNil(error);
}

// TEST0078: Valueless tag in pattern
- (void)test0078_ValuelessTagInPattern {
    // Pattern with value-less tag (K=*) requires instance to have the tag
    NSError *error = nil;
    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:generate;ext" error:&error];
    XCTAssertNotNil(pattern);

    CSTaggedUrn *instancePdf = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    CSTaggedUrn *instanceDocx = [CSTaggedUrn fromString:@"cap:generate;ext=docx" error:&error];
    CSTaggedUrn *instanceMissing = [CSTaggedUrn fromString:@"cap:generate" error:&error];

    BOOL matches;
    // NEW SEMANTICS: K=* (valueless tag) means must-have-any
    matches = [instancePdf conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches); // Has ext=pdf

    matches = [instanceDocx conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches); // Has ext=docx

    matches = [instanceMissing conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches); // Missing ext, pattern requires it

    // To accept missing ext, use ? instead
    CSTaggedUrn *patternOptional = [CSTaggedUrn fromString:@"cap:generate;ext=?" error:&error];
    XCTAssertNotNil(patternOptional);
    matches = [instanceMissing conformsTo:patternOptional error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);
}

// TEST0079: Valueless tag specificity
- (void)test0079_ValuelessTagSpecificity {
    // Six-form ladder: ?x=0, x?=v=1, x=*=2, x!=v=3, x=v=4, !x=5.
    NSError *error = nil;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:generate" error:&error];          // 1 marker
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:generate;optimize" error:&error]; // 2 markers
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];  // 1 marker + 1 exact

    XCTAssertEqual([urn1 specificity], 2);  // 1 marker = 2
    XCTAssertEqual([urn2 specificity], 4);  // 2 markers = 2 + 2 = 4
    XCTAssertEqual([urn3 specificity], 6);  // 1 marker + 1 exact = 2 + 4 = 6
}

// TEST0080: Valueless tag roundtrip
- (void)test0080_ValuelessTagRoundtrip {
    // Round-trip parsing and serialization
    NSError *error = nil;
    NSString *original = @"cap:ext=pdf;generate;optimize;secure";
    CSTaggedUrn *urn = [CSTaggedUrn fromString:original error:&error];
    XCTAssertNotNil(urn);
    NSString *serialized = [urn toString];
    CSTaggedUrn *reparsed = [CSTaggedUrn fromString:serialized error:&error];
    XCTAssertNotNil(reparsed);
    XCTAssertEqualObjects(urn, reparsed);
    XCTAssertEqualObjects(serialized, original);
}

// TEST0081: Valueless tag case normalization
- (void)test0081_ValuelessTagCaseNormalization {
    // Value-less tags are normalized to lowercase like other keys
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:OPTIMIZE;Fast;SECURE" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([urn getTag:@"fast"], @"*");
    XCTAssertEqualObjects([urn getTag:@"secure"], @"*");
    XCTAssertEqualObjects([urn toString], @"cap:fast;optimize;secure");
}

// TEST0082: Empty value still error
- (void)test0082_EmptyValueStillError {
    // Empty value with = is still an error (different from value-less)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=" error:&error];
    XCTAssertNil(urn);
    XCTAssertNotNil(error);

    error = nil;
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:key=;other=value" error:&error];
    XCTAssertNil(urn2);
    XCTAssertNotNil(error);
}

// TEST0083: Valueless tag directional accepts
- (void)test0083_ValuelessTagDirectionalAccepts {
    // Value-less tag (wildcard pattern) accepts any value
    NSError *error = nil;
    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:generate;ext" error:&error];
    XCTAssertNotNil(pattern);
    CSTaggedUrn *instancePdf = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(instancePdf);
    CSTaggedUrn *instanceDocx = [CSTaggedUrn fromString:@"cap:generate;ext=docx" error:&error];
    XCTAssertNotNil(instanceDocx);

    BOOL result;
    // Wildcard pattern accepts specific instances
    result = [pattern accepts:instancePdf error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    result = [pattern accepts:instanceDocx error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);

    // Specific instance does NOT accept different specific instance
    result = [instancePdf accepts:instanceDocx error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // ext=pdf does not accept ext=docx

    result = [instanceDocx accepts:instancePdf error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // ext=docx does not accept ext=pdf
}

// TEST0084: Valueless numeric key still rejected
- (void)test0084_ValuelessNumericKeyStillRejected {
    // Purely numeric keys are still rejected for value-less tags
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:123" error:&error];
    XCTAssertNil(urn);
    XCTAssertNotNil(error);

    error = nil;
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:generate;456" error:&error];
    XCTAssertNil(urn2);
    XCTAssertNotNil(error);
}

#pragma mark - Order-Theoretic Relations Tests

// TEST578: Equivalent URNs with identical tag sets
- (void)test578_equivalentIdenticalTags {
    NSError *error = nil;
    CSTaggedUrn *a = [CSTaggedUrn fromString:@"cap:generate;ext=pdf" error:&error];
    XCTAssertNotNil(a);
    CSTaggedUrn *b = [CSTaggedUrn fromString:@"cap:ext=pdf;generate" error:&error]; // same tags, different order
    XCTAssertNotNil(b);

    XCTAssertTrue([a isEquivalentTo:b error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([b isEquivalentTo:a error:&error]); // symmetric
    XCTAssertNil(error);
}

// TEST579: Non-equivalent URNs where one is more specific
- (void)test579_notEquivalentWhenOneMoreSpecific {
    NSError *error = nil;
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"media:" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"media:pdf" error:&error];
    XCTAssertNotNil(specific);

    XCTAssertFalse([general isEquivalentTo:specific error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([specific isEquivalentTo:general error:&error]);
    XCTAssertNil(error);
}

// TEST580: Comparable URNs on the same specialization chain
- (void)test580_comparableSpecializationChain {
    NSError *error = nil;
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"media:" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"media:pdf" error:&error];
    XCTAssertNotNil(specific);

    // general.accepts(specific) = true (wildcard ⊆ pdf)
    // specific.accepts(general) = false (pdf missing from general)
    // OR → true
    XCTAssertTrue([general isComparableTo:specific error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([specific isComparableTo:general error:&error]); // symmetric
    XCTAssertNil(error);
}

// TEST581: Incomparable URNs in different branches of the lattice
- (void)test581_incomparableDifferentBranches {
    NSError *error = nil;
    CSTaggedUrn *pdf = [CSTaggedUrn fromString:@"media:pdf" error:&error];
    XCTAssertNotNil(pdf);
    CSTaggedUrn *txt = [CSTaggedUrn fromString:@"media:txt;textable" error:&error];
    XCTAssertNotNil(txt);

    // pdf.accepts(txt) = false (pdf missing from txt)
    // txt.accepts(pdf) = false (txt missing from pdf)
    // OR → false
    XCTAssertFalse([pdf isComparableTo:txt error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([txt isComparableTo:pdf error:&error]);
    XCTAssertNil(error);
}

// TEST582: Equivalent implies comparable but not vice versa
- (void)test582_equivalentImpliesComparable {
    NSError *error = nil;
    CSTaggedUrn *a = [CSTaggedUrn fromString:@"cap:test;ext=pdf" error:&error];
    XCTAssertNotNil(a);
    CSTaggedUrn *b = [CSTaggedUrn fromString:@"cap:test;ext=pdf" error:&error];
    XCTAssertNotNil(b);

    // equivalent → comparable (AND implies OR)
    XCTAssertTrue([a isEquivalentTo:b error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([a isComparableTo:b error:&error]);
    XCTAssertNil(error);

    // comparable but NOT equivalent
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"cap:test" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"cap:test;ext=pdf" error:&error];
    XCTAssertNotNil(specific);

    XCTAssertFalse([general isEquivalentTo:specific error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([general isComparableTo:specific error:&error]);
    XCTAssertNil(error);
}

// TEST583: Prefix mismatch returns error for both relations
- (void)test583_prefixMismatchErrors {
    NSError *error = nil;
    CSTaggedUrn *cap = [CSTaggedUrn fromString:@"cap:test" error:&error];
    XCTAssertNotNil(cap);
    CSTaggedUrn *media = [CSTaggedUrn fromString:@"media:" error:&error];
    XCTAssertNotNil(media);

    error = nil;
    [cap isEquivalentTo:media error:&error];
    XCTAssertNotNil(error);

    error = nil;
    [cap isComparableTo:media error:&error];
    XCTAssertNotNil(error);
}

// TEST584: Empty tag set is comparable to everything with same prefix
- (void)test584_emptyTagsComparableToAll {
    NSError *error = nil;
    CSTaggedUrn *empty = [CSTaggedUrn fromString:@"media:" error:&error];
    XCTAssertNotNil(empty);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"media:pdf;thumbnail" error:&error];
    XCTAssertNotNil(specific);

    // empty.accepts(specific) = true (empty has no constraints)
    XCTAssertTrue([empty isComparableTo:specific error:&error]);
    XCTAssertNil(error);
    // but NOT equivalent (specific has tags empty doesn't)
    XCTAssertFalse([empty isEquivalentTo:specific error:&error]);
    XCTAssertNil(error);
    // empty is equivalent to itself
    CSTaggedUrn *empty2 = [CSTaggedUrn fromString:@"media:" error:&error];
    XCTAssertNotNil(empty2);
    XCTAssertTrue([empty isEquivalentTo:empty2 error:&error]);
    XCTAssertNil(error);
}

// TEST586: Special values (*, !, ?) with isEquivalent and isComparable
- (void)test586_specialValues {
    NSError *error = nil;
    CSTaggedUrn *mustHave = [CSTaggedUrn fromString:@"cap:ext" error:&error]; // ext=*
    XCTAssertNotNil(mustHave);
    CSTaggedUrn *exact = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error]; // ext=pdf
    XCTAssertNotNil(exact);
    CSTaggedUrn *mustNot = [CSTaggedUrn fromString:@"cap:ext=!" error:&error]; // ext=!
    XCTAssertNotNil(mustNot);
    CSTaggedUrn *unspecified = [CSTaggedUrn fromString:@"cap:ext=?" error:&error]; // ext=?
    XCTAssertNotNil(unspecified);

    // must_have (*) and exact (pdf): comparable — a pdf is some ext — and
    // NOT equivalent: equivalence is "the same tag set" (tagged-urn formal,
    // `equivalent_iff_same_forms`).
    XCTAssertFalse([mustHave isEquivalentTo:exact error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([mustHave isComparableTo:exact error:&error]);
    XCTAssertNil(error);

    // must_not (!) and exact (pdf): incomparable (conflict both directions)
    XCTAssertFalse([mustNot isComparableTo:exact error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([mustNot isEquivalentTo:exact error:&error]);
    XCTAssertNil(error);

    // must_not (!) and must_have (*): incomparable (conflict both directions)
    XCTAssertFalse([mustNot isComparableTo:mustHave error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([mustNot isEquivalentTo:mustHave error:&error]);
    XCTAssertNil(error);

    // unspecified (?) accepts everything, and is equivalent only to what
    // also constrains nothing.
    XCTAssertFalse([unspecified isEquivalentTo:exact error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([unspecified isEquivalentTo:mustHave error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([unspecified isEquivalentTo:mustNot error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([unspecified isComparableTo:exact error:&error]);
    XCTAssertNil(error);
    CSTaggedUrn *empty = [CSTaggedUrn fromString:@"cap:" error:&error];
    XCTAssertTrue([unspecified isEquivalentTo:empty error:&error]);
    XCTAssertNil(error);
}

// TEST599: every row of the proved model's table.
//
// The rules are proved in ../formal (Lean); this is what ties them to this
// mirror: every row of ../formal/conformance.json (written by the model,
// `lake exe conformance`) is parsed by this parser and must get the model's
// verdict — for the guarantee (conformsTo), the possibility (meets), and the
// complete reading of the instance (satisfies, maySatisfy). The same table runs
// in every mirror.
- (void)test599_everyRowOfTheModelsTable {
    NSString *here = [NSString stringWithUTF8String:__FILE__];
    NSString *path = here;
    for (int i = 0; i < 4; i++) path = [path stringByDeletingLastPathComponent];
    path = [[path stringByAppendingPathComponent:@"formal"] stringByAppendingPathComponent:@"conformance.json"];
    NSData *raw = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(raw, @"the model's table at %@", path);
    NSDictionary *table = [NSJSONSerialization JSONObjectWithData:raw options:0 error:nil];
    NSArray *refines = table[@"refines"];
    NSArray *scores = table[@"scores"];
    NSMutableArray *wrong = [NSMutableArray array];
    NSError *error = nil;
    for (NSDictionary *row in refines) {
        CSTaggedUrn *a = [CSTaggedUrn fromString:row[@"instance"] error:&error];
        CSTaggedUrn *b = [CSTaggedUrn fromString:row[@"pattern"] error:&error];
        XCTAssertNotNil(a);
        XCTAssertNotNil(b);
        if ([a conformsTo:b error:&error] != [row[@"refines"] boolValue]) {
            [wrong addObject:[NSString stringWithFormat:@"%@ ⪯ %@: model %@", row[@"instance"], row[@"pattern"], row[@"refines"]]];
        }
        if ([a isEquivalentTo:b error:&error] != [row[@"equivalent"] boolValue]) {
            [wrong addObject:[NSString stringWithFormat:@"%@ ≡ %@: model %@", row[@"instance"], row[@"pattern"], row[@"equivalent"]]];
        }
        if ([a meets:b error:&error] != [row[@"meets"] boolValue]) {
            [wrong addObject:[NSString stringWithFormat:@"%@ meets %@: model %@", row[@"instance"], row[@"pattern"], row[@"meets"]]];
        }
        if ([a satisfies:b error:&error] != [row[@"satisfies"] boolValue]) {
            [wrong addObject:[NSString stringWithFormat:@"%@ satisfies %@: model %@", row[@"instance"], row[@"pattern"], row[@"satisfies"]]];
        }
        if ([a maySatisfy:b error:&error] != [row[@"may_satisfy"] boolValue]) {
            [wrong addObject:[NSString stringWithFormat:@"%@ may satisfy %@: model %@", row[@"instance"], row[@"pattern"], row[@"may_satisfy"]]];
        }
    }
    for (NSDictionary *row in scores) {
        CSTaggedUrn *u = [CSTaggedUrn fromString:row[@"urn"] error:&error];
        if ((NSInteger)[u specificity] != [row[@"score"] integerValue]) {
            [wrong addObject:[NSString stringWithFormat:@"specificity %@: model %@", row[@"urn"], row[@"score"]]];
        }
    }
    XCTAssertTrue(refines.count > 4000 && scores.count > 60, @"the table is the full one");
    XCTAssertEqual(wrong.count, 0u, @"%lu answer(s) differ from the model, e.g. %@",
                   (unsigned long)wrong.count,
                   [wrong subarrayWithRange:NSMakeRange(0, MIN(8u, wrong.count))]);
}

// TEST587: Delta equivalent preserves runtime refinement
- (void)test587_deltaEquivalentPreservesRuntimeRefinement {
    NSError *error = nil;
    CSTaggedUrn *base = [CSTaggedUrn fromString:@"media:image;png" error:&error];
    XCTAssertNotNil(base);
    CSTaggedUrn *target = [CSTaggedUrn fromString:@"media:image;png" error:&error];
    XCTAssertNotNil(target);
    CSTaggedUrn *runtime = [CSTaggedUrn fromString:@"media:image;png;thumbnail" error:&error];
    XCTAssertNotNil(runtime);

    CSTaggedUrnCoordinateDelta *delta = [target deltaFrom:base error:&error];
    XCTAssertNotNil(delta);
    XCTAssertNil(error);
    XCTAssertEqual(delta.relationKind, CSTaggedUrnRelationKindEquivalent);
    XCTAssertTrue([delta isEmpty]);

    CSTaggedUrn *applied = [runtime applyDelta:delta error:&error];
    XCTAssertNotNil(applied);
    XCTAssertNil(error);
    XCTAssertEqualObjects([applied toString], @"media:image;png;thumbnail");
}

// TEST588: Delta incomparable replacement preserves unrelated refinement
- (void)test588_deltaIncomparableReplacementPreservesUnrelatedRefinement {
    NSError *error = nil;
    CSTaggedUrn *base = [CSTaggedUrn fromString:@"media:image;png" error:&error];
    XCTAssertNotNil(base);
    CSTaggedUrn *target = [CSTaggedUrn fromString:@"media:image;jpeg" error:&error];
    XCTAssertNotNil(target);
    CSTaggedUrn *runtime = [CSTaggedUrn fromString:@"media:image;png;thumbnail" error:&error];
    XCTAssertNotNil(runtime);

    CSTaggedUrnCoordinateDelta *delta = [target deltaFrom:base error:&error];
    XCTAssertNotNil(delta);
    XCTAssertNil(error);
    XCTAssertEqual(delta.relationKind, CSTaggedUrnRelationKindIncomparable);

    CSTaggedUrn *applied = [runtime applyDelta:delta error:&error];
    XCTAssertNotNil(applied);
    XCTAssertNil(error);
    XCTAssertEqualObjects([applied toString], @"media:image;jpeg;thumbnail");
}

// TEST589: Delta comparable removal drops only declared coordinate
- (void)test589_deltaComparableRemovalDropsOnlyDeclaredCoordinate {
    NSError *error = nil;
    CSTaggedUrn *base = [CSTaggedUrn fromString:@"media:image;png" error:&error];
    XCTAssertNotNil(base);
    CSTaggedUrn *target = [CSTaggedUrn fromString:@"media:image" error:&error];
    XCTAssertNotNil(target);
    CSTaggedUrn *runtime = [CSTaggedUrn fromString:@"media:image;png;thumbnail" error:&error];
    XCTAssertNotNil(runtime);

    CSTaggedUrnCoordinateDelta *delta = [target deltaFrom:base error:&error];
    XCTAssertNotNil(delta);
    XCTAssertNil(error);
    XCTAssertEqual(delta.relationKind, CSTaggedUrnRelationKindComparable);

    CSTaggedUrn *applied = [runtime applyDelta:delta error:&error];
    XCTAssertNotNil(applied);
    XCTAssertNil(error);
    XCTAssertEqualObjects([applied toString], @"media:image;thumbnail");
}

@end
