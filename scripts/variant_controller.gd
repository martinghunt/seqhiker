extends RefCounted
class_name VariantController

var host: Node = null


func configure(next_host: Node) -> void:
	host = next_host


func refresh_sources() -> bool:
	var resp: Dictionary = host._zem.list_variant_sources()
	if not resp.get("ok", false):
		host._set_status("List VCF sources failed: %s" % resp.get("error", "error"), true)
		return false
	host._variant_sources.clear()
	for src_any in resp.get("sources", []):
		if typeof(src_any) == TYPE_DICTIONARY:
			host._variant_sources.append((src_any as Dictionary).duplicate(true))
	sync_track()
	host._invalidate_cache()
	if host._current_chr_len > 0:
		host._schedule_fetch()
	return true


func sync_track() -> void:
	host.genome_view.set_variant_sources(host._variant_sources)
	host.genome_view.set_track_visible(host.TRACK_VCF, not host._variant_sources.is_empty())


func populate_track_settings(track_id: String, settings_box: VBoxContainer) -> bool:
	if track_id != host.TRACK_VCF:
		return false
	var info_label := Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.text = "One row per sample across all loaded VCF files. Double-click a SNP to view record details."
	settings_box.add_child(info_label)
	return true


func on_variant_clicked(variant: Dictionary) -> void:
	var chr_id := int(variant.get("chr_id", -1))
	if chr_id < 0:
		chr_id = host._go_get_browser_target_chr_id()
	if chr_id < 0 and not host._current_chr_name.is_empty():
		for chr_any in host._chromosomes:
			if typeof(chr_any) != TYPE_DICTIONARY:
				continue
			var chr: Dictionary = chr_any
			if str(chr.get("name", "")) == host._current_chr_name:
				chr_id = int(chr.get("id", -1))
				break
	if chr_id < 0 and not host._chromosomes.is_empty():
		var first_chr_any = host._chromosomes[0]
		if typeof(first_chr_any) == TYPE_DICTIONARY:
			chr_id = int((first_chr_any as Dictionary).get("id", -1))
	var source_id := int(variant.get("source_id", 0))
	if source_id <= 0 and host._variant_sources.size() == 1:
		var only_source_any = host._variant_sources[0]
		if typeof(only_source_any) == TYPE_DICTIONARY:
			source_id = int((only_source_any as Dictionary).get("id", 0))
	if chr_id < 0 or source_id <= 0:
		host._set_status("Variant detail query failed: unable to resolve source/chromosome", true)
		return
	var source_start := int(variant.get("source_start", int(variant.get("start", 0))))
	var ref := str(variant.get("ref", ""))
	var alt_summary := str(variant.get("alt_summary", ""))
	var resp: Dictionary = host._zem.get_variant_detail(source_id, chr_id, source_start, ref, alt_summary)
	if not resp.get("ok", false):
		host._set_status("Variant detail query failed: %s" % resp.get("error", "error"), true)
		return
	host._feature_panel_controller.on_variant_clicked(variant, resp.get("detail", {}))


func on_variant_selected(variant: Dictionary) -> void:
	host._play_ui_sound(host.SoundControllerScript.SOUND_BLIP)
	if not host._feature_panel_open:
		return
	if host.feature_title_label.text != "Variant Details":
		return
	on_variant_clicked(variant)
