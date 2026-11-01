// INITIALISE PROJECT

global.debug_enabled  = environment_get_variable("CI") != "";

window_set_caption("Grid Utility v" + GM_version);							// Set window caption text.
global.grid_controller = instance_create_layer(0, 0, "lyr_gui", obj_grid_controller);	// Generate instance of grid controller object.


// Generate unit test object.

if global.debug_enabled == true then global.unit_test = instance_create_layer(0, 0, "lyr_gui", obj_unit_test);	