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

// TEST0001: Builder basic construction
- (void)test0001_BuilderBasicConstruction {
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

// TEST0002: Builder fluent a p i
- (void)test0002_BuilderFluentAPI {
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
    XCTAssertEqualObjects([urn getTag:@"target"], [CSTagConstraint exact:@"thumbnail"]);
    XCTAssertEqualObjects([urn getTag:@"format"], [CSTagConstraint exact:@"pdf"]);
    XCTAssertEqualObjects([urn getTag:@"output"], [CSTagConstraint exact:@"binary"]);
}

// TEST0003: Builder j s o n output
- (void)test0003_BuilderJSONOutput {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"type" value:@"api"];
    [builder marker:@"process"];
    [builder tag:@"target" value:@"data"];
    [builder tag:@"output" value:@"json"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"output"], [CSTagConstraint exact:@"json"]);
    XCTAssertEqualObjects([urn getTag:@"output"], [CSTagConstraint exact:@"json"]);
}

// TEST0004: Builder custom tags
- (void)test0004_BuilderCustomTags {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"engine" value:@"v2"];
    [builder tag:@"quality" value:@"high"];
    [builder marker:@"compress"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertEqualObjects([urn getTag:@"engine"], [CSTagConstraint exact:@"v2"]);
    XCTAssertEqualObjects([urn getTag:@"quality"], [CSTagConstraint exact:@"high"]);
    XCTAssertTrue([urn hasMarkerTag:@"compress"]);
}

// TEST0005: Builder tag overrides
- (void)test0005_BuilderTagOverrides {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder marker:@"convert"];
    [builder tag:@"format" value:@"jpg"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    XCTAssertTrue([urn hasMarkerTag:@"convert"]);
    XCTAssertEqualObjects([urn getTag:@"format"], [CSTagConstraint exact:@"jpg"]);
}

// TEST0006: Builder empty build
- (void)test0006_BuilderEmptyBuild {
    NSError *error;
    CSTaggedUrn *urn = [[CSTaggedUrnBuilder builderWithPrefix:@"cap"] build:&error];

    XCTAssertNil(urn);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CSTaggedUrnErrorInvalidFormat);
    XCTAssertTrue([error.localizedDescription containsString:@"cannot be empty"]);
}

// TEST0007: Builder build allow empty
- (void)test0007_BuilderBuildAllowEmpty {
    NSError *error = nil;
    CSTaggedUrn *urn = [[CSTaggedUrnBuilder builderWithPrefix:@"cap"] buildAllowEmpty:&error];

    XCTAssertNotNil(urn, @"%@", error);
    XCTAssertEqual(urn.tags.count, 0);
    XCTAssertEqualObjects([urn toString], @"cap:");
}

// TEST0008: Builder single tag
- (void)test0008_BuilderSingleTag {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder tag:@"type" value:@"utility"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);

    // tag:@"type" value:@"utility" creates type=utility
    XCTAssertEqualObjects([urn toString], @"cap:type=utility");
    XCTAssertEqualObjects([urn getTag:@"type"], [CSTagConstraint exact:@"utility"]);
    // Six-form ladder: exact value = 4 points.
    XCTAssertEqual([urn specificity], 4);
}

// TEST0009: Builder complex
- (void)test0009_BuilderComplex {
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

    XCTAssertEqualObjects([urn getTag:@"type"], [CSTagConstraint exact:@"media"]);
    XCTAssertTrue([urn hasMarkerTag:@"transcode"]);
    XCTAssertEqualObjects([urn getTag:@"target"], [CSTagConstraint exact:@"video"]);
    XCTAssertEqualObjects([urn getTag:@"format"], [CSTagConstraint exact:@"mp4"]);
    XCTAssertEqualObjects([urn getTag:@"codec"], [CSTagConstraint exact:@"h264"]);
    XCTAssertEqualObjects([urn getTag:@"quality"], [CSTagConstraint exact:@"1080p"]);
    XCTAssertEqualObjects([urn getTag:@"framerate"], [CSTagConstraint exact:@"30fps"]);
    XCTAssertEqualObjects([urn getTag:@"output"], [CSTagConstraint exact:@"binary"]);

    // Six-form ladder: 7 exact-valued tags × 4 + 1 marker (transcode) × 2 = 28 + 2 = 30.
    XCTAssertEqual([urn specificity], 30);
}

// TEST0010: Builder wildcards
- (void)test0010_BuilderWildcards {
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

// TEST0011: Builder static factory
- (void)test0011_BuilderStaticFactory {
    CSTaggedUrnBuilder *builder1 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    CSTaggedUrnBuilder *builder2 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];

    XCTAssertNotEqual(builder1, builder2); // Should be different instances
    XCTAssertNotNil(builder1);
    XCTAssertNotNil(builder2);
}

// TEST0012: Builder custom prefix
- (void)test0012_BuilderCustomPrefix {
    NSError *error;
    CSTaggedUrnBuilder *builder = [CSTaggedUrnBuilder builderWithPrefix:@"myapp"];
    [builder tag:@"key" value:@"value"];
    CSTaggedUrn *urn = [builder build:&error];

    XCTAssertNotNil(urn);
    XCTAssertNil(error);
    XCTAssertEqualObjects(urn.prefix, @"myapp");
    XCTAssertEqualObjects([urn toString], @"myapp:key=value");
}

// TEST0013: Builder matching with built urn
- (void)test0013_BuilderMatchingWithBuiltUrn {
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

    // Create a pattern with a marker (ext means must-have-any)
    CSTaggedUrnBuilder *builder3 = [CSTaggedUrnBuilder builderWithPrefix:@"cap"];
    [builder3 marker:@"generate"];
    [builder3 tag:@"target" value:@"thumbnail"];
    [builder3 marker:@"ext"];
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

    // Six-form ladder: marker (x=*) = 2, exact (x=v) = 4.
    //   specificInstance:  generate marker (2) + target=thumbnail (4) + format=pdf (4) = 10
    //   generalPattern:    generate marker (2) = 2
    //   wildcardPattern:   generate marker (2) + target=thumbnail (4) + ext=* (2) = 8
    XCTAssertEqual([specificInstance specificity], 10);
    XCTAssertEqual([generalPattern specificity], 2);
    XCTAssertEqual([wildcardPattern specificity], 8);
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
    XCTAssertEqualObjects([urn getTag:@"name"], [CSTagConstraint exact:@"MyValue"]);
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
