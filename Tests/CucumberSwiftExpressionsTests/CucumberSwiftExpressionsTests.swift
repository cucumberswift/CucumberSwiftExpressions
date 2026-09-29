//  swiftlint:disable file_types_order

import XCTest
import CucumberSwiftExpressions

final class CucumberSwiftExpressionsTests: XCTestCase {
    func testPlainCucumberExpression() {
        let expression: CucumberExpression = "the member has A"
        XCTAssertNotNil(expression.match(in: "the member has A"))
        XCTAssertNil(expression.match(in: "the member has B"))
        XCTAssertNil(expression.match(in: "the member has C"))
    }
    
    func testCucumberExpressionGeneratesCorrectRegexForOptional() {
        let expression = CucumberExpression(#"There were 3 flight(s) from LAX."#)
        XCTAssertEqual(expression.regex, #"^There were 3 flight(?:s)? from LAX\.$"#)
    }

    func testOptionalTextIsEscaped() {
        let expression = CucumberExpression(#"There were 3 flight(s.) from LAX."#)
        XCTAssertEqual(expression.regex, #"^There were 3 flight(?:s\.)? from LAX\.$"#)
    }

    func testCucumberExpressionGeneratesCorrectRegexForAlternate() {
        let expression = CucumberExpression(#"There is/are/were 3 flights from LAX."#)
        XCTAssertEqual(expression.regex, #"^There (?:is|are|were) 3 flights from LAX\.$"#)
    }

    func testAlternateTextIsEscaped() {
        let expression = CucumberExpression(#"There is./are/were 3 flights from LAX."#)
        XCTAssertEqual(expression.regex, #"^There (?:is\.|are|were) 3 flights from LAX\.$"#)
    }

    func testCucumberExpressionGeneratesCorrectRegexForStringParameter() {
        let expression = CucumberExpression("The button says {string}.")
        XCTAssertEqual(expression.regex, #"^The button says ("([^"\\]*(\\.[^"\\]*)*)"|'([^'\\]*(\\.[^'\\]*)*)')\.$"#)
    }

    func testStringMatches() throws {
        let expression = CucumberExpression("The {string} says {string}.")
        let match = try XCTUnwrap(expression.match(in: #"The "button" says "sign in"."#))
        XCTAssertEqual(match[\.string, index: 0], "button")
        XCTAssertEqual(match[\.string, index: 1], "sign in")
        XCTAssertEqual(try match.first(\.string), "button")
        XCTAssertEqual(try match.last(\.string), "sign in")
        XCTAssertEqual(try match.allParameters(\.string), ["button", "sign in"])
    }

    func testCucumberExpressionGeneratesCorrectRegexForIntParameter() {
        let expression = CucumberExpression(#"There are {int} flights from LAX."#)
        XCTAssertEqual(expression.regex, #"^There are (-?\d+) flights from LAX\.$"#)
    }

    func testIntMatches() throws {
        let expression = CucumberExpression("There are {int} flights from LAX.")
        let match = try XCTUnwrap(expression.match(in: #"There are 3 flights from LAX."#))
        XCTAssertEqual(match[\.int, index: 0], 3)
        XCTAssertEqual(try match.first(\.int), 3)
        XCTAssertEqual(try match.last(\.int), 3)
        XCTAssertEqual(try match.allParameters(\.int), [3])
    }

    func testCucumberExpressionGeneratesCorrectRegexForWordParameter() {
        let expression = CucumberExpression(#"There are {word} flights from LAX."#)
        XCTAssertEqual(expression.regex, #"^There are ([^\s]+) flights from LAX\.$"#)
    }

    func testWordMatches() throws {
        let expression = CucumberExpression("There are {word} flights from LAX.")
        let match = try XCTUnwrap(expression.match(in: #"There are three flights from LAX."#))
        XCTAssertEqual(match[\.word, index: 0], "three")
        XCTAssertEqual(try match.first(\.word), "three")
        XCTAssertEqual(try match.last(\.word), "three")
        XCTAssertEqual(try match.allParameters(\.word), ["three"])
    }

    func testCucumberExpressionGeneratesCorrectRegexForFloatParameter() {
        let expression = CucumberExpression(#"There are {float} flights from LAX."#)
        XCTAssertEqual(expression.regex, #"^There are ((?=.*\d.*)[-+]?\d*(?:\.(?=\d.*))?\d*(?:\d+[E][+-]?\d+)?) flights from LAX\.$"#)
    }

    func testFloatMatches() throws {
        let expression = CucumberExpression("There are {float} flights from LAX.")
        let match = try XCTUnwrap(expression.match(in: #"There are 3.5 flights from LAX."#))
        XCTAssertEqual(match[\.float, index: 0], 3.5)
        XCTAssertEqual(try match.first(\.float), 3.5)
        XCTAssertEqual(try match.last(\.float), 3.5)
        XCTAssertEqual(try match.allParameters(\.float), [3.5])
    }

    func testCucumberExpressionGeneratesCorrectRegexForDoubleParameter() {
        let expression = CucumberExpression(#"There are {double} flights from LAX."#)
        XCTAssertEqual(expression.regex, #"^There are ((?=.*\d.*)[-+]?\d*(?:\.(?=\d.*))?\d*(?:\d+[E][+-]?\d+)?) flights from LAX\.$"#)
    }

    func testDoubleMatches() throws {
        let expression = CucumberExpression("There are {double} flights from LAX.")
        let match = try XCTUnwrap(expression.match(in: #"There are 3.1 flights from LAX."#))
        XCTAssertEqual(match[\.double, index: 0], 3.1)
        XCTAssertEqual(try match.first(\.double), 3.1)
        XCTAssertEqual(try match.last(\.double), 3.1)
        XCTAssertEqual(try match.allParameters(\.double), [3.1])
    }

    func testCucumberExpressionGeneratesCorrectRegexForAnonymousParameter() {
        let expression = CucumberExpression(#"There are {} flights from LAX."#)
        XCTAssertEqual(expression.regex, #"^There are (.*) flights from LAX\.$"#)
    }

    func testAnonymousMatches() throws {
        let expression = CucumberExpression("There are {} flights from LAX.")
        let match = try XCTUnwrap(expression.match(in: #"There are some number of flights from LAX."#))
        XCTAssertEqual(match[\.anonymous, index: 0], "some number of")
        XCTAssertEqual(try match.first(\.anonymous), "some number of")
        XCTAssertEqual(try match.last(\.anonymous), "some number of")
        XCTAssertEqual(try match.allParameters(\.anonymous), ["some number of"])
    }

    func testCucumberExpressionGeneratesCorrectRegexComplexExpression() {
        let expression = CucumberExpression(#"There is/are/were {int} flight(s) from {airport}."#)
        XCTAssertEqual(expression.regex, #"^There (?:is|are|were) (-?\d+) flight(?:s)? from ([A-Z]{3})\.$"#)
    }

    func testComplexMatches() throws {
        let expression = CucumberExpression(#"There is/are/were {int} flight(s) from {airport}."#)
        let match = try XCTUnwrap(expression.match(in: #"There are 3 flights from LAX."#))
        XCTAssertEqual(match[\.int, index: 0], 3)
        XCTAssertEqual(try match.first(\.int), 3)
        XCTAssertEqual(try match.last(\.int), 3)
        XCTAssertEqual(try match.allParameters(\.int), [3])
        XCTAssertIdentical(match[\.airport, index: 0], Airport.lax)
        XCTAssertIdentical(try match.first(\.airport), Airport.lax)
        XCTAssertIdentical(try match.last(\.airport), Airport.lax)
        XCTAssertEqual(try match.allParameters(\.airport).count, 1)
        XCTAssertIdentical(try match.allParameters(\.airport).first, Airport.lax)
    }

    func testAnchoredRegularExpressionMatches() {
        let expression = CucumberExpression("^some step$")
        XCTAssertNotNil(expression.match(in: "some step"))
        XCTAssertNil(expression.match(in: "another step"))
    }

    func testLeadingAnchorAloneIsARegularExpression() {
        let expression = CucumberExpression("^some step")
        XCTAssertNotNil(expression.match(in: "some step"))
        XCTAssertNil(expression.match(in: "not some step"))
    }

    func testTrailingAnchorAloneIsARegularExpression() {
        let expression = CucumberExpression("some step$")
        XCTAssertNotNil(expression.match(in: "some step"))
        XCTAssertNil(expression.match(in: "some step, then more"))
    }

    func testSlashDelimitedStringIsARegularExpression() {
        let expression = CucumberExpression("/some step/")
        XCTAssertNotNil(expression.match(in: "some step"))
        XCTAssertNil(expression.match(in: "another step"))
    }

    func testRegularExpressionModeReturnsThePatternAsWritten() {
        XCTAssertEqual(CucumberExpression("^the app is at the Main Menu$").regex, "^the app is at the Main Menu$")
        XCTAssertEqual(CucumberExpression("some step$").regex, "some step$")
        XCTAssertEqual(CucumberExpression("/some (step)/").regex, "some (step)")
    }

    func testCaptureGroupsInARegularExpressionYieldTheCapturedText() throws {
        let expression = CucumberExpression(#"^I owe (\d+) dollars to (\w+)$"#)
        let match = try XCTUnwrap(expression.match(in: "I owe 42 dollars to Alice"))
        XCTAssertEqual(match[\.anonymous, index: 0], "42")
        XCTAssertEqual(match[\.anonymous, index: 1], "Alice")
        XCTAssertEqual(try match.allParameters(\.anonymous), ["42", "Alice"])
    }

    func testOnlyTopLevelCaptureGroupsAreParameters() throws {
        let match = try XCTUnwrap(CucumberExpression("^((a)|(b))$").match(in: "a"))
        XCTAssertEqual(try match.allParameters(\.anonymous), ["a"])
    }

    func testNonCapturingLookaheadAndClassParenthesesAreNotGroups() throws {
        let match = try XCTUnwrap(CucumberExpression(#"^(?:x)(?=y)y[(]\((\d)\)$"#).match(in: "xy((3)"))
        XCTAssertEqual(try match.allParameters(\.anonymous), ["3"])
    }

    func testParenthesesInRegularExpressionCommentsAreNotGroups() throws {
        let extended = try XCTUnwrap(CucumberExpression("(?x)^((a)) # (\n$").match(in: "a"))
        XCTAssertEqual(try extended.allParameters(\.anonymous), ["a"])
        let inline = try XCTUnwrap(CucumberExpression("^(?# ( )((a))$").match(in: "a"))
        XCTAssertEqual(try inline.allParameters(\.anonymous), ["a"])
    }

    func testExtendedModeCommentsEndAtAnyLineTerminator() throws {
        for terminator in ["\n", "\r", "\r\n"] {
            let match = try XCTUnwrap(CucumberExpression("(?x)^# comment\(terminator)((a))$").match(in: "a"))
            XCTAssertEqual(try match.allParameters(\.anonymous), ["a"])
        }
    }

    func testRegularExpressionSearchesTheStepText() throws {
        // Like a plain regular expression, a pattern matches part of the step text unless both ends are anchored.
        XCTAssertNotNil(CucumberExpression("/some step/").match(in: "do some step now"))
        XCTAssertNotNil(CucumberExpression("^foo").match(in: "foobar"))
        XCTAssertNotNil(CucumberExpression("foo$").match(in: "xfoo"))
        XCTAssertNil(CucumberExpression("^foo$").match(in: "foobar"))
        let match = try XCTUnwrap(CucumberExpression(#"^I have (\d+) cukes"#).match(in: "I have 5 cukes in my belly"))
        XCTAssertEqual(try match.allParameters(\.anonymous), ["5"])
    }

    func testExtendedModeEndsWithItsGroup() throws {
        let scoped = try XCTUnwrap(CucumberExpression("^(?x: a )((b)#)(c)$").match(in: "ab#c"))
        XCTAssertEqual(try scoped.allParameters(\.anonymous), ["b#", "c"])
        let persistent = try XCTUnwrap(CucumberExpression("^(?:(?x) a )((b))#(c)$").match(in: "ab#c"))
        XCTAssertEqual(try persistent.allParameters(\.anonymous), ["b", "c"])
    }

    func testUnmatchedOptionalCaptureKeepsItsPosition() throws {
        let match = try XCTUnwrap(CucumberExpression("^(a)?(b)$").match(in: "b"))
        XCTAssertEqual(try match.allParameters(\.anonymous), ["", "b"])
        XCTAssertEqual(match[\.anonymous, index: 1], "b")
    }

    func testSlashesInsideACucumberExpressionAreStillAlternation() {
        let expression = CucumberExpression("a/b")
        XCTAssertEqual(expression.regex, "^(?:a|b)$")
        XCTAssertNotNil(expression.match(in: "b"))
    }

    func testDollarAnchorMigrationOfCurrencyExpression() throws {
        // "I owe {int}$" used to treat "$" as a literal; it is now a regular expression and traps.
        // Dropping the anchor, or writing a deliberate regular expression, are the two ways forward.
        let withoutAnchor = try XCTUnwrap(CucumberExpression("I owe {int}").match(in: "I owe 5"))
        XCTAssertEqual(try withoutAnchor.first(\.int), 5)

        let escaped = try XCTUnwrap(CucumberExpression(#"^I owe (\d+)\$"#).match(in: "I owe 5$"))
        XCTAssertEqual(try escaped.first(\.anonymous), "5")
    }

    func testAnInvalidAnchoredRegularExpressionIsKeptInsteadOfTrapping() throws {
        let expression = CucumberExpression("^a broken (step runs$")

        let error = try XCTUnwrap(expression.invalidRegularExpression)
        XCTAssertEqual(error.expression, "^a broken (step runs$")
        XCTAssertEqual(error.pattern, "^a broken (step runs$")
        XCTAssertEqual(expression.regex, "^a broken (step runs$")
        XCTAssert(error.description.hasPrefix(#"CucumberExpression: "^a broken (step runs$" starts with ^ or ends with $"#),
                  error.description)
        XCTAssert(error.description.hasSuffix("Remove the anchors, or write a valid regular expression."), error.description)
    }

    func testAnInvalidSlashDelimitedRegularExpressionIsKeptWithoutItsSlashes() throws {
        let error = try XCTUnwrap(CucumberExpression("/a broken (step runs/").invalidRegularExpression)

        XCTAssertEqual(error.expression, "/a broken (step runs/")
        XCTAssertEqual(error.pattern, "a broken (step runs")
        XCTAssert(error.description.contains("is written between slashes"), error.description)
        XCTAssert(error.description.hasSuffix("Remove the slashes, or write a valid regular expression."), error.description)
    }

    func testAnInvalidRegularExpressionStringLiteralDoesNotTrap() {
        let expression: CucumberExpression = "^a broken (step runs$"

        XCTAssertNotNil(expression.invalidRegularExpression)
    }

#if compiler(>=5.7) && canImport(_StringProcessing)
    // Swift's regular expression parser, which says what is wrong with a pattern, needs Swift 5.7.
    func testTheProblemSaysWhatIsWrongWithThePattern() throws {
        guard #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) else {
            throw XCTSkip("Swift's regular expression parser needs iOS 16, macOS 13, tvOS 16 or watchOS 9")
        }
        let error = try XCTUnwrap(CucumberExpression("^a broken (step runs$").invalidRegularExpression)

        XCTAssertEqual(error.problem, "expected ')'")
        XCTAssert(error.description.contains("but it is not valid as one: expected ')'."), error.description)
    }

    func testAPatternOnlySwiftAcceptsFallsBackToFoundationsDescription() throws {
        // NSRegularExpression rejects an omitted lower bound; Swift's parser accepts it, so it cannot
        // say what is wrong, and the problem falls back to Foundation's description.
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *), (try? Regex("^a{,3}$")) == nil {
            throw XCTSkip("This platform's Swift regular expression parser rejects the pattern too")
        }
        let error = try XCTUnwrap(CucumberExpression("^a{,3}$").invalidRegularExpression)

        XCTAssert(error.problem.hasPrefix("The value"), error.problem)
    }
#else
    func testWithoutSwiftsParserTheProblemIsFoundationsDescription() throws {
        let error = try XCTUnwrap(CucumberExpression("^a broken (step runs$").invalidRegularExpression)

        XCTAssert(error.problem.hasPrefix("The value"), error.problem)
    }
#endif

    func testValidatingInitializerThrowsForAnInvalidRegularExpression() {
        XCTAssertThrowsError(try CucumberExpression(validating: "^a broken (step runs$")) { error in
            XCTAssertEqual((error as? InvalidRegularExpression)?.pattern, "^a broken (step runs$")
        }
    }

    func testValidatingInitializerAcceptsValidExpressions() throws {
        XCTAssertNotNil(try CucumberExpression(validating: "^some (step)$").match(in: "some step"))
        XCTAssertNotNil(try CucumberExpression(validating: "I have {int} cukes").match(in: "I have 4 cukes"))
    }

    func testValidExpressionsAreNotInvalidRegularExpressions() {
        XCTAssertNil(CucumberExpression("^some step$").invalidRegularExpression)
        XCTAssertNil(CucumberExpression("/some step/").invalidRegularExpression)
        XCTAssertNil(CucumberExpression("I have {int} cukes").invalidRegularExpression)
        XCTAssertNil(CucumberExpression("a (broken step").invalidRegularExpression,
                     "An unanchored string is a Cucumber expression, not a regular expression")
    }
}

// swiftlint:disable:next convenience_type
class Airport {
    static let lax = Airport()
}

extension CucumberExpression: CustomParameters {
    public static var additionalParameters: [CucumberSwiftExpressions.AnyParameter] {
        [
            AirportParameter().eraseToAnyParameter()
        ]
    }
}

struct AirportParameter: Parameter {
    enum ParameterError: Error {
        case airportNotFound
    }

    static let name = "airport"

    let regexMatch = #"[A-Z]{3}"#

    func convert(input: String) throws -> Airport {
        switch input.lowercased() {
            case "lax": return Airport.lax
            default:
                throw ParameterError.airportNotFound
        }
    }
}

extension Match {
    var airport: AirportParameter {
        AirportParameter()
    }
}
