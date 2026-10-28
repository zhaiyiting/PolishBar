import PolishCore

func runPromptTests() {
    suite("DefaultPrompt")

    let prompt = DefaultPrompt.polish
    check(!prompt.isEmpty, "prompt is non-empty")
    check(prompt.lowercased().contains("native"), "aims for native-speaker English")
    check(prompt.lowercased().contains("grammar"), "mentions fixing grammar")
    check(prompt.lowercased().contains("chinese"), "handles mixed Chinese input")
    check(prompt.contains("ONLY"), "instructs to output only the rewritten text")
    check(Config.default.prompt == prompt, "config default uses the polish prompt")
}
