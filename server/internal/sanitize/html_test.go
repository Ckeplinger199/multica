package sanitize

import (
	"testing"
)

func TestHTML(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name:  "plain text",
			input: "hello world",
			want:  "hello world",
		},
		{
			name:  "safe markdown",
			input: "**bold** and *italic*",
			want:  "**bold** and *italic*",
		},
		{
			name:  "script tag stripped",
			input: `<script>alert(1)</script>`,
			want:  "",
		},
		{
			name:  "iframe stripped",
			input: `<iframe srcdoc="<script>parent.__xss=1</script>"></iframe>`,
			want:  "",
		},
		{
			name:  "img with onerror stripped",
			input: `<img src=x onerror="alert(1)">`,
			want:  `<img src="x">`,
		},
		{
			name:  "safe link preserved",
			input: `<a href="https://example.com">link</a>`,
			want:  `<a href="https://example.com" rel="nofollow">link</a>`,
		},
		{
			name:  "file card div preserved",
			input: `<div data-type="fileCard" data-href="https://cdn.example.com/file.pdf" data-filename="report.pdf"></div>`,
			want:  `<div data-type="fileCard" data-href="https://cdn.example.com/file.pdf" data-filename="report.pdf"></div>`,
		},
		{
			name:  "object tag stripped",
			input: `<object data="evil.swf"></object>`,
			want:  "",
		},
		{
			name:  "embed tag stripped",
			input: `<embed src="evil.swf">`,
			want:  "",
		},
		{
			name:  "style tag stripped",
			input: `<style>body{display:none}</style>`,
			want:  "",
		},
		{
			name:  "mention link preserved",
			input: `[@User](mention://member/abc-123)`,
			want:  `[@User](mention://member/abc-123)`,
		},
		{
			name:  "file card with javascript href stripped",
			input: `<div data-type="fileCard" data-href="javascript:alert(1)" data-filename="evil.pdf"></div>`,
			want:  `<div data-type="fileCard" data-filename="evil.pdf"></div>`,
		},
		{
			name:  "file card with data URI stripped",
			input: `<div data-type="fileCard" data-href="data:text/html,<script>alert(1)</script>" data-filename="x.html"></div>`,
			want:  `<div data-type="fileCard" data-filename="x.html"></div>`,
		},
		{
			name:  "file card with http href preserved",
			input: `<div data-type="fileCard" data-href="http://example.com/file.pdf" data-filename="file.pdf"></div>`,
			want:  `<div data-type="fileCard" data-href="http://example.com/file.pdf" data-filename="file.pdf"></div>`,
		},
		// Code block protection tests (issue #704)
		{
			name:  "fenced code block preserves angle brackets",
			input: "```go\nfunc foo() <-chan int {\n\treturn make(chan int)\n}\n```",
			want:  "```go\nfunc foo() <-chan int {\n\treturn make(chan int)\n}\n```",
		},
		{
			name:  "fenced code block preserves generics",
			input: "```typescript\nconst x: Array<string> = []\n```",
			want:  "```typescript\nconst x: Array<string> = []\n```",
		},
		{
			name:  "fenced code block preserves gt operator",
			input: "```python\nif x > 0:\n    print(x)\n```",
			want:  "```python\nif x > 0:\n    print(x)\n```",
		},
		{
			name:  "fenced code block preserves HTML tags in code",
			input: "```html\n<script>alert(1)</script>\n<div>hello</div>\n```",
			want:  "```html\n<script>alert(1)</script>\n<div>hello</div>\n```",
		},
		{
			name:  "inline code preserves angle brackets",
			input: "Use `Array<string>` for typed arrays",
			want:  "Use `Array<string>` for typed arrays",
		},
		{
			name:  "inline code preserves gt operator",
			input: "Check `x > 0` before proceeding",
			want:  "Check `x > 0` before proceeding",
		},
		{
			name:  "inline code preserves ampersand",
			input: "Use `a & b` for bitwise AND",
			want:  "Use `a & b` for bitwise AND",
		},
		{
			name:  "double backtick inline code preserved",
			input: "Use ``Map<string, List<int>>`` for nested generics",
			want:  "Use ``Map<string, List<int>>`` for nested generics",
		},
		{
			name:  "mixed code and XSS - code protected, XSS stripped",
			input: "Use `x > 0` and <script>alert(1)</script> done",
			want:  "Use `x > 0` and  done",
		},
		{
			name:  "tilde fenced code block preserved",
			input: "~~~rust\nfn main() -> Result<(), Error> {}\n~~~",
			want:  "~~~rust\nfn main() -> Result<(), Error> {}\n~~~",
		},
		{
			name:  "multiple code blocks preserved",
			input: "```go\na > b\n```\n\nSome text\n\n```ts\nx < y\n```",
			want:  "```go\na > b\n```\n\nSome text\n\n```ts\nx < y\n```",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := HTML(tt.input)
			if got != tt.want {
				t.Errorf("HTML() =\n  %q\nwant\n  %q", got, tt.want)
			}
		})
	}
}
