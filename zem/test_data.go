package main

import (
	"bytes"
	"fmt"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/biogo/hts/bam"
	"github.com/biogo/hts/sam"
)

const (
	testDataSeed     = 20260315
	testDataDirName  = "built_in_test_data_v1"
	testContigLen    = 10000
	testReadStep     = 35
	testReadLen      = 120
	testPairReadLen  = 90
	testErrorRate    = 0.01
	testSNPPos       = 2500
	testInsertionPos = 5000
	testDeletionPos  = 7500
	testDeletionLen  = 3
)

type demoVariantKind int

const (
	demoVariantNone demoVariantKind = iota
	demoVariantSNP
	demoVariantInsertion
	demoVariantDeletion
)

type demoVariant struct {
	pos  int
	ref  string
	alt  string
	kind demoVariantKind
}

type testReadSpec struct {
	name    string
	ref     *sam.Reference
	start   int
	seq     []byte
	cigar   []sam.CigarOp
	flags   sam.Flags
	mapQ    byte
	mateRef *sam.Reference
	matePos int
	tempLen int
}

func (e *Engine) GenerateTestData(rootDir string) ([]string, error) {
	if strings.TrimSpace(rootDir) == "" {
		return nil, fmt.Errorf("test data root directory is required")
	}
	entryDir := filepath.Join(rootDir, testDataDirName)
	if err := os.RemoveAll(entryDir); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(entryDir, 0o755); err != nil {
		return nil, err
	}

	rng := rand.New(rand.NewSource(testDataSeed))
	contigs := make([]struct {
		name string
		seq  string
	}, 0, 8)
	for _, suffix := range []string{"A", "B", "C", "D", "E", "F", "G", "H"} {
		contigs = append(contigs, struct {
			name string
			seq  string
		}{
			name: fmt.Sprintf("ctg%s", suffix),
			seq:  randomDNA(rng, testContigLen),
		})
	}
	contigByName := map[string]string{}
	for _, contig := range contigs {
		contigByName[contig.name] = contig.seq
	}

	refPath := filepath.Join(entryDir, "reference.fa")
	gffPath := filepath.Join(entryDir, "annotations.gff3")
	singleBAMPath := filepath.Join(entryDir, "reads_single.bam")
	singleBAIPath := singleBAMPath + ".bai"
	pairedBAMPath := filepath.Join(entryDir, "reads_paired.bam")
	pairedBAIPath := pairedBAMPath + ".bai"

	if err := writeTestFASTA(refPath, contigs); err != nil {
		return nil, err
	}
	if err := writeTestGFF3(gffPath, contigs); err != nil {
		return nil, err
	}
	if err := writeSingleEndTestBAMAndIndex(singleBAMPath, singleBAIPath, contigs, contigByName, rng); err != nil {
		return nil, err
	}
	if err := writePairedEndTestBAMAndIndex(pairedBAMPath, pairedBAIPath, contigs, contigByName, rng); err != nil {
		return nil, err
	}

	return []string{refPath, gffPath, singleBAMPath, pairedBAMPath}, nil
}

func writeTestFASTA(path string, contigs []struct {
	name string
	seq  string
}) error {
	var buf bytes.Buffer
	for _, contig := range contigs {
		buf.WriteString(">")
		buf.WriteString(contig.name)
		buf.WriteByte('\n')
		for start := 0; start < len(contig.seq); start += 60 {
			end := min(start+60, len(contig.seq))
			buf.WriteString(contig.seq[start:end])
			buf.WriteByte('\n')
		}
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func writeTestGFF3(path string, contigs []struct {
	name string
	seq  string
}) error {
	var buf bytes.Buffer
	buf.WriteString("##gff-version 3\n")
	for _, contig := range contigs {
		if contig.name == "ctgA" {
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t901\t2100\t.\t+\t.\tID=%s_gene1;Name=%s_gene1\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t901\t2100\t.\t+\t0\tID=%s_cds1;Parent=%s_gene1;Name=%s_cds1\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t6201\t8600\t.\t-\t.\tID=%s_gene2;Name=%s_gene2\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t6201\t8600\t.\t-\t0\tID=%s_cds2;Parent=%s_gene2;Name=%s_cds2\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\trepeat_region\t4801\t5350\t.\t+\t.\tID=%s_repeat1;Name=%s_repeat1\n", contig.name, contig.name, contig.name))
		} else if contig.name == "ctgB" {
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t1201\t2600\t.\t+\t.\tID=%s_gene1;Name=%s_gene1\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t1201\t2600\t.\t+\t0\tID=%s_cds1;Parent=%s_gene1;Name=%s_cds1\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t5401\t7600\t.\t-\t.\tID=%s_gene2;Name=%s_gene2\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t5401\t7600\t.\t-\t0\tID=%s_cds2;Parent=%s_gene2;Name=%s_cds2\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tmisc_feature\t9401\t9800\t.\t+\t.\tID=%s_misc1;Name=%s_misc1\n", contig.name, contig.name, contig.name))
		} else {
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t701\t1800\t.\t+\t.\tID=%s_gene1;Name=%s_gene1\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t701\t1800\t.\t+\t0\tID=%s_cds1;Parent=%s_gene1;Name=%s_cds1\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t4101\t6900\t.\t-\t.\tID=%s_gene2;Name=%s_gene2\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t4101\t6900\t.\t-\t0\tID=%s_cds2;Parent=%s_gene2;Name=%s_cds2\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\trepeat_region\t9001\t9700\t.\t+\t.\tID=%s_repeat1;Name=%s_repeat1\n", contig.name, contig.name, contig.name))
		}
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func writeSingleEndTestBAMAndIndex(bamPath, baiPath string, contigs []struct {
	name string
	seq  string
}, contigByName map[string]string, rng *rand.Rand) error {
	header, refByName, err := buildTestHeader(contigs)
	if err != nil {
		return err
	}

	variantByContig := map[string][]demoVariant{
		"ctgA": {
			{pos: testSNPPos, ref: string(contigByName["ctgA"][testSNPPos]), alt: pickAltBase(byte(contigByName["ctgA"][testSNPPos])), kind: demoVariantSNP},
			{pos: testInsertionPos, ref: string(contigByName["ctgA"][testInsertionPos]), alt: "TGA", kind: demoVariantInsertion},
			{pos: testDeletionPos, ref: contigByName["ctgA"][testDeletionPos : testDeletionPos+testDeletionLen], alt: "", kind: demoVariantDeletion},
		},
	}

	var specs []testReadSpec
	for _, contig := range contigs {
		ref := refByName[contig.name]
		for start := 0; start+testReadLen <= len(contig.seq); start += testReadStep {
			variant := pickVariantForWindow(variantByContig[contig.name], start, testReadLen)
			seq, cigar := buildReadSequence(contig.seq, start, testReadLen, variant)
			addRandomErrors(seq, variant, start, rng)
			var flags sam.Flags
			if ((start / testReadStep) % 2) == 1 {
				flags = sam.Reverse
			}
			specs = append(specs, testReadSpec{
				name:    fmt.Sprintf("%s_read_%05d", contig.name, start),
				ref:     ref,
				start:   start,
				seq:     seq,
				cigar:   cigar,
				flags:   flags,
				mapQ:    60,
				mateRef: nil,
				matePos: -1,
				tempLen: 0,
			})
		}
	}
	return writeTestBAMFromSpecs(bamPath, baiPath, header, specs)
}

func writePairedEndTestBAMAndIndex(bamPath, baiPath string, contigs []struct {
	name string
	seq  string
}, contigByName map[string]string, rng *rand.Rand) error {
	header, refByName, err := buildTestHeader(contigs)
	if err != nil {
		return err
	}

	makePairSeq := func(contigName string, start int) []byte {
		seq := []byte(contigByName[contigName][start : start+testPairReadLen])
		addRandomErrors(seq, demoVariant{}, start, rng)
		return seq
	}

	ctgARef := refByName["ctgA"]
	var specs []testReadSpec

	// Approximate 0.9X coverage from same-contig paired reads:
	// 90 bp + 20 bp gap + 90 bp per 200 bp fragment, stepped every 200 bp.
	pairGap := 20
	pairSpacing := testPairReadLen*2 + pairGap
	for _, contig := range contigs {
		ref := refByName[contig.name]
		for start := 0; start+pairSpacing <= len(contig.seq); start += pairSpacing {
			mateStart := start + testPairReadLen + pairGap
			fragLen := pairSpacing
			name := fmt.Sprintf("%s_pair_%05d", contig.name, start)
			specs = append(specs, testReadSpec{
				name:    name,
				ref:     ref,
				start:   start,
				seq:     makePairSeq(contig.name, start),
				cigar:   []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testPairReadLen)},
				flags:   sam.Paired | sam.ProperPair | sam.Read1 | sam.MateReverse,
				mapQ:    60,
				mateRef: ref,
				matePos: mateStart,
				tempLen: fragLen,
			})
			specs = append(specs, testReadSpec{
				name:    name,
				ref:     ref,
				start:   mateStart,
				seq:     makePairSeq(contig.name, mateStart),
				cigar:   []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testPairReadLen)},
				flags:   sam.Paired | sam.ProperPair | sam.Read2 | sam.Reverse,
				mapQ:    60,
				mateRef: ref,
				matePos: start,
				tempLen: -fragLen,
			})
		}
	}

	bridgeOffsetsByPair := []int{0, 180, 360}
	for contigIndex := 1; contigIndex < len(contigs); contigIndex++ {
		targetName := contigs[contigIndex].name
		targetRef := refByName[targetName]
		phaseOffset := (contigIndex - 1) * 30
		for pairIndex, pairOffset := range bridgeOffsetsByPair {
			startA := testContigLen - testPairReadLen - phaseOffset - pairOffset
			targetStart := pairIndex * testPairReadLen
			name := fmt.Sprintf("bridge_ctgA_%s_%d", targetName, pairIndex+1)
			specs = append(specs, testReadSpec{
				name:    name,
				ref:     ctgARef,
				start:   startA,
				seq:     makePairSeq("ctgA", startA),
				cigar:   []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testPairReadLen)},
				flags:   sam.Paired | sam.Read1 | sam.MateReverse,
				mapQ:    60,
				mateRef: targetRef,
				matePos: targetStart,
				tempLen: 0,
			})
			specs = append(specs, testReadSpec{
				name:    name,
				ref:     targetRef,
				start:   targetStart,
				seq:     makePairSeq(targetName, targetStart),
				cigar:   []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testPairReadLen)},
				flags:   sam.Paired | sam.Read2 | sam.Reverse,
				mapQ:    60,
				mateRef: ctgARef,
				matePos: startA,
				tempLen: 0,
			})
		}
	}
	return writeTestBAMFromSpecs(bamPath, baiPath, header, specs)
}

func buildTestHeader(contigs []struct {
	name string
	seq  string
}) (*sam.Header, map[string]*sam.Reference, error) {
	refs := make([]*sam.Reference, 0, len(contigs))
	refByName := map[string]*sam.Reference{}
	for _, contig := range contigs {
		ref, err := sam.NewReference(contig.name, "", "", len(contig.seq), nil, nil)
		if err != nil {
			return nil, nil, err
		}
		refs = append(refs, ref)
		refByName[contig.name] = ref
	}
	header, err := sam.NewHeader(nil, refs)
	if err != nil {
		return nil, nil, err
	}
	header.SortOrder = sam.Coordinate
	return header, refByName, nil
}

func writeTestBAMFromSpecs(bamPath, baiPath string, header *sam.Header, specs []testReadSpec) error {
	sort.Slice(specs, func(i, j int) bool {
		if specs[i].ref.ID() == specs[j].ref.ID() {
			if specs[i].start == specs[j].start {
				return specs[i].name < specs[j].name
			}
			return specs[i].start < specs[j].start
		}
		return specs[i].ref.ID() < specs[j].ref.ID()
	})

	bamFile, err := os.Create(bamPath)
	if err != nil {
		return err
	}
	defer bamFile.Close()
	bw, err := bam.NewWriter(bamFile, header, 1)
	if err != nil {
		return err
	}
	for _, spec := range specs {
		qual := bytes.Repeat([]byte{30}, len(spec.seq))
		rec, err := sam.NewRecord(spec.name, spec.ref, spec.mateRef, spec.start, spec.matePos, spec.tempLen, spec.mapQ, spec.cigar, spec.seq, qual, nil)
		if err != nil {
			_ = bw.Close()
			return err
		}
		rec.Flags = spec.flags
		if err := bw.Write(rec); err != nil {
			_ = bw.Close()
			return err
		}
	}
	if err := bw.Close(); err != nil {
		return err
	}

	bamIn, err := os.Open(bamPath)
	if err != nil {
		return err
	}
	defer bamIn.Close()
	br, err := bam.NewReader(bamIn, 1)
	if err != nil {
		return err
	}
	defer br.Close()
	var idx bam.Index
	for {
		rec, err := br.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		if err := idx.Add(rec, br.LastChunk()); err != nil {
			return err
		}
	}
	baiFile, err := os.Create(baiPath)
	if err != nil {
		return err
	}
	defer baiFile.Close()
	return bam.WriteIndex(baiFile, &idx)
}

func randomDNA(rng *rand.Rand, n int) string {
	alphabet := []byte("ACGT")
	out := make([]byte, n)
	for i := range out {
		out[i] = alphabet[rng.Intn(len(alphabet))]
	}
	return string(out)
}

func pickAltBase(ref byte) string {
	for _, b := range []byte("ACGT") {
		if b != ref {
			return string([]byte{b})
		}
	}
	return "A"
}

func pickVariantForWindow(variants []demoVariant, start, refSpan int) demoVariant {
	for _, v := range variants {
		if v.pos < start || v.pos >= start+refSpan {
			continue
		}
		if v.kind == demoVariantDeletion && v.pos+len(v.ref) > start+refSpan {
			continue
		}
		return v
	}
	return demoVariant{kind: demoVariantNone}
}

func buildReadSequence(refSeq string, start, refSpan int, variant demoVariant) ([]byte, []sam.CigarOp) {
	if variant.kind == demoVariantNone {
		return []byte(refSeq[start : start+refSpan]), []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, refSpan)}
	}
	prefix := variant.pos - start
	if prefix < 0 {
		prefix = 0
	}
	switch variant.kind {
	case demoVariantSNP:
		seq := []byte(refSeq[start : start+refSpan])
		seq[prefix] = variant.alt[0]
		return seq, []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, refSpan)}
	case demoVariantInsertion:
		var buf bytes.Buffer
		buf.WriteString(refSeq[start : start+prefix+1])
		buf.WriteString(variant.alt)
		buf.WriteString(refSeq[start+prefix+1 : start+refSpan])
		return buf.Bytes(), []sam.CigarOp{
			sam.NewCigarOp(sam.CigarMatch, prefix+1),
			sam.NewCigarOp(sam.CigarInsertion, len(variant.alt)),
			sam.NewCigarOp(sam.CigarMatch, refSpan-prefix-1),
		}
	case demoVariantDeletion:
		delLen := len(variant.ref)
		var buf bytes.Buffer
		buf.WriteString(refSeq[start : start+prefix])
		buf.WriteString(refSeq[start+prefix+delLen : start+refSpan])
		return buf.Bytes(), []sam.CigarOp{
			sam.NewCigarOp(sam.CigarMatch, prefix),
			sam.NewCigarOp(sam.CigarDeletion, delLen),
			sam.NewCigarOp(sam.CigarMatch, refSpan-prefix-delLen),
		}
	default:
		return []byte(refSeq[start : start+refSpan]), []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, refSpan)}
	}
}

func addRandomErrors(seq []byte, variant demoVariant, refStart int, rng *rand.Rand) {
	protectedStart := -1
	protectedEnd := -1
	switch variant.kind {
	case demoVariantSNP:
		protectedStart = variant.pos - refStart
		protectedEnd = protectedStart + 1
	case demoVariantInsertion:
		protectedStart = variant.pos - refStart + 1
		protectedEnd = protectedStart + len(variant.alt)
	case demoVariantDeletion:
		protectedStart = variant.pos - refStart
		protectedEnd = protectedStart + 1
	}
	for i := range seq {
		if protectedStart >= 0 && i >= protectedStart && i < protectedEnd {
			continue
		}
		if rng.Float64() >= testErrorRate {
			continue
		}
		seq[i] = mutateBase(seq[i], rng)
	}
}

func mutateBase(ref byte, rng *rand.Rand) byte {
	alts := []byte{'A', 'C', 'G', 'T'}
	var choices []byte
	for _, b := range alts {
		if b != ref {
			choices = append(choices, b)
		}
	}
	return choices[rng.Intn(len(choices))]
}
