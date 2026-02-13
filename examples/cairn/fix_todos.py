"""Example agent: Fix TODO comments in code.

This demonstrates:
- Content search using regex
- Processing multiple files
- Using LLM for implementation
- Tracking changed files
"""

# Search for TODO comments
results = search_content("TODO", ".")
changed_files = []

# Group by file
files_with_todos = {}
for result in results:
    file = result["file"]
    if file not in files_with_todos:
        files_with_todos[file] = []
    files_with_todos[file].append(result["text"])

# Process each file
for file_path, todo_lines in files_with_todos.items():
    log(f"Processing {file_path} with {len(todo_lines)} TODOs")

    # Read file
    content = read_file(file_path)

    # Ask LLM to implement TODOs
    prompt = f"Implement these TODO items:\n" + "\n".join(todo_lines)
    new_content = ask_llm(prompt, content)

    # Write updated file
    write_file(file_path, new_content)
    changed_files.append(file_path)
    log(f"Fixed TODOs in {file_path}")

# Submit result
if changed_files:
    submit_result(f"Fixed TODOs in {len(changed_files)} files", changed_files)
else:
    submit_result("No TODO comments found", [])
