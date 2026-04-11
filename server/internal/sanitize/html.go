package sanitize

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/microcosm-cc/bluemonday"
)

// httpURL matches only http:// and https:// URLs — blocks javascript:, data:, etc.
var httpURL = regexp.MustCompile(`^https?://`)

// policy is a shared bluemonday policy that allows safe Markdown HTML while
// stripping dangerous elements (script, iframe, object, embed, style, on*).
var policy *bluemonday.Policy

func init() {
	policy = bluemonday.UGCPolicy()
	policy.AllowElements("div", "span")
	// Allow file-card data attributes, but restrict data-href to http(s) only
	// to prevent javascript: and other dangerous URL schemes.
	policy.AllowAttrs("data-type", "data-filename").OnElements("div")
	policy.AllowAttrs("data-href").Matching(httpURL).OnElements("div")
	policy.AllowAttrs("class").OnElements("code", "div", "span", "pre")
}

// fencedCodeBacktick matches ```-fenced code blocks (with optional language tag).
var fencedCodeBacktick = regexp.MustCompile("(?ms)^```[^\n]*\n.*?^```\\s*$")

// fencedCodeTilde matches ~~~-fenced code blocks (with optional language tag).
var fencedCodeTilde = regexp.MustCompile("(?ms)^~~~[^\n]*\n.*?^~~~\\s*$")

// inlineCodeDouble matches double-backtick inline code (e.g. ``code``).
var inlineCodeDouble = regexp.MustCompile("``[^`]+``")

// inlineCodeSingle matches single-backtick inline code (e.g. `code`).
var inlineCodeSingle = regexp.MustCompile("`[^`\n]+`")

// HTML sanitizes user-provided HTML/Markdown content, stripping dangerous
// tags (script, iframe, object, embed, etc.) and event-handler attributes.
//
// Code blocks (fenced and inline) are protected from bluemonday to prevent
// it from encoding HTML entities or stripping tag-like syntax in code.
func HTML(input string) string {
	var placeholders []string

	replace := func(match string) string {
		idx := len(placeholders)
		placeholders = append(placeholders, match)
		return fmt.Sprintf("\x00CODE_%d\x00", idx)
	}

	// Protect fenced code blocks first (higher priority), then inline code.
	s := fencedCodeBacktick.ReplaceAllStringFunc(input, replace)
	s = fencedCodeTilde.ReplaceAllStringFunc(s, replace)
	s = inlineCodeDouble.ReplaceAllStringFunc(s, replace)
	s = inlineCodeSingle.ReplaceAllStringFunc(s, replace)

	s = policy.Sanitize(s)

	// Restore code blocks.
	for i, original := range placeholders {
		s = strings.Replace(s, fmt.Sprintf("\x00CODE_%d\x00", i), original, 1)
	}

	return s
}
