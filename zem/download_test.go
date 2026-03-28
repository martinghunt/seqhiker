package main

import (
	"archive/zip"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestIsAssemblyAccession(t *testing.T) {
	if !isAssemblyAccession("GCF_000001405.40") {
		t.Fatalf("expected GCF accession to be treated as assembly")
	}
	if !isAssemblyAccession(" gca_000001405.1 ") {
		t.Fatalf("expected GCA accession to be treated as assembly")
	}
	if isAssemblyAccession("NC_000962.3") {
		t.Fatalf("did not expect nuccore accession to be treated as assembly")
	}
}

func TestExtractGenomeFilesFromZip(t *testing.T) {
	tmpDir := t.TempDir()
	zipPath := filepath.Join(tmpDir, "test.zip")

	fout, err := os.Create(zipPath)
	if err != nil {
		t.Fatalf("create zip: %v", err)
	}
	zipWriter := zip.NewWriter(fout)
	writeZipEntry := func(name string, content string) {
		entry, err := zipWriter.Create(name)
		if err != nil {
			t.Fatalf("create zip entry %s: %v", name, err)
		}
		if _, err := entry.Write([]byte(content)); err != nil {
			t.Fatalf("write zip entry %s: %v", name, err)
		}
	}
	writeZipEntry("ncbi_dataset/data/GCF_1/test.fna", ">chr1\nACGT\n")
	writeZipEntry("ncbi_dataset/data/GCF_1/genomic.gff", "##gff-version 3\nchr1\tsrc\tgene\t1\t4\t.\t+\t.\tID=g1\n")
	writeZipEntry("README.md", "ignore me")
	if err := zipWriter.Close(); err != nil {
		t.Fatalf("close zip writer: %v", err)
	}
	if err := fout.Close(); err != nil {
		t.Fatalf("close zip file: %v", err)
	}

	files, err := extractGenomeFilesFromZip(zipPath, tmpDir)
	if err != nil {
		t.Fatalf("extractGenomeFilesFromZip: %v", err)
	}
	if len(files) != 2 {
		t.Fatalf("expected 2 extracted files, got %d (%v)", len(files), files)
	}

	for _, path := range files {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("expected extracted file %s to exist: %v", path, err)
		}
	}
}

func TestInstallDownloadedGenomeAndCacheHit(t *testing.T) {
	tmpDir := t.TempDir()
	downloadDir := filepath.Join(tmpDir, "incoming")
	if err := os.MkdirAll(downloadDir, 0o755); err != nil {
		t.Fatalf("mkdir incoming: %v", err)
	}
	fastaPath := filepath.Join(downloadDir, "x.fa")
	gffPath := filepath.Join(downloadDir, "x.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nACGT\n"), 0o644); err != nil {
		t.Fatalf("write fasta: %v", err)
	}
	if err := os.WriteFile(gffPath, []byte("##gff-version 3\nchr1\tsrc\tgene\t1\t4\t.\t+\t.\tID=g1\n"), 0o644); err != nil {
		t.Fatalf("write gff: %v", err)
	}

	entryDir := filepath.Join(tmpDir, "cache", "NC_1")
	files, err := installDownloadedGenome(entryDir, []string{fastaPath, gffPath})
	if err != nil {
		t.Fatalf("installDownloadedGenome: %v", err)
	}
	if len(files) != 2 {
		t.Fatalf("expected 2 installed files, got %d", len(files))
	}
	if _, ok := cachedGenomeFiles(entryDir); !ok {
		t.Fatalf("expected installed genome to be cache-hit readable")
	}
}

func TestCachedGenomeFilesRejectsMissingFiles(t *testing.T) {
	tmpDir := t.TempDir()
	entryDir := filepath.Join(tmpDir, "GCF_1")
	if err := os.MkdirAll(entryDir, 0o755); err != nil {
		t.Fatalf("mkdir entry: %v", err)
	}
	if _, ok := cachedGenomeFiles(entryDir); ok {
		t.Fatalf("expected cache miss when required files are missing")
	}
}

func TestPruneGenomeCacheKeepsProtectedLargeEntry(t *testing.T) {
	tmpDir := t.TempDir()
	oldDir := filepath.Join(tmpDir, "old")
	protectedDir := filepath.Join(tmpDir, "new")
	oldFile := filepath.Join(oldDir, "a.bin")
	protectedFile := filepath.Join(protectedDir, "b.bin")
	if err := os.MkdirAll(oldDir, 0o755); err != nil {
		t.Fatalf("mkdir old: %v", err)
	}
	if err := os.MkdirAll(protectedDir, 0o755); err != nil {
		t.Fatalf("mkdir new: %v", err)
	}
	if err := os.WriteFile(oldFile, make([]byte, 8), 0o644); err != nil {
		t.Fatalf("write old: %v", err)
	}
	if err := os.WriteFile(protectedFile, make([]byte, 60), 0o644); err != nil {
		t.Fatalf("write protected: %v", err)
	}
	past := time.Now().Add(-time.Hour)
	if err := os.Chtimes(oldDir, past, past); err != nil {
		t.Fatalf("chtimes old: %v", err)
	}
	if err := os.Chtimes(oldFile, past, past); err != nil {
		t.Fatalf("chtimes old file: %v", err)
	}

	if err := pruneGenomeCache(tmpDir, 50, protectedDir); err != nil {
		t.Fatalf("pruneGenomeCache: %v", err)
	}
	if _, err := os.Stat(protectedDir); err != nil {
		t.Fatalf("expected protected dir to remain: %v", err)
	}
	if _, err := os.Stat(oldDir); !os.IsNotExist(err) {
		t.Fatalf("expected old dir to be removed, got err=%v", err)
	}
}

func TestPruneGenomeCacheKeepsOnlyProtectedWhenStillOverLimit(t *testing.T) {
	tmpDir := t.TempDir()
	protectedDir := filepath.Join(tmpDir, "only")
	if err := os.MkdirAll(protectedDir, 0o755); err != nil {
		t.Fatalf("mkdir protected: %v", err)
	}
	if err := os.WriteFile(filepath.Join(protectedDir, "big.bin"), make([]byte, 60), 0o644); err != nil {
		t.Fatalf("write protected: %v", err)
	}

	if err := pruneGenomeCache(tmpDir, 50, protectedDir); err != nil {
		t.Fatalf("pruneGenomeCache: %v", err)
	}
	if _, err := os.Stat(protectedDir); err != nil {
		t.Fatalf("expected protected dir to remain: %v", err)
	}
}

func TestPruneGenomeCacheForIncomingRemovesOldEntriesBeforeInstall(t *testing.T) {
	tmpDir := t.TempDir()
	oldDir := filepath.Join(tmpDir, "old")
	newerDir := filepath.Join(tmpDir, "newer")
	oldFile := filepath.Join(oldDir, "a.bin")
	newerFile := filepath.Join(newerDir, "b.bin")
	if err := os.MkdirAll(oldDir, 0o755); err != nil {
		t.Fatalf("mkdir old: %v", err)
	}
	if err := os.MkdirAll(newerDir, 0o755); err != nil {
		t.Fatalf("mkdir newer: %v", err)
	}
	if err := os.WriteFile(oldFile, make([]byte, 30), 0o644); err != nil {
		t.Fatalf("write old: %v", err)
	}
	if err := os.WriteFile(newerFile, make([]byte, 30), 0o644); err != nil {
		t.Fatalf("write newer: %v", err)
	}
	past := time.Now().Add(-time.Hour)
	if err := os.Chtimes(oldDir, past, past); err != nil {
		t.Fatalf("chtimes old: %v", err)
	}
	if err := os.Chtimes(oldFile, past, past); err != nil {
		t.Fatalf("chtimes old file: %v", err)
	}

	if err := pruneGenomeCacheForIncoming(tmpDir, 70, 25); err != nil {
		t.Fatalf("pruneGenomeCacheForIncoming: %v", err)
	}
	if _, err := os.Stat(oldDir); !os.IsNotExist(err) {
		t.Fatalf("expected oldest dir to be removed, got err=%v", err)
	}
	if _, err := os.Stat(newerDir); err != nil {
		t.Fatalf("expected newer dir to remain: %v", err)
	}
}

func TestGenomeCacheEntriesSkipsHiddenTempDirs(t *testing.T) {
	tmpDir := t.TempDir()
	hiddenDir := filepath.Join(tmpDir, ".download-abc")
	visibleDir := filepath.Join(tmpDir, "GCF_1")
	if err := os.MkdirAll(hiddenDir, 0o755); err != nil {
		t.Fatalf("mkdir hidden: %v", err)
	}
	if err := os.MkdirAll(visibleDir, 0o755); err != nil {
		t.Fatalf("mkdir visible: %v", err)
	}
	if err := os.WriteFile(filepath.Join(hiddenDir, "tmp.bin"), make([]byte, 10), 0o644); err != nil {
		t.Fatalf("write hidden: %v", err)
	}
	if err := os.WriteFile(filepath.Join(visibleDir, "genome.fa"), []byte(">chr1\nACGT\n"), 0o644); err != nil {
		t.Fatalf("write visible: %v", err)
	}

	entries, _, err := genomeCacheEntries(tmpDir)
	if err != nil {
		t.Fatalf("genomeCacheEntries: %v", err)
	}
	if len(entries) != 1 || entries[0].Path != visibleDir {
		t.Fatalf("expected only visible cache dir, got %+v", entries)
	}
}
