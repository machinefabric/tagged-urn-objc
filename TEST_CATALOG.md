# Swift/ObjC Test Catalog

**Total Tests:** 95

**Numbered Tests:** 11

**Unnumbered Tests:** 84

**Numbered Tests Missing Descriptions:** 0

**Numbering Mismatches:** 0

All numbered test numbers are unique.

This catalog lists all tests in the Swift/ObjC codebase.

| Test # | Function Name | Description | File |
|--------|---------------|-------------|------|
| test578 | `test578_equivalentIdenticalTags` | TEST578: Equivalent URNs with identical tag sets | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1204 |
| test579 | `test579_notEquivalentWhenOneMoreSpecific` | TEST579: Non-equivalent URNs where one is more specific | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1218 |
| test580 | `test580_comparableSpecializationChain` | TEST580: Comparable URNs on the same specialization chain | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1232 |
| test581 | `test581_incomparableDifferentBranches` | TEST581: Incomparable URNs in different branches of the lattice | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1249 |
| test582 | `test582_equivalentImpliesComparable` | TEST582: Equivalent implies comparable but not vice versa | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1266 |
| test583 | `test583_prefixMismatchErrors` | TEST583: Prefix mismatch returns error for both relations | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1292 |
| test584 | `test584_emptyTagsComparableToAll` | TEST584: Empty tag set is comparable to everything with same prefix | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1309 |
| test586 | `test586_specialValues` | TEST586: Special values (*, !, ?) with isEquivalent and isComparable | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1330 |
| test596 | `test596_builderWithPrefix` | TEST596: Builder with prefix verification | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:256 |
| test597 | `test597_builderPreservesCase` | TEST597: Builder case preservation for quoted values | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:268 |
| test598 | `test598_builderRejectsEmptyValue` | TEST598: Builder rejects empty tag values (matches Rust's Result error) | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:282 |
| | | | |
| unnumbered | `testBuilder` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:271 |
| unnumbered | `testBuilderBasicConstruction` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:16 |
| unnumbered | `testBuilderBuildAllowEmpty` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:106 |
| unnumbered | `testBuilderComplex` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:130 |
| unnumbered | `testBuilderCustomPrefix` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:195 |
| unnumbered | `testBuilderCustomTags` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:66 |
| unnumbered | `testBuilderEmptyBuild` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:96 |
| unnumbered | `testBuilderFluentAPI` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:31 |
| unnumbered | `testBuilderJSONOutput` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:50 |
| unnumbered | `testBuilderMatchingWithBuiltUrn` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:207 |
| unnumbered | `testBuilderPreservesCase` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:745 |
| unnumbered | `testBuilderSingleTag` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:114 |
| unnumbered | `testBuilderStaticFactory` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:186 |
| unnumbered | `testBuilderTagOverrides` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:82 |
| unnumbered | `testBuilderWildcards` |  | Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:164 |
| unnumbered | `testBuilderWithCustomPrefix` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:287 |
| unnumbered | `testCanonicalStringFormat` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:57 |
| unnumbered | `testCoding` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:394 |
| unnumbered | `testCodingWithCustomPrefix` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:413 |
| unnumbered | `testConvenienceMethods` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:259 |
| unnumbered | `testCopying` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:432 |
| unnumbered | `testCustomPrefix` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:30 |
| unnumbered | `testDirectionalAccepts` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:230 |
| unnumbered | `testDuplicateKeyRejection` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:519 |
| unnumbered | `testEmptyTaggedUrn` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:443 |
| unnumbered | `testEmptyValueStillError` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1145 |
| unnumbered | `testEmptyWithCustomPrefix` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:474 |
| unnumbered | `testEmptyWithPrefixMethod` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:483 |
| unnumbered | `testEquality` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:375 |
| unnumbered | `testEqualityDifferentPrefix` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:386 |
| unnumbered | `testExtendedCharacterSupport` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:491 |
| unnumbered | `testHasTagCaseSensitive` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:728 |
| unnumbered | `testInvalidCharacters` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:139 |
| unnumbered | `testInvalidEscapeSequenceError` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:666 |
| unnumbered | `testInvalidTaggedUrn` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:119 |
| unnumbered | `testMatchingDifferentPrefixesError` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:773 |
| unnumbered | `testMatchingSemantics_Test1_ExactMatch` | These 9 tests verify the exact matching semantics from RULES.md Sections 12-17 All implementations (Rust, Go, JS, ObjC) must pass these identically | Tests/TaggedUrnTests/CSTaggedUrnTests.m:800 |
| unnumbered | `testMatchingSemantics_Test2_InstanceMissingTag` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:817 |
| unnumbered | `testMatchingSemantics_Test3_UrnHasExtraTag` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:843 |
| unnumbered | `testMatchingSemantics_Test4_RequestHasWildcard` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:860 |
| unnumbered | `testMatchingSemantics_Test5_UrnHasWildcard` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:877 |
| unnumbered | `testMatchingSemantics_Test6_ValueMismatch` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:894 |
| unnumbered | `testMatchingSemantics_Test7_PatternHasExtraTag` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:911 |
| unnumbered | `testMatchingSemantics_Test8_EmptyPatternMatchesAnything` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:930 |
| unnumbered | `testMatchingSemantics_Test9_CrossDimensionConstraints` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:956 |
| unnumbered | `testMerge` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:350 |
| unnumbered | `testMergePrefixMismatch` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:363 |
| unnumbered | `testMissingTagHandling` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:190 |
| unnumbered | `testMixedQuotedUnquoted` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:649 |
| unnumbered | `testNumericKeyRestriction` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:528 |
| unnumbered | `testPrefixCaseInsensitive` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:41 |
| unnumbered | `testPrefixMismatchError` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:177 |
| unnumbered | `testPrefixRequired` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:68 |
| unnumbered | `testQuotedValueEscapeSequences` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:633 |
| unnumbered | `testQuotedValueSpecialChars` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:610 |
| unnumbered | `testQuotedValuesPreserveCase` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:582 |
| unnumbered | `testRoundTripQuoted` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:716 |
| unnumbered | `testRoundTripSimple` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:705 |
| unnumbered | `testSemanticEquivalence` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:759 |
| unnumbered | `testSerializationSmartQuoting` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:674 |
| unnumbered | `testSpecificity` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:210 |
| unnumbered | `testSubset` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:342 |
| unnumbered | `testTagMatching` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:148 |
| unnumbered | `testTaggedUrnCreation` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:16 |
| unnumbered | `testTrailingSemicolonEquivalence` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:91 |
| unnumbered | `testUnquotedValuesLowercased` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:560 |
| unnumbered | `testUnterminatedQuoteError` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:658 |
| unnumbered | `testValuelessNumericKeyStillRejected` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1188 |
| unnumbered | `testValuelessTagAtEnd` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1027 |
| unnumbered | `testValuelessTagCaseNormalization` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1133 |
| unnumbered | `testValuelessTagDirectionalAccepts` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1158 |
| unnumbered | `testValuelessTagEquivalenceToWildcard` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1038 |
| unnumbered | `testValuelessTagInPattern` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1075 |
| unnumbered | `testValuelessTagMatching` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1051 |
| unnumbered | `testValuelessTagMixedWithValued` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1013 |
| unnumbered | `testValuelessTagParsing` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:128 |
| unnumbered | `testValuelessTagParsingMultiple` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1000 |
| unnumbered | `testValuelessTagParsingSingle` | VALUE-LESS TAG TESTS Value-less tags are equivalent to wildcard tags (key=*) | Tests/TaggedUrnTests/CSTaggedUrnTests.m:989 |
| unnumbered | `testValuelessTagRoundtrip` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1120 |
| unnumbered | `testValuelessTagSpecificity` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:1107 |
| unnumbered | `testWildcardRestrictions` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:501 |
| unnumbered | `testWildcardTag` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:322 |
| unnumbered | `testWithTag` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:299 |
| unnumbered | `testWithoutTag` |  | Tests/TaggedUrnTests/CSTaggedUrnTests.m:311 |
---

## Unnumbered Tests

The following tests are cataloged but do not currently participate in numeric test indexing.

- `testBuilder` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:271
- `testBuilderBasicConstruction` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:16
- `testBuilderBuildAllowEmpty` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:106
- `testBuilderComplex` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:130
- `testBuilderCustomPrefix` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:195
- `testBuilderCustomTags` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:66
- `testBuilderEmptyBuild` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:96
- `testBuilderFluentAPI` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:31
- `testBuilderJSONOutput` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:50
- `testBuilderMatchingWithBuiltUrn` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:207
- `testBuilderPreservesCase` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:745
- `testBuilderSingleTag` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:114
- `testBuilderStaticFactory` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:186
- `testBuilderTagOverrides` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:82
- `testBuilderWildcards` — Tests/TaggedUrnTests/CSTaggedUrnBuilderTests.m:164
- `testBuilderWithCustomPrefix` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:287
- `testCanonicalStringFormat` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:57
- `testCoding` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:394
- `testCodingWithCustomPrefix` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:413
- `testConvenienceMethods` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:259
- `testCopying` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:432
- `testCustomPrefix` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:30
- `testDirectionalAccepts` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:230
- `testDuplicateKeyRejection` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:519
- `testEmptyTaggedUrn` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:443
- `testEmptyValueStillError` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1145
- `testEmptyWithCustomPrefix` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:474
- `testEmptyWithPrefixMethod` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:483
- `testEquality` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:375
- `testEqualityDifferentPrefix` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:386
- `testExtendedCharacterSupport` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:491
- `testHasTagCaseSensitive` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:728
- `testInvalidCharacters` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:139
- `testInvalidEscapeSequenceError` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:666
- `testInvalidTaggedUrn` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:119
- `testMatchingDifferentPrefixesError` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:773
- `testMatchingSemantics_Test1_ExactMatch` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:800
- `testMatchingSemantics_Test2_InstanceMissingTag` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:817
- `testMatchingSemantics_Test3_UrnHasExtraTag` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:843
- `testMatchingSemantics_Test4_RequestHasWildcard` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:860
- `testMatchingSemantics_Test5_UrnHasWildcard` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:877
- `testMatchingSemantics_Test6_ValueMismatch` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:894
- `testMatchingSemantics_Test7_PatternHasExtraTag` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:911
- `testMatchingSemantics_Test8_EmptyPatternMatchesAnything` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:930
- `testMatchingSemantics_Test9_CrossDimensionConstraints` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:956
- `testMerge` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:350
- `testMergePrefixMismatch` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:363
- `testMissingTagHandling` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:190
- `testMixedQuotedUnquoted` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:649
- `testNumericKeyRestriction` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:528
- `testPrefixCaseInsensitive` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:41
- `testPrefixMismatchError` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:177
- `testPrefixRequired` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:68
- `testQuotedValueEscapeSequences` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:633
- `testQuotedValueSpecialChars` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:610
- `testQuotedValuesPreserveCase` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:582
- `testRoundTripQuoted` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:716
- `testRoundTripSimple` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:705
- `testSemanticEquivalence` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:759
- `testSerializationSmartQuoting` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:674
- `testSpecificity` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:210
- `testSubset` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:342
- `testTagMatching` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:148
- `testTaggedUrnCreation` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:16
- `testTrailingSemicolonEquivalence` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:91
- `testUnquotedValuesLowercased` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:560
- `testUnterminatedQuoteError` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:658
- `testValuelessNumericKeyStillRejected` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1188
- `testValuelessTagAtEnd` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1027
- `testValuelessTagCaseNormalization` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1133
- `testValuelessTagDirectionalAccepts` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1158
- `testValuelessTagEquivalenceToWildcard` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1038
- `testValuelessTagInPattern` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1075
- `testValuelessTagMatching` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1051
- `testValuelessTagMixedWithValued` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1013
- `testValuelessTagParsing` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:128
- `testValuelessTagParsingMultiple` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1000
- `testValuelessTagParsingSingle` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:989
- `testValuelessTagRoundtrip` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1120
- `testValuelessTagSpecificity` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:1107
- `testWildcardRestrictions` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:501
- `testWildcardTag` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:322
- `testWithTag` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:299
- `testWithoutTag` — Tests/TaggedUrnTests/CSTaggedUrnTests.m:311

---

*Generated from Swift/ObjC source tree*
*Total tests: 95*
*Total numbered tests: 11*
*Total unnumbered tests: 84*
*Total numbered tests missing descriptions: 0*
*Total numbering mismatches: 0*
