// =============================================================================
// GRID CONTROLLER OBJECT ARCHITECTURE OVERVIEW
// =============================================================================
// 
// --- PHASE 0: CONSTANTS & SOFT LIMITS (Create Event) ---
// 0.1 Cell dimension limits
// 0.2 Row and column quantity limits
// 0.3 Row and column shift limits
// 0.4 Scale limits
// 
// --- PHASE 1: CONTROLLER INITIALIZATION (Create Event) ---
// 1.1 Singleton guard
// 1.2 Declare globals
// 
// --- PHASE 2: GRID CONSTRUCTOR SETUP (Create Event) ---
// 2.1 Initialise constructor
// 2.2 Set core variables
// 2.3 Import arguments from constructor
// 2.4 Build shared vertex format
// 
// --- PHASE 3: GRID API & METHODS (Constructor Scope) ---
// 3.1 Core Build & Generation Methods
//      3.1a set_grid (Vertex buffer, label layout & tile draw list generation)
//          - Reset previous build data [3.1a.1]
//          - Measure font metrics & calculate scaled bounds [3.1a.2]
//          - Build row labels (incorporating y_shift & y_scale) [3.1a.3]
//          - Build column labels (incorporating x_shift & x_scale) [3.1a.4]
//          - Restore font [3.1a.5]
//          - Build vertex buffer lines [3.1a.6]
//              - Build row lines [3.1a.6a]
//              - Build column lines [3.1a.6b]
//              - Close buffer [3.1a.6c]
//          - Build tile draw entries (origin & rotation compensated) [3.1a.7]
//              - Row loop & out of bounds guard [3.1a.7a]
//              - Column loop & out of bounds guard [3.1a.7b]
//              - Sprite corners relative to origin [3.1a.7c]
//              - Rotation values [3.1a.7d]
//              - Rotated bounding box top-left [3.1a.7e]
//              - Store draw entry aligned to cell top-left [3.1a.7f]
// 3.2 Internal Helpers & Utilities
//      3.2a convert_letters (Atlas-style coordinate converter)
//      3.2b guard_alive (Instance destruction validation guard)
//      3.2c get_x (Get column index from X coordinate)
//      3.2d get_y (Get row index from Y coordinate)
//      3.2e shift_x (Shift columns utility)
//      3.2f shift_y (Shift rows utility)
//      3.2g clamp_shifts (Keep both shifts valid for current quantities)
//      3.2h update_row (Change number of rows)
//      3.2i update_column (Change number of columns)
//      3.2j zoom (Zoom in/out preserving on-screen size)
//      3.2k set_coords (Highlight labels under the cursor)
//      3.2l set_cursor (Pointer graphic while over the grid)
// 3.3 Lifecycle & Event Methods
//      3.3a step (Frame update logic)
//          - Guard alive [3.3a.1]
//          - Zoom input [3.3a.2]
//          - Shift input [3.3a.3]
//          - Selection & cursor update [3.3a.4]
//      3.3b draw (State preservation & rendering)
//          - Guard destroyed check [3.3b.1]
//          - Draw tiles [3.3b.2]
//          - Store current draw values [3.3b.3]
//          - Draw row labels [3.3b.4]
//          - Draw column labels [3.3b.5]
//          - Restore previous draw values [3.3b.6]
//          - Submit vertex buffer lines [3.3b.7]
//      3.3c destroy (Resource cleanup & self-unlinking)
//          - Already destroyed check [3.3c.1]
//          - Unlink from global list [3.3c.2]
//          - Free vertex buffer [3.3c.3]
//          - Restore cursor [3.3c.4]
//          - Mark destroyed & wipe data [3.3c.5]
// 
// --- PHASE 4: INITIALIZATION FINALIZE (Create Event) ---
// 4.1 Run initial grid build
// 4.2 Push instance to global list
// 
// --- PHASE 5: CONTROLLER STEP LOOP (Step Event) ---
// 5.1 Iterate active grids and execute step methods
// 
// --- PHASE 6: CONTROLLER DRAW LOOP (Draw Event) ---
// 6.1 Iterate active grids and execute draw methods
// 
// --- PHASE 7: CONTROLLER CLEANUP & SHUTDOWN (Cleanup Event) ---
// 7.1 Verify singleton ownership
// 7.2 Free active grids in reverse order
// 7.3 Free shared global vertex format buffer
// =============================================================================

// SOFT LIMITS

// Cell dimension limits [0.1]

#macro  LIMIT_CELL_WIDTH_MIN 8
#macro  LIMIT_CELL_WIDTH_MAX 256
#macro  LIMIT_CELL_HEIGHT_MIN 8
#macro  LIMIT_CELL_HEIGHT_MAX 256

// Row and column quantity limits [0.2]

#macro  LIMIT_ROW_QTY_MIN 1
#macro  LIMIT_ROW_QTY_MAX 128
#macro  LIMIT_COLUMN_QTY_MIN 1
#macro  LIMIT_COLUMN_QTY_MAX 128

// Row and column shift limits [0.3]

#macro LIMIT_ROW_SHIFT_MIN 0
#macro LIMIT_ROW_SHIFT_MAX 99
#macro LIMIT_COLUMN_SHIFT_MIN 0
#macro LIMIT_COLUMN_SHIFT_MAX 99

// Scale limits [0.4]

#macro LIMIT_X_SCALE_MIN 0.25
#macro LIMIT_Y_SCALE_MIN 0.25
#macro LIMIT_X_SCALE_MAX 2
#macro LIMIT_Y_SCALE_MAX 2

// Singleton guard [1.1]

if (variable_global_exists("controller") && instance_exists(global.controller))
{
    show_debug_message("A singleton pattern has been implemented for this object. Please don't call me again! RTFM");
    instance_destroy();
    exit;
}

// Declare globals [1.2]

global.controller   = id;           // Without this, the guard above can never trigger.
global.grid_list    = [];           // Stores array of grid structs.
global.grid_vformat = undefined;    // Shared vertex format for all grid instances.

// Initialise constructor [2.1]

/**
- @function                                    grid
- @description                                 Generates a 2D grid with row/column labels and optional tiles.
- @param {Real}   [_x_offset]                  Draw position (horizontal).
- @param {Real}   [_y_offset]                  Draw position (vertical).
- @param {Real}   [_cell_width]                Width of a cell.
- @param {Real}   [_cell_height]               Height of a cell.
- @param {Real}   [_row_qty]                   Number of rows.
- @param {Real}   [_column_qty]                Number of columns.
- @param {Bool}   [_label_text_type_row]       Row labels as letters (true) or numbers (false).
- @param {Bool}   [_label_text_type_column]    Column labels as letters (true) or numbers (false).
- @param {Real}   [_grid_colour]               Colour of the grid lines.
- @param {Real}   [_text_colour]               Colour of label text.
- @param {Real}   [_text_selection_colour]     Colour of label text for the row/column under the cursor.
- @param {Real}   [_font]                      Set grid text font.
- @param {Array}  [_tile_data]                 Array of arrays of structs, indexed [row][column]. Each struct: (sprite, index, angle, alpha).
- @returns        {Struct.grid}
 */
 
function grid
(
    _x_offset = 32, _y_offset = 32,
    _cell_width = 256, _cell_height = 256, 
    _row_qty = 4, _column_qty = 6, 
    _label_text_type_row = false, _label_text_type_column = true, 
    _grid_colour = c_lime, _text_colour = c_white, _text_selection_colour = c_red,
    _font = fnt_grid,
    _tile_data = undefined
) 
constructor
{
    // Set core variables [2.2]
    
    is_destroyed                 = false; // Set true by destroy(). Public methods check this before running.

    label_text_grid_gap_column   = 6;
    label_text_grid_gap_row      = 12;

    vbuff                        = -1;
    row_labels                   = [];
    column_labels                = [];
    tile_positions               = [];    // Precomputed tile draw structs (x, y, sprite, index, angle, alpha) for visible cells (populated by set_grid).
    
    cache_cursor                 = window_get_cursor();
    
    // Scaled grid bounds cache (populated by set_grid), declared here for discoverability.
    
    grid_x1 = 0;
    grid_y1 = 0;
    grid_x2 = 0;
    grid_y2 = 0;
    
    x_scale = 1;
    y_scale = 1;
    
    x_shift = 0;
    y_shift = 0;
    
    // Import arguments from constructor [2.3]
    
    x_offset                     = _x_offset;
    y_offset                     = _y_offset;

    cell_width                   = _cell_width;
    cell_height                  = _cell_height;

    row_qty                      = _row_qty;
    column_qty                   = _column_qty;

    label_text_type_row          = _label_text_type_row;
    label_text_type_column       = _label_text_type_column;

    grid_colour                  = _grid_colour;
    text_colour                  = _text_colour;
    text_selection_colour        = _text_selection_colour;
    
    font                         = _font;
    
    tile_data                    = _tile_data;

    // Build shared vertex format [2.4]
    
    if (is_undefined(global.grid_vformat))
    {
        vertex_format_begin();
        vertex_format_add_position();
        vertex_format_add_colour();

        global.grid_vformat = vertex_format_end();
    }
    
    // --- PHASE 3: GRID API & METHODS ---
    
    // Guard alive (Instance destruction validation guard) [3.2b]

    /**
- @function guard_alive()
- @description Throws if this instance has already been destroyed. Single source of truth for the
- use-after-destroy check. Call at the top of any method that reads vbuff/labels or mutates grid state.
- @since v0.1.0.
     */

    static guard_alive = function()
    {
        if (is_destroyed) then throw "GRID INSTANCE HAS BEEN DESTROYED";
    };

    // 3.1 Core Build & Generation Methods [3.1]
    
    /**
- @function set_grid
- @description Builds the label positions, the grid line vertex buffer and the tile draw list,
- applying x_scale/y_scale and shift bounds in advance so draw() performs zero calculations.
- Safe to call again after changing any grid property.
     */
    
    // set_grid (Vertex buffer, label layout & tile draw list generation) [3.1a]
    
    static set_grid = function() 
    {
        guard_alive(); // Prevents error if called mid deletion.

        // Reset previous build data [3.1a.1]
        
        row_labels     = [];
        column_labels  = [];
        tile_positions = [];
        
        if (vbuff != -1)
        {
            vertex_delete_buffer(vbuff);
            vbuff = -1;
        }

        // Measure font metrics & calculate scaled bounds [3.1a.2]
        
        var _old_font = draw_get_font();
        draw_set_font(font);
        
        var _cell_w = cell_width  * x_scale;
        var _cell_h = cell_height * y_scale;

        grid_x1 = x_offset;
        grid_y1 = y_offset;
        grid_x2 = x_offset + (column_qty * _cell_w);
        grid_y2 = y_offset + (row_qty    * _cell_h);
        
        // Build row labels (incorporating y_shift & y_scale) [3.1a.3]
        
        for (var _row = 0; _row < row_qty; ++_row)
        {
            var _actual_row = _row + y_shift;
            var _text = label_text_type_row ? convert_letters(_actual_row) : string(_actual_row); 
            
            array_push(row_labels,
            {
                text   : _text,
                x      : (x_offset - string_width(_text)) - label_text_grid_gap_row,
                y      : y_offset + (_row * _cell_h) + _cell_h / 2 - string_height(_text) / 2,
                colour : text_colour,
            });
        }

        // Build column labels (incorporating x_shift & x_scale) [3.1a.4]
        
        for (var _column = 0; _column < column_qty; ++_column)
        {
            var _actual_column = _column + x_shift;
            var _text = label_text_type_column ? convert_letters(_actual_column) : string(_actual_column); 
            
            array_push(column_labels,
            {
                text   : _text,
                x      : x_offset + (_column * _cell_w) + _cell_w / 2 - string_width(_text) / 2,
                y      : (y_offset - string_height(_text)) - label_text_grid_gap_column,
                colour : text_colour,
            });
        }
        
        // Restore font [3.1a.5]
        
        draw_set_font(_old_font); 

        // Build vertex buffer lines [3.1a.6]
        
        vbuff = vertex_create_buffer();
        vertex_begin(vbuff, global.grid_vformat);
        
        // Build row lines [3.1a.6a]
        
        for (var _row = 0; _row <= row_qty; ++_row)
        {
            var _y = y_offset + (_row * _cell_h);

            vertex_position(vbuff, grid_x1, _y); vertex_colour(vbuff, grid_colour, 1);
            vertex_position(vbuff, grid_x2, _y); vertex_colour(vbuff, grid_colour, 1);
        }
        
        // Build column lines [3.1a.6b]
        
        for (var _column = 0; _column <= column_qty; ++_column)
        {
            var _x = x_offset + (_column * _cell_w);

            vertex_position(vbuff, _x, grid_y1); vertex_colour(vbuff, grid_colour, 1);
            vertex_position(vbuff, _x, grid_y2); vertex_colour(vbuff, grid_colour, 1);
        }
        
        // Close buffer [3.1a.6c]
        
        vertex_end(vbuff);
        vertex_freeze(vbuff); // Static until the next set_grid() call.
        
        // Build tile draw entries (origin & rotation compensated) [3.1a.7]
        
        if (!is_undefined(tile_data))
        {
            var _tile_data_row_qty = array_length(tile_data);
            
            // Row loop & out of bounds guard [3.1a.7a]
            
            for (var _row = 0; _row < row_qty; ++_row)
            {
                var _tile_row = _row + y_shift;
                
                if (_tile_row >= _tile_data_row_qty) then break; // No more tile rows.
                
                // Column count is read per row, as rows are not guaranteed to be the same length.
                
                var _tile_data_column_qty = array_length(tile_data[_tile_row]);
                
                // Column loop & out of bounds guard [3.1a.7b]
                
                for (var _column = 0; _column < column_qty; ++_column)
                {
                    var _tile_column = _column + x_shift;
                    
                    if (_tile_column >= _tile_data_column_qty) then break; // Row is shorter.
                    
                    var _tile   = tile_data[_tile_row][_tile_column];
                    var _sprite = _tile.sprite;
                    var _angle  = _tile.angle;
                    
                    // Sprite corners relative to origin [3.1a.7c]
                    
                    var _dx0 = -sprite_get_xoffset(_sprite) * x_scale;
                    var _dx1 = _dx0 + sprite_get_width(_sprite)  * x_scale;
                    var _dy0 = -sprite_get_yoffset(_sprite) * y_scale;
                    var _dy1 = _dy0 + sprite_get_height(_sprite) * y_scale;
                    
                    // Rotation values [3.1a.7d]
                    
                    // GameMaker rotates counter-clockwise. Round for exact multiples of 90 to avoid float error.
                    
                    var _cos = dcos(_angle);
                    var _sin = dsin(_angle);
                    
                    if (_angle mod 90 == 0)
                    {
                        _cos = round(_cos);
                        _sin = round(_sin);
                    }
                    
                    // Rotated bounding box top-left [3.1a.7e]
                    
                    // x' = dx*cos + dy*sin, y' = -dx*sin + dy*cos (separable, so min of sums = sum of mins).
                    
                    var _min_x = min(_dx0 * _cos, _dx1 * _cos) + min(_dy0 * _sin, _dy1 * _sin);
                    var _min_y = min(-_dx0 * _sin, -_dx1 * _sin) + min(_dy0 * _cos, _dy1 * _cos);
                    
                    // Store draw entry aligned to cell top-left [3.1a.7f]
                    
                    array_push(tile_positions,
                    {
                        x      : (x_offset + (_column * _cell_w)) - _min_x,
                        y      : (y_offset + (_row    * _cell_h)) - _min_y,
                        sprite : _sprite,
                        index  : _tile.index,
                        angle  : _angle,
                        alpha  : _tile.alpha,
                    });
                }
            }
        }
    }
    
    // 3.2 Internal Helpers & Utilities [3.2]
    
    /**
- @function convert_letters
- @description Converts a number to a letter label, as on an atlas or spreadsheet (0 = A, 25 = Z, 26 = AA).
- @param {Real} _number The number to convert.
- @returns {String}
     */
    
    // convert_letters (Atlas-style coordinate converter) [3.2a]
    
    static convert_letters = function(_number)
    {
        var _num = floor(_number) + 1;
        var _string = "";

        while (_num > 0)
        {
            _num--;
            _string = chr((_num mod 26) + 65) + _string;
            _num = _num div 26;
        }

        return _string;
    }
    
    /**
- @function get_x()
- @description Gets the column index under the given X coordinate.
- @since v0.1.0.
- @param {Real} [_x] X coordinate to check (mouse pointer by default).
- @returns {Real} Column index, clamped to a valid range.
- @self {struct.grid}
     */
    
    // get_x (Get column index from X coordinate) [3.2c]
    
    static get_x = function(_x = mouse_x) 
    {
        guard_alive(); // Prevents error if called mid deletion. 
        
        return clamp(floor((_x - x_offset) / (cell_width * x_scale)), 0, floor(column_qty) - 1);
    }
    
    /**
- @function get_y()
- @description Gets the row index under the given Y coordinate.
- @since v0.1.0.
- @param {Real} [_y] Y coordinate to check (mouse pointer by default).
- @returns {Real} Row index, clamped to a valid range.
- @self {struct.grid}
     */
    
    // get_y (Get row index from Y coordinate) [3.2d]
    
    static get_y = function(_y = mouse_y) 
    {
        guard_alive(); // Prevents error if called mid deletion.

        return clamp(floor((_y - y_offset) / (cell_height * y_scale)), 0, floor(row_qty) - 1);
    }
    
    /**
- @function shift_x()
- @description Shifts columns. (Negative values shift left.)
- @since v0.1.0.
- @param {Real} _value Amount to add to the current column shift.
- @self {struct.grid}
     */

    // shift_x (Shift columns utility) [3.2e]
    
    static shift_x = function(_value) 
    {
        guard_alive(); // Prevents error if called mid deletion.
        
        x_shift = clamp(x_shift + _value, LIMIT_COLUMN_SHIFT_MIN, max(LIMIT_COLUMN_SHIFT_MIN, 1 + LIMIT_COLUMN_SHIFT_MAX - column_qty));

        set_grid();
    }
    
    /**
- @function shift_y()
- @description Shifts rows. (Negative values shift up.)
- @since v0.1.0.
- @param {Real} _value Amount to add to the current row shift.
- @self {struct.grid}
     */
    
    // shift_y (Shift rows utility) [3.2f]
    
    static shift_y = function(_value) 
    {
        guard_alive(); // Prevents error if called mid deletion.

        y_shift = clamp(y_shift + _value, LIMIT_ROW_SHIFT_MIN, max(LIMIT_ROW_SHIFT_MIN, 1 + LIMIT_ROW_SHIFT_MAX - row_qty));
        
        set_grid();
    }
    
    /**
- @function clamp_shifts()
- @description Re-clamps both shifts against the current row/column quantities. The max() guards
- against a quantity exceeding (1 + SHIFT_MAX), which would otherwise invert clamp()'s bounds
- and let a shift go negative.
- @since v0.1.0.
- @self {struct.grid}
     */
    
    // clamp_shifts (Keep both shifts valid for current quantities) [3.2g]
    
    static clamp_shifts = function()
    {
        x_shift = clamp(x_shift, LIMIT_COLUMN_SHIFT_MIN, max(LIMIT_COLUMN_SHIFT_MIN, 1 + LIMIT_COLUMN_SHIFT_MAX - column_qty));
        y_shift = clamp(y_shift, LIMIT_ROW_SHIFT_MIN,    max(LIMIT_ROW_SHIFT_MIN,    1 + LIMIT_ROW_SHIFT_MAX    - row_qty));
    }
    
    /**
- @function update_row()
- @description Changes the number of rows.
- @since v0.1.0.
- @param {Real} _value Number of rows in the new grid.
- @self {struct.grid}
     */
    
    // update_row (Change number of rows) [3.2h]
    
    static update_row = function(_value)
    {
        guard_alive();
        
        row_qty = clamp(_value, LIMIT_ROW_QTY_MIN, LIMIT_ROW_QTY_MAX);
        clamp_shifts();
        
        set_grid();
    }
    
    /**
- @function update_column()
- @description Changes the number of columns.
- @since v0.1.0.
- @param {Real} _value Number of columns in the new grid.
- @self {struct.grid}
     */
    
    // update_column (Change number of columns) [3.2i]
    
    static update_column = function(_value)
    {
        guard_alive();
        
        column_qty = clamp(_value, LIMIT_COLUMN_QTY_MIN, LIMIT_COLUMN_QTY_MAX);
        clamp_shifts();
        
        set_grid();
    }
    
    /**
- @function zoom()
- @description Zooms in/out while preserving the grid's total on-screen size.
- Zooming out halves the scale and doubles the quantities; zooming in does the reverse.
- Does nothing if the result would break a scale or quantity limit.
- @since v0.1.0.
- @param {Bool} [_zoom_direction] True to zoom in, false to zoom out.
- @self {struct.grid}
     */
    
    // zoom (Zoom in/out preserving on-screen size) [3.2j]
    
    static zoom = function(_zoom_direction = true)
    {
        guard_alive();
        
        var _new_x_scale;
        var _new_y_scale;
        var _new_col;
        var _new_row;
        
        if (_zoom_direction)
        {
            // Zooming in: double the scale, halve the quantities.
            
            _new_x_scale = x_scale * 2;
            _new_y_scale = y_scale * 2;
            _new_col     = ceil(column_qty / 2);
            _new_row     = ceil(row_qty    / 2);
        }
        else
        {
            // Zooming out: halve the scale, double the quantities.
            
            _new_x_scale = x_scale / 2;
            _new_y_scale = y_scale / 2;
            _new_col     = column_qty * 2;
            _new_row     = row_qty    * 2;
        }
        
        // Only apply if the new state respects every absolute limit.
        
        if (_new_x_scale >= LIMIT_X_SCALE_MIN && _new_x_scale <= LIMIT_X_SCALE_MAX &&
            _new_y_scale >= LIMIT_Y_SCALE_MIN && _new_y_scale <= LIMIT_Y_SCALE_MAX &&
            _new_col     >= LIMIT_COLUMN_QTY_MIN && _new_col <= LIMIT_COLUMN_QTY_MAX &&
            _new_row     >= LIMIT_ROW_QTY_MIN    && _new_row <= LIMIT_ROW_QTY_MAX)
        {
            x_scale    = _new_x_scale;
            y_scale    = _new_y_scale;
            column_qty = _new_col;
            row_qty    = _new_row;
        }
        
        // Re-clamp shifts against the (possibly changed) quantities, then rebuild.
        
        clamp_shifts();
        set_grid();
    }
    
    /**
- @function set_coords()
- @description Highlights the row/column labels under the mouse. Clears the highlight when the mouse is off the grid.
- @since v0.1.0.
- @self {struct.grid}
     */
    
    // set_coords (Highlight labels under the cursor) [3.2k]
    
    static set_coords = function()
    {
        guard_alive();
        
        var _inside   = point_in_rectangle(mouse_x, mouse_y, grid_x1, grid_y1, grid_x2, grid_y2);
        var _select_x = _inside ? get_x() : -1;
        var _select_y = _inside ? get_y() : -1;
        
        // Grab each label struct into a local and write through it, instead of a chained
        // array[_i].field = ... write.
        
        for (var _i = 0; _i < array_length(row_labels); ++_i)
        {
            var _row_label = row_labels[_i];
            _row_label.colour = (_i == _select_y) ? text_selection_colour : text_colour;
        }
        
        for (var _i = 0; _i < array_length(column_labels); ++_i)
        {
            var _column_label = column_labels[_i];
            _column_label.colour = (_i == _select_x) ? text_selection_colour : text_colour;
        }
    }
    
    /**
- @function set_cursor()
- @description Sets the mouse pointer graphic depending on whether the given point is over the grid.
- @since v0.1.0.
- @param {Real} [_x] X coordinate to check (mouse pointer by default).
- @param {Real} [_y] Y coordinate to check (mouse pointer by default).
- @self {struct.grid}
     */
    
    // set_cursor (Pointer graphic while over the grid) [3.2l]
    
    static set_cursor = function(_x = mouse_x, _y = mouse_y)
    {
        guard_alive();

        if (point_in_rectangle(_x, _y, grid_x1, grid_y1, grid_x2, grid_y2))
        {
            if (window_get_cursor() != cr_handpoint) then cache_cursor = window_get_cursor();

            window_set_cursor(cr_handpoint);
        }
        else
        {
            window_set_cursor(cache_cursor);
        }
    }
    
    // 3.3 Lifecycle & Event Methods [3.3]
    
    /**
- @function step
- @description Executes example grid functionality: wheel zoom, arrow key shifting, label highlight and cursor.
     */
    
    // step (Frame update logic) [3.3a]
    
    static step = function()
    {
        // Guard alive [3.3a.1]
        
        guard_alive();
        
        // Zoom input [3.3a.2]

        if (mouse_wheel_down()) then zoom(true);
        if (mouse_wheel_up())   then zoom(false);
        
        // Shift input [3.3a.3]
        
        if (keyboard_check_pressed(vk_left))  then shift_x(-1);
        if (keyboard_check_pressed(vk_right)) then shift_x(1);
        if (keyboard_check_pressed(vk_up))    then shift_y(-1);
        if (keyboard_check_pressed(vk_down))  then shift_y(1);
        
        // Selection & cursor update (after any rebuild above, so highlights are never a frame stale) [3.3a.4]
        
        set_coords();
        set_cursor();
    }

    // draw (State preservation & rendering) [3.3b]

    /**
- @function draw
- @description Draws the precomputed tiles, the labels and the grid lines.
     */
    
    static draw = function()
    {
        // Guard destroyed check [3.3b.1]
        
        if (is_destroyed) return;  // Prevents error if called mid deletion.
        
        // Draw tiles [3.3b.2]
        
        var _tile_count = array_length(tile_positions);
        
        for (var _i = 0; _i < _tile_count; ++_i)
        {
            var _tile = tile_positions[_i];
            
            draw_sprite_ext
            (
                _tile.sprite, _tile.index,
                _tile.x, _tile.y,
                x_scale, y_scale, _tile.angle, c_white, _tile.alpha
            );
        }
        
        // Store current draw values [3.3b.3]
        
        var _old_colour = draw_get_colour();
        var _old_font   = draw_get_font();
        var _old_halign = draw_get_halign();
        var _old_valign = draw_get_valign();

        draw_set_font(font);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        
        // Draw row labels [3.3b.4]
        
        for (var _i = 0; _i < array_length(row_labels); ++_i)
        {
            var _row_label = row_labels[_i];
            
            draw_set_colour(_row_label.colour);
            draw_text(_row_label.x, _row_label.y, _row_label.text);
        }

        // Draw column labels [3.3b.5]

        for (var _i = 0; _i < array_length(column_labels); ++_i)
        {
            var _column_label = column_labels[_i];
            
            draw_set_colour(_column_label.colour);
            draw_text(_column_label.x, _column_label.y, _column_label.text);
        }
        
        // Restore previous draw values [3.3b.6]
        
        draw_set_colour(_old_colour);
        draw_set_font(_old_font);
        draw_set_halign(_old_halign);
        draw_set_valign(_old_valign);

        // Submit vertex buffer lines [3.3b.7]
        
        vertex_submit(vbuff, pr_linelist, -1);
    }
    
    // destroy (Resource cleanup & self-unlinking) [3.3c]
    
    /**
- @function destroy
- @description Removes this grid from the global list, frees GPU resources, restores the cursor, and wipes all instance data.
     */
    
    static destroy = function() 
    {
        // Already destroyed check [3.3c.1]
        
        if is_destroyed == true return; // Safe no-op.

        // Unlink from global list [3.3c.2]
        
        var _index = array_get_index(global.grid_list, self);

        if (_index != -1) then array_delete(global.grid_list, _index, 1);

        // Free vertex buffer [3.3c.3]
        
        if (vbuff != -1)
        {
            vertex_delete_buffer(vbuff);
            vbuff = -1;
        }
        
        // Restore cursor [3.3c.4]
        
        window_set_cursor(cache_cursor); // Don't leave the hand pointer behind if destroyed while hovering.

        // Mark destroyed & wipe data [3.3c.5]
        
        is_destroyed = true; // Set before the wipe below, since the wipe would otherwise erase it too.

        var _names = variable_struct_get_names(self);

        for (var _i = 0; _i < array_length(_names); ++_i)
        {
            var _name = _names[_i];

            if (_name == "is_destroyed") then continue;
            if (is_method(variable_struct_get(self, _name))) then continue;

            variable_struct_set(self, _name, undefined);
        }
    }

    // --- PHASE 4: INITIALIZATION FINALIZE ---
    
    // Run initial grid build [4.1]
    
    set_grid(); // Called last, after every static method it depends on is defined.
    
    // Push instance to global list [4.2]
    
    array_push(global.grid_list, self); 
}