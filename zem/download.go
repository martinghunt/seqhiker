package main

import (
	"archive/zip"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const (
	datasetsDownloadURL = "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/%s/download?include_annotation_type=GENOME_FASTA&include_annotation_type=GENOME_GFF"
	sviewerFastaURL     = "https://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?id=%s&db=nuccore&report=fasta&retmode=text"
	sviewerGFF3URL      = "https://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?id=%s&db=nuccore&report=gff3&retmode=text"
	cacheFastaName      = "genome.fa"
	cacheGFFName        = "annotations.gff3"
)

type cacheEntry struct {
	Path    string
	Size    int64
	ModTime time.Time
}

func (e *Engine) DownloadGenome(accession string, cacheDir string, maxCacheBytes int64) ([]string, error) {
	acc := strings.TrimSpace(accession)
	if acc == "" {
		return nil, fmt.Errorf("empty accession")
	}
	log.Printf("download_genome: accession=%q cache_dir=%q max_cache_bytes=%d", acc, cacheDir, maxCacheBytes)

	rootDir, err := ensureCacheRoot(cacheDir)
	if err != nil {
		log.Printf("download_genome: ensureCacheRoot failed: %v", err)
		return nil, err
	}
	entryDir := filepath.Join(rootDir, sanitizeFilename(acc))
	if files, ok := cachedGenomeFiles(entryDir); ok {
		log.Printf("download_genome: cache hit entry_dir=%q files=%v", entryDir, files)
		touchPath(entryDir)
		return files, nil
	}

	tmpDir, err := os.MkdirTemp("", "zem-download-*")
	if err != nil {
		log.Printf("download_genome: MkdirTemp failed: %v", err)
		return nil, err
	}
	log.Printf("download_genome: temp_dir=%q entry_dir=%q", tmpDir, entryDir)
	defer os.RemoveAll(tmpDir)

	var downloaded []string
	if isAssemblyAccession(acc) {
		downloaded, err = downloadAssemblyGenome(acc, tmpDir)
	} else {
		downloaded, err = downloadNuccoreGenome(acc, tmpDir)
	}
	if err != nil {
		log.Printf("download_genome: download step failed: %v", err)
		return nil, err
	}
	log.Printf("download_genome: downloaded temp files=%v", downloaded)

	if maxCacheBytes > 0 {
		incomingBytes, err := fileListSize(downloaded)
		if err != nil {
			log.Printf("download_genome: fileListSize failed: %v", err)
			return nil, err
		}
		log.Printf("download_genome: incoming_bytes=%d", incomingBytes)
		if err := pruneGenomeCacheForIncoming(rootDir, maxCacheBytes, incomingBytes); err != nil {
			log.Printf("download_genome: pruneGenomeCacheForIncoming failed: %v", err)
			return nil, err
		}
	}
	files, err := installDownloadedGenome(entryDir, downloaded)
	if err != nil {
		log.Printf("download_genome: installDownloadedGenome failed: %v", err)
		return nil, err
	}
	for _, path := range files {
		info, err := os.Stat(path)
		if err != nil {
			log.Printf("download_genome: post-install stat failed path=%q err=%v", path, err)
			return nil, fmt.Errorf("installed cache file missing after download: %s (%w)", path, err)
		}
		if info.IsDir() {
			log.Printf("download_genome: post-install path is dir path=%q", path)
			return nil, fmt.Errorf("installed cache path is a directory, expected file: %s", path)
		}
		log.Printf("download_genome: installed file ok path=%q size=%d", path, info.Size())
	}
	log.Printf("download_genome: success files=%v", files)
	return files, nil
}

func fileListSize(paths []string) (int64, error) {
	var total int64
	for _, path := range paths {
		info, err := os.Stat(path)
		if err != nil {
			return 0, err
		}
		if info.IsDir() {
			continue
		}
		total += info.Size()
	}
	return total, nil
}

func ensureCacheRoot(cacheDir string) (string, error) {
	root := strings.TrimSpace(cacheDir)
	if root == "" {
		return "", fmt.Errorf("empty genome cache directory")
	}
	if err := os.MkdirAll(root, 0o755); err != nil {
		return "", err
	}
	return root, nil
}

func cachedGenomeFiles(entryDir string) ([]string, bool) {
	fastaPath := filepath.Join(entryDir, cacheFastaName)
	if err := validateDownloadedGenomeFile(fastaPath, inputKindFASTA); err != nil {
		return nil, false
	}
	files := []string{fastaPath}
	gffPath := filepath.Join(entryDir, cacheGFFName)
	if err := validateDownloadedGenomeFile(gffPath, inputKindGFF3); err == nil {
		files = append(files, gffPath)
	}
	return files, true
}

func installDownloadedGenome(entryDir string, downloaded []string) ([]string, error) {
	log.Printf("download_genome: install start entry_dir=%q downloaded=%v", entryDir, downloaded)
	if err := os.RemoveAll(entryDir); err != nil {
		log.Printf("download_genome: remove existing entry dir failed entry_dir=%q err=%v", entryDir, err)
		return nil, err
	}
	if err := os.MkdirAll(entryDir, 0o755); err != nil {
		log.Printf("download_genome: MkdirAll failed entry_dir=%q err=%v", entryDir, err)
		return nil, err
	}
	if info, err := os.Stat(entryDir); err != nil {
		log.Printf("download_genome: stat entry dir after mkdir failed entry_dir=%q err=%v", entryDir, err)
	} else {
		log.Printf("download_genome: entry dir ready path=%q mode=%v", entryDir, info.Mode())
	}

	files := make([]string, 0, len(downloaded))
	for _, path := range downloaded {
		kind, err := detectInputKind(path)
		if err != nil {
			log.Printf("download_genome: detectInputKind failed path=%q err=%v", path, err)
			return nil, err
		}
		var target string
		switch kind {
		case inputKindFASTA:
			target = filepath.Join(entryDir, cacheFastaName)
		case inputKindGFF3:
			target = filepath.Join(entryDir, cacheGFFName)
		default:
			continue
		}
		log.Printf("download_genome: moving kind=%v src=%q dst=%q", kind, path, target)
		if err := moveFile(path, target); err != nil {
			log.Printf("download_genome: moveFile failed src=%q dst=%q err=%v", path, target, err)
			return nil, err
		}
		if info, err := os.Stat(target); err != nil {
			log.Printf("download_genome: stat target after move failed dst=%q err=%v", target, err)
			return nil, err
		} else {
			log.Printf("download_genome: target after move ok dst=%q size=%d", target, info.Size())
		}
		files = append(files, target)
	}
	if len(files) == 0 {
		log.Printf("download_genome: install produced no usable files entry_dir=%q", entryDir)
		return nil, fmt.Errorf("download produced no usable genome files")
	}
	touchPath(entryDir)
	log.Printf("download_genome: install complete entry_dir=%q files=%v", entryDir, files)
	return files, nil
}

func moveFile(src string, dst string) error {
	if err := os.Rename(src, dst); err == nil {
		return nil
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return os.Remove(src)
}

func pruneGenomeCache(rootDir string, maxCacheBytes int64, protectedDir string) error {
	entries, totalBytes, err := genomeCacheEntries(rootDir)
	if err != nil {
		return err
	}
	if totalBytes <= maxCacheBytes {
		return nil
	}
	protectedSize := int64(0)
	for _, entry := range entries {
		if entry.Path == protectedDir {
			protectedSize = entry.Size
			break
		}
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].ModTime.Before(entries[j].ModTime)
	})
	for _, entry := range entries {
		if entry.Path == protectedDir {
			continue
		}
		if totalBytes <= maxCacheBytes {
			break
		}
		if err := os.RemoveAll(entry.Path); err != nil {
			return err
		}
		totalBytes -= entry.Size
	}
	if totalBytes > maxCacheBytes && totalBytes == protectedSize {
		return nil
	}
	return nil
}

func pruneGenomeCacheForIncoming(rootDir string, maxCacheBytes int64, incomingBytes int64) error {
	entries, totalBytes, err := genomeCacheEntries(rootDir)
	if err != nil {
		return err
	}
	log.Printf("download_genome: prune start root=%q total_bytes=%d incoming_bytes=%d max_bytes=%d entries=%d", rootDir, totalBytes, incomingBytes, maxCacheBytes, len(entries))
	if incomingBytes >= maxCacheBytes {
		for _, entry := range entries {
			log.Printf("download_genome: prune removing old entry=%q size=%d to keep oversized incoming", entry.Path, entry.Size)
			if err := os.RemoveAll(entry.Path); err != nil {
				return err
			}
		}
		return nil
	}
	if totalBytes+incomingBytes <= maxCacheBytes {
		return nil
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].ModTime.Before(entries[j].ModTime)
	})
	for _, entry := range entries {
		if totalBytes+incomingBytes <= maxCacheBytes {
			break
		}
		log.Printf("download_genome: prune removing entry=%q size=%d", entry.Path, entry.Size)
		if err := os.RemoveAll(entry.Path); err != nil {
			return err
		}
		totalBytes -= entry.Size
	}
	log.Printf("download_genome: prune done remaining_total=%d", totalBytes)
	return nil
}

func genomeCacheEntries(rootDir string) ([]cacheEntry, int64, error) {
	dirEntries, err := os.ReadDir(rootDir)
	if err != nil {
		return nil, 0, err
	}
	out := make([]cacheEntry, 0, len(dirEntries))
	var total int64
	for _, dirEntry := range dirEntries {
		if !dirEntry.IsDir() {
			continue
		}
		if strings.HasPrefix(dirEntry.Name(), ".") {
			continue
		}
		path := filepath.Join(rootDir, dirEntry.Name())
		size, modTime, err := dirTreeStats(path)
		if err != nil {
			return nil, 0, err
		}
		out = append(out, cacheEntry{Path: path, Size: size, ModTime: modTime})
		total += size
	}
	return out, total, nil
}

func dirTreeStats(root string) (int64, time.Time, error) {
	var total int64
	var latest time.Time
	err := filepath.Walk(root, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if info.IsDir() {
			if info.ModTime().After(latest) {
				latest = info.ModTime()
			}
			return nil
		}
		total += info.Size()
		if info.ModTime().After(latest) {
			latest = info.ModTime()
		}
		return nil
	})
	return total, latest, err
}

func touchPath(path string) {
	now := time.Now()
	_ = os.Chtimes(path, now, now)
}

func isAssemblyAccession(accession string) bool {
	upper := strings.ToUpper(strings.TrimSpace(accession))
	return strings.HasPrefix(upper, "GCF_") || strings.HasPrefix(upper, "GCA_")
}

func downloadAssemblyGenome(accession string, outDir string) ([]string, error) {
	zipPath := filepath.Join(outDir, sanitizeFilename(accession)+".zip")
	if err := downloadURLToFile(fmt.Sprintf(datasetsDownloadURL, accession), zipPath); err != nil {
		return nil, err
	}
	return extractGenomeFilesFromZip(zipPath, outDir)
}

func downloadNuccoreGenome(accession string, outDir string) ([]string, error) {
	base := sanitizeFilename(accession)
	fastaPath := filepath.Join(outDir, base+".fa")
	if err := downloadURLToFile(fmt.Sprintf(sviewerFastaURL, accession), fastaPath); err != nil {
		return nil, err
	}
	if err := validateDownloadedGenomeFile(fastaPath, inputKindFASTA); err != nil {
		return nil, err
	}

	files := []string{fastaPath}
	gffPath := filepath.Join(outDir, base+".gff3")
	if err := downloadURLToFile(fmt.Sprintf(sviewerGFF3URL, accession), gffPath); err == nil {
		if err := validateDownloadedGenomeFile(gffPath, inputKindGFF3); err == nil {
			files = append(files, gffPath)
		} else {
			_ = os.Remove(gffPath)
		}
	}

	return files, nil
}

func downloadURLToFile(url string, outPath string) error {
	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed: %s", resp.Status)
	}

	fout, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer fout.Close()

	if _, err := io.Copy(fout, resp.Body); err != nil {
		return err
	}
	return nil
}

func extractGenomeFilesFromZip(zipPath string, outDir string) ([]string, error) {
	reader, err := zip.OpenReader(zipPath)
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	var fastaOut string
	var gffOut string
	for _, file := range reader.File {
		lowerName := strings.ToLower(file.Name)
		targetPath := ""
		switch {
		case strings.HasSuffix(lowerName, ".fna"), strings.HasSuffix(lowerName, ".fa"), strings.HasSuffix(lowerName, ".fasta"):
			if fastaOut == "" {
				fastaOut = filepath.Join(outDir, filepath.Base(file.Name))
				targetPath = fastaOut
			}
		case strings.HasSuffix(lowerName, ".gff"), strings.HasSuffix(lowerName, ".gff3"):
			if gffOut == "" {
				gffOut = filepath.Join(outDir, filepath.Base(file.Name))
				targetPath = gffOut
			}
		}
		if targetPath == "" {
			continue
		}
		if err := extractZipFile(file, targetPath); err != nil {
			return nil, err
		}
	}

	if fastaOut == "" {
		return nil, fmt.Errorf("downloaded archive did not contain a FASTA file")
	}
	if err := validateDownloadedGenomeFile(fastaOut, inputKindFASTA); err != nil {
		return nil, err
	}

	files := []string{fastaOut}
	if gffOut != "" {
		if err := validateDownloadedGenomeFile(gffOut, inputKindGFF3); err == nil {
			files = append(files, gffOut)
		} else {
			_ = os.Remove(gffOut)
		}
	}
	return files, nil
}

func extractZipFile(file *zip.File, outPath string) error {
	src, err := file.Open()
	if err != nil {
		return err
	}
	defer src.Close()

	dst, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer dst.Close()

	_, err = io.Copy(dst, src)
	return err
}

func validateDownloadedGenomeFile(path string, expected inputKind) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if info.IsDir() {
		return fmt.Errorf("expected file but found directory: %s", path)
	}
	kind, err := detectInputKindByContent(path)
	if err != nil {
		return err
	}
	if kind != expected {
		return fmt.Errorf("downloaded %v but detected %v", expected, kind)
	}
	return nil
}

func sanitizeFilename(name string) string {
	replacer := strings.NewReplacer("/", "_", "\\", "_", " ", "_", ":", "_")
	return replacer.Replace(name)
}
