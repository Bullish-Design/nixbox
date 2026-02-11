# Filesystem Query Skill

**Skill ID**: `nixbox.filesystem.query`
**Category**: Filesystem Operations
**Complexity**: Intermediate

## Description

Query and filter files in an AgentFS sandboxed filesystem using type-safe Pydantic models and a powerful View/Query interface. This skill enables efficient file discovery, content loading, and metadata inspection without accessing the host filesystem.

## Capabilities

- Query files by glob patterns (`*.py`, `**/*.json`)
- Filter by regex patterns for complex matching
- Apply size constraints (min/max bytes)
- Load file content selectively
- Count files efficiently without loading content
- Use custom predicates for advanced filtering
- Chain operations with fluent API

## Input Contract

### Required Dependencies

```python
from nixbox import AgentFSOptions, View, ViewQuery
from agentfs_sdk import AgentFS
```

### Required Context

- AgentFS process running (via `devenv up` or `agentfs` command)
- Valid connection options (either `id` or `path`)

### Query Parameters

All parameters are optional with sensible defaults:

| Parameter         | Type           | Default | Description                              |
|-------------------|----------------|---------|------------------------------------------|
| `path_pattern`    | `str`          | `"*"`   | Glob pattern for file paths              |
| `recursive`       | `bool`         | `True`  | Search subdirectories recursively        |
| `include_content` | `bool`         | `False` | Load file contents into memory           |
| `include_stats`   | `bool`         | `True`  | Include file metadata (size, mtime)      |
| `regex_pattern`   | `Optional[str]`| `None`  | Additional regex filtering               |
| `max_size`        | `Optional[int]`| `None`  | Maximum file size in bytes               |
| `min_size`        | `Optional[int]`| `None`  | Minimum file size in bytes               |

## Output Contract

### Success Response

Returns `list[FileEntry]` where each entry contains:

```python
class FileEntry:
    path: str                           # File path in AgentFS
    stats: Optional[FileStats]          # Metadata (if include_stats=True)
    content: Optional[str | bytes]      # Content (if include_content=True)

class FileStats:
    size: int                           # Bytes
    mtime: datetime                     # Last modified timestamp
    is_file: bool                       # True if file
    is_directory: bool                  # True if directory
```

### Error Conditions

- **Connection Error**: AgentFS not running or unreachable
- **Invalid Pattern**: Malformed glob or regex pattern
- **Permission Error**: File access denied (rare in sandbox)
- **Memory Error**: Loading too many large files with `include_content=True`

## Usage Examples

### Basic Pattern Matching

```python
async with await AgentFS.open(AgentFSOptions(id="my-agent")) as agent:
    # Find all Python files
    view = View(agent=agent, query=ViewQuery(
        path_pattern="**/*.py",
        recursive=True
    ))
    python_files = await view.load()

    for file in python_files:
        print(f"{file.path}: {file.stats.size} bytes")
```

### Content Loading

```python
# Load configuration files with content
view = View(agent=agent, query=ViewQuery(
    path_pattern="**/*.json",
    include_content=True
))
config_files = await view.load()

for file in config_files:
    if file.content:
        config = json.loads(file.content)
        # Process configuration...
```

### Size Filtering

```python
# Find large files (> 1MB)
view = View(agent=agent, query=ViewQuery(
    path_pattern="**/*",
    min_size=1_048_576  # 1MB in bytes
))
large_files = await view.load()

print(f"Found {len(large_files)} files larger than 1MB")
```

### Regex Filtering

```python
# Find files in /src directory with .ts or .tsx extension
view = View(agent=agent, query=ViewQuery(
    path_pattern="**/*",
    regex_pattern=r"^/src/.*\.(ts|tsx)$"
))
typescript_files = await view.load()
```

### Fluent API

```python
# Chain operations for readable queries
json_configs = await (
    View(agent=agent)
    .with_pattern("**/config/*.json")
    .with_content(True)
    .load()
)
```

### Custom Predicates

```python
# Find files modified today
from datetime import datetime

view = View(agent=agent, query=ViewQuery(path_pattern="**/*"))
today = datetime.now().date()

recent_files = await view.filter(
    lambda f: f.stats and f.stats.mtime.date() == today
)
```

### Efficient Counting

```python
# Count files without loading content or stats
view = View(agent=agent, query=ViewQuery(path_pattern="**/*.py"))
total_python_files = await view.count()
print(f"Total Python files: {total_python_files}")
```

## Performance Considerations

### Memory Usage

- **Without content**: ~100 bytes per file (path + stats)
- **With content**: Varies by file size (keep `max_size` reasonable)
- **Recommendation**: Use `count()` first, then load in batches

### Query Optimization

1. **Narrow patterns**: `src/**/*.py` is faster than `**/*.py`
2. **Size filters**: Apply `max_size` to prevent memory issues
3. **Lazy loading**: Don't use `include_content=True` unless necessary
4. **Batch processing**: Filter → process → discard, not load-all-at-once

### Network Overhead

- AgentFS runs locally via HTTP (minimal latency)
- Each `load()` call makes 1+ HTTP requests
- Consider caching results if querying repeatedly

## Error Handling Patterns

### Connection Failure

```python
from agentfs_sdk import AgentFS

try:
    async with await AgentFS.open(AgentFSOptions(id="agent")) as agent:
        # Query operations...
        pass
except Exception as e:
    print(f"Failed to connect to AgentFS: {e}")
    print("Ensure AgentFS is running: devenv up")
```

### Pattern Validation

```python
import re

def validate_regex(pattern: str) -> bool:
    try:
        re.compile(pattern)
        return True
    except re.error:
        return False

if validate_regex(user_pattern):
    query = ViewQuery(regex_pattern=user_pattern)
else:
    print("Invalid regex pattern")
```

### Large Result Sets

```python
# Handle potentially large result sets
view = View(agent=agent, query=ViewQuery(path_pattern="**/*"))

# Option 1: Count first
count = await view.count()
if count > 10_000:
    print(f"Warning: {count} files match - consider narrowing query")

# Option 2: Filter by size first
small_files = await view.filter(lambda f: f.stats.size < 100_000)
```

## Integration Examples

### Code Analysis Agent

```python
async def analyze_python_imports():
    """Find all Python imports in the codebase."""
    async with await AgentFS.open(AgentFSOptions(id="analyzer")) as agent:
        view = View(agent=agent, query=ViewQuery(
            path_pattern="**/*.py",
            include_content=True,
            max_size=1_000_000  # Skip very large files
        ))
        files = await view.load()

        imports = set()
        for file in files:
            if file.content:
                # Extract imports using regex or AST parsing
                import_lines = [
                    line for line in file.content.split('\n')
                    if line.strip().startswith(('import ', 'from '))
                ]
                imports.update(import_lines)

        return sorted(imports)
```

### Documentation Generator

```python
async def generate_file_index():
    """Create an index of all documentation files."""
    async with await AgentFS.open(AgentFSOptions(id="docs")) as agent:
        view = View(agent=agent, query=ViewQuery(
            path_pattern="**/*.md",
            include_stats=True
        ))
        docs = await view.load()

        index = []
        for doc in docs:
            index.append({
                "path": doc.path,
                "size_kb": doc.stats.size // 1024 if doc.stats else 0,
                "modified": doc.stats.mtime.isoformat() if doc.stats else None
            })

        return index
```

## Best Practices

1. **Start narrow, widen if needed**: Begin with specific patterns, expand if no results
2. **Use size constraints**: Prevent memory issues with `max_size`
3. **Load content selectively**: Only set `include_content=True` when necessary
4. **Cache results**: Store query results if repeating the same query
5. **Validate inputs**: Check user-provided patterns before executing
6. **Handle empty results**: Always check `len(results) > 0`
7. **Document patterns**: Comment complex regex patterns for maintainability

## Related Skills

- `nixbox.environment.setup` - Setting up AgentFS environment
- `nixbox.tool.tracking` - Tracking filesystem operations as tool calls
- `nixbox.data.export` - Exporting query results to external formats

## Version History

- **v0.1.0** (2024-01): Initial skill definition
  - Basic query patterns
  - Size filtering
  - Content loading
  - Fluent API
