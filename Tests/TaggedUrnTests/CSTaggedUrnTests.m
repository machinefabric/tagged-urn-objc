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

- (void)testTaggedUrnCreation {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:op=transform;format=json;data_processing" error:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);

    XCTAssertEqualObjects(taggedUrn.prefix, @"cap");
    // data_processing is a valueless tag, stored as * (must-have-any)
    XCTAssertEqualObjects([taggedUrn getTag:@"data_processing"], @"*");
    XCTAssertEqualObjects([taggedUrn getTag:@"op"], @"transform");
    XCTAssertEqualObjects([taggedUrn getTag:@"format"], @"json");
}

- (void)testCustomPrefix {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"myapp:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects(urn.prefix, @"myapp");
    XCTAssertEqualObjects([urn getTag:@"op"], @"generate");
    XCTAssertEqualObjects([urn toString], @"myapp:ext=pdf;op=generate");
}

- (void)testPrefixCaseInsensitive {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"CAP:op=test" error:&error];
    XCTAssertNotNil(urn1);
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:op=test" error:&error];
    XCTAssertNotNil(urn2);
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"Cap:op=test" error:&error];
    XCTAssertNotNil(urn3);

    XCTAssertEqualObjects(urn1.prefix, @"cap");
    XCTAssertEqualObjects(urn2.prefix, @"cap");
    XCTAssertEqualObjects(urn3.prefix, @"cap");
    XCTAssertEqualObjects(urn1, urn2);
    XCTAssertEqualObjects(urn2, urn3);
}

- (void)testCanonicalStringFormat {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:op=generate;target=thumbnail;ext=pdf" error:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);

    // Should be sorted alphabetically: ext, op, target
    XCTAssertEqualObjects([taggedUrn toString], @"cap:ext=pdf;op=generate;target=thumbnail");
}

- (void)testPrefixRequired {
    NSError *error;
    // Missing prefix should fail
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"op=generate;ext=pdf" error:&error];
    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorMissingPrefix);

    // Empty prefix should fail
    error = nil;
    taggedUrn = [CSTaggedUrn fromString:@":op=generate" error:&error];
    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorEmptyPrefix);

    // Valid prefix should work
    error = nil;
    taggedUrn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([taggedUrn getTag:@"op"], @"generate");
}

- (void)testTrailingSemicolonEquivalence {
    NSError *error;
    // Both with and without trailing semicolon should be equivalent
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn1);

    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf;" error:&error];
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

- (void)testInvalidTaggedUrn {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"" error:&error];

    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidFormat);
}

- (void)testValuelessTagParsing {
    // Value-less tag is now valid and treated as wildcard
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:optimize" error:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([taggedUrn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([taggedUrn toString], @"cap:optimize");
}

- (void)testInvalidCharacters {
    NSError *error;
    CSTaggedUrn *taggedUrn = [CSTaggedUrn fromString:@"cap:type@invalid=value" error:&error];

    XCTAssertNil(taggedUrn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidCharacter);
}

- (void)testTagMatching {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf;target=thumbnail;" error:&error];

    // Exact match
    CSTaggedUrn *request1 = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf;target=thumbnail;" error:&error];
    BOOL matches = [urn conformsTo:request1 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    // Subset match
    CSTaggedUrn *request2 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    matches = [urn conformsTo:request2 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    // Wildcard request should match specific urn
    CSTaggedUrn *request3 = [CSTaggedUrn fromString:@"cap:ext=*" error:&error];
    matches = [urn conformsTo:request3 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    // No match - conflicting value
    CSTaggedUrn *request4 = [CSTaggedUrn fromString:@"cap:op=extract" error:&error];
    matches = [urn conformsTo:request4 error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches);
}

- (void)testPrefixMismatchError {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=test" error:&error];
    XCTAssertNotNil(urn1);
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"myapp:op=test" error:&error];
    XCTAssertNotNil(urn2);

    error = nil;
    [urn1 conformsTo:urn2 error:&error];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorPrefixMismatch);
}

- (void)testMissingTagHandling {
    // NEW SEMANTICS: Missing tag in instance means the tag doesn't exist.
    // Pattern constraints must be satisfied by instance.
    NSError *error;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];

    // Pattern with tag that instance doesn't have: NO MATCH
    CSTaggedUrn *pattern1 = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error];
    BOOL matches = [instance conformsTo:pattern1 error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches); // Instance missing ext, pattern wants ext=pdf

    // Pattern missing tag = no constraint: MATCH
    CSTaggedUrn *instance2 = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    CSTaggedUrn *pattern2 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    matches = [instance2 conformsTo:pattern2 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches); // Instance has ext=pdf, pattern doesn't constrain ext
}

- (void)testSpecificity {
    // NEW GRADED SPECIFICITY:
    // K=v (exact value): 3 points
    // K=* (must-have-any): 2 points
    // K=! (must-not-have): 1 point
    // K=? (unspecified): 0 points
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=*" error:&error]; // * = 2
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error]; // exact = 3
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:op=*;ext=pdf" error:&error]; // * + exact = 2 + 3 = 5

    XCTAssertEqual([urn1 specificity], 2); // * = 2
    XCTAssertEqual([urn2 specificity], 3); // exact = 3
    XCTAssertEqual([urn3 specificity], 5); // * + exact = 2 + 3 = 5

    BOOL moreSpecific = [urn2 isMoreSpecificThan:urn1 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(moreSpecific); // 3 > 2
}

- (void)testDirectionalAccepts {
    NSError *error;
    // General pattern accepts specific instance
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(specific);

    BOOL result = [general accepts:specific error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result); // General pattern accepts specific instance

    // Specific does NOT accept general (missing ext in general)
    result = [specific accepts:general error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // Specific pattern requires ext=pdf, general doesn't have it

    // Different values never accept each other
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:op=extract;ext=pdf" error:&error];
    XCTAssertNotNil(urn3);
    result = [specific accepts:urn3 error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // op mismatch

    result = [urn3 accepts:specific error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(result); // op mismatch
}

- (void)testConvenienceMethods {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf;output=binary;target=thumbnail" error:&error];

    XCTAssertEqualObjects([urn getTag:@"op"], @"generate");
    XCTAssertEqualObjects([urn getTag:@"target"], @"thumbnail");
    XCTAssertEqualObjects([urn getTag:@"ext"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");

    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");
}

- (void)testBuilder {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"op" value:@"generate"];
    [builder tag:@"target" value:@"thumbnail"];
    [builder tag:@"ext" value:@"pdf"];
    [builder tag:@"output" value:@"binary"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"op"], @"generate");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");
}

- (void)testBuilderWithCustomPrefix {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"custom"];
    [builder tag:@"key" value:@"value"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects(urn.prefix, @"custom");
    XCTAssertEqualObjects([urn toString], @"custom:key=value");
}

- (void)testWithTag {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    CSTaggedUrn *modified = [original withTag:@"ext" value:@"pdf"];

    // Alphabetical order: ext, op
    XCTAssertEqualObjects([modified toString], @"cap:ext=pdf;op=generate");

    // Original should be unchanged
    XCTAssertEqualObjects([original toString], @"cap:op=generate");
}

- (void)testWithoutTag {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    CSTaggedUrn *modified = [original withoutTag:@"ext"];

    XCTAssertEqualObjects([modified toString], @"cap:op=generate");

    // Original should be unchanged - alphabetical order: ext, op
    XCTAssertEqualObjects([original toString], @"cap:ext=pdf;op=generate");
}

- (void)testWildcardTag {
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

- (void)testSubset {
    NSError *error;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf;output=binary;target=thumbnail" error:&error];
    CSTaggedUrn *subset = [urn subset:@[@"type", @"ext"]];

    XCTAssertEqualObjects([subset toString], @"cap:ext=pdf");
}

- (void)testMerge {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:ext=pdf;output=binary" error:&error];
    CSTaggedUrn *merged = [urn1 merge:urn2 error:&error];

    XCTAssertNotNil(merged);
    XCTAssertNil(error);

    // Alphabetical order: ext, op, output
    XCTAssertEqualObjects([merged toString], @"cap:ext=pdf;op=generate;output=binary");
}

- (void)testMergePrefixMismatch {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"myapp:ext=pdf" error:&error];

    error = nil;
    CSTaggedUrn *merged = [urn1 merge:urn2 error:&error];
    XCTAssertNil(merged);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorPrefixMismatch);
}

- (void)testEquality {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error]; // different order
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:op=generate;image" error:&error];

    XCTAssertEqualObjects(urn1, urn2); // order doesn't matter
    XCTAssertNotEqualObjects(urn1, urn3);
    XCTAssertEqual([urn1 hash], [urn2 hash]);
}

- (void)testEqualityDifferentPrefix {
    NSError *error;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"myapp:op=generate" error:&error];

    XCTAssertNotEqualObjects(urn1, urn2);
}

- (void)testCoding {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
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

- (void)testCodingWithCustomPrefix {
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

- (void)testCopying {
    NSError *error;
    CSTaggedUrn *original = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    CSTaggedUrn *copy = [original copy];

    XCTAssertEqualObjects(original, copy);
    XCTAssertNotEqual(original, copy); // Different objects
}

#pragma mark - New Rule Tests

- (void)testEmptyTaggedUrn {
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
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];

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

- (void)testEmptyWithCustomPrefix {
    NSError *error = nil;
    CSTaggedUrn *empty = [CSTaggedUrn fromString:@"myapp:" error:&error];
    XCTAssertNotNil(empty);
    XCTAssertNil(error);
    XCTAssertEqualObjects(empty.prefix, @"myapp");
    XCTAssertEqualObjects([empty toString], @"myapp:");
}

- (void)testEmptyWithPrefixMethod {
    CSTaggedUrn *empty = [CSTaggedUrn emptyWithPrefix:@"custom"];
    XCTAssertNotNil(empty);
    XCTAssertEqualObjects(empty.prefix, @"custom");
    XCTAssertEqual(empty.tags.count, 0);
    XCTAssertEqualObjects([empty toString], @"custom:");
}

- (void)testExtendedCharacterSupport {
    NSError *error = nil;
    // Test forward slashes and colons in tag components
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:url=https://example_org/api;path=/some/file" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"url"], @"https://example_org/api");
    XCTAssertEqualObjects([urn getTag:@"path"], @"/some/file");
}

- (void)testWildcardRestrictions {
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

- (void)testDuplicateKeyRejection {
    NSError *error = nil;
    // Duplicate keys should be rejected
    CSTaggedUrn *duplicate = [CSTaggedUrn fromString:@"cap:key=value1;key=value2" error:&error];
    XCTAssertNil(duplicate);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorDuplicateKey);
}

- (void)testNumericKeyRestriction {
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

- (void)testUnquotedValuesLowercased {
    NSError *error = nil;
    // Unquoted values are normalized to lowercase
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:OP=Generate;EXT=PDF;Target=Thumbnail;" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // Keys are always lowercase
    XCTAssertEqualObjects([urn getTag:@"op"], @"generate");
    XCTAssertEqualObjects([urn getTag:@"ext"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"target"], @"thumbnail");

    // Key lookup is case-insensitive
    XCTAssertEqualObjects([urn getTag:@"OP"], @"generate");
    XCTAssertEqualObjects([urn getTag:@"Op"], @"generate");

    // Both URNs parse to same lowercase values
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf;target=thumbnail;" error:&error];
    XCTAssertEqualObjects([urn toString], [urn2 toString]);
    XCTAssertEqualObjects(urn, urn2);
}

- (void)testQuotedValuesPreserveCase {
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

- (void)testQuotedValueSpecialChars {
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

- (void)testQuotedValueEscapeSequences {
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

- (void)testMixedQuotedUnquoted {
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:a=\"Quoted\";b=simple" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"a"], @"Quoted");
    XCTAssertEqualObjects([urn getTag:@"b"], @"simple");
}

- (void)testUnterminatedQuoteError {
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"unterminated" error:&error];
    XCTAssertNil(urn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorUnterminatedQuote);
}

- (void)testInvalidEscapeSequenceError {
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:key=\"bad\\n\"" error:&error];
    XCTAssertNil(urn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidEscapeSequence);
}

- (void)testSerializationSmartQuoting {
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

- (void)testRoundTripSimple {
    NSError *error = nil;
    NSString *original = @"cap:op=generate;ext=pdf";
    CSTaggedUrn *urn = [CSTaggedUrn fromString:original error:&error];
    XCTAssertNotNil(urn);
    NSString *serialized = [urn toString];
    CSTaggedUrn *reparsed = [CSTaggedUrn fromString:serialized error:&error];
    XCTAssertNotNil(reparsed);
    XCTAssertEqualObjects(urn, reparsed);
}

- (void)testRoundTripQuoted {
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

- (void)testHasTagCaseSensitive {
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

- (void)testBuilderPreservesCase {
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

- (void)testSemanticEquivalence {
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

- (void)testMatchingDifferentPrefixesError {
    NSError *error = nil;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=test" error:&error];
    XCTAssertNotNil(urn1);
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"other:op=test" error:&error];
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

- (void)testMatchingSemantics_Test1_ExactMatch {
    // Test 1: Exact match
    // URN:     cap:op=generate;ext=pdf
    // Request: cap:op=generate;ext=pdf
    // Result:  MATCH
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 1: Exact match should succeed");
}

- (void)testMatchingSemantics_Test2_InstanceMissingTag {
    // Test 2: Instance missing tag
    // Instance: cap:op=generate
    // Pattern:  cap:op=generate;ext=pdf
    // Result:   NO MATCH (pattern requires ext=pdf, instance doesn't have ext)
    //
    // NEW SEMANTICS: Missing tag in instance means it doesn't exist.
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(pattern);

    BOOL matches = [instance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 2: Instance missing tag should NOT match when pattern requires it");

    // To accept any ext (or missing), use pattern with ext=?
    CSTaggedUrn *patternOptional = [CSTaggedUrn fromString:@"cap:op=generate;ext=?" error:&error];
    XCTAssertNotNil(patternOptional);
    matches = [instance conformsTo:patternOptional error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Pattern with ext=? should match instance without ext");
}

- (void)testMatchingSemantics_Test3_UrnHasExtraTag {
    // Test 3: URN has extra tag
    // URN:     cap:op=generate;ext=pdf;version=2
    // Request: cap:op=generate;ext=pdf
    // Result:  MATCH (request doesn't constrain version)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf;version=2" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 3: URN with extra tag should match");
}

- (void)testMatchingSemantics_Test4_RequestHasWildcard {
    // Test 4: Request has wildcard
    // URN:     cap:op=generate;ext=pdf
    // Request: cap:op=generate;ext=*
    // Result:  MATCH (request accepts any ext)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:op=generate;ext=*" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 4: Request wildcard should match");
}

- (void)testMatchingSemantics_Test5_UrnHasWildcard {
    // Test 5: URN has wildcard
    // URN:     cap:op=generate;ext=*
    // Request: cap:op=generate;ext=pdf
    // Result:  MATCH (URN handles any ext)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=*" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 5: URN wildcard should match");
}

- (void)testMatchingSemantics_Test6_ValueMismatch {
    // Test 6: Value mismatch
    // URN:     cap:op=generate;ext=pdf
    // Request: cap:op=generate;ext=docx
    // Result:  NO MATCH
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *request = [CSTaggedUrn fromString:@"cap:op=generate;ext=docx" error:&error];
    XCTAssertNotNil(request);

    BOOL matches = [urn conformsTo:request error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 6: Value mismatch should not match");
}

- (void)testMatchingSemantics_Test7_PatternHasExtraTag {
    // Test 7: Pattern has extra tag that instance doesn't have
    // Instance: cap:op=generate_thumbnail;out="media:binary"
    // Pattern:  cap:ext=wav;op=generate_thumbnail;out="media:binary"
    // Result:   NO MATCH (pattern requires ext=wav, instance doesn't have ext)
    //
    // NEW SEMANTICS: Pattern K=v requires instance to have K=v
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:op=generate_thumbnail;out=\"media:binary\"" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:ext=wav;op=generate_thumbnail;out=\"media:binary\"" error:&error];
    XCTAssertNotNil(pattern);

    BOOL matches = [instance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 7: Instance missing ext should NOT match when pattern requires ext=wav");
}

- (void)testMatchingSemantics_Test8_EmptyPatternMatchesAnything {
    // Test 8: Empty PATTERN matches any INSTANCE
    // Instance: cap:op=generate;ext=pdf
    // Pattern:  cap:
    // Result:   MATCH (pattern has no constraints)
    //
    // NEW SEMANTICS: Empty pattern = no constraints = matches any instance
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *emptyPattern = [CSTaggedUrn fromString:@"cap:" error:&error];
    XCTAssertNotNil(emptyPattern);

    BOOL matches = [instance conformsTo:emptyPattern error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches, @"Test 8: Any instance should match empty pattern");

    // Empty instance vs pattern with requirements: NO MATCH
    CSTaggedUrn *emptyInstance = [CSTaggedUrn fromString:@"cap:" error:&error];
    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    matches = [emptyInstance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Empty instance should NOT match pattern with requirements");
}

- (void)testMatchingSemantics_Test9_CrossDimensionConstraints {
    // Test 9: Cross-dimension constraints
    // Instance: cap:op=generate
    // Pattern:  cap:ext=pdf
    // Result:   NO MATCH (pattern requires ext=pdf, instance doesn't have ext)
    //
    // NEW SEMANTICS: Pattern K=v requires instance to have K=v
    NSError *error = nil;
    CSTaggedUrn *instance = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    XCTAssertNotNil(instance);

    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:ext=pdf" error:&error];
    XCTAssertNotNil(pattern);

    BOOL matches = [instance conformsTo:pattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches, @"Test 9: Instance without ext should NOT match pattern requiring ext");

    // Instance with ext vs pattern with different tag only: MATCH
    CSTaggedUrn *instance2 = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
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

- (void)testValuelessTagParsingSingle {
    // Single value-less tag
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:optimize" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    // Serializes as value-less (no =*)
    XCTAssertEqualObjects([urn toString], @"cap:optimize");
}

- (void)testValuelessTagParsingMultiple {
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

- (void)testValuelessTagMixedWithValued {
    // Mix of value-less and valued tags
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;optimize;ext=pdf;secure" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"op"], @"generate");
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([urn getTag:@"ext"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"secure"], @"*");
    // Serializes alphabetically
    XCTAssertEqualObjects([urn toString], @"cap:ext=pdf;op=generate;optimize;secure");
}

- (void)testValuelessTagAtEnd {
    // Value-less tag at the end (no trailing semicolon)
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;optimize" error:&error];
    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"op"], @"generate");
    XCTAssertEqualObjects([urn getTag:@"optimize"], @"*");
    XCTAssertEqualObjects([urn toString], @"cap:op=generate;optimize");
}

- (void)testValuelessTagEquivalenceToWildcard {
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

- (void)testValuelessTagMatching {
    // Value-less tag (wildcard) matches any value
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:op=generate;ext" error:&error];
    XCTAssertNotNil(urn);

    CSTaggedUrn *requestPdf = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    CSTaggedUrn *requestDocx = [CSTaggedUrn fromString:@"cap:op=generate;ext=docx" error:&error];
    CSTaggedUrn *requestAny = [CSTaggedUrn fromString:@"cap:op=generate;ext=anything" error:&error];

    BOOL matches;
    matches = [urn conformsTo:requestPdf error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    matches = [urn conformsTo:requestDocx error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    matches = [urn conformsTo:requestAny error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);
}

- (void)testValuelessTagInPattern {
    // Pattern with value-less tag (K=*) requires instance to have the tag
    NSError *error = nil;
    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:op=generate;ext" error:&error];
    XCTAssertNotNil(pattern);

    CSTaggedUrn *instancePdf = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    CSTaggedUrn *instanceDocx = [CSTaggedUrn fromString:@"cap:op=generate;ext=docx" error:&error];
    CSTaggedUrn *instanceMissing = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];

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
    CSTaggedUrn *patternOptional = [CSTaggedUrn fromString:@"cap:op=generate;ext=?" error:&error];
    XCTAssertNotNil(patternOptional);
    matches = [instanceMissing conformsTo:patternOptional error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);
}

- (void)testValuelessTagSpecificity {
    // NEW GRADED SPECIFICITY:
    // K=v (exact): 3, K=* (must-have-any): 2, K=! (must-not): 1, K=? (unspecified): 0
    NSError *error = nil;
    CSTaggedUrn *urn1 = [CSTaggedUrn fromString:@"cap:op=generate" error:&error];
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:op=generate;optimize" error:&error]; // optimize = *
    CSTaggedUrn *urn3 = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];

    XCTAssertEqual([urn1 specificity], 3);  // 1 exact = 3
    XCTAssertEqual([urn2 specificity], 5);  // 1 exact + 1 * = 3 + 2 = 5
    XCTAssertEqual([urn3 specificity], 6);  // 2 exact = 3 + 3 = 6
}

- (void)testValuelessTagRoundtrip {
    // Round-trip parsing and serialization
    NSError *error = nil;
    NSString *original = @"cap:ext=pdf;op=generate;optimize;secure";
    CSTaggedUrn *urn = [CSTaggedUrn fromString:original error:&error];
    XCTAssertNotNil(urn);
    NSString *serialized = [urn toString];
    CSTaggedUrn *reparsed = [CSTaggedUrn fromString:serialized error:&error];
    XCTAssertNotNil(reparsed);
    XCTAssertEqualObjects(urn, reparsed);
    XCTAssertEqualObjects(serialized, original);
}

- (void)testValuelessTagCaseNormalization {
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

- (void)testEmptyValueStillError {
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

- (void)testValuelessTagDirectionalAccepts {
    // Value-less tag (wildcard pattern) accepts any value
    NSError *error = nil;
    CSTaggedUrn *pattern = [CSTaggedUrn fromString:@"cap:op=generate;ext" error:&error];
    XCTAssertNotNil(pattern);
    CSTaggedUrn *instancePdf = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(instancePdf);
    CSTaggedUrn *instanceDocx = [CSTaggedUrn fromString:@"cap:op=generate;ext=docx" error:&error];
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

- (void)testValuelessNumericKeyStillRejected {
    // Purely numeric keys are still rejected for value-less tags
    NSError *error = nil;
    CSTaggedUrn *urn = [CSTaggedUrn fromString:@"cap:123" error:&error];
    XCTAssertNil(urn);
    XCTAssertNotNil(error);

    error = nil;
    CSTaggedUrn *urn2 = [CSTaggedUrn fromString:@"cap:op=generate;456" error:&error];
    XCTAssertNil(urn2);
    XCTAssertNotNil(error);
}

#pragma mark - Order-Theoretic Relations Tests

// TEST578: Equivalent URNs with identical tag sets
- (void)test578_equivalentIdenticalTags {
    NSError *error = nil;
    CSTaggedUrn *a = [CSTaggedUrn fromString:@"cap:op=generate;ext=pdf" error:&error];
    XCTAssertNotNil(a);
    CSTaggedUrn *b = [CSTaggedUrn fromString:@"cap:ext=pdf;op=generate" error:&error]; // same tags, different order
    XCTAssertNotNil(b);

    XCTAssertTrue([a isEquivalentTo:b error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([b isEquivalentTo:a error:&error]); // symmetric
    XCTAssertNil(error);
}

// TEST579: Non-equivalent URNs where one is more specific
- (void)test579_notEquivalentWhenOneMoreSpecific {
    NSError *error = nil;
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"media:bytes" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"media:pdf;bytes" error:&error];
    XCTAssertNotNil(specific);

    XCTAssertFalse([general isEquivalentTo:specific error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([specific isEquivalentTo:general error:&error]);
    XCTAssertNil(error);
}

// TEST580: Comparable URNs on the same specialization chain
- (void)test580_comparableSpecializationChain {
    NSError *error = nil;
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"media:bytes" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"media:pdf;bytes" error:&error];
    XCTAssertNotNil(specific);

    // general.accepts(specific) = true (bytes ⊆ pdf;bytes)
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
    CSTaggedUrn *pdf = [CSTaggedUrn fromString:@"media:pdf;bytes" error:&error];
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
    CSTaggedUrn *a = [CSTaggedUrn fromString:@"cap:op=test;ext=pdf" error:&error];
    XCTAssertNotNil(a);
    CSTaggedUrn *b = [CSTaggedUrn fromString:@"cap:op=test;ext=pdf" error:&error];
    XCTAssertNotNil(b);

    // equivalent → comparable (AND implies OR)
    XCTAssertTrue([a isEquivalentTo:b error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([a isComparableTo:b error:&error]);
    XCTAssertNil(error);

    // comparable but NOT equivalent
    CSTaggedUrn *general = [CSTaggedUrn fromString:@"cap:op=test" error:&error];
    XCTAssertNotNil(general);
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"cap:op=test;ext=pdf" error:&error];
    XCTAssertNotNil(specific);

    XCTAssertFalse([general isEquivalentTo:specific error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([general isComparableTo:specific error:&error]);
    XCTAssertNil(error);
}

// TEST583: Prefix mismatch returns error for both relations
- (void)test583_prefixMismatchErrors {
    NSError *error = nil;
    CSTaggedUrn *cap = [CSTaggedUrn fromString:@"cap:op=test" error:&error];
    XCTAssertNotNil(cap);
    CSTaggedUrn *media = [CSTaggedUrn fromString:@"media:bytes" error:&error];
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
    CSTaggedUrn *specific = [CSTaggedUrn fromString:@"media:pdf;bytes;thumbnail" error:&error];
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

    // must_have (*) and exact (pdf): equivalent — * accepts any value
    XCTAssertTrue([mustHave isEquivalentTo:exact error:&error]);
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

    // unspecified (?) is equivalent to everything — ? matches anything
    XCTAssertTrue([unspecified isEquivalentTo:exact error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([unspecified isEquivalentTo:mustHave error:&error]);
    XCTAssertNil(error);
    XCTAssertTrue([unspecified isEquivalentTo:mustNot error:&error]);
    XCTAssertNil(error);
}

@end
