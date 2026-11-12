# DEVELOPER

- [DEVELOPER](#developer)
  - [Developer Documentation](#developer-documentation)
  - [BASIC STRUCTURE AND DESIGN PHILOSOPHY](#basic-structure-and-design-philosophy)
    - [API](#api)
  - [CODE SECTIONS](#code-sections)
    - [RM\_MAIN - CREATE](#rm_main---create)
      - [INITIALISE PROJECT](#initialise-project)
        - [Set window caption text](#set-window-caption-text)
      - [UNIT TESTING](#unit-testing)
      - [LOAD GRID CONTROLLER](#load-grid-controller)
    - [OBJ-GRID\_CONTROLLER - CREATE](#obj-grid_controller---create)
      - [Singleton guard](#singleton-guard)
      - [Declare globals](#declare-globals)
      - [Initialise constructor](#initialise-constructor)
      - [Set core variables](#set-core-variables)
      - [Build vertex](#build-vertex)
      - [Set grid](#set-grid)
      - [Set coordinate letters](#set-coordinate-letters)
      - [Push data to array](#push-data-to-array)
      - [Execute step code](#execute-step-code)
      - [Execute draw code](#execute-draw-code)
  - [CONTACT INFORMATION](#contact-information)
  - [COPYRIGHT](#copyright)

## Developer Documentation

This document serves as the **technical blueprint for this project**. While `CONTRIBUTING.md` outlines the *how-to* for
processes and standards, this guide focuses on the *why* and *what* of the system architecture, internal logic, and
codebase organisation.

🚨 *This code will not work on HTML5 when WebGL is disabled or not supported by the browser. WebGL can be allowed or set
to be required in the HTML5 Game Options under Graphics.*

*Note: Please refer to the **[CONTRIBUTING.md](CONTRIBUTING.md)** for information regarding coding style, pull request
processes, and commit message conventions.*

## BASIC STRUCTURE AND DESIGN PHILOSOPHY

As stated in 'CONTRIBUTING.md' this project follows MVC design principles.

The grid GameMaker object itself `obj_grid_controller` is setup with a singleton pattern protection built-in. This is
because each grid object can generate one or many grids from a single object instance.

ℹ️ *GameMaker has a high overhead for native objects. Using a constructor to generate grids on-the-fly is many times
more efficient.*

ℹ️ *For performance reasons the grid will be drawn using primitives.*

### API

The constructor is made up various static functions and methods which are used to build and manipulate the grid. It is
not intended for the data to be manipulated directly from outside the object.

| Type   | Parameter                | Default Value | Description                                       |
| :----- | :----------------------- | :------------ | :------------------------------------------------ |
| `Real` | `_x_offset`              | `32`          | Draw position (horizontal).                       |
| `Real` | `_y_offset`              | `32`          | Draw position (vertical).                         |
| `Real` | `_cell_width`            | `256`         | Width of a cell.                                  |
| `Real` | `_cell_height`           | `256`         | Height of a cell.                                 |
| `Real` | `_row_qty`               | `4`           | Number of rows.                                   |
| `Real` | `_column_qty`            | `6`           | Number of columns.                                |
| `Bool` | `_label_text_type_row`   | `false`       | Row labels as letters (true) or numbers (false).  |
| `Bool` | `_label_text_type_column`| `false`       | Column labels as letters (true) or numbers (false)|
| `Real` | `_grid_colour`           | `c_lime`      | Colour of the grid lines.                         |
| `Real` | `_text_colour`           | `c_white`     | Colour of label text.                             |

ℹ️ *Input colour for grid lines and text was set to real rather than constant because GM feather has an issue where it
  incorrectly identifies the colour data type as real.*

To generate a new grid simply type `example_grid = new obj_grid_controller.grid();`. If you leave all the arguments
blank it will use the defaults detailed in the table above.

## CODE SECTIONS

This section covers each section of code:

- rm_main - create
- obj_grid-controller - Create
- obj_grid-controller - Clean Up
- obj_grid-controller - Step
- obj_grid-controller - Draw
- obj_unit_test - Create

### RM_MAIN - CREATE

Code for initialising project.

#### INITIALISE PROJECT

This block of code sets the window caption text and runs unit tests if it detects it is running in a CI environment.

##### Set window caption text

Displays caption text + the version number in the title bar.

```js
window_set_caption("Grid Utility v" + GM_version);
```

#### UNIT TESTING

1. Stores a value to determine if the code is running in a CI environment.
2. Execute unit tests if CI environment is detected.

```js
global.debug_enabled = environment_get_variable("CI") != "";   
if global.debug_enabled == true then global.unit_test = instance_create_layer(0, 0, "lyr_gui", obj_unit_test);
```

#### LOAD GRID CONTROLLER

Loops through 2D array and populates with random example tile data.

```gml
var _frames    = sprite_get_number(spr_jungle_temple);
var _tile_data = [];

repeat (30) // Rows.
{
	var _row_tiles = [];

	repeat (33) // Columns.
	{
		array_push(_row_tiles,
		{
			sprite	: spr_jungle_temple,
			index	: irandom(_frames - 1),	
			angle	: 90,
			alpha	: 1
		});
	}

	array_push(_tile_data, _row_tiles);
}
```

Generate example grid.

```gml
example_grid = new obj_grid_controller.grid();
```

### OBJ-GRID_CONTROLLER - CREATE

1. Singleton guard.
2. Declare globals.
3. Initialise constructor.
4. Set core variables.
5. Import variables from constructor.
6. Build vertex.
7. Set grid. (Apply grid data).
8. Convert coordinate letters.
9. Push data to array.
10. Execute step code.
11. Execute draw code.
12. Execute cleanup code. (On destruction of object).

#### Singleton guard

This prevents multiple instances of the grid controller from being created. The constructor is the class that contains
the logic, the object itself is just a logical container.

#### Declare globals

| Variable             | Value       | Description                                     |
| :------------------- | :---------- | :---------------------------------------------- |
| `global.controller`  | `id`        | Without this, the guard above can never trigger.|
| `global.grid_list`   | `[]`        | Stores array of grid structs.                   |
| `global.grid_vformat`| `undefined` | Shared vertex format for all grid instances.    |

#### Initialise constructor

#### Set core variables

| Variable                    | Value                    | Description                                                 |
| :-------------------------- | :----------------------  | :---------------------------------------------------------- |
| `is_destroyed`              | `false`                  | Set true by destroy().                                      |
| `label_text_grid_gap_column`| `6`                      | The gap in pixels between the text and horizontal gridlines.|
| `label_text_grid_gap_row`   | `12`                     | The gap in pixels between the text and vertical gridlines.  |
| `vbuff`                     | `-1`                     | Vertex buffer.                                              |
| `row_labels`                | `[]`                     | Row label text.                                             |
| `column_labels`             | `[]`                     | Column label text.                                          |
| `x_offset`                  | `_x_offset`              | The number of pixels to offset the grid horizontally,       |
|                             |                          | relative to the surface its been drawn.                     |
| `y_offset`                  | `_y_offset`              | The number of pixels to offset the grid vertically,         |
|                             |                          | relative to the surface its been drawn.                     |
| `cell_width`                | `_cell_width`            | Width in pixels of each drawn cell.                         |
| `cell_height`               | `_cell_height`           | Height in pixels of each drawn cell.                        |
| `row_qty`                   | `_row_qty`               | Number of cells to draw vertically.                         |
| `column_qty`                | `_column_qty`            | Number of cells to draw horizontally.                       |
| `label_text_type_row`       | `_label_text_type_row`   | Determines if letters or numbers should be used for         |
|                             |                          | row label text.                                             |
| `label_text_type_column`    | `_label_text_type_column`| Determines if letters or numbers should be used for         |
|                             |                          | column label text.                                          |
| `grid_colour`               | `_grid_colour`           | Colour to draw grid lines.                                  |
| `text_colour`               | `_text_colour`           | Colour to draw text.                                        |
| `font`                      | `_font`                  | Font to use for coordinate text.                            |

#### Build vertex

Build vertex data and assign it to `global.grid_vformat`.

#### Set grid

1. Check destroyed status.
2. Clear any existing data.
3. Store previous font.
4. Set new font.
5. Set initial vectors.
6. Create row labels.
7. Create Column labels.
8. Reapply old font.
9. Setup vertex buffer.
10. Draw row.
11. Draw column.
12. Finalise vertex buffer.

#### Set coordinate letters

Converts a number to a letter label, as on an atlas or spreadsheet (0 = A, 25 = Z, 26 = AA)

```gml
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
  ```

#### Push data to array

Push entire constructor to `global.grid_list`.

#### Execute step code

This object has been designed in such a way that the step code is not strictly required because the logic is agnostic in
regards to control.

For example you can request via API that you want to shift the grid to the left. The grid component does not care that a
key was pressed on a keyboard or a button pressed on a controller. All the grid component cares about is performing the
action.

Having said that the step code does provide an example of how this can be done. You will notice it calls internal
methods to perform actions and does not directly modify the data itself directly.

#### Execute draw code

This section is responsible for drawing what has been submitted to the vertex buffer.

1. Check destroyed status.
2. Preserve old draw states.
3. Set new draw states.
4. Draw row labels.
5. Draw column labels.
6. Restore old draw state.
7. Submit vertex buffer.

## CONTACT INFORMATION

Author: Daniel Mallett (Monkey Knuckles)

If you have any problems with the repository or have any suggestions please contact us at <info@ninjamonkeygames.com>.

You may also contact us via our [website](https://ninjamonkeygames.com).

Any bugs should be raised as an [issue](https://github.com/NinjaMonkeyGames/project-name-here/issues) on GitHub.

---

## COPYRIGHT

*NinjaMonkeyGames™ Copyright © 2026 All rights reserved.*
