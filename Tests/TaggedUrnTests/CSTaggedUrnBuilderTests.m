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
    [builder marker:@"transform"];
    [builder tag:@"format" value:@"json"];
    CSTaggedUrn *taggedUrn = [builder build:&error];

    XCTAssertNotNil(taggedUrn);
    XCTAssertNil(error);
    // Alphabetical order: format, transform (marker), type
    XCTAssertEqualObjects([taggedUrn toString], @"cap:format=json;transform;type=data_processing");
}

- (void)testBuilderFluentAPI {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder marker:@"generate"];
    [builder tag:@"target" value:@"thumbnail"];
    [builder tag:@"format" value:@"pdf"];
    [builder tag:@"output" value:@"binary"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertTrue([urn hasMarkerTag:@"generate"]);
    XCTAssertEqualObjects([urn getTag:@"target"], @"thumbnail");
    XCTAssertEqualObjects([urn getTag:@"format"], @"pdf");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");
}

- (void)testBuilderJSONOutput {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"type" value:@"api"];
    [builder marker:@"process"];
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
    [builder marker:@"compress"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"engine"], @"v2");
    XCTAssertEqualObjects([urn getTag:@"quality"], @"high");
    XCTAssertTrue([urn hasMarkerTag:@"compress"]);
}

- (void)testBuilderTagOverrides {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder marker:@"convert"];
    [builder tag:@"format" value:@"jpg"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertTrue([urn hasMarkerTag:@"convert"]);
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
    [builder marker:@"transcode"];
    [builder tag:@"target" value:@"video"];
    [builder tag:@"format" value:@"mp4"];
    [builder tag:@"codec" value:@"h264"];
    [builder tag:@"quality" value:@"1080p"];
    [builder tag:@"framerate" value:@"30fps"];
    [builder tag:@"output" value:@"binary"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // Alphabetical order: codec, format, framerate, output, quality, target, transcode (marker), type
    NSString *expected = @"cap:codec=h264;format=mp4;framerate=30fps;output=binary;quality=1080p;target=video;transcode;type=media";
    XCTAssertEqualObjects([urn toString], expected);

    XCTAssertEqualObjects([urn getTag:@"type"], @"media");
    XCTAssertTrue([urn hasMarkerTag:@"transcode"]);
    XCTAssertEqualObjects([urn getTag:@"target"], @"video");
    XCTAssertEqualObjects([urn getTag:@"format"], @"mp4");
    XCTAssertEqualObjects([urn getTag:@"codec"], @"h264");
    XCTAssertEqualObjects([urn getTag:@"quality"], @"1080p");
    XCTAssertEqualObjects([urn getTag:@"framerate"], @"30fps");
    XCTAssertEqualObjects([urn getTag:@"output"], @"binary");

    // GRADED SPECIFICITY: 7 exact-valued tags × 3 + 1 marker (transcode) × 2 = 21 + 2 = 23
    XCTAssertEqual([urn specificity], 23);
}

- (void)testBuilderWildcards {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder marker:@"convert"];
    [builder marker:@"ext"];
    [builder marker:@"quality"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // Three markers serialize as value-less, sorted alphabetically.
    XCTAssertEqualObjects([urn toString], @"cap:convert;ext;quality");
    // GRADED SPECIFICITY: 3 markers × 2 points each = 6
    XCTAssertEqual([urn specificity], 6);

    XCTAssertTrue([urn hasMarkerTag:@"convert"]);
    XCTAssertTrue([urn hasMarkerTag:@"ext"]);
    XCTAssertTrue([urn hasMarkerTag:@"quality"]);
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
    [builder1 marker:@"generate"];
    [builder1 tag:@"target" value:@"thumbnail"];
    [builder1 tag:@"format" value:@"pdf"];
    CSTaggedUrn *specificInstance = [builder1 build:&error];

    // Create a more general pattern (fewer constraints)
    CSTaggedUrnBuilder *builder2 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder2 marker:@"generate"];
    CSTaggedUrn *generalPattern = [builder2 build:&error];

    // Create a pattern with wildcard (ext=* means must-have-any)
    CSTaggedUrnBuilder *builder3 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder3 marker:@"generate"];
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

    // wildcardPattern requires ext=* (must-have-any). specificInstance has
    // no `ext` tag, so it does NOT conform.
    matches = [specificInstance conformsTo:wildcardPattern error:&error];
    XCTAssertNil(error);
    XCTAssertFalse(matches);

    // Check specificity
    BOOL moreSpecific = [specificInstance isMoreSpecificThan:generalPattern error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(moreSpecific);

    // GRADED SPECIFICITY:
    //   specificInstance:  generate marker (2) + target=thumbnail (3) + format=pdf (3) = 8
    //   generalPattern:    generate marker (2) = 2
    //   wildcardPattern:   generate marker (2) + target=thumbnail (3) + ext=* (2) = 7
    XCTAssertEqual([specificInstance specificity], 8);
    XCTAssertEqual([generalPattern specificity], 2);
    XCTAssertEqual([wildcardPattern specificity], 7);
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
