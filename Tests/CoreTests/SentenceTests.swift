import PolishCore

func runSentenceTests() {
    suite("SentenceCapture")

    do {
        let r = SentenceCapture.beforeCaret(in: "Hello world. How are you", caret: 24, maxLength: 400)
        equalOptional(r?.text, "How are you", "captures sentence after period")
        equalOptional(r?.start, 13, "reports correct start offset")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "Hello world. How are you", caret: 16, maxLength: 400)
        equalOptional(r?.text, "How", "captures from sentence start when caret is mid-sentence")
        equalOptional(r?.start, 13, "start offset mid-sentence")
    }

    do {
        equalOptional(SentenceCapture.beforeCaret(in: "Hi. ", caret: 4, maxLength: 400), nil, "nil right after terminator+space")
        equalOptional(SentenceCapture.beforeCaret(in: "Hi. ", caret: 3, maxLength: 400), nil, "nil right after terminator")
    }

    do {
        equalOptional(SentenceCapture.beforeCaret(in: "", caret: 0, maxLength: 400), nil, "nil for empty text")
        equalOptional(SentenceCapture.beforeCaret(in: "Hello", caret: 0, maxLength: 400), nil, "nil at start of text")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "你好。今天天气很好", caret: 9, maxLength: 400)
        equalOptional(r?.text, "今天天气很好", "captures CJK sentence")
        equalOptional(r?.start, 3, "CJK start offset")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "Just some words", caret: 15, maxLength: 400)
        equalOptional(r?.text, "Just some words", "captures whole text when no terminator")
        equalOptional(r?.start, 0, "start is 0 without terminator")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "Wow?! Really", caret: 12, maxLength: 400)
        equalOptional(r?.text, "Really", "run of terminators is a single boundary")
        equalOptional(r?.start, 6, "start after terminator run")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "Line one\nLine two", caret: 17, maxLength: 400)
        equalOptional(r?.text, "Line two", "newline terminates a sentence")
        equalOptional(r?.start, 9, "start after newline")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "First.    Second   ", caret: 19, maxLength: 400)
        equalOptional(r?.text, "Second", "trims surrounding whitespace")
        equalOptional(r?.start, 10, "start after trimming")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "One two three four", caret: 18, maxLength: 7)
        equalOptional(r?.text, "ee four", "caps length keeping text nearest caret")
        equalOptional(r?.start, 11, "start adjusted by cap")
    }

    do {
        let r = SentenceCapture.beforeCaret(in: "pi is 3.14 now", caret: 14, maxLength: 400)
        equalOptional(r?.text, "14 now", "period inside decimals still boundaries")
        equalOptional(r?.start, 8, "decimal boundary start")
    }
}
