// =============================================================================
// GRID CONTROLLER OBJECT ARCHITECTURE OVERVIEW
// =============================================================================
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
//     3.1a set_grid (Vertex buffer & label layout generation)
//          - Reset previous build data [3.1a.1]
//          - Measure font metrics [3.1a.2]
//          - Build row labels [3.1a.3]
//          - Build column labels [3.1a.4]
//          - Restore font [3.1a.5]
//          - Build vertex buffer lines [3.1a.6]
//              - Build row lines [3.1a.6a]
//              - Build column lines [3.1a.6b]
//              - Close buffer [3.1a.6c]
// 3.2 Internal Helpers & Utilities
//     3.2a convert_letters (Atlas-style coordinate converter)
//     3.2b guard_alive (Instance destruction validation guard)
//     3.2c get_x (Get column index from X coordinate)
//     3.2d get_y (Get row index from Y coordinate)
//     3.2e shift_x (Shift columns utility)
// 3.3 Lifecycle & Event Methods
//     3.3a step (Frame update logic)
//     3.3b draw (State preservation & rendering)
//          - Guard destroyed check [3.3b.1]
//          - Store current draw values [3.3b.2]
//          - Draw row labels [3.3b.3]
//          - Draw column labels [3.3b.4]
//          - Restore previous draw values [3.3b.5]
//          - Submit vertex buffer lines [3.3b.6]
//     3.3c destroy (Resource cleanup & self-unlinking)
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


// Singleton guard [1.1]

if (variable_global_exists("controller") && instance_exists(global.controller))
{
    show_debug_message("A singleton pattern has been implemented for this object. Please don't call me again! RTFM");
    instance_destroy();
    exit;
}

// Declare globals [1.2]

global.controller   = id;             // Without this, the guard above can never trigger.
global.grid_list    = [];             // Stores array of grid structs.
global.grid_vformat = undefined;      // Shared vertex format for all grid instances.


// Initialise constructor [2.1]

/**
 * @function                                grid
 * @description                             Generates a 2D grid with row/column labels.
 * @param {Real}   [_x_offset]              Draw position (horizontal).
 * @param {Real}   [_y_offset]              Draw position (vertical).
 * @param {Real}   [_cell_width]            Width of a cell.
 * @param {Real}   [_cell_height]           Height of a cell.
 * @param {Real}   [_row_qty]               Number of rows.
 * @param {Real}   [_column_qty]            Number of columns.
 * @param {Bool}   [_label_text_type_row]     Row labels as letters (true) or numbers (false).
 * @param {Bool}   [_label_text_type_column] Column labels as letters (true) or numbers (false).
 * @param {Real}   [_grid_colour]           Colour of the grid lines.
 * @param {Real}   [_text_colour]           Colour of label text.
 * @param {Real}   [_text_selection_colour] Colour of label text for selected cell.
 * @param {Real}   [_font]                  Set grid text font.
 * @returns        {Struct.grid}
 */
 
function grid
(
    _x_offset = 32, _y_offset = 32,
    _cell_width = 256, _cell_height = 256, 
    _row_qty = 4, _column_qty = 6, 
    _label_text_type_row = false, _label_text_type_column = true, 
    _grid_colour = c_lime, _text_colour = c_white, _text_selection_colour = c_red,
    _font = fnt_grid
) 
constructor
{
    // Set core variables [2.2]
    
    is_destroyed                     = false; // Set true by destroy(). Public methods check this before running.

    label_text_grid_gap_column   = 6;
    label_text_grid_gap_row      = 12;

    vbuff                        = -1;
    row_labels                   = [];
    column_labels                = [];
    
    x_scale = 1;
    y_scale = 1;
    
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
    
    font                         = _font;

    // Build shared vertex format [2.4]
    
    if (is_undefined(global.grid_vformat))
    {
        vertex_format_begin();
        vertex_format_add_position();
        vertex_format_add_colour();

        global.grid_vformat = vertex_format_end();
    }
    
    // Guard alive (Instance destruction validation guard) [3.2b]

    /**
     * @function guard_alive()
     * @description Throws if this instance has already been destroyed. Single source of truth for the
     * use-after-destroy check—call at the top of any method that reads cell_data/vbuff or mutates grid state.
     * @since v0.1.0.
     */

    static guard_alive = function()
    {
        if (is_destroyed) then throw "GRID INSTANCE HAS BEEN DESTROYED";
    };
    
    // --- PHASE 3: GRID API & METHODS ---

    // 3.1 Core Build & Generation Methods [3.1]
    
    /**
     * @function    set_grid
     * @description Builds the label positions and the grid line vertex buffer. Safe to call again after changing any grid property.
     */
    
    // set_grid (Vertex buffer & label layout generation) [3.1a]
    
    static set_grid = function() 
    {
        guard_alive(); // Prevents error if called mid deletion.

        // Reset previous build data [3.1a.1]

        row_labels    = [];
        column_labels = [];
        
        if (vbuff != -1)
        {
            vertex_delete_buffer(vbuff);
            vbuff = -1;
        }

        // Measure font metrics [3.1a.2]

        var _old_font = draw_get_font();
        draw_set_font(font);

        var _gx1 = x_offset;
        var _gy1 = y_offset;
        var _gx2 = x_offset + (column_qty * cell_width);
        var _gy2 = y_offset + (row_qty * cell_height);
        
        // Build row labels [3.1a.3]

        for (var _row = 0; _row < row_qty; ++_row)
        {
            var _text = label_text_type_row ? convert_letters(_row) : string(_row); 
            
            array_push(row_labels,
            {
                text : _text,
                x    : (x_offset - string_width(_text)) - label_text_grid_gap_row,
                y    : y_offset + (_row * cell_height) + cell_height / 2 - string_height(_text) / 2,
            });
        }

        // Build column labels [3.1a.4]

        for (var _column = 0; _column < column_qty; ++_column)
        {
            var _text = label_text_type_column ? convert_letters(_column) : string(_column); 
            
            array_push(column_labels,
            {
                text : _text,
                x    : x_offset + (_column * cell_width) + cell_width / 2 - string_width(_text) / 2,
                y    : (y_offset - string_height(_text)) - label_text_grid_gap_column,
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
            var _y = y_offset + (_row * cell_height);

            vertex_position(vbuff, _gx1, _y); vertex_colour(vbuff, grid_colour, 1);
            vertex_position(vbuff, _gx2, _y); vertex_colour(vbuff, grid_colour, 1);
        }
        
        // Build column lines [3.1a.6b]

        for (var _column = 0; _column <= column_qty; ++_column)
        {
            var _x = x_offset + (_column * cell_width);

            vertex_position(vbuff, _x, _gy1); vertex_colour(vbuff, grid_colour, 1);
            vertex_position(vbuff, _x, _gy2); vertex_colour(vbuff, grid_colour, 1);
        }
        
        // Close buffer [3.1a.6c]
        
        vertex_end(vbuff);
        vertex_freeze(vbuff);
    }
    
    // 3.2 Internal Helpers & Utilities [3.2]
    
    /**
     * @function convert_letters
     * @description Converts a number to a letter label, as on an atlas or spreadsheet (0 = A, 25 = Z, 26 = AA).
     * @param {Real} _number The number to convert.
     * @returns {String}
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
     * @function get_x()
     * @description Gets the row index under the given X coordinate.
     * @since v0.1.0.
     * @param {Real} [_x] X coordinate to check (mouse pointer by default).
     * @returns {Real} Column index, clamped to a valid range.
     * @self {struct.grid}
     */
    
    // get_x (Get column index from X coordinate) [3.2c]
    
    static get_x = function(_x = mouse_x) 
    {
        guard_alive();
        
        return clamp(floor((_x - x_offset) / (cell_width * x_scale)), 0, floor(column_qty) - 1);
    }
    
    /**
     * @function get_y()
     * @description Gets the row index under the given Y coordinate.
     * @since v0.1.0.
     * @param {Real} [_y] Y coordinate to check (mouse pointer by default).
     * @returns {Real} Row index, clamped to a valid range.
     * @self {struct.grid}
     */
    
    // get_y (Get row index from Y coordinate) [3.2d]
    
    static get_y = function(_y = mouse_y) 
    {
        guard_alive();

        return clamp(floor((_y - y_offset) / (cell_height * y_scale)), 0, floor(row_qty) - 1);
    }
    
    /**
     * @function shift_x()
     * @description Shifts columns. (Negative values shift left.)
     * @since v0.1.0.
     * @param {Real} _value Amount to add to the current column shift.
     * @self {struct.grid}
     */
    
    // shift_x (Shift columns utility) [3.2e]
    
    // 3.3 Lifecycle & Event Methods [3.3]
    
    /**
     * @function step
     * @description Executes example grid functionality.
     */
    
    // step (Frame update logic) [3.3a]
    
    static step = function()
    {
        show_debug_message(self.get_x());
        show_debug_message(self.get_y());
    }

    // draw (State preservation & rendering) [3.3b]

    /**
     * @function draw
     * @description Draws the labels and the grid lines.
     */
    
    static draw = function()
    {
        // Guard destroyed check [3.3b.1]
        
        if (is_destroyed) return;  // Prevents error if called mid deletion.
        
        // Store current draw values [3.3b.2]
        
        var _old_colour = draw_get_colour();
        var _old_font   = draw_get_font();
        var _old_halign = draw_get_halign();
        var _old_valign = draw_get_valign();

        draw_set_colour(text_colour);
        draw_set_font(font);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        
        // Draw row labels [3.3b.3]
        
        for (var _i = 0; _i < array_length(row_labels); ++_i)
        {
            draw_text(row_labels[_i].x, row_labels[_i].y, row_labels[_i].text);
        }

        // Draw column labels [3.3b.4]

        for (var _i = 0; _i < array_length(column_labels); ++_i)
        {
            draw_text(column_labels[_i].x, column_labels[_i].y, column_labels[_i].text);
        }
        
        // Restore previous draw values [3.3b.5]
        
        draw_set_colour(_old_colour);
        draw_set_font(_old_font);
        draw_set_halign(_old_halign);
        draw_set_valign(_old_valign);

        // Submit vertex buffer lines [3.3b.6]
        
        vertex_submit(vbuff, pr_linelist, -1);
    }
    
    // destroy (Resource cleanup & self-unlinking) [3.3c]
    
    /**
     * @function destroy
     * @description Removes this grid from the global list, frees GPU resources, and wipes all instance data.
     */
    
    static destroy = function() 
    {
        if (is_destroyed) return; // Already destroyed. Safe no-op.

        var _index = array_get_index(global.grid_list, self);

        if (_index != -1) array_delete(global.grid_list, _index, 1);

        if (vbuff != -1)
        {
            vertex_delete_buffer(vbuff);
            vbuff = -1;
        }

        is_destroyed = true; 

        var _names = variable_struct_get_names(self);

        for (var _i = 0; _i < array_length(_names); ++_i)
        {
            var _name = _names[_i];

            if (_name == "is_destroyed") continue;
            if (is_method(variable_struct_get(self, _name))) continue;

            variable_struct_set(self, _name, undefined);
        }
    }

    // --- PHASE 4: INITIALIZATION FINALIZE ---
    
    // Run initial grid build [4.1]
    
    set_grid(); 
    
    // Push instance to global list [4.2]
    
    array_push(global.grid_list, self); 
}