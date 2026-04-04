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
	demoVariantComplex
)

type demoVariant struct {
	pos  int
	ref  string
	alt  string
	kind demoVariantKind
}

type demoVCFRecord struct {
	chrom      string
	pos1       int
	id         string
	ref        string
	alt        string
	qual       string
	filter     string
	info       string
	formatKeys []string
	samples    []string
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
	for _, suffix := range []string{"A", "B", "C", "D", "E", "F", "G", "H", "I"} {
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
	vcfPath := filepath.Join(entryDir, "variants.vcf")
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
	vcfRecords := buildDemoVCFRecords(contigByName)
	if err := writeTestVCF(vcfPath, contigs, vcfRecords); err != nil {
		return nil, err
	}
	return []string{refPath, gffPath, singleBAMPath, pairedBAMPath, vcfPath}, nil
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
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t3001\t4200\t.\t+\t.\tID=%s_gene3;Name=%s_gene3_two_exon\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tmRNA\t3001\t4200\t.\t+\t.\tID=%s_tx3;Parent=%s_gene3;Name=%s_tx3\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\texon\t3001\t3300\t.\t+\t.\tID=%s_exon3a;Parent=%s_tx3;Name=%s_exon3a\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t3001\t3300\t.\t+\t0\tID=%s_cds3a;Parent=%s_tx3;Name=%s_cds3a\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\texon\t3902\t4200\t.\t+\t.\tID=%s_exon3b;Parent=%s_tx3;Name=%s_exon3b\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t3902\t4200\t.\t+\t0\tID=%s_cds3b;Parent=%s_tx3;Name=%s_cds3b\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t6201\t8600\t.\t-\t.\tID=%s_gene2;Name=%s_gene2\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t6201\t8600\t.\t-\t0\tID=%s_cds2;Parent=%s_gene2;Name=%s_cds2\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\trepeat_region\t4801\t5350\t.\t+\t.\tID=%s_repeat1;Name=%s_repeat1\n", contig.name, contig.name, contig.name))
		} else if contig.name == "ctgB" {
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t1201\t2600\t.\t+\t.\tID=%s_gene1;Name=%s_gene1\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t1201\t2600\t.\t+\t0\tID=%s_cds1;Parent=%s_gene1;Name=%s_cds1\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t5401\t7600\t.\t-\t.\tID=%s_gene2;Name=%s_gene2\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t5401\t7600\t.\t-\t0\tID=%s_cds2;Parent=%s_gene2;Name=%s_cds2\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tmisc_feature\t9401\t9800\t.\t+\t.\tID=%s_misc1;Name=%s_misc1\n", contig.name, contig.name, contig.name))
		} else if contig.name != "ctgI" {
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t701\t1800\t.\t+\t.\tID=%s_gene1;Name=%s_gene1\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t701\t1800\t.\t+\t0\tID=%s_cds1;Parent=%s_gene1;Name=%s_cds1\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tgene\t4101\t6900\t.\t-\t.\tID=%s_gene2;Name=%s_gene2\n", contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\tCDS\t4101\t6900\t.\t-\t0\tID=%s_cds2;Parent=%s_gene2;Name=%s_cds2\n", contig.name, contig.name, contig.name, contig.name))
			buf.WriteString(fmt.Sprintf("%s\tdemo\trepeat_region\t9001\t9700\t.\t+\t.\tID=%s_repeat1;Name=%s_repeat1\n", contig.name, contig.name, contig.name))
		}
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func buildDemoVCFRecords(contigByName map[string]string) []demoVCFRecord {
	ctgA := contigByName["ctgA"]
	ctgB := contigByName["ctgB"]

	snpRefPos0 := testSNPPos - 3
	snpRefRef := ctgA[snpRefPos0 : snpRefPos0+1]
	snpRefAlt := pickAltBase(ctgA[snpRefPos0])

	snpHetPos0 := testSNPPos
	snpHetRef := ctgA[snpHetPos0 : snpHetPos0+1]
	snpHetAlt := pickAltBase(ctgA[snpHetPos0])

	snpHomAltPos0 := testSNPPos + 3
	snpHomAltRef := ctgA[snpHomAltPos0 : snpHomAltPos0+1]
	snpHomAltAlt := pickAltBase(ctgA[snpHomAltPos0])

	snpHetAltPos0 := testSNPPos + 6
	snpHetAltRef := ctgA[snpHetAltPos0 : snpHetAltPos0+1]
	snpHetAltA := pickAltBase(ctgA[snpHetAltPos0])
	snpHetAltB := string([]byte{pickAltBaseExcluding(ctgA[snpHetAltPos0], []byte{snpHetAltA[0]})})

	delNearPos0 := testSNPPos + 9
	delNearRef := ctgA[delNearPos0 : delNearPos0+3]
	delNearAlt := delNearRef[:1]

	delNearRefPos0 := testSNPPos + 14
	delNearRefRef := ctgA[delNearRefPos0 : delNearRefPos0+4]
	delNearRefAlt := delNearRefRef[:1]

	insNearPos0 := testSNPPos + 18
	insNearRef := ctgA[insNearPos0 : insNearPos0+1]
	insNearAlt := insNearRef + "TG"

	insNearRefPos0 := testSNPPos + 21
	insNearRefRef := ctgA[insNearRefPos0 : insNearRefPos0+1]
	insNearRefAlt := insNearRefRef + "CA"

	insPos0 := testInsertionPos
	insRef := ctgA[insPos0 : insPos0+1]
	insAlt := insRef + "TGA"

	delAnchor0 := testDeletionPos
	delRef := ctgA[delAnchor0 : delAnchor0+1+testDeletionLen]
	delAlt := ctgA[delAnchor0 : delAnchor0+1]

	complexPos0 := 8400
	complexRef := ctgB[complexPos0 : complexPos0+7]
	complexAlt := buildComplexAlt(complexRef)

	return []demoVCFRecord{
		{
			chrom:      "ctgA",
			pos1:       snpRefPos0 + 1,
			id:         "demo_snp_ref",
			ref:        snpRefRef,
			alt:        snpRefAlt,
			qual:       "60",
			filter:     "PASS",
			info:       "TYPE=SNP",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"0/0:18:18,0", "0/1:18:9,9"},
		},
		{
			chrom:      "ctgA",
			pos1:       snpHetPos0 + 1,
			id:         "demo_snp_1",
			ref:        snpHetRef,
			alt:        snpHetAlt,
			qual:       "60",
			filter:     "PASS",
			info:       "TYPE=SNP",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"0/1:18:9,9", "1/1:22:0,22"},
		},
		{
			chrom:      "ctgA",
			pos1:       snpHomAltPos0 + 1,
			id:         "demo_snp_hom_alt",
			ref:        snpHomAltRef,
			alt:        snpHomAltAlt,
			qual:       "59",
			filter:     "PASS",
			info:       "TYPE=SNP",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"1/1:20:0,20", "0/0:20:20,0"},
		},
		{
			chrom:      "ctgA",
			pos1:       snpHetAltPos0 + 1,
			id:         "demo_snp_het_alt",
			ref:        snpHetAltRef,
			alt:        snpHetAltA + "," + snpHetAltB,
			qual:       "58",
			filter:     "PASS",
			info:       "TYPE=SNP",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"1/2:16:0,8,8", "0/1:16:8,8,0"},
		},
		{
			chrom:      "ctgA",
			pos1:       delNearPos0 + 1,
			id:         "demo_del_near_1",
			ref:        delNearRef,
			alt:        delNearAlt,
			qual:       "57",
			filter:     "PASS",
			info:       "TYPE=DEL",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"0/1:18:9,9", "1/1:18:0,18"},
		},
		{
			chrom:      "ctgA",
			pos1:       delNearRefPos0 + 1,
			id:         "demo_del_near_2",
			ref:        delNearRefRef,
			alt:        delNearRefAlt,
			qual:       "56",
			filter:     "PASS",
			info:       "TYPE=DEL",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"0/0:16:16,0", "0/1:16:8,8"},
		},
		{
			chrom:      "ctgA",
			pos1:       insNearPos0 + 1,
			id:         "demo_ins_near_1",
			ref:        insNearRef,
			alt:        insNearAlt,
			qual:       "57",
			filter:     "PASS",
			info:       "TYPE=INS",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"0/1:18:9,9", "1/1:18:0,18"},
		},
		{
			chrom:      "ctgA",
			pos1:       insNearRefPos0 + 1,
			id:         "demo_ins_near_2",
			ref:        insNearRefRef,
			alt:        insNearRefAlt,
			qual:       "56",
			filter:     "PASS",
			info:       "TYPE=INS",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"0/0:16:16,0", "0/1:16:8,8"},
		},
		{
			chrom:      "ctgA",
			pos1:       insPos0 + 1,
			id:         "demo_ins_1",
			ref:        insRef,
			alt:        insAlt,
			qual:       "58",
			filter:     "PASS",
			info:       "TYPE=INS",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"1/1:16:0,16", "0/1:19:10,9"},
		},
		{
			chrom:      "ctgA",
			pos1:       delAnchor0 + 1,
			id:         "demo_del_1",
			ref:        delRef,
			alt:        delAlt,
			qual:       "57",
			filter:     "PASS",
			info:       "TYPE=DEL",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"0/1:20:11,9", "1/1:17:0,17"},
		},
		{
			chrom:      "ctgB",
			pos1:       complexPos0 + 1,
			id:         "demo_complex_1",
			ref:        complexRef,
			alt:        complexAlt,
			qual:       "55",
			filter:     "PASS",
			info:       "TYPE=COMPLEX",
			formatKeys: []string{"GT", "DP", "AD"},
			samples:    []string{"1/1:14:0,14", "0/1:21:12,9"},
		},
	}
}

func writeTestVCF(path string, contigs []struct {
	name string
	seq  string
}, records []demoVCFRecord) error {
	var buf bytes.Buffer
	buf.WriteString("##fileformat=VCFv4.2\n")
	for _, contig := range contigs {
		buf.WriteString(fmt.Sprintf("##contig=<ID=%s,length=%d>\n", contig.name, len(contig.seq)))
	}
	buf.WriteString("##INFO=<ID=TYPE,Number=1,Type=String,Description=\"Demo variant class\">\n")
	buf.WriteString("##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n")
	buf.WriteString("##FORMAT=<ID=DP,Number=1,Type=Integer,Description=\"Read depth\">\n")
	buf.WriteString("##FORMAT=<ID=AD,Number=R,Type=Integer,Description=\"Allelic depths\">\n")
	buf.WriteString("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tsample_a\tsample_b\n")
	for _, record := range records {
		buf.WriteString(record.chrom)
		buf.WriteByte('\t')
		buf.WriteString(fmt.Sprintf("%d", record.pos1))
		buf.WriteByte('\t')
		buf.WriteString(record.id)
		buf.WriteByte('\t')
		buf.WriteString(record.ref)
		buf.WriteByte('\t')
		buf.WriteString(record.alt)
		buf.WriteByte('\t')
		buf.WriteString(record.qual)
		buf.WriteByte('\t')
		buf.WriteString(record.filter)
		buf.WriteByte('\t')
		buf.WriteString(record.info)
		buf.WriteByte('\t')
		buf.WriteString(strings.Join(record.formatKeys, ":"))
		for _, sample := range record.samples {
			buf.WriteByte('\t')
			buf.WriteString(sample)
		}
		buf.WriteByte('\n')
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
		if contig.name == "ctgI" {
			continue
		}
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
	logoRef := refByName["ctgI"]
	logoSeq := contigByName["ctgI"]
	mix50Pos := 1060
	mix50Start := mix50Pos - 40
	mix50Alt := pickAltBase(logoSeq[mix50Pos])
	specs = append(specs,
		testReadSpec{name: "ctgI_mix50_ref_1", ref: logoRef, start: mix50Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix50Start, testReadLen, mix50Pos, 0), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: 0, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix50_ref_2", ref: logoRef, start: mix50Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix50Start, testReadLen, mix50Pos, 0), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: sam.Reverse, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix50_alt_1", ref: logoRef, start: mix50Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix50Start, testReadLen, mix50Pos, mix50Alt[0]), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: 0, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix50_alt_2", ref: logoRef, start: mix50Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix50Start, testReadLen, mix50Pos, mix50Alt[0]), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: sam.Reverse, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
	)
	mix3Pos := 1460
	mix3Start := mix3Pos - 40
	mix3AltA := pickAltBase(logoSeq[mix3Pos])
	mix3AltB := pickAltBaseExcluding(logoSeq[mix3Pos], []byte{mix3AltA[0]})
	specs = append(specs,
		testReadSpec{name: "ctgI_mix325_ref", ref: logoRef, start: mix3Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix3Start, testReadLen, mix3Pos, 0), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: 0, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix325_altA", ref: logoRef, start: mix3Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix3Start, testReadLen, mix3Pos, mix3AltA[0]), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: sam.Reverse, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix325_altB_1", ref: logoRef, start: mix3Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix3Start, testReadLen, mix3Pos, mix3AltB), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: 0, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix325_altB_2", ref: logoRef, start: mix3Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix3Start, testReadLen, mix3Pos, mix3AltB), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: sam.Reverse, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
	)
	mix4Pos := 1860
	mix4Start := mix4Pos - 40
	mix4Alts := remainingBases(logoSeq[mix4Pos])
	specs = append(specs,
		testReadSpec{name: "ctgI_mix4_ref", ref: logoRef, start: mix4Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix4Start, testReadLen, mix4Pos, 0), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: 0, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix4_alt1", ref: logoRef, start: mix4Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix4Start, testReadLen, mix4Pos, mix4Alts[0]), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: sam.Reverse, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix4_alt2", ref: logoRef, start: mix4Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix4Start, testReadLen, mix4Pos, mix4Alts[1]), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: 0, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
		testReadSpec{name: "ctgI_mix4_alt3", ref: logoRef, start: mix4Start, seq: buildReadSequenceWithExplicitSNP(logoSeq, mix4Start, testReadLen, mix4Pos, mix4Alts[2]), cigar: []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testReadLen)}, flags: sam.Reverse, mapQ: 60, mateRef: nil, matePos: -1, tempLen: 0},
	)
	specs = append(specs, testReadSpec{
		name:  "ctgA_softclip_single",
		ref:   refByName["ctgA"],
		start: 3400,
		seq:   buildSoftClippedReadSequence(contigByName["ctgA"], 3400, testReadLen, 10, 12),
		cigar: []sam.CigarOp{
			sam.NewCigarOp(sam.CigarSoftClipped, 10),
			sam.NewCigarOp(sam.CigarMatch, testReadLen),
			sam.NewCigarOp(sam.CigarSoftClipped, 12),
		},
		flags:   0,
		mapQ:    60,
		mateRef: nil,
		matePos: -1,
		tempLen: 0,
	})
	specs = append(specs,
		testReadSpec{
			name:  "ctgA_softclip_start_overhang",
			ref:   refByName["ctgA"],
			start: 0,
			seq:   buildSoftClippedReadSequence(contigByName["ctgA"], 0, testReadLen, 24, 0),
			cigar: []sam.CigarOp{
				sam.NewCigarOp(sam.CigarSoftClipped, 24),
				sam.NewCigarOp(sam.CigarMatch, testReadLen),
			},
			flags:   0,
			mapQ:    60,
			mateRef: nil,
			matePos: -1,
			tempLen: 0,
		},
		testReadSpec{
			name:  "ctgA_softclip_end_overhang",
			ref:   refByName["ctgA"],
			start: testContigLen - testReadLen,
			seq:   buildSoftClippedReadSequence(contigByName["ctgA"], testContigLen-testReadLen, testReadLen, 0, 28),
			cigar: []sam.CigarOp{
				sam.NewCigarOp(sam.CigarMatch, testReadLen),
				sam.NewCigarOp(sam.CigarSoftClipped, 28),
			},
			flags:   sam.Reverse,
			mapQ:    60,
			mateRef: nil,
			matePos: -1,
			tempLen: 0,
		},
		testReadSpec{
			name:  "ctgB_softclip_start_overhang",
			ref:   refByName["ctgB"],
			start: 0,
			seq:   buildSoftClippedReadSequence(contigByName["ctgB"], 0, testReadLen, 22, 0),
			cigar: []sam.CigarOp{
				sam.NewCigarOp(sam.CigarSoftClipped, 22),
				sam.NewCigarOp(sam.CigarMatch, testReadLen),
			},
			flags:   0,
			mapQ:    60,
			mateRef: nil,
			matePos: -1,
			tempLen: 0,
		},
	)
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
		if contig.name == "ctgI" {
			continue
		}
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

	// One mapped read at the start of ctgA whose mate is flagged unmapped,
	// but still carries mate coordinates as seen in real BAMs.
	specs = append(specs, testReadSpec{
		name:    "ctgA_mate_unmapped_1",
		ref:     ctgARef,
		start:   0,
		seq:     makePairSeq("ctgA", 0),
		cigar:   []sam.CigarOp{sam.NewCigarOp(sam.CigarMatch, testPairReadLen)},
		flags:   sam.Paired | sam.Read1 | sam.MateUnmapped,
		mapQ:    60,
		mateRef: ctgARef,
		matePos: testPairReadLen + pairGap,
		tempLen: 0,
	})
	specs = append(specs, testReadSpec{
		name:    "ctgA_mate_unmapped_1",
		ref:     ctgARef,
		start:   testPairReadLen + pairGap,
		seq:     makePairSeq("ctgA", testPairReadLen+pairGap),
		cigar:   nil,
		flags:   sam.Paired | sam.Read2 | sam.Unmapped,
		mapQ:    0,
		mateRef: ctgARef,
		matePos: 0,
		tempLen: 0,
	})

	specs = append(specs, testReadSpec{
		name:  "ctgA_softclip_pair_1",
		ref:   ctgARef,
		start: 5600,
		seq:   buildSoftClippedReadSequence(contigByName["ctgA"], 5600, testPairReadLen, 8, 10),
		cigar: []sam.CigarOp{
			sam.NewCigarOp(sam.CigarSoftClipped, 8),
			sam.NewCigarOp(sam.CigarMatch, testPairReadLen),
			sam.NewCigarOp(sam.CigarSoftClipped, 10),
		},
		flags:   sam.Paired | sam.ProperPair | sam.Read1 | sam.MateReverse,
		mapQ:    60,
		mateRef: ctgARef,
		matePos: 5760,
		tempLen: 250,
	})
	specs = append(specs, testReadSpec{
		name:  "ctgA_softclip_pair_1",
		ref:   ctgARef,
		start: 5760,
		seq:   buildSoftClippedReadSequence(contigByName["ctgA"], 5760, testPairReadLen, 6, 14),
		cigar: []sam.CigarOp{
			sam.NewCigarOp(sam.CigarSoftClipped, 6),
			sam.NewCigarOp(sam.CigarMatch, testPairReadLen),
			sam.NewCigarOp(sam.CigarSoftClipped, 14),
		},
		flags:   sam.Paired | sam.ProperPair | sam.Read2 | sam.Reverse,
		mapQ:    60,
		mateRef: ctgARef,
		matePos: 5600,
		tempLen: -250,
	})

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

func buildSoftClippedReadSequence(refSeq string, start, alignedSpan, leftClip, rightClip int) []byte {
	var buf bytes.Buffer
	leftAlphabet := []byte("TGCATGCATGCA")
	rightAlphabet := []byte("CAGTCAGTCAGT")
	for i := 0; i < leftClip; i++ {
		buf.WriteByte(leftAlphabet[i%len(leftAlphabet)])
	}
	buf.WriteString(refSeq[start : start+alignedSpan])
	for i := 0; i < rightClip; i++ {
		buf.WriteByte(rightAlphabet[i%len(rightAlphabet)])
	}
	return buf.Bytes()
}

func buildReadSequenceWithExplicitSNP(refSeq string, start, refSpan, snpPos int, alt byte) []byte {
	seq := []byte(refSeq[start : start+refSpan])
	if alt == 0 {
		return seq
	}
	idx := snpPos - start
	if idx >= 0 && idx < len(seq) {
		seq[idx] = alt
	}
	return seq
}

func pickAltBaseExcluding(ref byte, excluded []byte) byte {
	for _, b := range []byte("ACGT") {
		if b == ref {
			continue
		}
		skip := false
		for _, ex := range excluded {
			if b == ex {
				skip = true
				break
			}
		}
		if !skip {
			return b
		}
	}
	return pickAltBase(ref)[0]
}

func remainingBases(ref byte) []byte {
	out := make([]byte, 0, 3)
	for _, b := range []byte("ACGT") {
		if b != ref {
			out = append(out, b)
		}
	}
	return out
}

func buildComplexAlt(ref string) string {
	if len(ref) < 4 {
		return ref
	}
	out := make([]byte, 0, len(ref)-1)
	out = append(out, ref[0])
	for i := 1; i < len(ref); i++ {
		if i == 3 {
			continue
		}
		if i%2 == 1 {
			out = append(out, pickAltBase(ref[i])[0])
		} else {
			out = append(out, ref[i])
		}
	}
	if string(out) == ref {
		out[len(out)-1] = pickAltBase(out[len(out)-1])[0]
	}
	return string(out)
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
