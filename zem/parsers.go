package main

import (
	"bufio"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"unicode"

	"github.com/shenwei356/xopen"
)

var digitsRegexp = regexp.MustCompile(`\d+`)

func nextLongLine(r *bufio.Reader) (string, error) {
	var out []byte
	for {
		frag, isPrefix, err := r.ReadLine()
		if err != nil {
			if err == io.EOF && len(out) > 0 {
				return string(out), nil
			}
			return "", err
		}
		out = append(out, frag...)
		if !isPrefix {
			return string(out), nil
		}
	}
}

func parseFASTA(path string) (map[string]string, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	reader := bufio.NewReader(f)
	seqs := make(map[string]string)
	var current string
	var b strings.Builder

	flush := func() {
		if current == "" {
			return
		}
		seqs[current] = strings.ToUpper(b.String())
		b.Reset()
	}

	for {
		rawLine, err := nextLongLine(reader)
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		line := strings.TrimSpace(rawLine)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, ">") {
			flush()
			hdr := strings.TrimSpace(line[1:])
			fields := strings.Fields(hdr)
			if len(fields) == 0 {
				return nil, fmt.Errorf("invalid FASTA header in %s", path)
			}
			current = fields[0]
			continue
		}
		if current == "" {
			return nil, fmt.Errorf("FASTA sequence before header in %s", path)
		}
		for _, r := range line {
			if unicode.IsLetter(r) || r == '*' || r == '-' {
				b.WriteRune(unicode.ToUpper(r))
			}
		}
	}
	flush()

	if len(seqs) == 0 {
		return nil, fmt.Errorf("no sequences found in %s", path)
	}
	return seqs, nil
}

func parseGFF3(path string) (map[string]string, map[string][]Feature, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return nil, nil, err
	}
	defer f.Close()

	reader := bufio.NewReader(f)
	out := make(map[string][]Feature)
	seqs := make(map[string]string)
	inFASTA := false
	var fastaName string
	var fastaBuilder strings.Builder

	flushFASTA := func() error {
		if fastaName == "" {
			return nil
		}
		seq := strings.ToUpper(fastaBuilder.String())
		if seq == "" {
			return fmt.Errorf("empty FASTA sequence for %s in %s", fastaName, path)
		}
		seqs[fastaName] = seq
		fastaName = ""
		fastaBuilder.Reset()
		return nil
	}

	for {
		rawLine, err := nextLongLine(reader)
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, nil, err
		}
		line := strings.TrimSpace(rawLine)
		if inFASTA {
			if line == "" {
				continue
			}
			if strings.HasPrefix(line, ">") {
				if err := flushFASTA(); err != nil {
					return nil, nil, err
				}
				hdr := strings.TrimSpace(line[1:])
				fields := strings.Fields(hdr)
				if len(fields) == 0 {
					return nil, nil, fmt.Errorf("invalid embedded FASTA header in %s", path)
				}
				fastaName = fields[0]
				continue
			}
			if fastaName == "" {
				return nil, nil, fmt.Errorf("embedded FASTA sequence before header in %s", path)
			}
			for _, r := range line {
				if unicode.IsLetter(r) || r == '*' || r == '-' {
					fastaBuilder.WriteRune(unicode.ToUpper(r))
				}
			}
			continue
		}
		if line == "" {
			continue
		}
		if line == "##FASTA" {
			inFASTA = true
			continue
		}
		if strings.HasPrefix(line, "#") {
			continue
		}
		cols := strings.Split(line, "\t")
		if len(cols) < 9 {
			continue
		}
		start, err := strconv.Atoi(cols[3])
		if err != nil {
			continue
		}
		end, err := strconv.Atoi(cols[4])
		if err != nil {
			continue
		}
		strand := byte('.')
		if cols[6] != "" {
			strand = cols[6][0]
		}
		phase := int8(-1)
		if cols[7] != "" && cols[7] != "." {
			phaseValue, err := strconv.Atoi(cols[7])
			if err == nil && phaseValue >= 0 && phaseValue <= 2 {
				phase = int8(phaseValue)
			}
		}
		feat := Feature{
			SeqName:    cols[0],
			Source:     cols[1],
			Type:       cols[2],
			Start:      start - 1,
			End:        end,
			Strand:     strand,
			Phase:      phase,
			Attributes: cols[8],
		}
		out[feat.SeqName] = append(out[feat.SeqName], feat)
	}
	if inFASTA {
		if err := flushFASTA(); err != nil {
			return nil, nil, err
		}
	}
	return seqs, out, nil
}

func parseFlatFile(path string) (map[string]string, map[string][]Feature, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return nil, nil, err
	}
	defer f.Close()

	seqs := make(map[string]string)
	feats := make(map[string][]Feature)

	scanner := bufio.NewScanner(f)
	var recName string
	var seqBuilder strings.Builder
	var inFeatures bool
	var inSeq bool
	var pending *Feature
	var qualifierParts []string

	flushPending := func() {
		if pending == nil || recName == "" {
			return
		}
		if len(qualifierParts) > 0 {
			pending.Attributes = strings.Join(qualifierParts, ";")
			qualifierParts = nil
		}
		feats[recName] = append(feats[recName], *pending)
		pending = nil
	}
	flushRecord := func() {
		flushPending()
		if recName != "" && seqBuilder.Len() > 0 {
			seqs[recName] = strings.ToUpper(seqBuilder.String())
		}
		recName = ""
		seqBuilder.Reset()
		inFeatures = false
		inSeq = false
		pending = nil
		qualifierParts = nil
	}

	for scanner.Scan() {
		line := scanner.Text()
		trim := strings.TrimSpace(line)

		if strings.HasPrefix(line, "LOCUS") {
			flushRecord()
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				recName = fields[1]
			}
			continue
		}
		if strings.HasPrefix(line, "ID") && len(line) > 2 && unicode.IsSpace(rune(line[2])) {
			flushRecord()
			rest := strings.TrimSpace(line[2:])
			fields := strings.Fields(rest)
			if len(fields) > 0 {
				recName = strings.TrimSuffix(fields[0], ";")
			}
			continue
		}
		if strings.HasPrefix(trim, "FEATURES") || strings.HasPrefix(line, "FH") {
			inFeatures = true
			inSeq = false
			continue
		}
		if strings.HasPrefix(trim, "ORIGIN") || strings.HasPrefix(line, "SQ") {
			flushPending()
			inFeatures = false
			inSeq = true
			continue
		}
		if trim == "//" {
			flushRecord()
			continue
		}

		if inSeq {
			for _, r := range line {
				if unicode.IsLetter(r) {
					seqBuilder.WriteRune(unicode.ToUpper(r))
				}
			}
			continue
		}

		if !inFeatures || recName == "" {
			continue
		}

		if pending != nil {
			if q, ok := parseFlatFileQualifier(line); ok {
				qualifierParts = append(qualifierParts, q)
				continue
			}
		}

		featureType, location, ok := parseFeatureLine(line)
		if !ok {
			continue
		}
		flushPending()
		start, end := parseLocation(location)
		if end <= start {
			continue
		}
		strand := byte('+')
		if strings.Contains(location, "complement") {
			strand = '-'
		}
		pending = &Feature{
			SeqName: recName,
			Source:  "flatfile",
			Type:    featureType,
			Start:   start,
			End:     end,
			Strand:  strand,
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, nil, err
	}
	flushRecord()

	return seqs, feats, nil
}

func parseFlatFileQualifier(line string) (string, bool) {
	trimmed := strings.TrimSpace(line)
	if strings.HasPrefix(line, "FT") {
		rest := ""
		if len(line) > 2 {
			rest = line[2:]
		}
		trimmed = strings.TrimSpace(rest)
	}
	if !strings.HasPrefix(trimmed, "/") {
		return "", false
	}
	trimmed = strings.TrimPrefix(trimmed, "/")
	eq := strings.Index(trimmed, "=")
	if eq < 0 {
		return trimmed, true
	}
	key := strings.TrimSpace(trimmed[:eq])
	value := strings.TrimSpace(trimmed[eq+1:])
	value = strings.TrimPrefix(value, "\"")
	value = strings.TrimSuffix(value, "\"")
	return key + "=" + value, true
}

func parseFeatureLine(line string) (featureType, location string, ok bool) {
	if strings.HasPrefix(line, "FT") {
		rest := ""
		if len(line) > 2 {
			rest = strings.TrimSpace(line[2:])
		}
		fields := strings.Fields(rest)
		if len(fields) < 2 {
			return "", "", false
		}
		return fields[0], strings.Join(fields[1:], " "), true
	}
	if len(line) >= 21 && strings.HasPrefix(line, "     ") {
		key := strings.TrimSpace(line[:21])
		if key == "" || strings.HasPrefix(strings.TrimSpace(line), "/") {
			return "", "", false
		}
		loc := strings.TrimSpace(line[21:])
		if loc == "" {
			return "", "", false
		}
		return key, loc, true
	}
	return "", "", false
}

func parseLocation(location string) (int, int) {
	nums := digitsRegexp.FindAllString(location, -1)
	if len(nums) == 0 {
		return 0, 0
	}
	minVal := int(^uint(0) >> 1)
	maxVal := 0
	for _, n := range nums {
		v, err := strconv.Atoi(n)
		if err != nil {
			continue
		}
		if v < minVal {
			minVal = v
		}
		if v > maxVal {
			maxVal = v
		}
	}
	if minVal == int(^uint(0)>>1) {
		return 0, 0
	}
	if minVal > 0 {
		minVal--
	}
	return minVal, maxVal
}
