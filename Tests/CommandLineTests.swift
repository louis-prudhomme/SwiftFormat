//
//  CommandLineTests.swift
//  SwiftFormat
//
//  Created by Nick Lockwood on 10/01/2017.
//  Copyright 2017 Nick Lockwood
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/SwiftFormat
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest
@testable import SwiftFormat

private func createTmpFile(_ path: String? = nil, contents: String) throws -> URL {
    let path = path ?? (UUID().uuidString + ".swift")
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(path)
    let directory = url.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func withTmpFile(_ path: String? = nil, contents: String, fn: (URL) -> Void) throws {
    let path = path ?? (UUID().uuidString + ".swift")
    let prefix = UUID().uuidString
    let url = try createTmpFile("\(prefix)/\(path)", contents: contents)
    fn(url)
    try FileManager.default.removeItem(at: url)
}

private func withTmpFiles(_ files: [String: String], fn: (URL) throws -> Void) throws {
    var urls = [URL]()
    let prefix = UUID().uuidString
    for (path, contents) in files {
        try urls.append(createTmpFile("\(prefix)/\(path)", contents: contents))
    }
    for url in urls where url.pathExtension == "swift" || url.pathExtension == "md" {
        try fn(url)
    }
    for url in urls {
        try FileManager.default.removeItem(at: url)
    }
}

class CommandLineTests: XCTestCase {
    // MARK: stdin

    func testStdin() {
        CLI.print = { message, type in
            switch type {
            case .raw, .content:
                XCTAssertEqual(message, "func foo() {\n    bar()\n}\n")
            case .error, .warning:
                XCTFail()
            case .info, .success:
                break
            }
        }
        var readCount = 0
        CLI.readLine = {
            readCount += 1
            switch readCount {
            case 1:
                return "func foo()\n"
            case 2:
                return "{\n"
            case 3:
                return "bar()\n"
            case 4:
                return "}"
            default:
                return nil
            }
        }
        _ = processArguments([""], in: "")
        readCount = 0
        _ = processArguments(["", "stdin"], in: "")
    }

    func testStdinOutputTokens() {
        CLI.print = { message, type in
            switch type {
            case .raw, .content:
                XCTAssertEqual(message, """
                {"tokens":[\
                {"string":"func","type":"keyword"},\
                {"string":" ","type":"space"},\
                {"string":"foo","type":"identifier"},\
                {"string":"(","type":"startOfScope"},\
                {"string":")","type":"endOfScope"},\
                {"string":" ","type":"space"},\
                {"string":"{","type":"startOfScope"},\
                {"originalLine":2,"string":"\\n","type":"linebreak"},\
                {"string":"    ","type":"space"},\
                {"string":"bar","type":"identifier"},\
                {"string":"(","type":"startOfScope"},\
                {"string":")","type":"endOfScope"},\
                {"string":" ","type":"space"},\
                {"operatorType":"infix","string":"+","type":"operator"},\
                {"string":" ","type":"space"},\
                {"string":"baaz","type":"identifier"},\
                {"string":"(","type":"startOfScope"},\
                {"string":")","type":"endOfScope"},\
                {"string":" ","type":"space"},\
                {"operatorType":"infix","string":"+","type":"operator"},\
                {"string":" ","type":"space"},\
                {"numberType":"integer","string":"25","type":"number"},\
                {"originalLine":3,"string":"\\n","type":"linebreak"},\
                {"string":"}","type":"endOfScope"},\
                {"originalLine":4,"string":"\\n","type":"linebreak"}\
                ],"version":"\(swiftFormatVersion)"}
                """)
            case .error, .warning:
                XCTFail()
            case .info, .success:
                break
            }
        }
        var readCount = 0
        CLI.readLine = {
            readCount += 1
            switch readCount {
            case 1:
                return "func foo()\n"
            case 2:
                return "{\n"
            case 3:
                return "bar() + baaz() + 25\n"
            case 4:
                return "}"
            default:
                return nil
            }
        }

        _ = processArguments(["", "stdin", "--outputtokens"], in: "")
    }

    func testExcludeStdinPath() throws {
        CLI.print = { message, type in
            switch type {
            case .raw, .content:
                XCTAssertEqual(message, "func foo() {\n}\n")
            case .error, .warning:
                XCTFail()
            case .info, .success:
                break
            }
        }
        var readCount = 0
        CLI.readLine = {
            readCount += 1
            switch readCount {
            case 1:
                return "func foo() {\n"
            case 2:
                return "}\n"
            default:
                return nil
            }
        }
        try withTmpFile(contents: "") { url in
            _ = processArguments([
                "",
                "stdin",
                "--stdinpath", url.path,
                "--exclude", url.path,
            ], in: "")
        }
    }

    func testExcludeStdinPath2() throws {
        CLI.print = { message, type in
            switch type {
            case .raw, .content:
                XCTAssertEqual(message, "func foo() {\n}\n")
            case .error, .warning:
                XCTFail()
            case .info, .success:
                break
            }
        }
        var readCount = 0
        CLI.readLine = {
            readCount += 1
            switch readCount {
            case 1:
                return "func foo() {\n"
            case 2:
                return "}\n"
            default:
                return nil
            }
        }
        try withTmpFiles([
            ".swiftformat": "--exclude *",
            "foo.swift": "",
        ]) { url in
            _ = processArguments([
                "",
                "stdin",
                "--stdinpath", url.path,
            ], in: "")
        }
    }

    func testExcludeStdinPath3() throws {
        CLI.print = { message, type in
            switch type {
            case .raw, .content:
                XCTAssertEqual(message, "func foo() {\n}\n")
            case .error, .warning:
                XCTFail()
            case .info, .success:
                break
            }
        }
        var readCount = 0
        CLI.readLine = {
            readCount += 1
            switch readCount {
            case 1:
                return "func foo() {\n"
            case 2:
                return "}\n"
            default:
                return nil
            }
        }
        try withTmpFiles([
            ".swiftformat": "--exclude foo",
            "foo/bar/baz.swift": "",
        ]) { url in
            _ = processArguments([
                "",
                "stdin",
                "--stdinpath", url.path,
            ], in: "")
        }
    }

    func testUnexcludeStdinPath() throws {
        CLI.print = { message, type in
            switch type {
            case .raw, .content:
                XCTAssertEqual(message, "func foo() {}\n")
            case .error, .warning:
                XCTFail()
            case .info, .success:
                break
            }
        }
        var readCount = 0
        CLI.readLine = {
            readCount += 1
            switch readCount {
            case 1:
                return "func foo() {\n"
            case 2:
                return "}\n"
            default:
                return nil
            }
        }
        try withTmpFiles([
            ".swiftformat": """
            --exclude foo
            --unexclude **/baz.*
            """,
            "foo/bar/baz.swift": "",
        ]) { url in
            _ = processArguments([
                "",
                "stdin",
                "--stdinpath", url.path,
            ], in: "")
        }
    }

    // MARK: help

    func testOptionsHelpText() {
        for option in Descriptors.all {
            XCTAssertFalse(
                option.help.contains("\n"),
                "Help for option --\(option.argumentName) contains linebreak"
            )
        }
    }

    func testHelpOptionsImplemented() {
        CLI.print = { message, _ in
            if message.hasPrefix("--") {
                let name = String(message["--".endIndex ..< message.endIndex]).components(separatedBy: " ")[0]
                XCTAssertTrue(commandLineArguments.contains(name), name)
            }
        }
        printHelp(as: .content)
    }

    func testHelpOptionsDocumented() {
        var arguments = Set(commandLineArguments).subtracting(deprecatedArguments)
        CLI.print = { allHelpMessage, _ in
            allHelpMessage
                .components(separatedBy: "\n")
                .forEach { message in
                    if message.hasPrefix("--") {
                        let name = String(message["--".endIndex ..< message.endIndex]).components(separatedBy: " ")[0]
                        XCTAssert(arguments.contains(name), "Unknown option --\(name) in help")
                        arguments.remove(name)
                    }
                }
        }
        printHelp(as: .content)
        printOptions(as: .content)
        XCTAssert(arguments.isEmpty, "\(arguments.joined(separator: ",")) not listed in help")
    }

    func testHelpOptionFormatting() {
        let shortOption = OptionDescriptor(
            argumentName: "option",
            displayName: "option",
            help: "Short option description",
            keyPath: \.fragment,
            trueValues: [],
            falseValues: []
        )

        let mediumOption = OptionDescriptor(
            argumentName: "option-medium",
            displayName: "option-medium",
            help: "Option with a medium name and description length",
            keyPath: \.fragment,
            trueValues: [],
            falseValues: []
        )

        let longOption = OptionDescriptor(
            argumentName: "option-with-longer-name",
            displayName: "option-with-longer-name",
            help: """
            This is a longer option with a name over the original 16 character limit, \
            and a help text over the original 80 character limit.
            """,
            keyPath: \.fragment,
            trueValues: [],
            falseValues: []
        )

        CLI.print = { output, _ in
            guard !output.isEmpty else { return }
            XCTAssertEqual(output, """
            --option           Short option description
            --option           Short option description
            --option-medium    Option with a medium name and description length
            --option-medium    Option with a medium name and description length
            --option-with-longer-name
                               This is a longer option with a name over the original 16 character limit, and a help text over the original 80 character limit.
            --option-with-longer-name
                               This is a longer option with a name over the original 16 character limit, and a help text over the original 80 character limit.
            """)
        }

        printOptions([shortOption, shortOption, mediumOption, mediumOption, longOption, longOption], as: .content)
    }

    // MARK: cache

    func testHashIsFasterThanFormatting() throws {
        let sourceFile = URL(fileURLWithPath: #file)
        let source = try String(contentsOf: sourceFile, encoding: .utf8)
        let hash = computeHash(source + ";")

        let hashTime = timeEvent { _ = computeHash(source) == hash }
        let formatTime = try timeEvent { _ = try format(source) }
        XCTAssertLessThan(hashTime, formatTime)
    }

    func testCacheHit() throws {
        let input = "let foo = bar"
        XCTAssertEqual(computeHash(input), computeHash(input))
    }

    func testCacheMiss() throws {
        let input = "let foo = bar"
        let output = "let foo = bar\n"
        XCTAssertNotEqual(computeHash(input), computeHash(output))
    }

    func testCachePotentialFalsePositive() throws {
        let input = "let foo = bar;"
        let output = "let foo = bar\n"
        XCTAssertNotEqual(computeHash(input), computeHash(output))
    }

    func testCachePotentialFalsePositive2() throws {
        let input = """
        import Foo
        import Bar

        """
        let output = """
        import Bar
        import Foo

        """
        XCTAssertNotEqual(computeHash(input), computeHash(output))
    }

    // MARK: rules

    func testRulesNotMarkedAsDisabled() {
        CLI.print = { message, _ in
            XCTAssert(!message.contains("(disabled)") ||
                FormatRules.disabledByDefault.contains(where: { message.contains($0.name) }))
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "--rules"), .ok)
    }

    func testEnableOverridesDisableAll() {
        CLI.print = { message, _ in
            XCTAssertFalse(message.contains("wrap (disabled)"))
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path,
                               with: "--disable all --enable wrap --rules"), .ok)
    }

    // MARK: quiet mode

    func testQuietModeNoOutput() {
        CLI.print = { message, _ in
            XCTFail(message)
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "--quiet --dry-run"), .ok)
    }

    func testQuietModeAllowsContent() {
        CLI.print = { message, type in
            XCTAssertEqual(type, .content, message)
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "--quiet --help"), .ok)
    }

    func testQuietModeAllowsErrors() {
        CLI.print = { message, type in
            XCTAssertEqual(type, .error, message)
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "foobar.swift --quiet"), .error)
    }

    // MARK: split input paths

    func testSplitInputPaths() {
        CLI.print = { message, type in
            XCTAssertEqual(type, .error, message)
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "Sources --dry-run Tests --rules indent"), .error)
    }

    // MARK: file list

    func testParseFileList() {
        let source = """
        #foo
        Package.swift #bar

        #baz
        Sources/FormatRule.swift
        CommandLineTool/*.swift
        """
        XCTAssertEqual(try parseFileList(source, in: projectDirectory.path), [
            URL(fileURLWithPath: "\(projectDirectory.path)/Package.swift"),
            URL(fileURLWithPath: "\(projectDirectory.path)/Sources/FormatRule.swift"),
            URL(fileURLWithPath: "\(projectDirectory.path)/CommandLineTool/main.swift"),
        ])
    }

    // MARK: script input files

    func testParseScriptInput() throws {
        let result = try parseScriptInput(from: [
            "SCRIPT_INPUT_FILE_COUNT": "2",
            "SCRIPT_INPUT_FILE_0": "\(projectDirectory.path)/File1.swift",
            "SCRIPT_INPUT_FILE_1": "\(projectDirectory.path)/File2.swift",
        ])
        XCTAssertEqual(
            result,
            [
                URL(fileURLWithPath: "\(projectDirectory.path)/File1.swift"),
                URL(fileURLWithPath: "\(projectDirectory.path)/File2.swift"),
            ]
        )
    }

    // MARK: config

    func testBadConfigFails() {
        var error = ""
        CLI.print = { message, type in
            if type == .error {
                error += message + "\n"
            }
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "Tests/BadConfig/Test.swift --unexclude Tests/BadConfig --config Tests/BadConfig/.swiftformat --lint"), .error)
        XCTAssert(error.contains("'ifdef' is not a formatting rule"), error)
    }

    func testBadConfigFails2() {
        var error = ""
        CLI.print = { message, type in
            if type == .error {
                error += message + "\n"
            }
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "Tests/BadConfig/Test.swift --unexclude Tests/BadConfig --lint"), .error)
        XCTAssert(error.contains("'ifdef' is not a formatting rule"), error)
    }

    func testWarnIfOptionsSpecifiedForDisabledRule() {
        CLI.print = { message, type in
            if type == .warning {
                XCTAssertEqual(
                    message,
                    "warning: --header option has no effect when fileHeader rule is disabled"
                )
            }
        }
        XCTAssertEqual(CLI.run(in: projectDirectory.path, with: "stdin --lint --rules indent --header foo"), .ok)
    }

    func testMultipleConfigFiles() throws {
        try withTmpFiles([
            "config1.swiftformat": """
            --indent 2
            --rules trailingCommas
            --rules redundantSelf
            """,
            "config2.swiftformat": """
            --indent 4
            --disable trailingCommas
            """,
            "test.swift": """
            func foo() {
                let array = [1, 2, 3,]
                self.bar()
            }
            """,
        ]) { url in
            guard url.pathExtension == "swift" else { return }
            let testDir = url.deletingLastPathComponent().path

            CLI.print = { _, _ in }

            XCTAssertEqual(
                CLI.run(in: testDir, with: "test.swift --config config1.swiftformat --config config2.swiftformat"),
                .ok
            )

            let output = try String(contentsOf: url, encoding: .utf8)

            XCTAssertEqual(output, """
            func foo() {
                let array = [1, 2, 3,]
                bar()
            }
            """)
        }
    }

    func testMultipleConfigFilesWithCommaDelimitedPaths() throws {
        try withTmpFiles([
            "config1.swiftformat": """
            --indent 2
            --rules trailingCommas
            --rules redundantSelf
            """,
            "config2.swiftformat": """
            --indent 4
            --disable trailingCommas
            """,
            "test.swift": """
            func foo() {
                let array = [1, 2, 3,]
                self.bar()
            }
            """,
        ]) { url in
            guard url.pathExtension == "swift" else { return }
            let testDir = url.deletingLastPathComponent().path

            CLI.print = { _, _ in }

            XCTAssertEqual(
                CLI.run(in: testDir, with: "test.swift --config config1.swiftformat,config2.swiftformat"),
                .ok
            )

            let output = try String(contentsOf: url, encoding: .utf8)

            XCTAssertEqual(output, """
            func foo() {
                let array = [1, 2, 3,]
                bar()
            }
            """)
        }
    }

    // MARK: reporter

    func testJSONReporterEndToEnd() throws {
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { message, type in
                switch type {
                case .raw:
                    XCTAssert(message.contains("\"rule_id\" : \"emptyBraces\""))
                case .error, .warning:
                    break
                case .info, .success:
                    break
                case .content:
                    XCTFail()
                }
            }
            _ = processArguments([
                "",
                "--lint",
                "--reporter",
                "json",
                url.path,
            ], in: "")
        }
    }

    func testJSONReporterInferredFromURL() throws {
        let outputURL = try createTmpFile("report.json", contents: "")
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { _, _ in }
            _ = processArguments([
                "",
                "--lint",
                "--report",
                outputURL.path,
                url.path,
            ], in: "")
        }
        let output = try String(contentsOf: outputURL)
        XCTAssert(output.contains("\"rule_id\" : \"emptyBraces\""))
    }

    func testGithubActionsLogReporterEndToEnd() throws {
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { message, type in
                switch type {
                case .raw:
                    XCTAssert(message.hasPrefix("::warning file=foo.swift,line=1::"))
                case .error, .warning:
                    break
                case .info, .success:
                    break
                case .content:
                    XCTFail()
                }
            }
            _ = processArguments([
                "",
                "--lint",
                "--reporter",
                "github-actions-log",
                url.path,
            ],
            environment: ["GITHUB_WORKSPACE": url.deletingLastPathComponent().path],
            in: "")
        }
    }

    func testGithubActionsLogReporterMisspelled() throws {
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { message, type in
                switch type {
                case .raw, .warning, .info:
                    break
                case .error:
                    XCTAssert(message.contains("did you mean 'github-actions-log'?"))
                case .content, .success:
                    XCTFail()
                }
            }
            _ = processArguments([
                "",
                "--lint",
                "--reporter",
                "github-action-log",
                url.path,
            ], in: "")
        }
    }

    func testXMLReporterEndToEnd() throws {
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { message, type in
                switch type {
                case .raw:
                    XCTAssert(message.contains("<error line=\"1\" column=\"0\" severity=\"warning\""))
                case .error, .warning:
                    break
                case .info, .success:
                    break
                case .content:
                    XCTFail()
                }
            }
            _ = processArguments([
                "",
                "--lint",
                "--reporter",
                "xml",
                url.path,
            ], in: "")
        }
    }

    func testXMLReporterInferredFromURL() throws {
        let outputURL = try createTmpFile("report.xml", contents: "")
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { _, _ in }
            _ = processArguments([
                "",
                "--lint",
                "--report",
                outputURL.path,
                url.path,
            ], in: "")
        }
        let output = try String(contentsOf: outputURL)
        XCTAssert(output.contains("<error line=\"1\" column=\"0\" severity=\"warning\""))
    }

    func testSARIFReporterEndToEnd() throws {
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { message, type in
                switch type {
                case .raw:
                    XCTAssert(message.contains("\"ruleId\" : \"emptyBraces\""))
                case .error, .warning:
                    break
                case .info, .success:
                    break
                case .content:
                    XCTFail()
                }
            }
            _ = processArguments([
                "",
                "--lint",
                "--reporter",
                "sarif",
                url.path,
            ], in: "")
        }
    }

    func testSARIFReporterInferredFromURL() throws {
        let outputURL = try createTmpFile("report.sarif", contents: "")
        try withTmpFiles([
            "foo.swift": "func foo() {\n}\n",
        ]) { url in
            CLI.print = { _, _ in }
            _ = processArguments([
                "",
                "--lint",
                "--report",
                outputURL.path,
                url.path,
            ], in: "")
        }
        let output = try String(contentsOf: outputURL)
        XCTAssert(output.contains("\"ruleId\" : \"emptyBraces\""))
    }

    func testLintCommandOutputsOrganizeDeclarationOrderingViolations() {
        var output: [String] = []
        CLI.print = { message, _ in
            output.append(message)
        }

        let input = """
        struct Test {
            func test() {
                print("Test")
            }
            var foo: Foo
            func bar() {
                print("Bar")
            }
        }
        """

        let lines = input.components(separatedBy: "\n").map { $0 + "\n" }

        var readCount = 0
        CLI.readLine = {
            guard readCount < lines.count else { return nil }
            defer { readCount += 1 }
            return lines[readCount]
        }

        _ = processArguments(["", "stdin", "--lint", "--rules", "organizeDeclarations"], in: "")

        XCTAssertEqual(output, [
            "Running SwiftFormat...",
            "(lint mode - no files will be changed.)",
            ":2:1: error: (organizeDeclarations) Organize declarations within class, struct, enum, actor, and extension bodies.",
            ":5:1: error: (organizeDeclarations) Organize declarations within class, struct, enum, actor, and extension bodies.",
            "Source input did not pass lint check.",
        ])
    }

    func testFormatMarkdownFile() throws {
        CLI.print = { message, type in
            if type == .error {
                XCTFail(message)
            }
        }

        try withTmpFiles([
            "README.md": """
            # Sample README

            This is a nice project with lots of cool APIs to know about, including:

            ```swift
            func foo(
            bar: Bar,
            baaz: Baaz
            ) -> Foo { ... }
            ```

              ```swift --indent 2
              func foo(
              bar: Bar,
              baaz: Baaz
              ) -> Foo { ... }
              ```

            ```swift --disable indent
            print( "foo" )
              print( "bar" )
                print( "baaz" )
            ```

            ```swift --disable spaceInsideParens
            print( "foo" )
              print( "bar" )
                print( "baaz" )
            ```

            ```swift --enable organizeDeclarations
            class Foo {
                init() {}
                func bar() {}
            }
            ```

            ```swift
            --markdownfiles format-lenient ignores blocks that can't be parsed:
            print("Foo
            ```

            Thanks for reading!
            """,
        ]) { url in
            _ = processArguments([
                "",
                url.path,
                "--markdownfiles", "format-lenient",
                "--rules", "indent",
                "--rules", "braces",
                "--rules", "spaceInsideParens",
                "--rules", "linebreakAtEndOfFile",
            ], in: "")

            let updatedReadme = try String(contentsOf: url, encoding: .utf8)

            // The Swift code blocks should be indented correctly:
            XCTAssertEqual(updatedReadme, """
            # Sample README

            This is a nice project with lots of cool APIs to know about, including:

            ```swift
            func foo(
                bar: Bar,
                baaz: Baaz
            ) -> Foo { ... }
            ```

              ```swift --indent 2
              func foo(
                bar: Bar,
                baaz: Baaz
              ) -> Foo { ... }
              ```

            ```swift --disable indent
            print("foo")
              print("bar")
                print("baaz")
            ```

            ```swift --disable spaceInsideParens
            print( "foo" )
            print( "bar" )
            print( "baaz" )
            ```

            ```swift --enable organizeDeclarations
            class Foo {

                // MARK: Lifecycle

                init() {}

                // MARK: Internal

                func bar() {}
            }
            ```

            ```swift
            --markdownfiles format-lenient ignores blocks that can't be parsed:
            print("Foo
            ```

            Thanks for reading!
            """)
        }
    }

    func testStrictMarkdownFormatting() throws {
        var errors = [String]()

        CLI.print = { message, type in
            if type == .error {
                errors.append(message)
            }
        }

        try withTmpFiles([
            "README.md": """
            # Sample README

            This is a nice project with lots of cool APIs to know about, including:

            ```swift
            --markdownfiles format-strict fails if there are parsing errors:
            print("Foo
            ```

            ```swift no-format
            This block is ignored
            print("Foo
            ```

            Thanks for reading!
            """,
        ]) { url in
            _ = processArguments([
                "",
                url.path,
                "--markdownfiles", "format-strict",
                "--rules", "indent",
            ], in: "")
        }

        XCTAssertEqual(errors.count, 1)
        XCTAssert(errors[0].contains("Unexpected end of file at 7:11"))
    }

    func testUnbalancedCodeBlockTokens() throws {
        var errors = [String]()

        CLI.print = { message, type in
            if type == .error {
                errors.append(message)
            }
        }

        try withTmpFiles([
            "README.md": """
            # Sample README

            This markdown file has unbalanced code block tokens:

            ```swift
            print("Hello, world!")
            // Missing closing ```

            This should cause an error in strict mode.
            """,
        ]) { url in
            _ = processArguments([
                "",
                url.path,
                "--markdownfiles", "format-strict",
                "--rules", "indent",
            ], in: "")
        }

        XCTAssertEqual(errors.count, 1)
        XCTAssert(errors[0].contains("Unbalanced code block delimiters in markdown"))
    }

    func testTrailingCommasCollectionsOnlyDoesNotTriggerDeprecationWarning_issue_2141() throws {
        var warnings = [String]()
        CLI.print = { message, type in
            if type == .warning {
                warnings.append(message)
            }
        }

        try withTmpFiles([
            "foo/bar/baz.swift": "",
        ]) { url in
            _ = processArguments(["", url.path, "--trailing-commas", "collections-only", "--swift-version", "6.0"], in: "")
        }

        // Should not contain the deprecation warning about --commas
        XCTAssertEqual(warnings, [])
    }
}
