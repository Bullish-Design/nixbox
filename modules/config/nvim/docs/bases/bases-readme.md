# bases.nvim

Obsidian Bases integration for Neovim. Parse, filter, sort, and display data from [Obsidian Bases](https://github.com/SkepticMystic/obsidian-bases) `.base` files.

## Features

### Core Library

- 📄 **Parse `.base` YAML files** - Full support for Bases file format
- 🔍 **Filter expressions** - Evaluate Bases filter syntax against data
- 🔢 **Sorting** - Multi-column sorting with ASC/DESC
- 🧪 **Well-tested** - Comprehensive test suite
- 🔌 **Plugin-friendly** - Clean API for other plugins to use

### Enhanced UI (Optional)

- 📊 **Multiple table modes** - nui (interactive), unicode (formatted), or virtual (overlay)
- 🎯 **Quick-access navigation** - Type a-z for instant row selection
- 🎨 **Unicode rendering** - Beautiful tables with box drawing characters
- 📱 **Pagination** - Handles 1000+ rows with 50-row pages
- 🌈 **Smart highlighting** - Alternating row colors, NULL value indicators
- 🎯 **Picker integration** - View selector with Snacks/Telescope support

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  dir = "~/path/to/bases.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim", -- Required for table views
  },
}
```

## Usage

### Basic Example

```lua
local bases = require("bases")

-- Parse a .base file
local data, err = bases.parse_file("~/vault/Views/tasks.base")

-- Scan directory for views
local views, err = bases.scan_views("~/vault/Views")

-- Filter data
local filtered = bases.filter(tasks, {
  ['and'] = {
    'status == "open"',
    'priority == "high"'
  }
})

-- Query with filtering and sorting
local results = bases.query({
  data = tasks,
  filter = view.filters,
  sort = {{ column = "due", direction = "ASC" }}
})
```

### Bases File Format

```yaml
filters:
  and:
    - note.type == "task"

views:
  - type: tasknotesTaskList
    name: "High Priority"
    filters:
      and:
        - priority == "high"
        - status != "done"
    order:
      - status
      - priority
      - due
    sort:
      - column: due
        direction: ASC
```

### Supported Filter Expressions

#### Property Comparisons

- `property == "value"` - Equality
- `property != "value"` - Inequality
- `note.type == "task"` - Property paths
- `file.tags.contains("tag")` - Array membership

#### Property Methods

- `property.isEmpty()` - Check if nil or empty
- `property.isEmpty() != true` - Check if NOT empty
- `property.contains("value")` - Array contains
- `property.contains("archived") == false` - Array doesn't contain

#### Date Functions

- `date(due) < today()` - Past dates
- `date(due) == today()` - Today
- `date(due) <= today()` - Today or before
- `date(due) >= today()` - Today or after

#### Logical Operators

- `and: [...]` - All conditions must be true
- `or: [...]` - Any condition must be true
- Nested logic supported

## API Reference

### Core Functions

#### `bases.parse_file(filepath)`

Parse a single `.base` file.

```lua
local data, err = bases.parse_file("path/to/file.base")
-- Returns: { filters = {...}, views = [...] }
```

#### `bases.scan_views(views_dir, opts?)`

Scan directory for all `.base` files and extract views.

```lua
local views, err = bases.scan_views("~/vault/Views", {
  view_type = "tasknotesTaskList" -- Optional filter
})
-- Returns: { ["filename:viewname"] = view_object }
```

#### `bases.get_view(view_id, views_dir, opts?)`

Get a specific view by ID.

```lua
local view, err = bases.get_view("tasks-default:Today", "~/vault/Views")
```

#### `bases.evaluate(filter, data_object)`

Evaluate filter expression against a single data object.

```lua
local matches = bases.evaluate(filter_spec, task)
-- Returns: boolean
```

#### `bases.query(opts)`

Filter and sort data in one operation.

```lua
local results = bases.query({
  data = data_array,
  filter = filter_spec,
  sort = sort_spec
})
```

### UI Components

#### `bases.ui.table(opts)`

Show table view in interactive, unicode, or virtual mode.

**Mode Selection**:

- `mode = "nui"` (default) - Interactive nui.table with mouse support
- `mode = "unicode"` - Unicode-bordered table with quick-access keys (a-z)
- `mode = "virtual"` - Virtual text overlay (non-intrusive)

**Basic Usage (nui mode)**:

```lua
bases.ui.table({
  data = data_array,
  view_spec = {
    order = {"title", "status", "due"},
    sort = {{ column = "due", direction = "ASC" }},
  },
  on_select = function(row)
    print("Selected:", row.title)
  end,
  title = "My View"
})
```

**Unicode Mode with Quick-Access**:

```lua
bases.ui.table({
  data = results,
  view_spec = view,
  mode = "unicode",           -- Use Unicode box drawing
  enable_quick_access = true, -- Enable a-z navigation
  max_line_length = 80,       -- Fold long columns
  show_alternating_colors = true,
  on_select = function(row)
    vim.cmd("edit " .. row.path)
  end
})
```

**Virtual Mode (Overlay)**:

```lua
bases.ui.table({
  data = results,
  mode = "virtual",
  line = vim.api.nvim_win_get_cursor(0)[1],
  virt_lines_above = false,   -- Display below cursor
})
```

**Pagination (Auto-enabled for 50+ rows)**:

```lua
bases.ui.table({
  data = large_dataset,
  mode = "unicode",
  pagination = {
    enabled = true,
    page_size = 50,
  },
  -- Use 'n' for next page, 'p' for previous, 'i' for page info
})
```

#### `bases.ui.picker(opts)`

Show view selector picker.

```lua
bases.ui.picker({
  views_dir = "~/vault/Views",
  view_type = "tasknotesTaskList", -- Optional
  on_select = function(view_id, view)
    print("Selected view:", view.name)
  end,
  prompt = "Select View",
  backend = "snacks" -- or "telescope" or nil (auto-detect)
})
```

#### `bases.ui.floats` - Floating Window Utilities

Utility functions for creating floating windows with selection menus, input prompts, and hover tooltips.

**`bases.ui.floats.select(items, opts, on_select)`**

Create a selection menu in a floating window.

```lua
local items = { "Option 1", "Option 2", "Option 3" }
local winid = bases.ui.floats.select(items, {
  title = "Choose an option",
  width = 40,
  max_height = 15,
  format_item = function(item) return "• " .. item end,
}, function(idx, item)
  print("Selected:", idx, item)
end)

-- Keymaps:
--   q/<Esc> - Close without selecting
--   <CR>    - Select item under cursor
--   1-9     - Quick select by number
```

**`bases.ui.floats.input(prompt, opts, on_confirm)`**

Create an input prompt in a floating window.

```lua
bases.ui.floats.input("Enter task title:", {
  default = "New task",
}, function(text)
  print("User entered:", text)
end)

-- Keymaps:
--   <CR> (insert mode) - Confirm input
--   <Esc>              - Cancel
```

**`bases.ui.floats.hover(content, opts)`**

Display hover information near the cursor.

```lua
-- String content
bases.ui.floats.hover("This is hover text", {
  max_width = 80,
  max_height = 20,
  anchor = "NE", -- Position relative to cursor
})

-- Multi-line content
bases.ui.floats.hover({
  "Line 1",
  "Line 2",
  "Line 3"
}, { max_width = 60 })

-- Keymaps:
--   q/<Esc> - Close hover
```

## Development

### Running Tests

```bash
# Run all tests
just test

# Run specific test file
just test-file tests/test_parser.lua

# Run core tests
just test-parser
just test-evaluator

# Run UI tests (new)
just test-ui              # All UI tests
just test-highlighters    # Color/highlight generation
just test-quick-access    # Keyboard navigation
just test-formatters      # Unicode table rendering
just test-renderer        # Virtual text rendering
just test-ui-floats       # Floating windows
just test-ui-common       # Common utilities
```

### Project Structure

```
lua/bases/
├── init.lua              # Main API
├── parser.lua            # .base file parser
├── evaluator.lua         # Expression evaluator
├── query.lua             # Filter/sort engine
├── types.lua             # Central type definitions
├── config.lua            # Configuration validation
├── health.lua            # Health check implementation
└── ui/
    ├── init.lua          # UI module exports
    ├── table.lua         # Table display (nui/unicode/virtual modes)
    ├── picker.lua        # View selector
    ├── common.lua        # Shared buffer/window utilities
    ├── floats.lua        # Floating windows (select/input/hover)
    ├── renderer.lua      # Virtual text rendering
    ├── formatters.lua    # Unicode table formatting
    ├── quick_access.lua  # a-z keyboard navigation
    └── highlighters.lua  # Color/highlight generation

tests/
├── test_parser.lua
├── test_evaluator.lua
├── test_config.lua
├── test_ui_common.lua
├── test_ui_floats.lua
├── test_highlighters.lua
├── test_quick_access.lua
├── test_formatters.lua
├── test_renderer.lua
└── helpers.lua
```

## Enhanced UI Features

### Quick-Access Navigation

Press `<leader>j` (configurable) to activate quick-access mode, then type:

- `a` through `z` - Select rows 1-26
- `aa`, `ab`, ... - Select rows 27+
- `ESC` - Cancel
- Auto-selects when unique match found

Example:

```
┌────────────┬──────────┐
│ a Task 1   │ open     │
│ b Task 2   │ pending  │
│ c Task 3   │ done     │
└────────────┴──────────┘

Type "a" → Row 1 selected
Type "ab" → Row 28 selected (if it exists)
```

### Unicode Table Rendering

Beautiful Unicode box drawing with automatic column width calculation:

- Alternating row colors for readability
- NULL value highlighting (shown as "NULL")
- Line folding for columns exceeding max_length
- Performance-optimized width caching

### Pagination

Automatically enabled for datasets with 50+ rows:

- **n** - Next page
- **p** - Previous page
- **i** - Show page info
- Configurable page size

### Virtual Text Mode

Non-intrusive overlay rendering using Neovim extmarks:

- Display above or below cursor
- Template-based variable interpolation
- Perfect for inline previews

## Integration Examples

### TaskNotes Plugin

```lua
-- In your plugin's dependency list
dependencies = {
  "bases.nvim",
}

-- Use bases for view filtering
local bases = require("bases")
local view = bases.get_view(view_id, views_dir, {
  view_type = "tasknotesTaskList"
})

local filtered_tasks = bases.query({
  data = all_tasks,
  filter = view.filters,
  sort = view.sort
})
```

### Generic Note Browser

```lua
local bases = require("bases")

-- Load all notes
local notes = load_markdown_files("~/vault")

-- Show table view
bases.ui.table({
  data = notes,
  view_spec = {
    order = {"title", "date", "tags"},
    sort = {{ column = "date", direction = "DESC" }},
    filter = {
      ['and'] = {
        'file.tags.contains("project")',
        'date(dateModified) >= today()'
      }
    }
  },
  on_select = function(note)
    vim.cmd("edit " .. note.path)
  end
})
```

## Requirements

- Neovim >= 0.9.0
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) (for table views)
- Optional: [Snacks.nvim](https://github.com/folke/snacks.nvim) or [Telescope](https://github.com/nvim-telescope/telescope.nvim) (for picker)
- Optional: `yq` command-line tool (for more robust YAML parsing)

## License

MIT

## Related

- [Obsidian Bases](https://github.com/SkepticMystic/obsidian-bases) - Original Obsidian plugin
- [tasknotes.nvim](https://github.com/edmundmiller/tasknotes.nvim) - Task management with Obsidian
- [obsidian.nvim](https://github.com/epwalsh/obsidian.nvim) - Obsidian integration for Neovim
