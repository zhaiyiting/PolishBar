@main
struct Runner {
    static func main() async {
        runSentenceTests()
        runConfigTests()
        runPromptTests()
        runOpenAIWireTests()
        await runLoggingTests()
        await runControllerTests()
        finish()
    }
}
