// =============================================================================
// GRID CONTROLLER OBJECT (CLEANUP EVENT) [Phase 7]
// =============================================================================

/**
 * @description Free all grids and the shared vertex format.
 */

// Verify singleton ownership before executing shutdown [7.1]

if (!variable_global_exists("controller") || global.controller != id) exit;

// Free all active grids in reverse order to prevent shifting bugs [7.2]

for (var _i = array_length(global.grid_list) - 1; _i >= 0; --_i)
{
    global.grid_list[_i].destroy();
}

// Free the shared global vertex format buffer [7.3]

if (!is_undefined(global.grid_vformat))
{
    vertex_format_delete(global.grid_vformat);
    global.grid_vformat = undefined;
}