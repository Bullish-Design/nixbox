"""Example agent: Add type hints to Python functions.

This demonstrates:
- File pattern matching
- Analyzing code structure
- LLM-based code improvement
- File modification
"""

# Find Python files
py_files = search_files("*.py")
changed_files = []

for file_path in py_files:
    # Skip test files
    if "test_" in file_path:
        continue

    log(f"Checking {file_path}")

    # Read file
    content = read_file(file_path)

    # Check if file has functions without type hints
    if "def " in content and "->" not in content:
        log(f"Adding type hints to {file_path}")

        # Ask LLM to add type hints
        prompt = "Add type hints to all function parameters and return types"
        new_content = ask_llm(prompt, content)

        # Write modified file
        write_file(file_path, new_content)
        changed_files.append(file_path)
        log(f"Added type hints to {file_path}")

# Submit result
if changed_files:
    submit_result(
        f"Added type hints to {len(changed_files)} files", changed_files
    )
else:
    submit_result("All files already have type hints", [])
