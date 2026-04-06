#include "register_types.h"

#include <gdextension_interface.h>

#include <godot_cpp/godot.hpp>

#include "zem_bridge.h"

using namespace godot;

void initialize_seqhiker_zem_bridge_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	GDREGISTER_CLASS(ZemBridge);
}

void uninitialize_seqhiker_zem_bridge_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT seqhiker_zem_bridge_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_seqhiker_zem_bridge_module);
	init_obj.register_terminator(uninitialize_seqhiker_zem_bridge_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
