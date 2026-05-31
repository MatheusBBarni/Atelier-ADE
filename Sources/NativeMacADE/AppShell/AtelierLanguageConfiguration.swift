import LanguageSupport

private let atelierJavaScriptReservedIdentifiers = [
    "arguments", "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger",
    "default", "delete", "do", "else", "export", "extends", "false", "finally", "for", "function",
    "if", "import", "in", "instanceof", "let", "new", "null", "of", "return", "static", "super",
    "switch", "this", "throw", "true", "try", "typeof", "undefined", "var", "void", "while", "with",
    "yield"
]

private let atelierTypeScriptReservedIdentifiers = atelierJavaScriptReservedIdentifiers + [
    "abstract", "any", "as", "asserts", "bigint", "boolean", "declare", "enum", "from", "get", "implements",
    "infer", "interface", "is", "keyof", "module", "namespace", "never", "number", "object", "override",
    "private", "protected", "public", "readonly", "require", "satisfies", "set", "string", "symbol", "type",
    "unique", "unknown"
]

private let atelierJSONReservedIdentifiers = ["true", "false", "null"]

private let atelierYAMLReservedIdentifiers = ["true", "false", "null", "yes", "no", "on", "off"]

private let atelierJavaReservedIdentifiers = [
    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue",
    "default", "do", "double", "else", "enum", "extends", "false", "final", "finally", "float", "for",
    "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "null",
    "package", "private", "protected", "public", "return", "short", "static", "strictfp", "super", "switch",
    "synchronized", "this", "throw", "throws", "transient", "true", "try", "void", "volatile", "while"
]

private let atelierKotlinReservedIdentifiers = [
    "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in", "interface", "is",
    "null", "object", "package", "return", "super", "this", "throw", "true", "try", "typealias", "val", "var",
    "when", "while", "by", "catch", "constructor", "delegate", "dynamic", "field", "file", "finally", "get",
    "import", "init", "param", "property", "receiver", "set", "setparam", "where"
]

private let atelierGoReservedIdentifiers = [
    "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "false", "for",
    "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct",
    "switch", "true", "type", "var"
]

private let atelierShellReservedIdentifiers = [
    "if", "then", "else", "elif", "fi", "for", "in", "do", "done", "case", "esac", "while", "until",
    "function", "select", "time", "coproc", "return", "export", "readonly", "local"
]

private let atelierRustReservedIdentifiers = [
    "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
    "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
    "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe",
    "use", "where", "while"
]

private let atelierMakefileReservedIdentifiers = [
    "include", "ifdef", "ifndef", "ifeq", "ifneq", "else", "endif", ".PHONY", ".DEFAULT_GOAL"
]

private let atelierOCamlReservedIdentifiers = [
    "and", "as", "assert", "begin", "class", "constraint", "do", "done", "downto", "else", "end", "exception",
    "external", "false", "for", "fun", "function", "functor", "if", "in", "include", "inherit", "initializer",
    "lazy", "let", "match", "method", "module", "mutable", "new", "nonrec", "object", "of", "open", "or",
    "private", "rec", "sig", "struct", "then", "to", "true", "try", "type", "val", "virtual", "when", "while",
    "with"
]

private let atelierReasonMLReservedIdentifiers = atelierOCamlReservedIdentifiers + [
    "esfun", "switch", "pub", "pri"
]

private let atelierReScriptReservedIdentifiers = [
    "and", "as", "assert", "async", "await", "class", "constraint", "else", "exception", "external", "false", "for",
    "if", "in", "include", "let", "module", "mutable", "open", "private", "pub", "rec", "switch", "true", "try",
    "type", "when", "while", "with"
]

private let atelierOPAMReservedIdentifiers = [
    "build", "depends", "depexts", "dev-repo", "homepage", "license", "maintainer", "name", "opam-version", "run-test",
    "synopsis", "tags", "url", "version", "with-doc", "with-test"
]

private let atelierMavenReservedIdentifiers = [
    "project", "modelVersion", "groupId", "artifactId", "version", "packaging", "dependencies", "dependency", "plugins",
    "plugin", "build", "properties", "parent", "modules", "repositories", "repository", "scope"
]

private let atelierXMLReservedIdentifiers = [
    "xml", "version", "encoding", "xmlns", "schemaLocation", "DOCTYPE"
]

extension LanguageConfiguration {
    static func atelierJavaScript() -> LanguageConfiguration {
        atelierScriptConfiguration(name: "JavaScript", reservedIdentifiers: atelierJavaScriptReservedIdentifiers)
    }

    static func atelierTypeScript() -> LanguageConfiguration {
        atelierScriptConfiguration(name: "TypeScript", reservedIdentifiers: atelierTypeScriptReservedIdentifiers)
    }

    static func atelierJSON() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "JSON",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"/,
            characterRegex: nil,
            numberRegex: /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/,
            singleLineComment: nil,
            nestedComment: nil,
            identifierRegex: /[A-Za-z_][A-Za-z0-9_]*/,
            operatorRegex: nil,
            reservedIdentifiers: atelierJSONReservedIdentifiers,
            reservedOperators: []
        )
    }

    static func atelierYAML() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "YAML",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/,
            characterRegex: nil,
            numberRegex: /-?(?:0|[1-9]\d*)(?:\.\d+)?/,
            singleLineComment: "#",
            nestedComment: nil,
            identifierRegex: /[A-Za-z_][A-Za-z0-9_.-]*/,
            operatorRegex: /[:?&*!|>%@-]+/,
            reservedIdentifiers: atelierYAMLReservedIdentifiers,
            reservedOperators: [":", "-", "|"]
        )
    }

    static func atelierMarkdown() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Markdown",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: false,
            stringRegex: /`[^`]*`|"(?:\\.|[^"\\])*"/,
            characterRegex: nil,
            numberRegex: /\d+/,
            singleLineComment: nil,
            nestedComment: nil,
            identifierRegex: /[A-Za-z][A-Za-z0-9_-]*/,
            operatorRegex: /[#*_`>\-\[\]()!]+/,
            reservedIdentifiers: [],
            reservedOperators: ["#", "*", "`", ">", "-"]
        )
    }

    static func atelierJava() -> LanguageConfiguration {
        atelierCLikeConfiguration(name: "Java", reservedIdentifiers: atelierJavaReservedIdentifiers)
    }

    static func atelierKotlin() -> LanguageConfiguration {
        atelierCLikeConfiguration(name: "Kotlin", reservedIdentifiers: atelierKotlinReservedIdentifiers)
    }

    static func atelierGo() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Go",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"|`[^`]*`/,
            characterRegex: /'(?:\\.|[^'\\])'/,
            numberRegex: /-?(?:0[xX][0-9A-Fa-f]+|\d+(?:\.\d+)?)/,
            singleLineComment: "//",
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: /[A-Za-z_][A-Za-z0-9_]*/,
            operatorRegex: /[:=+*\/%&|^!<>.-]+/,
            reservedIdentifiers: atelierGoReservedIdentifiers,
            reservedOperators: [":="]
        )
    }

    static func atelierShell() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Shell",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`[^`]*`/,
            characterRegex: nil,
            numberRegex: /-?(?:0|[1-9]\d*)/,
            singleLineComment: "#",
            nestedComment: nil,
            identifierRegex: /[A-Za-z_][A-Za-z0-9_]*/,
            operatorRegex: /[|&;<>=$!:+*?~-]+/,
            reservedIdentifiers: atelierShellReservedIdentifiers,
            reservedOperators: ["&&", "||", "|", ";", ">", "<"]
        )
    }

    static func atelierRust() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Rust",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /r#*"(?:.|\n)*?"#*|b?"(?:\\.|[^"\\])*"/,
            characterRegex: /b?'(?:\\.|[^'\\])'/,
            numberRegex: /-?(?:0[xX][0-9A-Fa-f_]+|\d[\d_]*(?:\.\d[\d_]*)?)/,
            singleLineComment: "//",
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: /[A-Za-z_][A-Za-z0-9_]*/,
            operatorRegex: /[:=+*\/%&|^!<>?.-]+/,
            reservedIdentifiers: atelierRustReservedIdentifiers,
            reservedOperators: ["->", "=>", "::"]
        )
    }

    static func atelierOCaml() -> LanguageConfiguration {
        atelierMLConfiguration(name: "OCaml", reservedIdentifiers: atelierOCamlReservedIdentifiers)
    }

    static func atelierReasonML() -> LanguageConfiguration {
        atelierMLConfiguration(name: "ReasonML", reservedIdentifiers: atelierReasonMLReservedIdentifiers)
    }

    static func atelierReScript() -> LanguageConfiguration {
        atelierMLConfiguration(name: "ReScript", reservedIdentifiers: atelierReScriptReservedIdentifiers)
    }

    static func atelierOPAM() -> LanguageConfiguration {
        atelierMLConfiguration(name: "OPAM", reservedIdentifiers: atelierOPAMReservedIdentifiers)
    }

    static func atelierMaven() -> LanguageConfiguration {
        atelierXMLLikeConfiguration(name: "Maven", reservedIdentifiers: atelierMavenReservedIdentifiers)
    }

    static func atelierMakefile() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Makefile",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/,
            characterRegex: nil,
            numberRegex: /\d+/,
            singleLineComment: "#",
            nestedComment: nil,
            identifierRegex: /[.$A-Za-z_][.$A-Za-z0-9_-]*/,
            operatorRegex: /[:=+@\\$(){}%<>-]+/,
            reservedIdentifiers: atelierMakefileReservedIdentifiers,
            reservedOperators: [":", "=", "+=", "?="]
        )
    }

    static func atelierXML() -> LanguageConfiguration {
        atelierXMLLikeConfiguration(name: "XML", reservedIdentifiers: atelierXMLReservedIdentifiers)
    }

    private static func atelierScriptConfiguration(
        name: String,
        reservedIdentifiers: [String]
    ) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/,
            characterRegex: nil,
            numberRegex: /-?(?:0[xX][0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/,
            singleLineComment: "//",
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: /[$A-Za-z_][$0-9A-Za-z_]*/,
            operatorRegex: /[+*\/%=&|^!<>?:~.-]+/,
            reservedIdentifiers: reservedIdentifiers,
            reservedOperators: ["=>"]
        )
    }

    private static func atelierCLikeConfiguration(
        name: String,
        reservedIdentifiers: [String]
    ) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/,
            characterRegex: /'(?:\\.|[^'\\])'/,
            numberRegex: /-?(?:0[xX][0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/,
            singleLineComment: "//",
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: /[$A-Za-z_][$0-9A-Za-z_]*/,
            operatorRegex: /[+*\/%=&|^!<>?:~.-]+/,
            reservedIdentifiers: reservedIdentifiers,
            reservedOperators: ["=>"]
        )
    }

    private static func atelierMLConfiguration(
        name: String,
        reservedIdentifiers: [String]
    ) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:\\.|[^"\\])*"/,
            characterRegex: /'(?:\\.|[^'\\])'/,
            numberRegex: /-?(?:0[xX][0-9A-Fa-f]+|\d+(?:\.\d+)?)/,
            singleLineComment: nil,
            nestedComment: (open: "(*", close: "*)"),
            identifierRegex: /[A-Za-z_][A-Za-z0-9_']*/,
            operatorRegex: /[:=+*\/%&|^!<>@?-]+/,
            reservedIdentifiers: reservedIdentifiers,
            reservedOperators: ["=>", "->", "|>"]
        )
    }

    private static func atelierXMLLikeConfiguration(
        name: String,
        reservedIdentifiers: [String]
    ) -> LanguageConfiguration {
        LanguageConfiguration(
            name: name,
            supportsSquareBrackets: false,
            supportsCurlyBrackets: false,
            stringRegex: /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/,
            characterRegex: nil,
            numberRegex: /\d+(?:\.\d+)?/,
            singleLineComment: nil,
            nestedComment: nil,
            identifierRegex: /[A-Za-z_][A-Za-z0-9_.:-]*/,
            operatorRegex: /[-<>\/=!?]+/,
            reservedIdentifiers: reservedIdentifiers,
            reservedOperators: ["<", ">", "</", "/>", "="]
        )
    }
}
