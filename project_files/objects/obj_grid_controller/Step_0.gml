// =============================================================================
// GRID CONTROLLER OBJECT (STEP EVENT) [Phase 5]
// =============================================================================

// Loops through step code for each active grid instance [5.1]


var _list_size = array_length(global.grid_list);

for (var i = 0; i < _list_size; i++)
{
    var _current_instance = global.grid_list[i];
    
    // Safety check to ensure instance exists and isn't destroyed [5.1.1]
	
    if (!is_undefined(_current_instance) && !_current_instance.is_destroyed)
    {
        _current_instance.step();
    }
}