extends RefCounted
class_name ThemesLib

const ANONYMOUS_PRO_FONT := preload("res://fonts/Anonymous-Pro/Anonymous_Pro.ttf")
const COURIER_NEW_FONT := preload("res://fonts/Courier-New/couriernew.ttf")
const DEJAVU_SANS_FONT_PATH := "res://fonts/Dejavu-sans/DejaVuSans.ttf"


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
#  - aa_alt_bg: alternating AA row background
#  - map_contig: primary contig fill in map track
#  - map_contig_alt: alternating contig fill in map track
#  - map_view_fill: map viewport/drag selection fill
#  - map_view_outline: map viewport/drag selection outline
#  - region_select_fill: genome-track dragged region fill
#  - region_select_outline: genome-track dragged region outline
#  - genome: genome axis/main genome highlight color
#  - read: default read/depth-summary color
#  - gc_plot: GC plot color
#  - depth_plot: depth plot color
#  - depth_plot_series: per-BAM depth plot series colors
#  - pileup_logo_bases: per-base colors for pileup logo A/C/G/T/D
#  - snp: SNP marker fill
#  - snp_text: text drawn on SNP markers
#  - aa_forward: forward-frame AA summary/read-derived accent
#  - aa_reverse: reverse-frame AA summary/read-derived accent
#  - feature: annotation feature box fill
#  - feature_accent: subtle annotation sub-feature accent
#  - feature_text: annotation feature label/border color
#  - stop_codon: AA/annotation overview stop-codon marker color
#  - comparison_same_strand: comparison-match fill for same-strand hits
#  - comparison_opp_strand: comparison-match fill for opposite-strand hits
#  - comparison_snp: comparison-detail SNP connector color


const THEMES := {
	"Classic": {
		"bg": Color("ffffff"),
		"panel": Color("ffffff"),
		"panel_alt": Color("efefef"),
		"grid": Color("c8c8c8"),
		"border": Color8(115, 137, 189),
		"text": Color("000000"),
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
		"aa_alt_bg": Color("f5f5f5"),
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
		"pileup_logo_bases": {
			"A": Color("2b9348"),
			"C": Color("1d4ed8"),
			"G": Color("a16207"),
			"T": Color("b91c1c"),
			"D": Color("4a4a4a")
		},
		"snp": Color("ff0000"),
		"comparison_snp": Color("ff00ff"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("0000ff"),
		"aa_reverse": Color("00aa00"),
		"feature": Color8(116, 250, 252),
		"feature_accent": Color8(36, 164, 166),
		"feature_text": Color("000000"),
		"comparison_same_strand": Color("ff0000"),
		"comparison_opp_strand": Color("0000ff")
	},
	"Monochrome Light": {
		"bg": Color("fcfcfc"),
		"panel": Color("ffffff"),
		"panel_alt": Color("f0f0f0"),
		"grid": Color("cfcfcf"),
		"border": Color("c8c8c8"),
		"text": Color("202020"),
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
		"aa_alt_bg": Color("f5f5f5"),
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
		"pileup_logo_bases": {
			"A": Color("4c4c4c"),
			"C": Color("666666"),
			"G": Color("808080"),
			"T": Color("9a9a9a"),
			"D": Color("2f2f2f")
		},
		"snp": Color("2f2f2f"),
		"comparison_snp": Color("2f2f2f"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("5f5f5f"),
		"aa_reverse": Color("8a8a8a"),
		"feature": Color("d9d9d9"),
		"feature_accent": Color("8c8c8c"),
		"feature_text": Color("242424"),
		"comparison_same_strand": Color("555555"),
		"comparison_opp_strand": Color("8a8a8a")
	},
	"Light": {
		"bg": Color("ffffff"),
		"panel": Color("ffffff"),
		"panel_alt": Color("f5f5f5"),
		"grid": Color("d0d0d0"),
		"border": Color("d0d0d0"),
		"text": Color("111111"),
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
		"aa_alt_bg": Color("efefef"),
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
		"pileup_logo_bases": {
			"A": Color("2b9348"),
			"C": Color("1d4ed8"),
			"G": Color("a16207"),
			"T": Color("b91c1c"),
			"D": Color("4a5568")
		},
		"snp": Color("b11f47"),
		"comparison_snp": Color("7a00ff"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("8a4fff"),
		"aa_reverse": Color("f39237"),
		"feature": Color("dce8f7"),
		"feature_accent": Color("7f9cc3"),
		"feature_text": Color("1e3557"),
		"comparison_same_strand": Color("cf5c36"),
		"comparison_opp_strand": Color("3f5a7a")
	},
	"Forest": {
		"bg": Color("eaf4e5"),
		"panel": Color("f6fff0"),
		"panel_alt": Color("eef8e9"),
		"grid": Color("b8d1ad"),
		"border": Color("b8d1ad"),
		"text": Color("20301f"),
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
		"aa_alt_bg": Color("dfe8d8"),
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
		"pileup_logo_bases": {
			"A": Color("4f8a3f"),
			"C": Color("2f6f99"),
			"G": Color("8f6a1b"),
			"T": Color("9a3d32"),
			"D": Color("4f5f4d")
		},
		"snp": Color("7a143a"),
		"comparison_snp": Color("7b2cbf"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("588157"),
		"aa_reverse": Color("bc4749"),
		"feature": Color("c8dfc0"),
		"feature_accent": Color("6e9662"),
		"feature_text": Color("1f3a24"),
		"comparison_same_strand": Color("b15a3c"),
		"comparison_opp_strand": Color("4f7d64")
	},
	"Slate": {
		"bg": Color("e8edf2"),
		"panel": Color("f6f9fc"),
		"panel_alt": Color("edf2f6"),
		"grid": Color("b6c3cf"),
		"border": Color("b6c3cf"),
		"text": Color("1f2933"),
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
		"aa_alt_bg": Color("dde3ea"),
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
		"pileup_logo_bases": {
			"A": Color("2b9348"),
			"C": Color("1d4ed8"),
			"G": Color("a16207"),
			"T": Color("b91c1c"),
			"D": Color("4b5563")
		},
		"snp": Color("d7263d"),
		"comparison_snp": Color("7a00ff"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("5c6784"),
		"aa_reverse": Color("f4a259"),
		"feature": Color("c6d6ec"),
		"feature_accent": Color("6f93c7"),
		"feature_text": Color("1f3654"),
		"comparison_same_strand": Color("cb5a4a"),
		"comparison_opp_strand": Color("4d78b0")
	},
	"Dark": {
		"bg": Color("1a1d22"),
		"panel": Color("21262d"),
		"panel_alt": Color("2a3038"),
		"grid": Color("3a434f"),
		"border": Color("3a434f"),
		"text": Color("e6edf3"),
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
		"aa_alt_bg": Color("2c333d"),
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
		"pileup_logo_bases": {
			"A": Color("5ac26b"),
			"C": Color("73b7ff"),
			"G": Color("d3a34a"),
			"T": Color("ff7b72"),
			"D": Color("aab6c2")
		},
		"snp": Color("ff7b72"),
		"comparison_snp": Color("ffd166"),
		"snp_text": Color("111111"),
		"aa_forward": Color("b392f0"),
		"aa_reverse": Color("ffb86b"),
		"feature": Color("2e466e"),
		"feature_accent": Color("6e8dbb"),
		"feature_text": Color("eaf2ff"),
		"comparison_same_strand": Color("d17a6b"),
		"comparison_opp_strand": Color("7aa2f7")
	},
	"Monochrome Dark": {
		"bg": Color("171717"),
		"panel": Color("202020"),
		"panel_alt": Color("2b2b2b"),
		"grid": Color("444444"),
		"border": Color("4b4b4b"),
		"text": Color("e6e6e6"),
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
		"aa_alt_bg": Color("303030"),
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
		"pileup_logo_bases": {
			"A": Color("d0d0d0"),
			"C": Color("b0b0b0"),
			"G": Color("909090"),
			"T": Color("707070"),
			"D": Color("f0f0f0")
		},
		"snp": Color("f0f0f0"),
		"comparison_snp": Color("f0f0f0"),
		"snp_text": Color("111111"),
		"aa_forward": Color("bababa"),
		"aa_reverse": Color("727272"),
		"feature": Color("505050"),
		"feature_accent": Color("9a9a9a"),
		"feature_text": Color("f0f0f0"),
		"comparison_same_strand": Color("d0d0d0"),
		"comparison_opp_strand": Color("7a7a7a")
	},
	"Solarized Light": {
		"bg": Color("fdf6e3"),
		"panel": Color("fdf6e3"),
		"panel_alt": Color("eee8d5"),
		"grid": Color("93a1a1"),
		"border": Color("93a1a1"),
		"text": Color("657b83"),
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
		"aa_alt_bg": Color("eee8d5"),
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
		"pileup_logo_bases": {
			"A": Color("859900"),
			"C": Color("268bd2"),
			"G": Color("b58900"),
			"T": Color("dc322f"),
			"D": Color("657b83")
		},
		"snp": Color("d33682"),
		"comparison_snp": Color("6c71c4"),
		"snp_text": Color("fdf6e3"),
		"aa_forward": Color("6c71c4"),
		"aa_reverse": Color("cb4b16"),
		"feature": Color("dcecf6"),
		"feature_accent": Color("7eb6d6"),
		"feature_text": Color("1f5d85"),
		"comparison_same_strand": Color("cb6b47"),
		"comparison_opp_strand": Color("268bd2")
	},
	"Solarized Dark": {
		"bg": Color("002b36"),
		"panel": Color("002b36"),
		"panel_alt": Color("073642"),
		"grid": Color("586e75"),
		"border": Color("586e75"),
		"text": Color("839496"),
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
		"aa_alt_bg": Color("073642"),
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
		"pileup_logo_bases": {
			"A": Color("859900"),
			"C": Color("268bd2"),
			"G": Color("b58900"),
			"T": Color("dc322f"),
			"D": Color("839496")
		},
		"snp": Color("d33682"),
		"comparison_snp": Color("b58900"),
		"snp_text": Color("fdf6e3"),
		"aa_forward": Color("6c71c4"),
		"aa_reverse": Color("cb4b16"),
		"feature": Color("12455f"),
		"feature_accent": Color("5190ad"),
		"feature_text": Color("dceef8"),
		"comparison_same_strand": Color("c56a49"),
		"comparison_opp_strand": Color("268bd2")
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
	return names

func has_theme(theme_name: String) -> bool:
	return THEMES.has(_resolve_theme_name(theme_name))

func palette(theme_name: String) -> Dictionary:
	var resolved := _resolve_theme_name(theme_name)
	if not THEMES.has(resolved):
		resolved = "Slate"
	var p := (THEMES[resolved] as Dictionary).duplicate(true)
	if not p.has("stop_codon"):
		p["stop_codon"] = p.get("text", Color.BLACK)
	return p

func genome_palette(theme_name: String) -> Dictionary:
	var p := palette(theme_name)
	return {
		"bg": p["bg"],
		"panel": p["panel"],
		"grid": p["grid"],
		"text": p["text"],
		"aa_alt_bg": p["aa_alt_bg"],
		"map_contig": p["map_contig"],
		"map_contig_alt": p["map_contig_alt"],
		"map_view_fill": p["map_view_fill"],
		"map_view_outline": p["map_view_outline"],
		"region_select_fill": p["region_select_fill"],
		"region_select_outline": p["region_select_outline"],
		"genome": p["genome"],
		"read": p["read"],
		"gc_plot": p["gc_plot"],
		"depth_plot": p["depth_plot"],
		"depth_plot_series": p.get("depth_plot_series", [p["depth_plot"]]),
		"pileup_logo_bases": p.get("pileup_logo_bases", {}),
		"snp": p["snp"],
		"snp_text": p["snp_text"],
		"aa_forward": p["aa_forward"],
		"aa_reverse": p["aa_reverse"],
		"feature": p["feature"],
		"feature_accent": p["feature_accent"],
		"feature_text": p["feature_text"],
		"stop_codon": p.get("stop_codon", p["text"])
	}

func depth_plot_series(theme_name: String) -> Array:
	var p := palette(theme_name)
	var colors_any: Variant = p.get("depth_plot_series", [p["depth_plot"]])
	var colors: Array = []
	for color_any in colors_any:
		if color_any is Color:
			colors.append(color_any)
	return colors

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


func make_theme(theme_name: String, font_size: int, font_name: String = "Noto Sans") -> Theme:
	var p := palette(theme_name)
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
	return theme_name

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
