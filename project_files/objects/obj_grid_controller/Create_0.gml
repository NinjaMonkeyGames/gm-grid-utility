// GRID CONTROLLER OBJECT //

// Note: This is the order the code executes in not the order it is written necciserally. 

// 1.  Singleton guard.
// 2.  Declare globals.
// 3.  Initialise constructor.
// 4.  Set core variables.
// 5.  Import variables from constructor.
// 6.  Build vertex.
// 7.  Set grid. (Apply grid data).
// 8.  Push data to array.
// 9.  Execute step code.
// 10. Execute draw code.
// 11. Execute cleanup code. (On destruction of object).

// API

// - convert_letters
// - destroy


/// @description Singleton guard

if (variable_global_exists("controller") && instance_exists(global.controller))
{
	show_debug_message("A singleton pattern has been implemented for this object. Please don't call me again! RTFM");
	instance_destroy();
	exit;
}

global.controller   = id;        // Without this, the guard above can never trigger.
global.grid_list    = [];        // Stores array of grid structs
global.grid_vformat = undefined; // Shared vertex format for all grid instances

/**
 * @function grid
 * @description								Generates a 2D grid with row/column labels.
 * @param {Real}  [_x_offset]               Draw position (horizontal).
 * @param {Real}  [_y_offset]               Draw position (vertical).
 * @param {Real}  [_cell_width]             Width of a cell.
 * @param {Real}  [_cell_height]            Height of a cell.
 * @param {Real}  [_row_qty]                Number of rows.
 * @param {Real}  [_column_qty]             Number of columns.
 * @param {Bool}  [_label_text_type_row]    Row labels as letters (true) or numbers (false).
 * @param {Bool}  [_label_text_type_column] Column labels as letters (true) or numbers (false).
 * @param {Real}  [_grid_colour]            Colour of the grid lines.
 * @param {Real}  [_text_colour]            Colour of label text.
 * @param {Real}  [_text_selection_colour]  Colour of label text for selected cell.
 * @param {Real}  [_font]					Set grid text font.
 * @returns		  {Struct.grid}
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
	is_destroyed				= false; // Set true by destroy(). Public methods check this before running.

	label_text_grid_gap_column	= 6;
	label_text_grid_gap_row		= 12;

	vbuff						= -1;
	row_labels					= [];
	column_labels				= [];
	
	x_offset					= _x_offset;
	y_offset					= _y_offset;

	cell_width					= _cell_width;
	cell_height					= _cell_height;

	row_qty						= _row_qty;
	column_qty					= _column_qty;

	label_text_type_row			= _label_text_type_row;
	label_text_type_column		= _label_text_type_column;

	grid_colour					= _grid_colour;
	text_colour					= _text_colour;
	
	font						= _font;

	// Build the shared vertex format once, the first time any grid is created.

	if (is_undefined(global.grid_vformat))
	{
		vertex_format_begin();
		vertex_format_add_position();
		vertex_format_add_colour();

		global.grid_vformat = vertex_format_end();
	}

	/**
	 * @function set_grid
	 * @description Builds the label positions and the grid line vertex buffer. Safe to call again after changing any grid property.
	 */

	static set_grid = function()
	{
		if (is_destroyed) return; // Prevents error if called mid deletion.

		// Reset anything from a previous build.

		row_labels    = [];
		column_labels = [];

		if (vbuff != -1)
		{
			vertex_delete_buffer(vbuff);
			vbuff = -1;
		}

		// Measure labels with the same font that draw() will use.

		var _old_font = draw_get_font();
		draw_set_font(font);

		var _gx1 = x_offset;
		var _gy1 = y_offset;
		var _gx2 = x_offset + (column_qty * cell_width);
		var _gy2 = y_offset + (row_qty * cell_height);

		// Row labels (left of the grid).

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

		// Column labels (above the grid).

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

		draw_set_font(_old_font);

		// Grid lines.

		vbuff = vertex_create_buffer();
		vertex_begin(vbuff, global.grid_vformat);
		
		// Row
		
		for (var _row = 0; _row <= row_qty; ++_row)
		{
			var _y = y_offset + (_row * cell_height);

			vertex_position(vbuff, _gx1, _y); vertex_colour(vbuff, grid_colour, 1);
			vertex_position(vbuff, _gx2, _y); vertex_colour(vbuff, grid_colour, 1);
		}
		
		// Column

		for (var _column = 0; _column <= column_qty; ++_column)
		{
			var _x = x_offset + (_column * cell_width);

			vertex_position(vbuff, _x, _gy1); vertex_colour(vbuff, grid_colour, 1);
			vertex_position(vbuff, _x, _gy2); vertex_colour(vbuff, grid_colour, 1);
		}

		vertex_end(vbuff);
		vertex_freeze(vbuff);
	}

	/**
	 * @function convert_letters
	 * @description Converts a number to a letter label, as on an atlas or spreadsheet (0 = A, 25 = Z, 26 = AA).
	 * @param {Real} _number The number to convert.
	 * @returns {String}
	 */

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

	static step = function()
	{
		
	}

	/**
	 * @function draw
	 * @description Draws the labels and the grid lines.
	 */

	static draw = function()
	{
		//if (is_destroyed) return;  // Prevents error if called mid deletion.

		//// Save the caller's draw state.

		//var _old_colour = draw_get_colour();
		//var _old_font   = draw_get_font();
		//var _old_halign = draw_get_halign();
		//var _old_valign = draw_get_valign();

		//draw_set_colour(text_colour);
		//draw_set_font(font);
		//draw_set_halign(fa_left);
		//draw_set_valign(fa_top);

		//// Row labels (left of the grid).

		//for (var _i = 0; _i < array_length(row_labels); ++_i)
		//{
		//	draw_text(row_labels[_i].x, row_labels[_i].y, row_labels[_i].text);
		//}

		//// Column labels (above the grid).

		//for (var _i = 0; _i < array_length(column_labels); ++_i)
		//{
		//	draw_text(column_labels[_i].x, column_labels[_i].y, column_labels[_i].text);
		//}

		//// Restore the caller's draw state.

		//draw_set_colour(_old_colour);
		//draw_set_font(_old_font);
		//draw_set_halign(_old_halign);
		//draw_set_valign(_old_valign);

		//vertex_submit(vbuff, pr_linelist, -1);
	}

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

		is_destroyed = true; // Set before the wipe so the wipe can skip it.

		var _names = variable_struct_get_names(self);

		for (var _i = 0; _i < array_length(_names); ++_i)
		{
			var _name = _names[_i];

			if (_name == "is_destroyed") continue;
			if (is_method(variable_struct_get(self, _name))) continue;

			variable_struct_set(self, _name, undefined);
		}
	}

	set_grid();

	array_push(global.grid_list, self);
}