package main

import (
	"bytes"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
)

const (
	comparisonTestDataSeed    = 42
	comparisonTestDataDirName = "comparison_test_data_v1"
)

type comparisonPartSpec struct {
	Label  string
	Seq    string
	Strand byte
	Type   string
}

type comparisonContigSpec struct {
	Name  string
	Parts []comparisonPartSpec
}

type comparisonGenomeSpec struct {
	Name    string
	Contigs []comparisonContigSpec
}

func (e *Engine) ResetComparisonState() {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.resetComparisonStateLocked()
}

func (e *Engine) resetComparisonStateLocked() {
	e.comparisonGenomes = make(map[uint16]*comparisonGenome)
	e.comparisonGenomeOrder = e.comparisonGenomeOrder[:0]
	e.nextComparisonGenomeID = 1
	e.comparisonPairs = make(map[uint16]*comparisonPair)
	e.comparisonPairOrder = e.comparisonPairOrder[:0]
	e.nextComparisonPairID = 1
}

func (e *Engine) GenerateComparisonTestData(rootDir string) ([]string, error) {
	if strings.TrimSpace(rootDir) == "" {
		return nil, fmt.Errorf("comparison test data root directory is required")
	}
	entryDir := filepath.Join(rootDir, comparisonTestDataDirName)
	if err := os.RemoveAll(entryDir); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(entryDir, 0o755); err != nil {
		return nil, err
	}

	rng := rand.New(rand.NewSource(comparisonTestDataSeed))
	blocks := map[string]string{
		"alpha":   randomDNA(rng, 4200),
		"beta":    randomDNA(rng, 3600),
		"gamma":   randomDNA(rng, 3000),
		"island":  randomDNA(rng, 1400),
		"repeatA": randomDNA(rng, 700),
		"repeatB": randomDNA(rng, 560),
		"delta":   randomDNA(rng, 2400),
		"tail":    randomDNA(rng, 1300),
		"uniq1":   randomDNA(rng, 1600),
		"uniq2":   randomDNA(rng, 1700),
		"uniq3":   randomDNA(rng, 1500),
	}

	alphaVar := mutateComparisonBlock(blocks["alpha"], 71, 14, "TGA", 4)
	gammaRC, _ := reverseComplementDNA(mutateComparisonBlock(blocks["gamma"], 113, 9, "CC", 3))
	islandVar := mutateComparisonBlock(blocks["island"], 211, 6, "AAT", 2)
	gammaVar := mutateComparisonBlock(blocks["gamma"], 307, 8, "GG", 2)
	deltaVar := mutateComparisonBlock(blocks["delta"], 401, 10, "TTC", 3)
	tailVar := mutateComparisonBlock(blocks["tail"], 509, 7, "CGA", 2)
	islandRC, _ := reverseComplementDNA(blocks["island"])
	tailRC, _ := reverseComplementDNA(blocks["tail"])

	genomes := []comparisonGenomeSpec{
		{
			Name: "cmp_alpha",
			Contigs: []comparisonContigSpec{
				{
					Name: "chrA1",
					Parts: []comparisonPartSpec{
						{Label: "alpha", Seq: blocks["alpha"], Strand: '+', Type: "gene"},
						{Label: "repeatA", Seq: blocks["repeatA"], Strand: '+', Type: "repeat_region"},
						{Label: "beta", Seq: blocks["beta"], Strand: '+', Type: "gene"},
						{Label: "uniq1", Seq: blocks["uniq1"], Strand: '+', Type: "misc_feature"},
						{Label: "repeatB", Seq: blocks["repeatB"], Strand: '+', Type: "repeat_region"},
						{Label: "gamma", Seq: blocks["gamma"], Strand: '-', Type: "gene"},
					},
				},
				{
					Name: "chrA2",
					Parts: []comparisonPartSpec{
						{Label: "island", Seq: blocks["island"], Strand: '+', Type: "gene"},
						{Label: "repeatA", Seq: blocks["repeatA"], Strand: '+', Type: "repeat_region"},
						{Label: "delta", Seq: blocks["delta"], Strand: '-', Type: "gene"},
					},
				},
				{
					Name: "chrA3",
					Parts: []comparisonPartSpec{
						{Label: "tail", Seq: blocks["tail"], Strand: '+', Type: "gene"},
						{Label: "repeatB", Seq: blocks["repeatB"], Strand: '+', Type: "repeat_region"},
					},
				},
			},
		},
		{
			Name: "cmp_beta",
			Contigs: []comparisonContigSpec{
				{
					Name: "chrB1",
					Parts: []comparisonPartSpec{
						{Label: "alpha_var", Seq: alphaVar, Strand: '+', Type: "gene"},
						{Label: "repeatA_1", Seq: blocks["repeatA"], Strand: '+', Type: "repeat_region"},
						{Label: "beta", Seq: blocks["beta"], Strand: '+', Type: "gene"},
						{Label: "repeatA_2", Seq: blocks["repeatA"], Strand: '+', Type: "repeat_region"},
						{Label: "uniq2", Seq: blocks["uniq2"], Strand: '-', Type: "misc_feature"},
						{Label: "gamma_rc", Seq: gammaRC, Strand: '-', Type: "gene"},
					},
				},
				{
					Name: "chrB2",
					Parts: []comparisonPartSpec{
						{Label: "island_var", Seq: islandVar, Strand: '+', Type: "gene"},
						{Label: "repeatB", Seq: blocks["repeatB"], Strand: '+', Type: "repeat_region"},
						{Label: "delta", Seq: blocks["delta"], Strand: '-', Type: "gene"},
					},
				},
				{
					Name: "chrB3",
					Parts: []comparisonPartSpec{
						{Label: "tail_var", Seq: tailVar, Strand: '+', Type: "gene"},
						{Label: "repeatB_3", Seq: blocks["repeatB"], Strand: '+', Type: "repeat_region"},
					},
				},
			},
		},
		{
			Name: "cmp_gamma",
			Contigs: []comparisonContigSpec{
				{
					Name: "chrC1",
					Parts: []comparisonPartSpec{
						{Label: "uniq3", Seq: blocks["uniq3"], Strand: '+', Type: "misc_feature"},
						{Label: "beta", Seq: blocks["beta"], Strand: '+', Type: "gene"},
						{Label: "repeatB_1", Seq: blocks["repeatB"], Strand: '+', Type: "repeat_region"},
						{Label: "alpha", Seq: blocks["alpha"], Strand: '+', Type: "gene"},
						{Label: "repeatB_2", Seq: blocks["repeatB"], Strand: '+', Type: "repeat_region"},
						{Label: "gamma_var", Seq: gammaVar, Strand: '-', Type: "gene"},
					},
				},
				{
					Name: "chrC2",
					Parts: []comparisonPartSpec{
						{Label: "island_rc", Seq: islandRC, Strand: '-', Type: "gene"},
						{Label: "repeatA", Seq: blocks["repeatA"], Strand: '+', Type: "repeat_region"},
						{Label: "delta_var", Seq: deltaVar, Strand: '-', Type: "gene"},
					},
				},
				{
					Name: "chrC3",
					Parts: []comparisonPartSpec{
						{Label: "tail_rc", Seq: tailRC, Strand: '-', Type: "gene"},
						{Label: "repeatA_2", Seq: blocks["repeatA"], Strand: '+', Type: "repeat_region"},
					},
				},
			},
		},
	}

	paths := make([]string, 0, len(genomes))
	for _, genome := range genomes {
		genomeDir := filepath.Join(entryDir, genome.Name)
		if err := os.MkdirAll(genomeDir, 0o755); err != nil {
			return nil, err
		}
		fastaPath := filepath.Join(genomeDir, genome.Name+".fa")
		gffPath := filepath.Join(genomeDir, genome.Name+".gff3")
		if err := writeComparisonGenomeFASTA(fastaPath, genome.Contigs); err != nil {
			return nil, err
		}
		if err := writeComparisonGenomeGFF3(gffPath, genome.Name, genome.Contigs); err != nil {
			return nil, err
		}
		paths = append(paths, genomeDir)
	}
	return paths, nil
}

func writeComparisonGenomeFASTA(path string, contigs []comparisonContigSpec) error {
	var buf bytes.Buffer
	for _, contig := range contigs {
		buf.WriteString(">")
		buf.WriteString(contig.Name)
		buf.WriteByte('\n')
		seq := assembleComparisonContig(contig)
		for start := 0; start < len(seq); start += 60 {
			end := min(start+60, len(seq))
			buf.WriteString(seq[start:end])
			buf.WriteByte('\n')
		}
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func writeComparisonGenomeGFF3(path, genomeName string, contigs []comparisonContigSpec) error {
	var buf bytes.Buffer
	buf.WriteString("##gff-version 3\n")
	for _, contig := range contigs {
		pos := 0
		for i, part := range contig.Parts {
			start := pos + 1
			end := pos + len(part.Seq)
			buf.WriteString(fmt.Sprintf("%s\tcmpdemo\t%s\t%d\t%d\t.\t%c\t.\tID=%s_%s_%d;Name=%s\n",
				contig.Name,
				part.Type,
				start,
				end,
				part.Strand,
				genomeName,
				sanitizeComparisonLabel(part.Label),
				i+1,
				part.Label,
			))
			pos = end
		}
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func assembleComparisonContig(contig comparisonContigSpec) string {
	var b strings.Builder
	for _, part := range contig.Parts {
		b.WriteString(part.Seq)
	}
	return b.String()
}

func mutateComparisonBlock(seq string, seed int64, snpCount int, insertion string, deletionLen int) string {
	if seq == "" {
		return seq
	}
	out := []byte(seq)
	rng := rand.New(rand.NewSource(seed))
	for i := 0; i < snpCount; i++ {
		pos := 25 + rng.Intn(max(1, len(out)-50))
		out[pos] = mutateBase(out[pos], rng)
	}
	if deletionLen > 0 && len(out) > deletionLen+40 {
		delPos := 20 + rng.Intn(len(out)-deletionLen-40)
		out = append(out[:delPos], out[delPos+deletionLen:]...)
	}
	if insertion != "" && len(out) > 40 {
		insPos := 20 + rng.Intn(len(out)-40)
		out = append(out[:insPos], append([]byte(insertion), out[insPos:]...)...)
	}
	return string(out)
}

func sanitizeComparisonLabel(label string) string {
	label = strings.ReplaceAll(label, " ", "_")
	label = strings.ReplaceAll(label, "/", "_")
	return label
}
