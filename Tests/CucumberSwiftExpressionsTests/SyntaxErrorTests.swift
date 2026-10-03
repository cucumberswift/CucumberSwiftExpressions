import XCTest
import CucumberSwiftExpressions

final class SyntaxErrorTests: XCTestCase {
    private func syntaxError(_ expression: String, file: StaticString = #filePath, line: UInt = #line) -> CucumberExpression.SyntaxError? {
        do {
            _ = try CucumberExpression.Syntax(parsing: expression)
            XCTFail("\"\(expression)\" parsed without an error", file: file, line: line)
        } catch let error as CucumberExpression.SyntaxError {
            return error
        } catch {
            XCTFail("\"\(expression)\" threw \(error)", file: file, line: line)
        }
        return nil
    }

    // MARK: Syntax errors, as the specification's test data reports them

    func testAParameterWithoutItsClosingBrace() throws {
        let error = try XCTUnwrap(syntaxError("I have {int cukes"))
        XCTAssertEqual(error.problem, .missingClosingBrace)
        XCTAssertEqual(String(error.expression[error.range]), "{")
        XCTAssertEqual(error.range.lowerBound, error.expression.firstIndex(of: "{"))
        XCTAssertEqual(error.message, "The '{' does not have a matching '}'")
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 8:

            I have {int cukes
                   ^
            The '{' does not have a matching '}'.
            If you did not intend to use a parameter you can use '\{' to escape the a parameter
            """#)
    }

    func testAnEscapedClosingBraceDoesNotCloseAParameter() throws {
        let error = try XCTUnwrap(syntaxError(#"three (exceptionally\) {string\} mice"#))
        XCTAssertEqual(error.problem, .missingClosingBrace)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 24:

            three (exceptionally\) {string\} mice
                                   ^
            The '{' does not have a matching '}'.
            If you did not intend to use a parameter you can use '\{' to escape the a parameter
            """#)
    }

    func testAnOptionalWithoutItsClosingParenthesis() throws {
        let error = try XCTUnwrap(syntaxError("three ((exceptionally\\) strong) mice"))
        XCTAssertEqual(error.problem, .missingClosingParenthesis)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 7:

            three ((exceptionally\) strong) mice
                  ^
            The '(' does not have a matching ')'.
            If you did not intend to use optional text you can use '\(' to escape the optional text
            """#)
    }

    func testAnUnclosedOptionalAfterAnAlternation() throws {
        let error = try XCTUnwrap(syntaxError(#"three blind\ mice/rats("#))
        XCTAssertEqual(error.problem, .missingClosingParenthesis)
        XCTAssertEqual(error.description.components(separatedBy: "\n").first,
                       "This Cucumber Expression has a problem at column 23:")
    }

    func testAnOpeningBraceOrParenthesisAlone() throws {
        XCTAssertEqual(syntaxError("{")?.problem, .missingClosingBrace)
        XCTAssertEqual(syntaxError("(")?.problem, .missingClosingParenthesis)
    }

    func testAReservedCharacterInAParameterName() throws {
        let error = try XCTUnwrap(syntaxError("{(string)}"))
        XCTAssertEqual(error.problem, .invalidParameterName)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 2:

            {(string)}
             ^
            Parameter names may not contain '{', '}', '(', ')', '\' or '/'.
            Did you mean to use a regular expression?
            """#)
    }

    func testAParameterInsideAnOptional() throws {
        let error = try XCTUnwrap(syntaxError("({int})"))
        XCTAssertEqual(error.problem, .parameterInOptional)
        XCTAssertEqual(String(error.expression[error.range]), "{int}")
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 2:

            ({int})
             ^---^
            An optional may not contain a parameter type.
            If you did not mean to use an parameter type you can use '\{' to escape the '{'
            """#)
    }

    func testAnOptionalInsideAnOptional() throws {
        let error = try XCTUnwrap(syntaxError("(a(b))"))
        XCTAssertEqual(error.problem, .optionalInOptional)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 3:

            (a(b))
              ^-^
            An optional may not contain an other optional.
            If you did not mean to use an optional type you can use '\(' to escape the '('. For more complicated expressions consider using a regular expression instead.
            """#)
    }

    func testAnEmptyOptional() throws {
        let error = try XCTUnwrap(syntaxError("three () mice"))
        XCTAssertEqual(error.problem, .emptyOptional)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 7:

            three () mice
                  ^^
            An optional must contain some text.
            If you did not mean to use an optional you can use '\(' to escape the '('
            """#)
    }

    func testAnAlternationInsideAnOptional() throws {
        let error = try XCTUnwrap(syntaxError("three( brown/black) mice"))
        XCTAssertEqual(error.problem, .alternationInOptional)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 13:

            three( brown/black) mice
                        ^
            An alternation can not be used inside an optional.
            If you did not mean to use an alternation you can use '\/' to escape the '/'. Otherwise rephrase your expression or consider using a regular expression instead.
            """#)
    }

    func testAnEmptyAlternativeIsAnEmptyRange() throws {
        let error = try XCTUnwrap(syntaxError("three brown//black mice"))
        XCTAssertEqual(error.problem, .emptyAlternative)
        XCTAssertTrue(error.range.isEmpty)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 13:

            three brown//black mice
                        ^
            Alternative may not be empty.
            If you did not mean to use an alternative you can use '\/' to escape the '/'
            """#)
    }

    func testAnAlternationNextToAParameterNeedsTextOnBothSides() throws {
        let right = try XCTUnwrap(syntaxError("x/{int}"))
        XCTAssertEqual(right.problem, .emptyAlternative)
        XCTAssertEqual(right.description.components(separatedBy: "\n").first,
                       "This Cucumber Expression has a problem at column 3:")
        let left = try XCTUnwrap(syntaxError("{int}/x"))
        XCTAssertEqual(left.problem, .emptyAlternative)
        XCTAssertEqual(left.description.components(separatedBy: "\n").first,
                       "This Cucumber Expression has a problem at column 6:")
    }

    func testAnAlternativeOfOnlyOptionalText() throws {
        let error = try XCTUnwrap(syntaxError("three (brown)/black mice"))
        XCTAssertEqual(error.problem, .alternativeWithOnlyOptionals)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 7:

            three (brown)/black mice
                  ^-----^
            An alternative may not exclusively contain optionals.
            If you did not mean to use an optional you can use '\(' to escape the '('
            """#)
    }

    func testOnlyReservedCharactersCanBeEscaped() throws {
        let error = try XCTUnwrap(syntaxError(#"\["#))
        XCTAssertEqual(error.problem, .cannotEscape)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 2:

            \[
             ^
            Only the characters '{', '}', '(', ')', '\', '/' and whitespace can be escaped.
            If you did mean to use an '\' you can use '\\' to escape it
            """#)
    }

    func testTheEndOfTheExpressionCannotBeEscaped() throws {
        let error = try XCTUnwrap(syntaxError(#"\"#))
        XCTAssertEqual(error.problem, .escapedEndOfLine)
        XCTAssertEqual(error.description, #"""
            This Cucumber Expression has a problem at column 1:

            \
            ^
            The end of line can not be escaped.
            You can use '\\' to escape the '\'
            """#)
    }

    func testColumnsCountCharacters() throws {
        let error = try XCTUnwrap(syntaxError("🥒 {int"))
        XCTAssertEqual(error.description.components(separatedBy: "\n").first,
                       "This Cucumber Expression has a problem at column 3:")
    }

    // MARK: The lenient initializers do not change

    func testAnExpressionWithASyntaxErrorStillMatchesLeniently() throws {
        for expression in ["I have {int cukes", "three () mice", "({int})", #"I have \d cukes"#] {
            XCTAssertNotNil(syntaxError(expression))
            let lenient = CucumberExpression(expression)
            XCTAssertNoThrow(try CucumberExpression(validating: expression))
            XCTAssertNil(lenient.invalidRegularExpression)
        }
    }
}
