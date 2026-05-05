//
//  CSTaggedUrnBuilderTests.m
//  Tests for CSTaggedUrnBuilder tag-based system
//
//  NOTE: The `action` tag has been replaced with `op` in the new format.
//

#import <XCTest/XCTest.h>
@import TaggedUrn;

@interface CSTaggedUrnBuilderTests : XCTestCase
@end

@implementation CSTaggedUrnBuilderTests

- (void)testBuilderBasicConstruction {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"type" value:@"data_processing"];
    [builder tag:@"op" value:@"transform"];
    [builder tag:@"format" value:@"json"];
    CSTaggedUrn *taggedUrn = [builder build:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);
    // Alphabetical order: format, op, type
    // tag:@"type" value:@"data_processing" creates type=data_processing, not valueless
    XCTAssertEqualObjects([taggedUrn toString], @"cap:format=json;transform;type=data_processing");
}

- (void)testBuilderFluentAPI {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"op" value:@"generate"];
    [builder tag:@"target" value:@"thumbnail"];
    [builder tag:@"format" value:@"pdf"];
    [builder tag:@"output" value:@"binary"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"op"], @"generate");
    XCTAssertEqualObjects([urn getTag:@"target"], @"thumbnail");
    XCTAssertEqualObjects([urn getTag:@"format"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");
}

- (void)testBuilderJSONOutput {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"type" value:@"api"];
    [builder tag:@"op" value:@"process"];
    [builder tag:@"target" value:@"data"];
    [builder tag:@"output" value:@"json"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"output"], @"json");
    XCTAssertEqualObjects([urn getTag:@"output"], @"json");
}

- (void)testBuilderCustomTags {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"engine" value:@"v2"];
    [builder tag:@"quality" value:@"high"];
    [builder tag:@"op" value:@"compress"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"engine"], @"v2");
    XCTAssertEqualObjects([urn getTag:@"quality"], @"high");
    XCTAssertEqualObjects([urn getTag:@"op"], @"compress");
}

- (void)testBuilderTagOverrides {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"op" value:@"convert"];
    [builder tag:@"format" value:@"jpg"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"op"], @"convert");
    XCTAssertEqualObjects([urn getTag:@"format"], @"jpg");
}

- (void)testBuilderEmptyBuild {
    NSError *error;
    CSTaggedUrn *urn = [[CSTaggedUrnBuilder builderWithPrefix:@"cap"] build:&error];

    XCTAssertNil(urn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidFormat);
    XCTAssertTrue([error.localizedDescription containsString:@"cannot be empty"]);
}

- (void)testBuilderBuildAllowEmpty {
    CSTaggedUrn *urn = [[CSTaggedUrnBuilder builderWithPrefix:@"cap"] buildAllowEmpty];

    XCTAssertNotNil(urn);
    XCTAssertEqual(urn.tags.count, 0);
    XCTAssertEqualObjects([urn toString], @"cap:");
}

- (void)testBuilderSingleTag {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"type" value:@"utility"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // tag:@"type" value:@"utility" creates type=utility
    XCTAssertEqualObjects([urn toString], @"cap:type=utility");
    XCTAssertEqualObjects([urn getTag:@"type"], @"utility");
    // NEW GRADED SPECIFICITY: exact value = 3 points
    XCTAssertEqual([urn specificity], 3);
}

- (void)testBuilderComplex {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"type" value:@"media"];
    [builder tag:@"op" value:@"transcode"];
    [builder tag:@"target" value:@"video"];
    [builder tag:@"format" value:@"mp4"];
    [builder tag:@"codec" value:@"h264"];
    [builder tag:@"quality" value:@"1080p"];
    [builder tag:@"framerate" value:@"30fps"];
    [builder tag:@"output" value:@"binary"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // Alphabetical order: codec, format, framerate, op, output, quality, target, type
    // tag:@"type" value:@"media" creates type=media, not valueless
    NSString *expected = @"cap:codec=h264;format=mp4;framerate=30fps;transcode;output=binary;quality=1080p;target=video;type=media";
    XCTAssertEqualObjects([urn toString], expected);

    XCTAssertEqualObjects([urn getTag:@"type"], @"media");
    XCTAssertEqualObjects([urn getTag:@"op"], @"transcode");
    XCTAssertEqualObjects([urn getTag:@"target"], @"video");
    XCTAssertEqualObjects([urn getTag:@"format"], @"mp4");
    XCTAssertEqualObjects([urn getTag:@"codec"], @"h264");
    XCTAssertEqualObjects([urn getTag:@"quality"], @"1080p");
    XCTAssertEqualObjects([urn getTag:@"framerate"], @"30fps");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");

    // NEW GRADED SPECIFICITY: 8 exact values × 3 points each = 24
    XCTAssertEqual([urn specificity], 24);
}

- (void)testBuilderWildcards {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"op" value:@"convert"];
    [builder tag:@"ext" value:@"*"]; // Wildcard format
    [builder tag:@"quality" value:@"*"]; // Wildcard quality
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // Alphabetical order: ext, op, quality (wildcards serialize as value-less)
    XCTAssertEqualObjects([urn toString], @"cap:ext;convert;quality");
    // NEW GRADED SPECIFICITY:
    // op=convert (exact) = 3, ext=* = 2, quality=* = 2
    // Total = 3 + 2 + 2 = 7
    XCTAssertEqual([urn specificity], 7);

    XCTAssertEqualObjects([urn getTag:@"ext"], @"*");
    XCTAssertEqualObjects([urn getTag:@"quality"], @"*");
}

- (void)testBuilderStaticFactory {
    CSTaggedUrnBuilder *builder1 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    CSTaggedUrnBuilder *builder2 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];

    XCTAssertNotEqual(builder1, builder2); // Should be different instances
    XCTAssertNotNil(builder1);
    XCTAssertNotNil(builder2);
}

- (void)testBuilderCustomPrefix {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"myapp"];
    [builder tag:@"key" value:@"value"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects(urn.prefix, @"myapp");
    XCTAssertEqualObjects([urn toString], @"myapp:key=value");
}

- (void)testBuilderMatchingWithBuiltUrn {
    NSError *error;

    // Create a specific instance
    CSTaggedUrnBuilder *builder1 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder1 tag:@"op" value:@"generate"];
    [builder1 tag:@"target" value:@"thumbnail"];
    [builder1 tag:@"format" value:@"pdf"];
    CSTaggedUrn *specificInstance = [builder1 build:&error];

    // Create a more general pattern (fewer constraints)
    CSTaggedUrnBuilder *builder2 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder2 tag:@"op" value:@"generate"];
    CSTaggedUrn *generalPattern = [builder2 build:&error];

    // Create a pattern with wildcard (ext=* means must-have-any)
    CSTaggedUrnBuilder *builder3 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder3 tag:@"op" value:@"generate"];
    [builder3 tag:@"target" value:@"thumbnail"];
    [builder3 tag:@"ext" value:@"*"];
    CSTaggedUrn *wildcardPattern = [builder3 build:&error];

    XCTAssertNotNil(specificInstance);
    XCTAssertNotNil(generalPattern);
    XCTAssertNotNil(wildcardPattern);

    // Specific instance should match general pattern (pattern has fewer constraints)
    BOOL matches = [specificInstance conformsTo:generalPattern error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(matches);

    // NEW SEMANTICS: wildcardPattern has ext=* which means instance MUST have ext
    // specificInstance doesn't have ext, so this should NOT match
    matches = [specificInstance conformsTo:wildcardPattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches); // Instance missing ext, pattern requires ext to be present

    // Check specificity
    BOOL moreSpecific = [specificInstance isMoreSpecificThan:generalPattern error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(moreSpecific);

    // NEW GRADED SPECIFICITY: exact value = 3 points, * = 2 points
    XCTAssertEqual([specificInstance specificity], 9); // 3 exact values × 3 = 9
    XCTAssertEqual([generalPattern specificity], 3); // 1 exact value × 3 = 3
    XCTAssertEqual([wildcardPattern specificity], 8); // 2 exact × 3 + 1 * × 2 = 6 + 2 = 8
}

// TEST596: Builder with prefix verification
- (void)test596_builderWithPrefix {
    NSError *error = nil;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"custom"];
    [builder tag:@"key" value:@"value"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects(urn.prefix, @"custom");
}

// TEST597: Builder case preservation for quoted values
- (void)test597_builderPreservesCase {
    NSError *error = nil;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"name" value:@"MyValue"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects([urn getTag:@"name"], @"MyValue");
    // Should be quoted to preserve case
    XCTAssertTrue([[urn toString] containsString:@"\"MyValue\""]);
}

// TEST598: Builder rejects empty tag values (matches Rust's Result error)
- (void)test598_builderRejectsEmptyValue {
    NSError *error = nil;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"key" value:@""]; // This sets buildError internally
    CSTaggedUrn *urn = [builder build:&error];

    // Should fail with error - matches Rust: TaggedUrnBuilder::new("cap").tag("key", "") returns Err
    XCTAssertNil(urn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorEmptyTag);
    XCTAssertTrue([error.localizedDescription containsString:@"Empty value"]);
    XCTAssertTrue([error.localizedDescription containsString:@"use '*' for wildcard"]);
}

@end
