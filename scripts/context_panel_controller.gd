extends RefCounted
class_name ContextPanelController


var host: Node = null


func configure(next_host: Node) -> void:
	host = next_host


func toggle_search_panel() -> void:
	if host == null or host._search_controller == null:
		return
	if host._feature_panel_open and host._context_panel_mode == host.CONTEXT_PANEL_SEARCH:
		host._close_feature_panel()
		return
	prepare_context_panel(host.CONTEXT_PANEL_SEARCH, "Search", false)
	host._search_controller.show_panel()
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)
	host._search_controller.focus_query()


func toggle_go_panel() -> void:
	if host == null or host._go_controller == null:
		return
	if host._feature_panel_open and host._context_panel_mode == host.CONTEXT_PANEL_GO:
		host._close_feature_panel()
		return
	prepare_context_panel(host.CONTEXT_PANEL_GO, "Go to position", false)
	host._go_controller.show_panel()
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)
	host._go_controller.focus_start()


func toggle_download_panel() -> void:
	if host == null or host._download_panel == null:
		return
	if host._feature_panel_open and host._context_panel_mode == host.CONTEXT_PANEL_DOWNLOAD:
		host._close_feature_panel()
		return
	prepare_context_panel(host.CONTEXT_PANEL_DOWNLOAD, "Download Genome", false)
	host._download_panel.visible = true
	if not host._download_in_progress:
		host._set_download_status("")
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)
	if host._download_accession_edit != null:
		host._download_accession_edit.grab_focus()


func prepare_context_panel(mode: int, title: String, show_detail_labels: bool) -> void:
	if host == null:
		return
	if host._context_panel_mode == host.CONTEXT_PANEL_TRACK_SETTINGS and mode != host.CONTEXT_PANEL_TRACK_SETTINGS:
		host._maybe_save_genome_track_settings()
	host._context_panel_mode = mode
	host._track_settings_open = false
	host._active_track_settings_id = ""
	host.feature_title_label.text = title
	host.feature_name_label.visible = show_detail_labels
	host._set_feature_labels_visible(show_detail_labels)
	hide_context_subpanels()


func hide_context_subpanels() -> void:
	if host == null:
		return
	if host._track_settings_box != null:
		host._track_settings_box.visible = false
	if host._feature_panel_controller != null:
		host._feature_panel_controller.hide_subpanels()
	if host._search_controller != null:
		host._search_controller.hide_panel()
	if host._go_controller != null:
		host._go_controller.hide_panel()
	if host._download_panel != null:
		host._download_panel.visible = false
	if host.read_mate_jump_button != null:
		host.read_mate_jump_button.visible = false
