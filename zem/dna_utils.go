package zem

func reverseComplementString(seq string) string {
	out := make([]byte, len(seq))
	for i := 0; i < len(seq); i++ {
		switch seq[i] {
		case 'A':
			out[len(seq)-1-i] = 'T'
		case 'C':
			out[len(seq)-1-i] = 'G'
		case 'G':
			out[len(seq)-1-i] = 'C'
		case 'T':
			out[len(seq)-1-i] = 'A'
		default:
			out[len(seq)-1-i] = 'N'
		}
	}
	return string(out)
}
