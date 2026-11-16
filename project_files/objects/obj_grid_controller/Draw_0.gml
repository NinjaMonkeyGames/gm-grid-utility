// =============================================================================
// GRID CONTROLLER OBJECT (DRAW EVENT) [Phase 6]
// =============================================================================

// Loops through draw code for each active grid instance [6.1]

var _list_size = array_length(global.grid_list);

for (var _i = 0; _i < _list_size; _i++)
{
    var _current_instance = global.grid_list[_i]; 
    
    // Safety check to ensure instance exists and isn't destroyed [6.1.1]
	
    if (!is_undefined(_current_instance) && !_current_instance.is_destroyed)
    {
        _current_instance.draw();
    }
}