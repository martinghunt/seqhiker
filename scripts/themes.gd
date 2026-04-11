extends RefCounted
class_name ThemesLib

const ANONYMOUS_PRO_FONT := preload("res://fonts/Anonymous-Pro/Anonymous_Pro.ttf")
const COURIER_NEW_FONT := preload("res://fonts/Courier-New/couriernew.ttf")
const DEJAVU_SANS_FONT_PATH := "res://fonts/Dejavu-sans/DejaVuSans.ttf"
const USER_THEME_CONFIG_PATH := "user://seqhiker_user_themes.cfg"


# Key explanations:
#  - bg: main app background
#  - panel: panel/container background
#  - panel_alt: alternate panel/control background
#  - grid: gridlines and light guide lines
#  - border: general panel/control borders
#  - text: main text color
#  - scrollbar_outline: scrollbar grabber outline
#  - text_muted: secondary/de-emphasized text
#  - text_inverse: text on dark/accent fills
#  - button_bg: normal button fill
#  - button_hover: hovered button fill
#  - button_pressed: pressed button fill
#  - field_bg: text/input field background
#  - field_border: text/input field border
#  - field_focus: focused input/control outline
#  - accent: primary accent color
#  - status_error: error/status text color
#  - track_alt_bg: alternating track-row background
#  - map_contig: primary contig fill in map track
#  - map_contig_alt: alternating contig fill in map track
#  - map_view_fill: map viewport/drag selection fill
#  - map_view_outline: map viewport/drag selection outline
#  - region_select_fill: genome-track dragged region fill
#  - region_select_outline: genome-track dragged region outline
#  - genome: genome axis/main genome highlight color
#  - read: default read/depth-summary color
#  - insertion_marker: read insertion marker color
#  - gc_plot: GC plot color
#  - depth_plot: depth plot color
#  - depth_plot_series: per-BAM depth plot series colors
#  - vcf_gt_ref_fill/text: VCF genotype colors for 0/0 calls
#  - vcf_gt_het_fill/text: VCF genotype colors for heterozygous calls
#  - vcf_gt_hom_alt_fill/text: VCF genotype colors for homozygous ALT calls
#  - pileup_logo_bases: per-base colors for pileup logo A/C/G/T/D
#  - ambiguous_base: color for ambiguous nucleotide letters
#  - snp: SNP marker fill
#  - snp_text: text drawn on SNP markers
#  - feature: annotation feature box fill
#  - feature_accent: subtle annotation sub-feature accent
#  - feature_text: annotation feature label/border color
#  - stop_codon: AA/annotation overview stop-codon marker color
#  - comparison_same_strand: comparison-match fill for same-strand hits
#  - comparison_opp_strand: comparison-match fill for opposite-strand hits
#  - comparison_selected_fill: comparison-match fill for the selected hit
#  - comparison_match_line: comparison internal match-line color
#  - comparison_snp: comparison-detail SNP connector color

const LIVE_PALETTE_KEYS := [
	"bg",
	"panel",
	"panel_alt",
	"grid",
	"border",
	"text",
	"insertion_marker",
	"scrollbar_outline",
	"text_muted",
	"text_inverse",
	"button_bg",
	"button_hover",
	"button_pressed",
	"field_bg",
	"field_border",
	"field_focus",
	"accent",
	"status_error",
	"track_alt_bg",
	"map_contig",
	"map_contig_alt",
	"map_view_fill",
	"map_view_outline",
	"region_select_fill",
	"region_select_outline",
	"genome",
	"read",
	"gc_plot",
	"depth_plot",
	"depth_plot_series",
	"vcf_gt_ref_fill",
	"vcf_gt_ref_text",
	"vcf_gt_het_fill",
	"vcf_gt_het_text",
	"vcf_gt_hom_alt_fill",
	"vcf_gt_hom_alt_text",
	"pileup_logo_bases",
	"ambiguous_base",
	"snp",
	"comparison_snp",
	"comparison_match_line",
	"snp_text",
	"feature",
	"feature_accent",
	"feature_text",
	"comparison_same_strand",
	"comparison_opp_strand",
	"comparison_selected_fill",
	"stop_codon"
]

const EDITOR_ROLE_GROUPS := [
	{"title": "Core UI", "roles": [
		{"key": "bg", "label": "Background"},
		{"key": "track_alt_bg", "label": "Track alt bg"},
		{"key": "panel", "label": "Panel"},
		{"key": "panel_alt", "label": "Panel alt"},
		{"key": "grid", "label": "Grid"},
		{"key": "border", "label": "Border"},
		{"key": "scrollbar_outline", "label": "Scrollbar outline"},
		{"key": "text", "label": "Text"},
		{"key": "text_inverse", "label": "Check mark"},
		{"key": "text_muted", "label": "Text muted"},
		{"key": "accent", "label": "Accent"},
		{"key": "status_error", "label": "Error message"}
	]},
	{"title": "Header Controls", "roles": [
		{"key": "button_bg", "label": "Button bg"},
		{"key": "button_hover", "label": "Button hover"},
		{"key": "button_pressed", "label": "Button pressed"},
		{"key": "field_bg", "label": "Field bg"},
		{"key": "field_border", "label": "Field border"},
		{"key": "field_focus", "label": "Field focus"}
	]},
	{"title": "Plots", "roles": [
		{"key": "gc_plot", "label": "GC plot"},
		{"key": "depth_plot", "label": "Depth plot"}
	]},
	{"title": "Depth plot colours", "roles": [
		{"key": "depth_plot_series_0", "label": "Colour 1"},
		{"key": "depth_plot_series_1", "label": "Colour 2"},
		{"key": "depth_plot_series_2", "label": "Colour 3"},
		{"key": "depth_plot_series_3", "label": "Colour 4"},
		{"key": "depth_plot_series_4", "label": "Colour 5"},
		{"key": "depth_plot_series_5", "label": "Colour 6"}
	]},
	{"title": "AA / Annotation", "roles": [
		{"key": "feature", "label": "Feature"},
		{"key": "feature_accent", "label": "Feature border"},
		{"key": "feature_text", "label": "Feature text"},
		{"key": "stop_codon", "label": "Stop codon"}
	]},
	{"title": "Genome", "roles": [
		{"key": "genome", "label": "Genome"},
		{"key": "region_select_fill", "label": "Region select fill"},
		{"key": "region_select_outline", "label": "Region select outline"},
		{"key": "ambiguous_base", "label": "Ambiguous base"},
		{"key": "pileup_base_a", "label": "Base A"},
		{"key": "pileup_base_c", "label": "Base C"},
		{"key": "pileup_base_g", "label": "Base G"},
		{"key": "pileup_base_t", "label": "Base T"},
		{"key": "pileup_base_d", "label": "Base D"}
	]},
	{"title": "Map", "roles": [
		{"key": "map_contig", "label": "Map contig"},
		{"key": "map_contig_alt", "label": "Map contig alt"},
		{"key": "map_view_fill", "label": "Map view fill"},
		{"key": "map_view_outline", "label": "Map view outline"}
	]},
	{"title": "Reads", "roles": [
		{"key": "read", "label": "Read"},
		{"key": "insertion_marker", "label": "Insertion marker"},
		{"key": "snp", "label": "SNP in read"},
		{"key": "snp_text", "label": "SNP text"}
	]},
	{"title": "VCF", "roles": [
		{"key": "vcf_gt_ref_fill", "label": "VCF ref call"},
		{"key": "vcf_gt_ref_text", "label": "VCF ref call text"},
		{"key": "vcf_gt_het_fill", "label": "VCF het call"},
		{"key": "vcf_gt_het_text", "label": "VCF het call text"},
		{"key": "vcf_gt_hom_alt_fill", "label": "VCF hom call"},
		{"key": "vcf_gt_hom_alt_text", "label": "VCF hom call text"}
	]},
	{"title": "Comparison", "roles": [
		{"key": "comparison_same_strand", "label": "Match same strand"},
		{"key": "comparison_opp_strand", "label": "Reverse match"},
		{"key": "comparison_selected_fill", "label": "Selected match"},
		{"key": "comparison_match_line", "label": "Match line"},
		{"key": "comparison_snp", "label": "SNP line"}
	]}
]


const THEMES := {
	"Classic": {
		"bg": Color("ffffff"),
		"panel": Color("ffffff"),
		"panel_alt": Color("efefef"),
		"grid": Color("c8c8c8"),
		"border": Color8(115, 137, 189),
		"text": Color("000000"),
		"insertion_marker": Color("000000"),
		"scrollbar_outline": Color8(115, 137, 189),
		"text_muted": Color("7d7d7d"),
		"text_inverse": Color("ffffff"),
		"button_bg": Color("f2f2f2"),
		"button_hover": Color("e6e6e6"),
		"button_pressed": Color("dcdcdc"),
		"field_bg": Color("ffffff"),
		"field_border": Color8(115, 137, 189),
		"field_focus": Color("0000ff"),
		"accent": Color("0000ff"),
		"status_error": Color("ff0000"),
		"track_alt_bg": Color("f5f5f5"),
		"map_contig": Color8(192, 152, 107),
		"map_contig_alt": Color8(239, 181, 70),
		"map_view_fill": Color8(243, 178, 177),
		"map_view_outline": Color8(243, 178, 177),
		"region_select_fill": Color8(236, 103, 101),
		"region_select_outline": Color8(236, 103, 101),
		"genome": Color("000000"),
		"read": Color8(25, 7, 244),
		"gc_plot": Color("000000"),
		"depth_plot": Color("000000"),
		"depth_plot_series": [
			Color("000000"),
			Color("3f3f3f"),
			Color("6a6a6a"),
			Color("8f8f8f"),
			Color("b5b5b5"),
			Color("d0d0d0")
		],
		"vcf_gt_ref_fill": Color("000000"),
		"vcf_gt_ref_text": Color("ffffff"),
		"vcf_gt_het_fill": Color8(25, 7, 244),
		"vcf_gt_het_text": Color("000000"),
		"vcf_gt_hom_alt_fill": Color("ff0000"),
		"vcf_gt_hom_alt_text": Color("ffffff"),
		"pileup_logo_bases": {
			"A": Color("2b9348"),
			"C": Color("1d4ed8"),
			"G": Color("a16207"),
			"T": Color("b91c1c"),
			"D": Color("4a4a4a")
		},
		"ambiguous_base": Color("000000"),
		"snp": Color("ff0000"),
		"comparison_snp": Color("ff00ff"),
		"comparison_match_line": Color("000000"),
		"snp_text": Color("ffffff"),
		"feature": Color8(116, 250, 252),
		"feature_accent": Color8(36, 164, 166),
		"feature_text": Color("000000"),
		"comparison_same_strand": Color("ff0000"),
		"comparison_opp_strand": Color("0000ff"),
		"comparison_selected_fill": Color("ffff00")
	},
	"Monochrome Light": {
		"bg": Color("fcfcfc"),
		"panel": Color("ffffff"),
		"panel_alt": Color("f0f0f0"),
		"grid": Color("cfcfcf"),
		"border": Color("c8c8c8"),
		"text": Color("202020"),
		"insertion_marker": Color("202020"),
		"scrollbar_outline": Color("7a7a7a"),
		"text_muted": Color("6f6f6f"),
		"text_inverse": Color("ffffff"),
		"button_bg": Color("efefef"),
		"button_hover": Color("e2e2e2"),
		"button_pressed": Color("d6d6d6"),
		"field_bg": Color("ffffff"),
		"field_border": Color("bbbbbb"),
		"field_focus": Color("666666"),
		"accent": Color("555555"),
		"status_error": Color("444444"),
		"track_alt_bg": Color("f5f5f5"),
		"map_contig": Color("fafafa"),
		"map_contig_alt": Color("ececec"),
		"map_view_fill": Color("666666"),
		"map_view_outline": Color("303030"),
		"region_select_fill": Color("666666"),
		"region_select_outline": Color("303030"),
		"genome": Color("575757"),
		"read": Color("686868"),
		"gc_plot": Color("7e7e7e"),
		"depth_plot": Color("444444"),
		"depth_plot_series": [
			Color("444444"),
			Color("5c5c5c"),
			Color("747474"),
			Color("8c8c8c"),
			Color("a4a4a4"),
			Color("bcbcbc")
		],
		"vcf_gt_ref_fill": Color("202020"),
		"vcf_gt_ref_text": Color("ffffff"),
		"vcf_gt_het_fill": Color("686868"),
		"vcf_gt_het_text": Color("ffffff"),
		"vcf_gt_hom_alt_fill": Color("2f2f2f"),
		"vcf_gt_hom_alt_text": Color("ffffff"),
		"pileup_logo_bases": {
			"A": Color("4c4c4c"),
			"C": Color("666666"),
			"G": Color("808080"),
			"T": Color("9a9a9a"),
			"D": Color("2f2f2f")
		},
		"ambiguous_base": Color("202020"),
		"snp": Color("2f2f2f"),
		"comparison_snp": Color("2f2f2f"),
		"comparison_match_line": Color("202020"),
		"snp_text": Color("ffffff"),
		"feature": Color("d9d9d9"),
		"feature_accent": Color("8c8c8c"),
		"feature_text": Color("242424"),
		"comparison_same_strand": Color("555555"),
		"comparison_opp_strand": Color("8a8a8a"),
		"comparison_selected_fill": Color("8e8e8e")
	},
	"Light": {
		"bg": Color("ffffff"),
		"panel": Color("ffffff"),
		"panel_alt": Color("f5f5f5"),
		"grid": Color("d0d0d0"),
		"border": Color("d0d0d0"),
		"text": Color("111111"),
		"insertion_marker": Color("111111"),
		"scrollbar_outline": Color("5a5a5a"),
		"text_muted": Color("4a4a4a"),
		"text_inverse": Color("ffffff"),
		"button_bg": Color("efefef"),
		"button_hover": Color("e5e5e5"),
		"button_pressed": Color("dadada"),
		"field_bg": Color("ffffff"),
		"field_border": Color("c8c8c8"),
		"field_focus": Color("5b8def"),
		"accent": Color("3f5a7a"),
		"status_error": Color("8b0000"),
		"track_alt_bg": Color("efefef"),
		"map_contig": Color("ffffff"),
		"map_contig_alt": Color("efefef"),
		"map_view_fill": Color("3f5a7a"),
		"map_view_outline": Color("111111"),
		"region_select_fill": Color("3f5a7a"),
		"region_select_outline": Color("111111"),
		"genome": Color("3f5a7a"),
		"read": Color("0f8b8d"),
		"gc_plot": Color("2aa198"),
		"depth_plot": Color("345995"),
		"depth_plot_series": [
			Color("345995"),
			Color("2a9d8f"),
			Color("e76f51"),
			Color("6d597a"),
			Color("4f772d"),
			Color("b56576")
		],
		"vcf_gt_ref_fill": Color("111111"),
		"vcf_gt_ref_text": Color("ffffff"),
		"vcf_gt_het_fill": Color("0f8b8d"),
		"vcf_gt_het_text": Color("ffffff"),
		"vcf_gt_hom_alt_fill": Color("b11f47"),
		"vcf_gt_hom_alt_text": Color("ffffff"),
		"pileup_logo_bases": {
			"A": Color("2b9348"),
			"C": Color("1d4ed8"),
			"G": Color("a16207"),
			"T": Color("b91c1c"),
			"D": Color("4a5568")
		},
		"ambiguous_base": Color("111111"),
		"snp": Color("b11f47"),
		"comparison_snp": Color("7a00ff"),
		"comparison_match_line": Color("111111"),
		"snp_text": Color("ffffff"),
		"feature": Color("dce8f7"),
		"feature_accent": Color("7f9cc3"),
		"feature_text": Color("1e3557"),
		"comparison_same_strand": Color("cf5c36"),
		"comparison_opp_strand": Color("3f5a7a"),
		"comparison_selected_fill": Color("ffd84d")
	},
	"Forest": {
		"bg": Color("eaf4e5"),
		"panel": Color("f6fff0"),
		"panel_alt": Color("eef8e9"),
		"grid": Color("b8d1ad"),
		"border": Color("b8d1ad"),
		"text": Color("20301f"),
		"insertion_marker": Color("20301f"),
		"scrollbar_outline": Color("566653"),
		"text_muted": Color("41513f"),
		"text_inverse": Color("ffffff"),
		"button_bg": Color("dcebd5"),
		"button_hover": Color("d3e4ca"),
		"button_pressed": Color("c8dbbe"),
		"field_bg": Color("f8fff4"),
		"field_border": Color("abc7a0"),
		"field_focus": Color("588157"),
		"accent": Color("386641"),
		"status_error": Color("8b1f1f"),
		"track_alt_bg": Color("dfe8d8"),
		"map_contig": Color("eaf4e5"),
		"map_contig_alt": Color("dfe8d8"),
		"map_view_fill": Color("386641"),
		"map_view_outline": Color("20301f"),
		"region_select_fill": Color("386641"),
		"region_select_outline": Color("20301f"),
		"genome": Color("386641"),
		"read": Color("6a994e"),
		"gc_plot": Color("2a9d8f"),
		"depth_plot": Color("386641"),
		"depth_plot_series": [
			Color("386641"),
			Color("2a9d8f"),
			Color("bc4749"),
			Color("588157"),
			Color("6a994e"),
			Color("7f5539")
		],
		"vcf_gt_ref_fill": Color("20301f"),
		"vcf_gt_ref_text": Color("f6fff0"),
		"vcf_gt_het_fill": Color("6a994e"),
		"vcf_gt_het_text": Color("20301f"),
		"vcf_gt_hom_alt_fill": Color("7a143a"),
		"vcf_gt_hom_alt_text": Color("ffffff"),
		"pileup_logo_bases": {
			"A": Color("4f8a3f"),
			"C": Color("2f6f99"),
			"G": Color("8f6a1b"),
			"T": Color("9a3d32"),
			"D": Color("4f5f4d")
		},
		"ambiguous_base": Color("20301f"),
		"snp": Color("7a143a"),
		"comparison_snp": Color("7b2cbf"),
		"comparison_match_line": Color("20301f"),
		"snp_text": Color("ffffff"),
		"feature": Color("c8dfc0"),
		"feature_accent": Color("6e9662"),
		"feature_text": Color("1f3a24"),
		"comparison_same_strand": Color("b15a3c"),
		"comparison_opp_strand": Color("4f7d64"),
		"comparison_selected_fill": Color("f4d35e")
	},
	"Slate": {
		"bg": Color("e8edf2"),
		"panel": Color("f6f9fc"),
		"panel_alt": Color("edf2f6"),
		"grid": Color("b6c3cf"),
		"border": Color("b6c3cf"),
		"text": Color("1f2933"),
		"insertion_marker": Color("1f2933"),
		"scrollbar_outline": Color("5f6d79"),
		"text_muted": Color("4d5a67"),
		"text_inverse": Color("ffffff"),
		"button_bg": Color("dde6ee"),
		"button_hover": Color("d4dee8"),
		"button_pressed": Color("c9d5e2"),
		"field_bg": Color("f9fbfd"),
		"field_border": Color("a9bac9"),
		"field_focus": Color("2d7dd2"),
		"accent": Color("345995"),
		"status_error": Color("8b1f1f"),
		"track_alt_bg": Color("dde3ea"),
		"map_contig": Color("e8edf2"),
		"map_contig_alt": Color("dde3ea"),
		"map_view_fill": Color("345995"),
		"map_view_outline": Color("1f2933"),
		"region_select_fill": Color("345995"),
		"region_select_outline": Color("1f2933"),
		"genome": Color("345995"),
		"read": Color("2d7dd2"),
		"gc_plot": Color("2d7dd2"),
		"depth_plot": Color("345995"),
		"depth_plot_series": [
			Color("345995"),
			Color("2d7dd2"),
			Color("f4a259"),
			Color("5c6784"),
			Color("7d8597"),
			Color("8d99ae")
		],
		"vcf_gt_ref_fill": Color("1f2933"),
		"vcf_gt_ref_text": Color("f6f9fc"),
		"vcf_gt_het_fill": Color("2d7dd2"),
		"vcf_gt_het_text": Color("ffffff"),
		"vcf_gt_hom_alt_fill": Color("d7263d"),
		"vcf_gt_hom_alt_text": Color("ffffff"),
		"pileup_logo_bases": {
			"A": Color("2b9348"),
			"C": Color("1d4ed8"),
			"G": Color("a16207"),
			"T": Color("b91c1c"),
			"D": Color("4b5563")
		},
		"ambiguous_base": Color("1f2933"),
		"snp": Color("d7263d"),
		"comparison_snp": Color("7a00ff"),
		"comparison_match_line": Color("1f2933"),
		"snp_text": Color("ffffff"),
		"feature": Color("c6d6ec"),
		"feature_accent": Color("6f93c7"),
		"feature_text": Color("1f3654"),
		"comparison_same_strand": Color("cb5a4a"),
		"comparison_opp_strand": Color("4d78b0"),
		"comparison_selected_fill": Color("ffd84d")
	},
	"Dark": {
		"bg": Color("1a1d22"),
		"panel": Color("21262d"),
		"panel_alt": Color("2a3038"),
		"grid": Color("3a434f"),
		"border": Color("3a434f"),
		"text": Color("e6edf3"),
		"insertion_marker": Color("e6edf3"),
		"scrollbar_outline": Color("9fb0bc"),
		"text_muted": Color("aab6c2"),
		"text_inverse": Color("111111"),
		"button_bg": Color("2f3742"),
		"button_hover": Color("374150"),
		"button_pressed": Color("2a3240"),
		"field_bg": Color("1f252d"),
		"field_border": Color("455061"),
		"field_focus": Color("58a6ff"),
		"accent": Color("58a6ff"),
		"status_error": Color("ff7b72"),
		"track_alt_bg": Color("2c333d"),
		"map_contig": Color("1a1d22"),
		"map_contig_alt": Color("2c333d"),
		"map_view_fill": Color("7aa2f7"),
		"map_view_outline": Color("e6edf3"),
		"region_select_fill": Color("7aa2f7"),
		"region_select_outline": Color("e6edf3"),
		"genome": Color("7aa2f7"),
		"read": Color("4fb6c2"),
		"gc_plot": Color("58a6ff"),
		"depth_plot": Color("7aa2f7"),
		"depth_plot_series": [
			Color("7aa2f7"),
			Color("58a6ff"),
			Color("4fb6c2"),
			Color("b392f0"),
			Color("ffb86b"),
			Color("8ec07c")
		],
		"vcf_gt_ref_fill": Color("e6edf3"),
		"vcf_gt_ref_text": Color("21262d"),
		"vcf_gt_het_fill": Color("4fb6c2"),
		"vcf_gt_het_text": Color("111111"),
		"vcf_gt_hom_alt_fill": Color("ff7b72"),
		"vcf_gt_hom_alt_text": Color("111111"),
		"pileup_logo_bases": {
			"A": Color("5ac26b"),
			"C": Color("73b7ff"),
			"G": Color("d3a34a"),
			"T": Color("ff7b72"),
			"D": Color("aab6c2")
		},
		"ambiguous_base": Color("e6edf3"),
		"snp": Color("ff7b72"),
		"comparison_snp": Color("ffd166"),
		"comparison_match_line": Color("e6edf3"),
		"snp_text": Color("111111"),
		"feature": Color("2e466e"),
		"feature_accent": Color("6e8dbb"),
		"feature_text": Color("eaf2ff"),
		"comparison_same_strand": Color("d17a6b"),
		"comparison_opp_strand": Color("7aa2f7"),
		"comparison_selected_fill": Color("ffd166")
	},
	"Monochrome Dark": {
		"bg": Color("171717"),
		"panel": Color("202020"),
		"panel_alt": Color("2b2b2b"),
		"grid": Color("444444"),
		"border": Color("4b4b4b"),
		"text": Color("e6e6e6"),
		"insertion_marker": Color("e6e6e6"),
		"scrollbar_outline": Color("9f9f9f"),
		"text_muted": Color("acacac"),
		"text_inverse": Color("111111"),
		"button_bg": Color("303030"),
		"button_hover": Color("3a3a3a"),
		"button_pressed": Color("464646"),
		"field_bg": Color("232323"),
		"field_border": Color("5a5a5a"),
		"field_focus": Color("9a9a9a"),
		"accent": Color("b5b5b5"),
		"status_error": Color("c7c7c7"),
		"track_alt_bg": Color("303030"),
		"map_contig": Color("1a1a1a"),
		"map_contig_alt": Color("2c2c2c"),
		"map_view_fill": Color("9d9d9d"),
		"map_view_outline": Color("e0e0e0"),
		"region_select_fill": Color("9d9d9d"),
		"region_select_outline": Color("e0e0e0"),
		"genome": Color("b0b0b0"),
		"read": Color("9a9a9a"),
		"gc_plot": Color("7f7f7f"),
		"depth_plot": Color("c8c8c8"),
		"depth_plot_series": [
			Color("c8c8c8"),
			Color("b0b0b0"),
			Color("989898"),
			Color("808080"),
			Color("686868"),
			Color("505050")
		],
		"vcf_gt_ref_fill": Color("e6e6e6"),
		"vcf_gt_ref_text": Color("202020"),
		"vcf_gt_het_fill": Color("9a9a9a"),
		"vcf_gt_het_text": Color("111111"),
		"vcf_gt_hom_alt_fill": Color("f0f0f0"),
		"vcf_gt_hom_alt_text": Color("111111"),
		"pileup_logo_bases": {
			"A": Color("d0d0d0"),
			"C": Color("b0b0b0"),
			"G": Color("909090"),
			"T": Color("707070"),
			"D": Color("f0f0f0")
		},
		"ambiguous_base": Color("e6e6e6"),
		"snp": Color("f0f0f0"),
		"comparison_snp": Color("f0f0f0"),
		"comparison_match_line": Color("e6e6e6"),
		"snp_text": Color("111111"),
		"feature": Color("505050"),
		"feature_accent": Color("9a9a9a"),
		"feature_text": Color("f0f0f0"),
		"comparison_same_strand": Color("d0d0d0"),
		"comparison_opp_strand": Color("7a7a7a"),
		"comparison_selected_fill": Color("bcbcbc")
	},
	"Solarized Light": {
		"bg": Color("fdf6e3"),
		"panel": Color("fdf6e3"),
		"panel_alt": Color("eee8d5"),
		"grid": Color("93a1a1"),
		"border": Color("93a1a1"),
		"text": Color("657b83"),
		"insertion_marker": Color("657b83"),
		"scrollbar_outline": Color("8f9ea2"),
		"text_muted": Color("93a1a1"),
		"text_inverse": Color("fdf6e3"),
		"button_bg": Color("eee8d5"),
		"button_hover": Color("e4dcc8"),
		"button_pressed": Color("d9d1bc"),
		"field_bg": Color("fdf6e3"),
		"field_border": Color("93a1a1"),
		"field_focus": Color("268bd2"),
		"accent": Color("268bd2"),
		"status_error": Color("dc322f"),
		"track_alt_bg": Color("eee8d5"),
		"map_contig": Color("fdf6e3"),
		"map_contig_alt": Color("eee8d5"),
		"map_view_fill": Color("268bd2"),
		"map_view_outline": Color("657b83"),
		"region_select_fill": Color("268bd2"),
		"region_select_outline": Color("657b83"),
		"genome": Color("268bd2"),
		"read": Color("2aa198"),
		"gc_plot": Color("2aa198"),
		"depth_plot": Color("268bd2"),
		"depth_plot_series": [
			Color("268bd2"),
			Color("2aa198"),
			Color("cb4b16"),
			Color("6c71c4"),
			Color("859900"),
			Color("d33682")
		],
		"vcf_gt_ref_fill": Color("657b83"),
		"vcf_gt_ref_text": Color("fdf6e3"),
		"vcf_gt_het_fill": Color("2aa198"),
		"vcf_gt_het_text": Color("073642"),
		"vcf_gt_hom_alt_fill": Color("d33682"),
		"vcf_gt_hom_alt_text": Color("fdf6e3"),
		"pileup_logo_bases": {
			"A": Color("859900"),
			"C": Color("268bd2"),
			"G": Color("b58900"),
			"T": Color("dc322f"),
			"D": Color("657b83")
		},
		"ambiguous_base": Color("657b83"),
		"snp": Color("d33682"),
		"comparison_snp": Color("6c71c4"),
		"comparison_match_line": Color("657b83"),
		"snp_text": Color("fdf6e3"),
		"feature": Color("dcecf6"),
		"feature_accent": Color("7eb6d6"),
		"feature_text": Color("1f5d85"),
		"comparison_same_strand": Color("cb6b47"),
		"comparison_opp_strand": Color("268bd2"),
		"comparison_selected_fill": Color("b58900")
	},
	"Solarized Dark": {
		"bg": Color("002b36"),
		"panel": Color("002b36"),
		"panel_alt": Color("073642"),
		"grid": Color("586e75"),
		"border": Color("586e75"),
		"text": Color("839496"),
		"insertion_marker": Color("cccccc"),
		"scrollbar_outline": Color("839193"),
		"text_muted": Color("657b83"),
		"text_inverse": Color("002b36"),
		"button_bg": Color("073642"),
		"button_hover": Color("0d414d"),
		"button_pressed": Color("114853"),
		"field_bg": Color("073642"),
		"field_border": Color("586e75"),
		"field_focus": Color("268bd2"),
		"accent": Color("268bd2"),
		"status_error": Color("dc322f"),
		"track_alt_bg": Color("073642"),
		"map_contig": Color("002b36"),
		"map_contig_alt": Color("073642"),
		"map_view_fill": Color("268bd2"),
		"map_view_outline": Color("839496"),
		"region_select_fill": Color("268bd2"),
		"region_select_outline": Color("839496"),
		"genome": Color("268bd2"),
		"read": Color("2aa198"),
		"gc_plot": Color("2aa198"),
		"depth_plot": Color("268bd2"),
		"depth_plot_series": [
			Color("268bd2"),
			Color("2aa198"),
			Color("cb4b16"),
			Color("6c71c4"),
			Color("859900"),
			Color("d33682")
		],
		"vcf_gt_ref_fill": Color("839496"),
		"vcf_gt_ref_text": Color("002b36"),
		"vcf_gt_het_fill": Color("2aa198"),
		"vcf_gt_het_text": Color("002b36"),
		"vcf_gt_hom_alt_fill": Color("d33682"),
		"vcf_gt_hom_alt_text": Color("fdf6e3"),
		"pileup_logo_bases": {
			"A": Color("859900"),
			"C": Color("268bd2"),
			"G": Color("b58900"),
			"T": Color("dc322f"),
			"D": Color("839496")
		},
		"ambiguous_base": Color("839496"),
		"snp": Color("d33682"),
		"comparison_snp": Color("b58900"),
		"comparison_match_line": Color("839496"),
		"snp_text": Color("fdf6e3"),
		"feature": Color("12455f"),
		"feature_accent": Color("5190ad"),
		"feature_text": Color("dceef8"),
		"comparison_same_strand": Color("c56a49"),
		"comparison_opp_strand": Color("268bd2"),
		"comparison_selected_fill": Color("b58900")
	}
}

const THEME_ORDER := [
	"Slate",
	"Light",
	"Dark",
	"Solarized Light",
	"Solarized Dark",
	"Monochrome Light",
	"Monochrome Dark",
	"Forest",
	"Classic"
]

var _user_themes := {}
var _user_theme_order := PackedStringArray()


func _init() -> void:
	_load_user_themes()

func theme_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in THEME_ORDER:
		if THEMES.has(key):
			names.append(key)
	for key in THEMES.keys():
		var theme_name := str(key)
		if names.has(theme_name):
			continue
		names.append(theme_name)
	for theme_name in _user_theme_order:
		if names.has(theme_name):
			continue
		names.append(theme_name)
	for key in _user_themes.keys():
		var theme_name := str(key)
		if names.has(theme_name):
			continue
		names.append(theme_name)
	return names

func has_theme(theme_name: String) -> bool:
	var resolved := _resolve_theme_name(theme_name)
	return THEMES.has(resolved) or _user_themes.has(resolved)

func is_builtin_theme(theme_name: String) -> bool:
	return THEMES.has(_resolve_theme_name(theme_name))

func is_user_theme(theme_name: String) -> bool:
	return _user_themes.has(_resolve_theme_name(theme_name))

func user_theme_names() -> PackedStringArray:
	return _user_theme_order.duplicate()

func make_unique_user_theme_name(base_name: String) -> String:
	var trimmed := base_name.strip_edges()
	if trimmed.is_empty():
		trimmed = "Custom Theme"
	var candidate := trimmed
	var suffix := 2
	while has_theme(candidate):
		candidate = "%s %d" % [trimmed, suffix]
		suffix += 1
	return candidate

func create_user_theme_from(source_theme_name: String, requested_name: String = "") -> String:
	var source_name := source_theme_name if has_theme(source_theme_name) else "Slate"
	var base_name := requested_name.strip_edges()
	if base_name.is_empty():
		base_name = "%s Copy" % source_name
	var unique_name := make_unique_user_theme_name(base_name)
	upsert_user_theme(unique_name, palette(source_name))
	return unique_name

func upsert_user_theme(theme_name: String, theme_palette: Dictionary) -> void:
	var name := theme_name.strip_edges()
	if name.is_empty():
		return
	var normalized := _normalize_palette(theme_palette)
	_user_themes[name] = normalized
	if not _user_theme_order.has(name):
		_user_theme_order.append(name)
	_save_user_themes()

func rename_user_theme(old_name: String, new_name: String) -> String:
	var old_trimmed := old_name.strip_edges()
	if not _user_themes.has(old_trimmed):
		return ""
	var requested := new_name.strip_edges()
	if requested.is_empty():
		requested = old_trimmed
	var unique_name := requested
	if unique_name != old_trimmed:
		unique_name = make_unique_user_theme_name(requested)
	var existing := (_user_themes[old_trimmed] as Dictionary).duplicate(true)
	_user_themes.erase(old_trimmed)
	var idx := _user_theme_order.find(old_trimmed)
	if idx >= 0:
		_user_theme_order.remove_at(idx)
	_user_themes[unique_name] = existing
	_user_theme_order.append(unique_name)
	_save_user_themes()
	return unique_name

func delete_user_theme(theme_name: String) -> void:
	var trimmed := theme_name.strip_edges()
	if not _user_themes.has(trimmed):
		return
	_user_themes.erase(trimmed)
	var idx := _user_theme_order.find(trimmed)
	if idx >= 0:
		_user_theme_order.remove_at(idx)
	_save_user_themes()

func palette(theme_name: String) -> Dictionary:
	var resolved := _resolve_theme_name(theme_name)
	var raw: Dictionary
	if THEMES.has(resolved):
		raw = (THEMES[resolved] as Dictionary).duplicate(true)
	elif _user_themes.has(resolved):
		raw = (_user_themes[resolved] as Dictionary).duplicate(true)
	else:
		raw = (THEMES["Slate"] as Dictionary).duplicate(true)
	return _normalize_palette(raw)

func make_theme_from_palette(theme_palette: Dictionary, font_size: int, font_name: String = "Noto Sans") -> Theme:
	var p := _normalize_palette(theme_palette)
	var t := Theme.new()
	var fs := maxi(8, font_size)
	t.default_font_size = fs
	t.default_font = ui_font(font_name)

	_set_font_colors(t, p)
	_set_panel_styles(t, p)
	_set_button_styles(t, p)
	_set_field_styles(t, p)
	_set_item_list_styles(t, p)
	_set_popup_menu_styles(t, p)
	_set_checkbox_styles(t, p)
	_set_check_button_styles(t, p)
	_set_slider_styles(t, p)
	_set_option_button_icons(t, p)
	return t

func genome_palette_from_palette(theme_palette: Dictionary) -> Dictionary:
	var p := _normalize_palette(theme_palette)
	return {
		"bg": p["bg"],
		"panel": p["panel"],
		"border": p["border"],
		"grid": p["grid"],
		"text": p["text"],
		"track_alt_bg": p["track_alt_bg"],
		"map_contig": p["map_contig"],
		"map_contig_alt": p["map_contig_alt"],
		"map_view_fill": p["map_view_fill"],
		"map_view_outline": p["map_view_outline"],
		"region_select_fill": p["region_select_fill"],
		"region_select_outline": p["region_select_outline"],
		"genome": p["genome"],
		"read": p["read"],
		"insertion_marker": p.get("insertion_marker", p["text"]),
		"gc_plot": p["gc_plot"],
		"depth_plot": p["depth_plot"],
		"depth_plot_series": p.get("depth_plot_series", [p["depth_plot"]]),
		"vcf_gt_ref_fill": p.get("vcf_gt_ref_fill", p["text"]),
		"vcf_gt_ref_text": p.get("vcf_gt_ref_text", p["panel"]),
		"vcf_gt_het_fill": p.get("vcf_gt_het_fill", p["read"]),
		"vcf_gt_het_text": p.get("vcf_gt_het_text", p["text"]),
		"vcf_gt_hom_alt_fill": p.get("vcf_gt_hom_alt_fill", p["snp"]),
		"vcf_gt_hom_alt_text": p.get("vcf_gt_hom_alt_text", p["snp_text"]),
		"pileup_logo_bases": p.get("pileup_logo_bases", {}),
		"ambiguous_base": p.get("ambiguous_base", p["text"]),
		"snp": p["snp"],
		"snp_text": p["snp_text"],
		"feature": p["feature"],
		"feature_accent": p["feature_accent"],
		"feature_text": p["feature_text"],
		"stop_codon": p.get("stop_codon", p["text"])
	}


func comparison_theme_colors_from_palette(theme_palette: Dictionary) -> Dictionary:
	var p := _normalize_palette(theme_palette)
	return {
		"text": p["text"],
		"text_muted": p["text_muted"],
		"border": p["border"],
		"panel_alt": p["panel_alt"],
		"genome": p["genome"],
		"map_contig": p["map_contig"],
		"map_contig_alt": p["map_contig_alt"],
		"map_view_fill": p["map_view_fill"],
		"map_view_outline": p["map_view_outline"],
		"feature": p["feature"],
		"feature_text": p["feature_text"],
		"same_strand": p["comparison_same_strand"],
		"opp_strand": p["comparison_opp_strand"],
		"selected_fill": p["comparison_selected_fill"],
		"selection_outline": p["text"],
		"snp": p["comparison_snp"],
		"region_select_fill": p["region_select_fill"],
		"region_select_outline": p["region_select_outline"]
	}

func palette_role_keys() -> PackedStringArray:
	return PackedStringArray(LIVE_PALETTE_KEYS)


func editor_role_groups() -> Array:
	return EDITOR_ROLE_GROUPS.duplicate(true)

func _normalize_palette(raw_palette: Dictionary) -> Dictionary:
	var p := raw_palette.duplicate(true)
	if not p.has("stop_codon"):
		p["stop_codon"] = p.get("text", Color.BLACK)
	if not p.has("track_alt_bg"):
		p["track_alt_bg"] = p.get("panel_alt", Color("efefef"))
	if not p.has("insertion_marker"):
		p["insertion_marker"] = p.get("text", Color.BLACK)
	if not p.has("vcf_gt_ref_fill"):
		p["vcf_gt_ref_fill"] = p.get("text", Color.BLACK)
	if not p.has("vcf_gt_ref_text"):
		p["vcf_gt_ref_text"] = p.get("panel", Color.WHITE)
	if not p.has("vcf_gt_het_fill"):
		p["vcf_gt_het_fill"] = p.get("read", Color("0f8b8d"))
	if not p.has("vcf_gt_het_text"):
		p["vcf_gt_het_text"] = p.get("text", Color.BLACK)
	if not p.has("vcf_gt_hom_alt_fill"):
		p["vcf_gt_hom_alt_fill"] = p.get("snp", Color("d7263d"))
	if not p.has("vcf_gt_hom_alt_text"):
		p["vcf_gt_hom_alt_text"] = p.get("snp_text", p.get("text_inverse", Color.WHITE))
	if not p.has("pileup_logo_bases"):
		p["pileup_logo_bases"] = {
			"A": Color("2b9348"),
			"C": Color("1d4ed8"),
			"G": Color("a16207"),
			"T": Color("b91c1c"),
			"D": p.get("read", Color("6b7280"))
		}
	if not p.has("ambiguous_base"):
		p["ambiguous_base"] = p.get("text", Color.BLACK)
	if not p.has("comparison_match_line"):
		p["comparison_match_line"] = p.get("text", Color.BLACK)
	return p

func genome_palette(theme_name: String) -> Dictionary:
	return genome_palette_from_palette(palette(theme_name))

func depth_plot_series(theme_name: String) -> Array:
	var p := palette(theme_name)
	var colors_any: Variant = p.get("depth_plot_series", [p["depth_plot"]])
	var colors: Array = []
	for color_any in colors_any:
		if color_any is Color:
			colors.append(color_any)
	return colors

func export_theme_json(theme_name: String) -> Dictionary:
	var resolved := _resolve_theme_name(theme_name)
	return {
		"format": "seqhiker-theme",
		"version": 1,
		"name": resolved,
		"palette": _theme_value_to_json(palette(resolved))
	}

func export_theme_json_string(theme_name: String) -> String:
	return JSON.stringify(export_theme_json(theme_name), "\t")

func export_theme_json_file(theme_name: String, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(export_theme_json_string(theme_name))
	return true

func import_user_theme_from_json_text(json_text: String, fallback_name: String = "") -> String:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return ""
	var data: Dictionary = parsed
	if str(data.get("format", "")) != "seqhiker-theme":
		return ""
	if int(data.get("version", 0)) < 1:
		return ""
	var palette_any: Variant = data.get("palette", null)
	if not (palette_any is Dictionary):
		return ""
	var imported_palette: Dictionary = _theme_value_from_json(palette_any)
	if not (imported_palette is Dictionary):
		return ""
	var raw_name := str(data.get("name", fallback_name)).strip_edges()
	if raw_name.is_empty():
		raw_name = fallback_name.strip_edges()
	if raw_name.is_empty():
		raw_name = "Imported Theme"
	var unique_name := make_unique_user_theme_name(raw_name)
	upsert_user_theme(unique_name, imported_palette)
	return unique_name

func import_user_theme_from_json_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var text := FileAccess.get_file_as_string(path)
	return import_user_theme_from_json_text(text, path.get_file().get_basename())

func ui_font(font_name: String) -> Font:
	match font_name:
		"Anonymous Pro":
			return ANONYMOUS_PRO_FONT
		"Courier New":
			return COURIER_NEW_FONT
		"DejaVu Sans":
			return _load_dejavu_sans_font()
		_:
			return ThemeDB.fallback_font


func _load_dejavu_sans_font() -> Font:
	if _dejavu_sans_font != null:
		return _dejavu_sans_font
	var font := FontFile.new()
	var err := font.load_dynamic_font(DEJAVU_SANS_FONT_PATH)
	if err != OK:
		return ThemeDB.fallback_font
	_dejavu_sans_font = font
	return _dejavu_sans_font

func _theme_value_to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_COLOR:
			return "#" + (value as Color).to_html(true)
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			var dict: Dictionary = value
			for key in dict.keys():
				out[str(key)] = _theme_value_to_json(dict[key])
			return out
		TYPE_ARRAY:
			var out_arr: Array = []
			for item in value:
				out_arr.append(_theme_value_to_json(item))
			return out_arr
		_:
			return value

func _theme_value_from_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING:
			var text := str(value).strip_edges()
			if _is_json_color_string(text):
				return Color.from_string(text if text.begins_with("#") else "#%s" % text, Color())
			return text
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			var dict: Dictionary = value
			for key in dict.keys():
				out[str(key)] = _theme_value_from_json(dict[key])
			return out
		TYPE_ARRAY:
			var out_arr: Array = []
			for item in value:
				out_arr.append(_theme_value_from_json(item))
			return out_arr
		_:
			return value

func _is_json_color_string(text: String) -> bool:
	var s := text.strip_edges()
	if s.begins_with("#"):
		s = s.substr(1)
	if s.length() != 6 and s.length() != 8:
		return false
	for ch in s:
		var c := str(ch)
		var lc := c.to_lower()
		if not (lc >= "0" and lc <= "9") and not (lc >= "a" and lc <= "f"):
			return false
	return true


func make_theme(theme_name: String, font_size: int, font_name: String = "Noto Sans") -> Theme:
	return make_theme_from_palette(palette(theme_name), font_size, font_name)

func _set_font_colors(theme: Theme, p: Dictionary) -> void:
	var text: Color = p["text"]
	var text_muted: Color = p["text_muted"]
	theme.set_color("font_color", "Label", text)
	theme.set_color("font_color", "RichTextLabel", text)
	theme.set_color("default_color", "RichTextLabel", text)
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", text)
	theme.set_color("font_pressed_color", "Button", text)
	theme.set_color("font_focus_color", "Button", text)
	theme.set_color("font_disabled_color", "Button", text_muted)
	theme.set_color("font_color", "CheckBox", text)
	theme.set_color("font_hover_color", "CheckBox", text)
	theme.set_color("font_pressed_color", "CheckBox", text)
	theme.set_color("font_hover_pressed_color", "CheckBox", text)
	theme.set_color("font_focus_color", "CheckBox", text)
	theme.set_color("font_disabled_color", "CheckBox", text_muted)
	theme.set_color("font_color", "CheckButton", text)
	theme.set_color("font_hover_color", "CheckButton", text)
	theme.set_color("font_pressed_color", "CheckButton", text)
	theme.set_color("font_hover_pressed_color", "CheckButton", text)
	theme.set_color("font_focus_color", "CheckButton", text)
	theme.set_color("font_disabled_color", "CheckButton", text_muted)
	theme.set_color("font_color", "LineEdit", text)
	theme.set_color("caret_color", "LineEdit", text)
	theme.set_color("selection_color", "LineEdit", text)
	theme.set_color("font_color", "OptionButton", text)
	theme.set_color("font_color", "ItemList", text)
	theme.set_color("font_color", "PopupMenu", text)
	theme.set_color("font_disabled_color", "PopupMenu", text_muted)
	theme.set_color("font_hover_color", "PopupMenu", text)
	theme.set_color("font_separator_color", "PopupMenu", text_muted)
	theme.set_color("font_accelerator_color", "PopupMenu", text_muted)

func _set_panel_styles(theme: Theme, p: Dictionary) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = p["panel"]
	panel.border_color = p["border"]
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var bg_panel := StyleBoxFlat.new()
	bg_panel.bg_color = p["bg"]
	bg_panel.border_color = p["border"]
	bg_panel.set_border_width_all(1)
	theme.set_stylebox("panel", "Window", bg_panel)

func _set_button_styles(theme: Theme, p: Dictionary) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = p["button_bg"]
	normal.border_color = p["border"]
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("normal", "OptionButton", normal)

	var hover := normal.duplicate()
	hover.bg_color = p["button_hover"]
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("hover", "OptionButton", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = p["button_pressed"]
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("pressed", "OptionButton", pressed)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("focus", "OptionButton", focus)

func _set_field_styles(theme: Theme, p: Dictionary) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = p["field_bg"]
	normal.border_color = p["field_border"]
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("read_only", "LineEdit", normal)

	var focus := normal.duplicate()
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "LineEdit", focus)

func _set_item_list_styles(theme: Theme, p: Dictionary) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = p["button_bg"]
	panel.border_color = p["border"]
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	theme.set_stylebox("panel", "ItemList", panel)

	var focus := panel.duplicate()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "ItemList", focus)

	var selected_bg: Color = p["button_pressed"]
	var selected_border: Color = p["border"]
	var cursor := StyleBoxFlat.new()
	cursor.bg_color = selected_bg
	cursor.border_color = selected_border
	cursor.set_border_width_all(1)
	cursor.set_corner_radius_all(4)
	theme.set_stylebox("cursor", "ItemList", cursor)
	theme.set_stylebox("cursor_unfocused", "ItemList", cursor.duplicate())

	theme.set_color("font_selected_color", "ItemList", p["text"])
	theme.set_color("font_hovered_color", "ItemList", p["text"])
	theme.set_color("font_hovered_selected_color", "ItemList", p["text"])
	theme.set_color("font_disabled_color", "ItemList", p["text_muted"])
	theme.set_color("font_outline_color", "ItemList", Color(0, 0, 0, 0))
	theme.set_color("selection_fill", "ItemList", selected_bg)
	theme.set_color("selection_rect", "ItemList", selected_border)

func _set_popup_menu_styles(theme: Theme, p: Dictionary) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = p["field_bg"]
	panel.border_color = p["field_border"]
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	theme.set_stylebox("panel", "PopupMenu", panel)

	var hover := StyleBoxFlat.new()
	hover.bg_color = p["button_hover"]
	hover.border_color = p["button_hover"]
	hover.set_border_width_all(0)
	hover.set_corner_radius_all(4)
	theme.set_stylebox("hover", "PopupMenu", hover)

func _set_option_button_icons(theme: Theme, p: Dictionary) -> void:
	var arrow := _make_arrow_icon(10, 7, p["text"])
	theme.set_icon("arrow", "OptionButton", arrow)
	theme.set_constant("arrow_margin", "OptionButton", 8)
	theme.set_color("modulate_arrow", "OptionButton", p["text"])

func _set_checkbox_styles(theme: Theme, p: Dictionary) -> void:
	var unchecked := _make_checkbox_texture(16, p["field_bg"], p["field_border"])
	var checked := _make_check_texture(16, p["accent"], p["text_inverse"], p["accent"])
	theme.set_icon("unchecked", "CheckBox", unchecked)
	theme.set_icon("checked", "CheckBox", checked)
	theme.set_icon("unchecked_disabled", "CheckBox", unchecked)
	theme.set_icon("checked_disabled", "CheckBox", checked)
	theme.set_constant("h_separation", "CheckBox", 6)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 2
	normal.content_margin_right = 2
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	theme.set_stylebox("normal", "CheckBox", normal)

	var hover := normal.duplicate()
	hover.bg_color = (p["button_hover"] as Color)
	hover.bg_color.a *= 0.35
	theme.set_stylebox("hover", "CheckBox", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = (p["button_pressed"] as Color)
	pressed.bg_color.a *= 0.45
	theme.set_stylebox("pressed", "CheckBox", pressed)

	var focus := normal.duplicate()
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(1)
	theme.set_stylebox("focus", "CheckBox", focus)

func _set_check_button_styles(theme: Theme, p: Dictionary) -> void:
	var toggle_w := 40
	var toggle_h := 22
	var off_icon := _make_toggle_icon(toggle_w, toggle_h, p["button_hover"], p["field_border"], p["button_bg"], false)
	var on_icon := _make_toggle_icon(toggle_w, toggle_h, p["button_hover"], p["field_border"], p["accent"], true)
	theme.set_icon("off", "CheckButton", off_icon)
	theme.set_icon("off_disabled", "CheckButton", off_icon)
	theme.set_icon("on", "CheckButton", on_icon)
	theme.set_icon("on_disabled", "CheckButton", on_icon)
	theme.set_icon("unchecked", "CheckButton", off_icon)
	theme.set_icon("unchecked_disabled", "CheckButton", off_icon)
	theme.set_icon("checked", "CheckButton", on_icon)
	theme.set_icon("checked_disabled", "CheckButton", on_icon)
	theme.set_constant("h_separation", "CheckButton", 8)
	theme.set_constant("icon_max_width", "CheckButton", toggle_w)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 2
	normal.content_margin_right = 2
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	theme.set_stylebox("normal", "CheckButton", normal)

	var hover := normal.duplicate()
	theme.set_stylebox("hover", "CheckButton", hover)

	var pressed := normal.duplicate()
	theme.set_stylebox("pressed", "CheckButton", pressed)
	theme.set_stylebox("hover_pressed", "CheckButton", pressed.duplicate())

	var disabled := normal.duplicate()
	theme.set_stylebox("disabled", "CheckButton", disabled)
	theme.set_stylebox("disabled_mirrored", "CheckButton", disabled.duplicate())

	var focus := normal.duplicate()
	theme.set_stylebox("focus", "CheckButton", focus)

func _set_slider_styles(theme: Theme, p: Dictionary) -> void:
	var grabber_size := 18
	var grabber := _make_pill_icon(grabber_size, grabber_size, p["accent"])
	theme.set_icon("grabber", "Slider", grabber)
	theme.set_icon("grabber_highlight", "Slider", _make_pill_icon(grabber_size, grabber_size, p["field_focus"]))
	theme.set_icon("grabber_disabled", "Slider", grabber)

	var track := StyleBoxFlat.new()
	track.bg_color = p["button_hover"]
	track.border_color = p["button_hover"]
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", track)
	theme.set_stylebox("grabber_area_highlight", "HSlider", track)
	theme.set_stylebox("slider", "VSlider", track)
	theme.set_stylebox("grabber_area", "VSlider", track)
	theme.set_stylebox("grabber_area_highlight", "VSlider", track)

	theme.set_constant("grabber_size", "HSlider", grabber_size)
	theme.set_constant("grabber_size", "VSlider", grabber_size)

	var sb_scroll := StyleBoxFlat.new()
	sb_scroll.bg_color = p["field_bg"]
	sb_scroll.border_color = p["border"]
	sb_scroll.set_border_width_all(1)
	sb_scroll.set_corner_radius_all(5)
	sb_scroll.content_margin_left = 2
	sb_scroll.content_margin_right = 2
	sb_scroll.content_margin_top = 2
	sb_scroll.content_margin_bottom = 2

	var sb_grabber := StyleBoxFlat.new()
	sb_grabber.bg_color = p["button_hover"]
	sb_grabber.border_color = p.get("scrollbar_outline", p["text"])
	sb_grabber.set_border_width_all(2)
	sb_grabber.set_corner_radius_all(5)

	var sb_grabber_h := sb_grabber.duplicate()
	sb_grabber_h.bg_color = p["button_pressed"]
	sb_grabber_h.border_color = p.get("scrollbar_outline", p["text"])

	var sb_grabber_p := sb_grabber.duplicate()
	sb_grabber_p.bg_color = p["accent"]
	sb_grabber_p.border_color = p.get("scrollbar_outline", p["text"])

	theme.set_stylebox("scroll", "VScrollBar", sb_scroll)
	theme.set_stylebox("scroll_focus", "VScrollBar", sb_scroll)
	theme.set_stylebox("grabber", "VScrollBar", sb_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", sb_grabber_h)
	theme.set_stylebox("grabber_pressed", "VScrollBar", sb_grabber_p)
	theme.set_constant("scroll_size", "VScrollBar", 12)
	theme.set_constant("min_grab_thickness", "VScrollBar", 36)

	theme.set_stylebox("scroll", "HScrollBar", sb_scroll)
	theme.set_stylebox("scroll_focus", "HScrollBar", sb_scroll)
	theme.set_stylebox("grabber", "HScrollBar", sb_grabber)
	theme.set_stylebox("grabber_highlight", "HScrollBar", sb_grabber_h)
	theme.set_stylebox("grabber_pressed", "HScrollBar", sb_grabber_p)
	theme.set_constant("scroll_size", "HScrollBar", 12)
	theme.set_constant("min_grab_thickness", "HScrollBar", 36)

func _resolve_theme_name(theme_name: String) -> String:
	if THEMES.has(theme_name):
		return theme_name
	if _user_themes.has(theme_name):
		return theme_name
	return theme_name

func _load_user_themes() -> void:
	_user_themes.clear()
	_user_theme_order = PackedStringArray()
	if not FileAccess.file_exists(USER_THEME_CONFIG_PATH):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(USER_THEME_CONFIG_PATH)
	if err != OK:
		return
	var order_any: Variant = cfg.get_value("meta", "order", PackedStringArray())
	if order_any is PackedStringArray:
		_user_theme_order = order_any
	elif order_any is Array:
		for name_any in order_any:
			_user_theme_order.append(str(name_any))
	for section in cfg.get_sections():
		var section_name := str(section)
		if not section_name.begins_with("theme:"):
			continue
		var theme_name := section_name.trim_prefix("theme:")
		if theme_name.is_empty():
			continue
		var stored_palette: Variant = cfg.get_value(section_name, "palette", {})
		if not (stored_palette is Dictionary):
			continue
		_user_themes[theme_name] = _normalize_palette(stored_palette)
		if not _user_theme_order.has(theme_name):
			_user_theme_order.append(theme_name)

func _save_user_themes() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "order", _user_theme_order)
	for theme_name in _user_theme_order:
		if not _user_themes.has(theme_name):
			continue
		cfg.set_value("theme:%s" % theme_name, "palette", _user_themes[theme_name])
	cfg.save(USER_THEME_CONFIG_PATH)

func _make_flat_texture(color: Color, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _make_checkbox_texture(size: int, fill: Color, border: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(size):
		for x in range(size):
			var is_border := x == 0 or y == 0 or x == size - 1 or y == size - 1
			img.set_pixel(x, y, border if is_border else fill)
	return ImageTexture.create_from_image(img)

func _make_pill_icon(width: int, height: int, color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var rx := (x + 0.5 - 0.5 * width) / (0.5 * width)
			var ry := (y + 0.5 - 0.5 * height) / (0.5 * height)
			if rx * rx + ry * ry <= 1.0:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _make_toggle_icon(width: int, height: int, fill: Color, _border: Color, knob: Color, on: bool) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cy := int(floor(float(height) * 0.5))
	var knob_radius := maxi(6, int(floor(float(height) * 0.38)))
	var track_margin := knob_radius + 1
	var track_h := 8
	var track_y0 := cy - int(floor(float(track_h) * 0.5))
	var track_y1 := track_y0 + track_h - 1
	for y in range(track_y0, track_y1 + 1):
		for x in range(track_margin, width - track_margin):
			if y >= 0 and y < height and x >= 0 and x < width:
				img.set_pixel(x, y, fill)
	var knob_cx := width - knob_radius - 2 if on else knob_radius + 1
	var knob_cy := cy
	for y in range(height):
		for x in range(width):
			var dx := x - knob_cx
			var dy := y - knob_cy
			if dx * dx + dy * dy <= knob_radius * knob_radius:
				img.set_pixel(x, y, knob)
	return ImageTexture.create_from_image(img)

func _make_check_texture(size: int, bg: Color, mark: Color, border: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var is_border := x == 0 or y == 0 or x == size - 1 or y == size - 1
			img.set_pixel(x, y, border if is_border else bg)
	var inset := 3
	for i in range(inset, size - inset):
		img.set_pixel(i, i, mark)
		img.set_pixel(i, size - 1 - i, mark)
	return ImageTexture.create_from_image(img)

func _make_arrow_icon(width: int, height: int, color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid := int(floor(float(width) * 0.5))
	for y in range(height):
		var half := int(floor(float(y) * float(mid) / float(maxi(1, height - 1))))
		var x0 := mid - half
		var x1 := mid + half
		for x in range(x0, x1 + 1):
			if x >= 0 and x < width:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
var _dejavu_sans_font: FontFile = null
