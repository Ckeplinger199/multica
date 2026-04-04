package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"
)

var attachmentCmd = &cobra.Command{
	Use:   "attachment",
	Short: "Manage attachments",
}

var attachmentDownloadCmd = &cobra.Command{
	Use:   "download <attachment-id>",
	Short: "Download an attachment file by ID",
	Args:  cobra.ExactArgs(1),
	RunE:  runAttachmentDownload,
}

func init() {
	attachmentCmd.AddCommand(attachmentDownloadCmd)
	attachmentDownloadCmd.Flags().StringP("output-dir", "o", ".", "Directory to save the downloaded file")
}

func runAttachmentDownload(cmd *cobra.Command, args []string) error {
	attachmentID := args[0]

	client, err := newAPIClient(cmd)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Fetch attachment metadata to get the download URL and filename.
	var att map[string]any
	if err := client.GetJSON(ctx, "/api/attachments/"+attachmentID, &att); err != nil {
		return fmt.Errorf("get attachment: %w", err)
	}

	downloadURL := strVal(att, "download_url")
	if downloadURL == "" {
		return fmt.Errorf("attachment has no download URL")
	}

	filename := strVal(att, "filename")
	if filename == "" {
		filename = attachmentID
	}

	outDir, _ := cmd.Flags().GetString("output-dir")
	destPath := filepath.Join(outDir, filename)

	// Download the file.
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, downloadURL, nil)
	if err != nil {
		return fmt.Errorf("create download request: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("download file: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("download failed with status %d", resp.StatusCode)
	}

	f, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("create file %s: %w", destPath, err)
	}
	defer f.Close()

	if _, err := io.Copy(f, resp.Body); err != nil {
		return fmt.Errorf("write file: %w", err)
	}

	abs, _ := filepath.Abs(destPath)
	fmt.Println(abs)
	return nil
}
