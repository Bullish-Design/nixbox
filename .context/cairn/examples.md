# examples.md
# Example Agent Tasks and Generated Code

## Example 1: Add Docstrings

**Task:**
```
Add docstrings to all functions that don't have them in Python files
```

**Expected Generated Code:**
```python
# Find all Python files
files = search_files("*.py")

for file_path in files:
    log(f"Processing {file_path}")

    # Read the file
    content = read_file(file_path)

    # Check if any functions lack docstrings
    lines = content.split("\n")
    needs_docstrings = False

    for i, line in enumerate(lines):
        if line.strip().startswith("def ") and i + 1 < len(lines):
            next_line = lines[i + 1].strip()
            if not next_line.startswith('"""') and not next_line.startswith("'''"):
                needs_docstrings = True
                break

    if needs_docstrings:
        # Ask LLM to add docstrings
        new_content = ask_llm(
            "Add Google-style docstrings to all functions. "
            "Keep the original code unchanged except for adding docstrings.",
            content
        )

        # Write the modified content
        write_file(file_path, new_content)
        log(f"Updated {file_path} with docstrings")

# Submit the results
submit_result("Added docstrings to functions", files)
```

## Example 2: Fix TODO Comments

**Task:**
```
Find all TODO comments and implement them
```

**Expected Generated Code:**
```python
# Search for files with TODO comments
files = search_files("TODO")

changed_files = []

for file_path in files:
    log(f"Found TODOs in {file_path}")

    content = read_file(file_path)

    # Extract TODO comments
    todos = []
    for line in content.split("\n"):
        if "TODO" in line:
            todos.append(line.strip())

    if todos:
        # Ask LLM to implement TODOs
        todo_list = "\n".join(todos)
        prompt = f"Implement these TODO items:\n{todo_list}\n\nHere's the current file:"

        new_content = ask_llm(prompt, content)

        # Write the updated file
        write_file(file_path, new_content)
        changed_files.append(file_path)
        log(f"Implemented TODOs in {file_path}")

submit_result(f"Implemented {len(changed_files)} TODO items", changed_files)
```

## Example 3: Add Type Hints

**Task:**
```
Add type hints to function parameters and return types
```

**Expected Generated Code:**
```python
files = search_files("*.py")
changed = []

for file_path in files:
    content = read_file(file_path)

    # Check if file has untyped functions
    has_untyped = False
    for line in content.split("\n"):
        if "def " in line and "->" not in line and "(" in line:
            has_untyped = True
            break

    if has_untyped:
        new_content = ask_llm(
            "Add type hints to all function parameters and return types. "
            "Use typing module imports as needed. "
            "Infer types from usage context.",
            content
        )

        write_file(file_path, new_content)
        changed.append(file_path)

submit_result("Added type hints", changed)
```

## Example 4: Refactor Long Functions

**Task:**
```
Split any function longer than 50 lines into smaller functions
```

**Expected Generated Code:**
```python
files = search_files("*.py")
refactored = []

for file_path in files:
    content = read_file(file_path)
    lines = content.split("\n")

    # Track function lengths
    current_func = None
    current_func_start = 0
    current_func_lines = 0

    needs_refactor = False

    for i, line in enumerate(lines):
        if line.strip().startswith("def "):
            if current_func and current_func_lines > 50:
                needs_refactor = True
                break
            current_func = line
            current_func_start = i
            current_func_lines = 0
        elif current_func and not line.startswith(" ") and line.strip():
            # End of function
            if current_func_lines > 50:
                needs_refactor = True
                break
            current_func = None
        elif current_func:
            current_func_lines += 1

    if needs_refactor:
        new_content = ask_llm(
            "Refactor any functions longer than 50 lines into smaller helper functions. "
            "Keep the same functionality but improve modularity.",
            content
        )

        write_file(file_path, new_content)
        refactored.append(file_path)
        log(f"Refactored {file_path}")

submit_result(f"Refactored {len(refactored)} files", refactored)
```

## Example 5: Update Imports

**Task:**
```
Replace all `from typing import List, Dict` with `from __future__ import annotations` and native types
```

**Expected Generated Code:**
```python
files = search_files("*.py")
updated = []

for file_path in files:
    content = read_file(file_path)

    # Check if file has old-style typing imports
    if "from typing import" in content and "List" in content:
        new_content = ask_llm(
            "Replace old-style typing imports (List, Dict, Optional) with:\n"
            "1. Add 'from __future__ import annotations' at the top\n"
            "2. Use native types: list, dict, | None\n"
            "Keep all other imports and code unchanged.",
            content
        )

        write_file(file_path, new_content)
        updated.append(file_path)

submit_result("Updated typing imports to modern syntax", updated)
```

## Example 6: Add Error Handling

**Task:**
```
Add try-except blocks around file operations and network calls
```

**Expected Generated Code:**
```python
files = search_files("*.py")
updated_files = []

for file_path in files:
    content = read_file(file_path)

    # Check for unprotected operations
    needs_error_handling = False

    dangerous_ops = ["open(", "read(", "write(", ".get(", ".post("]

    for op in dangerous_ops:
        if op in content and "try:" not in content:
            needs_error_handling = True
            break

    if needs_error_handling:
        new_content = ask_llm(
            "Add appropriate try-except error handling around:\n"
            "- File operations (open, read, write)\n"
            "- Network calls (requests, httpx)\n"
            "Use specific exception types and include logging.",
            content
        )

        write_file(file_path, new_content)
        updated_files.append(file_path)

submit_result("Added error handling", updated_files)
```

## Notes on Agent Code Quality

The LLM-generated code should be:

1. **Simple** - No classes, no fancy patterns
2. **Procedural** - Functions, loops, conditionals only
3. **Direct** - Use external functions, not stdlib
4. **Focused** - One task at a time
5. **Defensive** - Check before modifying

The orchestrator will reject code that:
- Uses `import`
- Defines classes
- Uses `open()`, `print()`, `exec()`
- Has infinite loops
- Exceeds memory limits

Monty's error messages are clear, so the agent can iterate:

```
Error: Cannot use 'import' statement
Error: Cannot call 'open' - not an external function
Error: Cannot define classes
Error: Execution timeout (5s limit)
```

The LLM can use these errors to refine the code.
