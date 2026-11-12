/// @description Free all grids and the shared vertex format

if (!variable_global_exists("controller") || global.controller != id) exit;

for (var _i = array_length(global.grid_list) - 1; _i >= 0; --_i)
{
	global.grid_list[_i].destroy();
}

if (!is_undefined(global.grid_vformat))
{
	vertex_format_delete(global.grid_vformat);
	global.grid_vformat = undefined;
}