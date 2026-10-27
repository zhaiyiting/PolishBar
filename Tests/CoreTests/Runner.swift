@main
struct Runner {
    static func main() async {
        runSentenceTests()
        runConfigTests()
        await runControllerTests()
        finish()
    }
}
