import XCTest
import CucumberSwiftExpressions

final class SyntaxTests: XCTestCase {
    private func texts(of syntax: CucumberExpression.Syntax) -> [String] {
        syntax.arguments.map { String(syntax.expression[$0.range]) }
    }

    private func names(of syntax: CucumberExpression.Syntax) -> [String] {
        syntax.arguments.map(\.parameterName)
    }

    // MARK: Arguments of a Cucumber expression

    func testParametersAreArgumentsInOrderWithTheirRanges() throws {
        let syntax = try CucumberExpression.Syntax(parsing: "I have {int} cukes in my {string} belly")
        XCTAssertEqual(syntax.kind, .cucumberExpression)
        XCTAssertEqual(names(of: syntax), ["int", "string"])
        XCTAssertEqual(texts(of: syntax), ["{int}", "{string}"])
    }

    func testAnAnonymousParameterHasAnEmptyName() throws {
        let syntax = try CucumberExpression.Syntax(parsing: "I see {}")
        XCTAssertEqual(names(of: syntax), [AnonymousParameter.name])
        XCTAssertEqual(texts(of: syntax), ["{}"])
    }

    func testAnUnknownParameterIsAnArgumentNotAnError() throws {
        let syntax = try CucumberExpression.Syntax(parsing: "I fly from {airport} to {airport}")
        XCTAssertEqual(names(of: syntax), ["airport", "airport"])
    }

    func testOptionalsAlternationsAndEscapesAreNotArguments() throws {
        let syntax = try CucumberExpression.Syntax(parsing: #"There is/are {int} flight(s) \{from\} \(LAX\)"#)
        XCTAssertEqual(names(of: syntax), ["int"])
        XCTAssertEqual(texts(of: syntax), ["{int}"])
    }

    func testAnExpressionWithoutParametersHasNoArguments() throws {
        XCTAssertEqual(try CucumberExpression.Syntax(parsing: "").arguments, [])
        XCTAssertEqual(try CucumberExpression.Syntax(parsing: "the member has A").arguments, [])
    }

    func testAnEscapedCharacterInAParameterNameIsPartOfTheName() throws {
        let syntax = try CucumberExpression.Syntax(parsing: #"{a\ b}"#)
        XCTAssertEqual(names(of: syntax), ["a b"])
        XCTAssertEqual(texts(of: syntax), [#"{a\ b}"#])
    }

    func testRangesCountCharactersNotBytes() throws {
        let syntax = try CucumberExpression.Syntax(parsing: "🥒 café {int} 👍🏽 {word}")
        XCTAssertEqual(texts(of: syntax), ["{int}", "{word}"])
    }

    // MARK: Arguments of a regular expression

    func testEachTopLevelCaptureGroupIsAnAnonymousArgument() throws {
        let syntax = try CucumberExpression.Syntax(parsing: #"^I have (\d+) cukes (?:in|on) (my (\w+)) belly$"#)
        XCTAssertEqual(syntax.kind, .regularExpression)
        XCTAssertEqual(names(of: syntax), [AnonymousParameter.name, AnonymousParameter.name])
        XCTAssertEqual(texts(of: syntax), [#"(\d+)"#, #"(my (\w+))"#])
    }

    func testCaptureGroupRangesAreInTheStringWithItsSlashes() throws {
        let syntax = try CucumberExpression.Syntax(parsing: #"/I have (\d+) (?<what>\w+)/"#)
        XCTAssertEqual(texts(of: syntax), [#"(\d+)"#, #"(?<what>\w+)"#])
    }

    func testParenthesesThatAreNotCaptureGroupsAreNotArguments() throws {
        let syntax = try CucumberExpression.Syntax(parsing: #"^a (?=b)[(](?#c)\(d\) (?<!e)$"#)
        XCTAssertEqual(syntax.arguments, [])
    }

    func testAnInvalidRegularExpressionThrows() {
        XCTAssertThrowsError(try CucumberExpression.Syntax(parsing: "^I have (unclosed$")) { error in
            XCTAssertTrue(error is InvalidRegularExpression, "\(error)")
        }
    }

    // MARK: The same arguments as matching

    /// The arguments are the ones ``CucumberExpression/match(in:)`` passes, so a caller that checks a
    /// step definition against them sees what the step receives at run time.
    func testArgumentsAreTheParametersAMatchPasses() throws {
        let cases: [(expression: String, text: String)] = [
            ("I have {int} cukes", "I have 3 cukes"),
            ("{int} and {word} and {string} and {float} and {}", #"1 and two and "three" and 4.5 and six"#),
            (#"There is/are {int} flight(s) from \{LAX\}"#, "There are 2 flights from {LAX}"),
            (#"{int}\/{int}"#, "1/2"),
            ("{word} x/y a/b {int}", "w y b 7"),
            (#"^I have (\d+) cukes (?:in|on) (my (\w+)) belly$"#, "I have 3 cukes in my big belly"),
            (#"/(a)(b(c))?(?<d>d)/"#, "ad"),
            (#"^(?x) (a) # (b) $"#, "a")
        ]
        for (expression, text) in cases {
            let syntax = try CucumberExpression.Syntax(parsing: expression)
            let match = try XCTUnwrap(CucumberExpression(expression).match(in: text), expression)
            let counts = Dictionary(names(of: syntax).map { ($0, 1) }, uniquingKeysWith: +)
            XCTAssertEqual(try match.allParameters(\.int).count, counts["int"] ?? 0, expression)
            XCTAssertEqual(try match.allParameters(\.word).count, counts["word"] ?? 0, expression)
            XCTAssertEqual(try match.allParameters(\.string).count, counts["string"] ?? 0, expression)
            XCTAssertEqual(try match.allParameters(\.float).count, counts["float"] ?? 0, expression)
            XCTAssertEqual(try match.allParameters(\.anonymous).count, counts[AnonymousParameter.name] ?? 0, expression)
        }
    }
}
