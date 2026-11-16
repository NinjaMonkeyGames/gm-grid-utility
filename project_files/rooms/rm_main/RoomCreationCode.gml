// =============================================================================
// INITIALISE PROJECT SCRIPT [Phase 1]
// =============================================================================
// 1. Set window caption.
// 2. Unit testing setup.
// 3. Load grid controller and generate example tile/grid data.
// =============================================================================

// [1] SET WINDOW CAPTION //

window_set_caption("Grid Utility v" + GM_version); // Set window caption text. [1.1]


// [2] UNIT TESTING //

/**
 * @description Runs unit tests if it detects a CI environment.
 */
global.debug_enabled = environment_get_variable("CI") != "";                                                                        
if (global.debug_enabled == true) 
{
    global.unit_test = instance_create_layer(0, 0, "lyr_gui", obj_unit_test); // [2.1]
}


// [3] LOAD GRID CONTROLLER //

/**
 * @description Loads grid controller object with example tile data.
 */
global.grid_controller = instance_create_layer(0, 0, "lyr_gui", obj_grid_controller); // Generate instance of grid controller object. [3.1]

// Generate example tilemap (30 rows x 33 columns, indexed [row][column]) [3.2]

var _frames    = sprite_get_number(spr_jungle_temple); // Number of subimages (valid indices are 0 .. _frames - 1).
var _tile_data = [];

repeat (30) // Rows.
{
    var _row_tiles = [];

    repeat (33) // Columns.
    {
        array_push(_row_tiles,
        {
            sprite : spr_jungle_temple,
            index  : irandom(_frames - 1), // irandom() is inclusive, so subtract 1.
            angle  : 90,                   // Degrees 0, 90, 180, 270
            alpha  : 1
        });
    }

    array_push(_tile_data, _row_tiles);
}

// Generate example grid instances [3.3]

example_grid   = new obj_grid_controller.grid();      // Generate example grid instance (uses constructor defaults).
//example_grid_0 = new obj_grid_controller.grid(10, 10); // Generate secondary grid instance with custom offset.