package usage

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// scanPi reads Pi JSONL session files from
// ~/.pi/sessions/*.jsonl
// and extracts token usage from agent_end events.
//
// Pi logs session events as JSONL. Token usage appears in:
//   - "agent_end" events with a "usage" field containing cumulative totals
func (s *Scanner) scanPi() []Record {
	root := piSessionRoot()
	if root == "" {
		return nil
	}

	pattern := filepath.Join(root, "*.jsonl")
	files, err := filepath.Glob(pattern)
	if err != nil {
		s.logger.Debug("pi glob error", "error", err)
		return nil
	}

	var allRecords []Record
	for _, f := range files {
		record := s.parsePiFile(f)
		if record != nil {
			allRecords = append(allRecords, *record)
		}
	}

	return mergeRecords(allRecords)
}

// piSessionRoot returns the Pi sessions directory.
func piSessionRoot() string {
	if piHome := os.Getenv("PI_HOME"); piHome != "" {
		dir := filepath.Join(piHome, "sessions")
		if info, err := os.Stat(dir); err == nil && info.IsDir() {
			return dir
		}
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	candidates := []string{
		filepath.Join(home, ".pi", "sessions"),
		filepath.Join(home, ".local", "share", "pi", "sessions"),
		filepath.Join(home, ".config", "pi", "sessions"),
	}
	for _, dir := range candidates {
		if info, err := os.Stat(dir); err == nil && info.IsDir() {
			return dir
		}
	}
	return ""
}

// piLine represents a line in a Pi session JSONL file.
type piLine struct {
	Type      string `json:"type"`
	Timestamp string `json:"timestamp"`
	Usage     *struct {
		Model             string `json:"model"`
		InputTokens       int64  `json:"input_tokens"`
		OutputTokens      int64  `json:"output_tokens"`
		CachedInputTokens int64  `json:"cached_input_tokens"`
	} `json:"usage"`
}

// parsePiFile extracts the final token usage from a Pi session file.
// Returns nil if no usage data found.
func (s *Scanner) parsePiFile(path string) *Record {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	var lastUsage *struct {
		Model             string `json:"model"`
		InputTokens       int64  `json:"input_tokens"`
		OutputTokens      int64  `json:"output_tokens"`
		CachedInputTokens int64  `json:"cached_input_tokens"`
	}
	var lastTimestamp string

	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 0, 256*1024), 1024*1024)

	for scanner.Scan() {
		line := scanner.Bytes()

		// Fast pre-filter.
		if !bytesContains(line, `"usage"`) && !bytesContains(line, `"input_tokens"`) {
			continue
		}

		var entry piLine
		if err := json.Unmarshal(line, &entry); err != nil {
			continue
		}

		if entry.Usage == nil {
			continue
		}

		lastUsage = entry.Usage
		if entry.Timestamp != "" {
			lastTimestamp = entry.Timestamp
		}
	}

	if lastUsage == nil {
		return nil
	}
	if lastUsage.InputTokens == 0 && lastUsage.OutputTokens == 0 {
		return nil
	}

	var date string
	if lastTimestamp != "" {
		if ts, err := time.Parse(time.RFC3339Nano, lastTimestamp); err == nil {
			date = ts.Local().Format("2006-01-02")
		} else if ts, err := time.Parse(time.RFC3339, lastTimestamp); err == nil {
			date = ts.Local().Format("2006-01-02")
		}
	}
	if date == "" {
		if info, err := os.Stat(path); err == nil {
			date = info.ModTime().Local().Format("2006-01-02")
		} else {
			return nil
		}
	}

	model := lastUsage.Model
	if model == "" {
		model = "unknown"
	}

	return &Record{
		Date:            date,
		Provider:        "pi",
		Model:           model,
		InputTokens:     lastUsage.InputTokens,
		OutputTokens:    lastUsage.OutputTokens,
		CacheReadTokens: lastUsage.CachedInputTokens,
	}
}
