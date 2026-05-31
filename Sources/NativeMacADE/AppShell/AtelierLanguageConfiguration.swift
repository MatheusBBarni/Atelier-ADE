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
}
