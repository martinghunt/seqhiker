package main

import (
	"bufio"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/shenwei356/xopen"
)

type inputKind uint8

const (
	inputKindUnknown inputKind = iota
	inputKindFASTA
	inputKindGFF3
	inputKindFlatFile
	inputKindComparisonSession
	inputKindVCF
)

func gatherInputFiles(path string) ([]string, error) {
	st, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if !st.IsDir() {
		return []string{path}, nil
	}

	var files []string
	err = filepath.WalkDir(path, func(p string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		kind, detectErr := detectInputKind(p)
		if detectErr != nil {
			return detectErr
		}
		if kind != inputKindUnknown {
			files = append(files, p)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, errors.New("no supported genome files found")
	}
	slices.Sort(files)
	return files, nil
}

func detectInputKind(path string) (inputKind, error) {
	if ok, err := isComparisonSessionFile(path); err != nil {
		return inputKindUnknown, err
	} else if ok {
		return inputKindComparisonSession, nil
	}
	if kind, err := detectInputKindByContent(path); err != nil {
		return inputKindUnknown, err
	} else if kind != inputKindUnknown {
		return kind, nil
	}
	return detectInputKindByName(path), nil
}

func detectInputKindByName(name string) inputKind {
	base := strings.ToLower(filepath.Base(name))
	for _, suffix := range []string{".gz", ".bgz", ".bz2", ".xz", ".zst", ".zstd"} {
		if strings.HasSuffix(base, suffix) {
			base = strings.TrimSuffix(base, suffix)
			break
		}
	}
	switch filepath.Ext(base) {
	case ".fa", ".fasta", ".fna", ".ffn", ".frn", ".faa":
		return inputKindFASTA
	case ".gff", ".gff3":
		return inputKindGFF3
	case ".embl", ".gb", ".gbk", ".genbank":
		return inputKindFlatFile
	case ".vcf":
		return inputKindVCF
	default:
		return inputKindUnknown
	}
}

func detectInputKindByContent(path string) (inputKind, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return inputKindUnknown, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		line = strings.TrimPrefix(line, "\uFEFF")
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, ">") {
			return inputKindFASTA, nil
		}
		if strings.HasPrefix(line, "##gff-version") || looksLikeGFF3Data(line) {
			return inputKindGFF3, nil
		}
		if strings.HasPrefix(line, "##fileformat=VCF") || strings.HasPrefix(line, "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO") {
			return inputKindVCF, nil
		}
		if strings.HasPrefix(line, "LOCUS ") || strings.HasPrefix(line, "ID   ") {
			return inputKindFlatFile, nil
		}
		return inputKindUnknown, nil
	}
	if err := scanner.Err(); err != nil {
		return inputKindUnknown, err
	}
	return inputKindUnknown, nil
}

func looksLikeGFF3Data(line string) bool {
	if strings.HasPrefix(line, "#") {
		return false
	}
	return strings.Count(line, "\t") >= 8
}

func gff3HasEmbeddedSequence(path string) (bool, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return false, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		line = strings.TrimPrefix(line, "\uFEFF")
		if line == "##FASTA" {
			return true, nil
		}
	}
	if err := scanner.Err(); err != nil {
		return false, err
	}
	return false, nil
}
