# Tool Tracking Skill

**Skill ID**: `nixbox.tool.tracking`
**Category**: Observability & Monitoring
**Complexity**: Intermediate

## Description

Track tool/function calls with structured metadata using Pydantic models. This skill enables LLM agents to record execution history, measure performance, analyze failures, and maintain audit trails of all operations.

## Capabilities

- Record tool invocations with parameters
- Track execution status (pending, success, error)
- Measure execution duration
- Store results and error messages
- Generate statistics per tool
- Query historical tool calls
- Analyze failure patterns

## Input Contract

### Required Models

```python
from nixbox import ToolCall, ToolCallStats
from datetime import datetime
```

### ToolCall Structure

```python
class ToolCall(BaseModel):
    id: int                           # Unique call identifier
    name: str                         # Tool/function name
    parameters: dict[str, Any]        # Input parameters
    result: Optional[dict[str, Any]]  # Success result
    error: Optional[str]              # Error message
    status: str                       # 'pending', 'success', or 'error'
    started_at: datetime              # Call start timestamp
    completed_at: Optional[datetime]  # Call completion timestamp
    duration_ms: Optional[float]      # Duration in milliseconds
```

### ToolCallStats Structure

```python
class ToolCallStats(BaseModel):
    name: str              # Tool/function name
    total_calls: int       # Total number of calls
    successful: int        # Number of successful calls
    failed: int            # Number of failed calls
    avg_duration_ms: float # Average duration in milliseconds
```

## Output Contract

### Success Metrics

- **Call Records**: Serialized `ToolCall` objects stored in AgentFS
- **Statistics**: Aggregated `ToolCallStats` for analysis
- **Audit Logs**: Complete history of all tool invocations
- **Performance Data**: Duration measurements for optimization

### Storage Format

Tool calls can be stored in AgentFS as:
- **JSON files**: `/tools/calls/{timestamp}_{id}.json`
- **KV entries**: `tool_call:{id}` → serialized ToolCall
- **Statistics cache**: `/tools/stats/{tool_name}.json`

## Usage Examples

### Basic Tool Call Tracking

```python
from nixbox import ToolCall
from datetime import datetime

def track_tool_call(tool_name: str, params: dict):
    """Create a tracked tool call."""
    call = ToolCall(
        id=generate_unique_id(),
        name=tool_name,
        parameters=params,
        status="pending",
        started_at=datetime.now()
    )
    return call

# Usage
call = track_tool_call("search_web", {"query": "Python async"})
# ... execute tool ...
call.status = "success"
call.result = {"urls": ["http://..."]}
call.completed_at = datetime.now()
call.duration_ms = (call.completed_at - call.started_at).total_seconds() * 1000
```

### Decorator Pattern

```python
import functools
from datetime import datetime
from nixbox import ToolCall

def track_execution(tool_name: str):
    """Decorator to track function execution."""
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            call = ToolCall(
                id=generate_unique_id(),
                name=tool_name,
                parameters={"args": args, "kwargs": kwargs},
                status="pending",
                started_at=datetime.now()
            )

            try:
                result = await func(*args, **kwargs)
                call.status = "success"
                call.result = {"data": result}
                return result
            except Exception as e:
                call.status = "error"
                call.error = str(e)
                raise
            finally:
                call.completed_at = datetime.now()
                call.duration_ms = (
                    call.completed_at - call.started_at
                ).total_seconds() * 1000
                await save_tool_call(call)

        return wrapper
    return decorator

# Usage
@track_execution("fetch_data")
async def fetch_data(url: str):
    # ... implementation ...
    pass
```

### Context Manager Pattern

```python
from contextlib import asynccontextmanager
from datetime import datetime
from nixbox import ToolCall

@asynccontextmanager
async def tracked_tool(name: str, params: dict):
    """Context manager for tracked tool execution."""
    call = ToolCall(
        id=generate_unique_id(),
        name=name,
        parameters=params,
        status="pending",
        started_at=datetime.now()
    )

    try:
        yield call
        call.status = "success"
    except Exception as e:
        call.status = "error"
        call.error = str(e)
        raise
    finally:
        call.completed_at = datetime.now()
        call.duration_ms = (
            call.completed_at - call.started_at
        ).total_seconds() * 1000
        await save_tool_call(call)

# Usage
async with tracked_tool("web_search", {"query": "LLM agents"}) as call:
    results = await perform_search(call.parameters["query"])
    call.result = {"count": len(results), "items": results}
```

### Persistence with AgentFS

```python
from agentfs_sdk import AgentFS
from nixbox import AgentFSOptions, ToolCall
import json

async def save_tool_call(call: ToolCall):
    """Save tool call to AgentFS."""
    async with await AgentFS.open(AgentFSOptions(id="tracker")) as agent:
        # Store as JSON file
        filename = f"/tools/calls/{call.started_at.isoformat()}_{call.id}.json"
        content = call.model_dump_json(indent=2)
        await agent.fs.write_file(filename, content)

async def load_tool_calls(tool_name: Optional[str] = None) -> list[ToolCall]:
    """Load tool calls from AgentFS."""
    from nixbox import View, ViewQuery

    async with await AgentFS.open(AgentFSOptions(id="tracker")) as agent:
        view = View(agent=agent, query=ViewQuery(
            path_pattern="/tools/calls/*.json",
            include_content=True
        ))
        files = await view.load()

        calls = []
        for file in files:
            if file.content:
                call = ToolCall.model_validate_json(file.content)
                if tool_name is None or call.name == tool_name:
                    calls.append(call)

        return calls
```

### Statistics Generation

```python
from nixbox import ToolCallStats
from collections import defaultdict

async def generate_tool_stats() -> dict[str, ToolCallStats]:
    """Generate statistics for all tools."""
    calls = await load_tool_calls()

    # Aggregate by tool name
    stats_data = defaultdict(lambda: {
        "total": 0,
        "successful": 0,
        "failed": 0,
        "durations": []
    })

    for call in calls:
        data = stats_data[call.name]
        data["total"] += 1

        if call.status == "success":
            data["successful"] += 1
        elif call.status == "error":
            data["failed"] += 1

        if call.duration_ms is not None:
            data["durations"].append(call.duration_ms)

    # Create ToolCallStats objects
    stats = {}
    for name, data in stats_data.items():
        avg_duration = (
            sum(data["durations"]) / len(data["durations"])
            if data["durations"] else 0.0
        )
        stats[name] = ToolCallStats(
            name=name,
            total_calls=data["total"],
            successful=data["successful"],
            failed=data["failed"],
            avg_duration_ms=avg_duration
        )

    return stats
```

### Analysis and Reporting

```python
async def analyze_tool_performance():
    """Analyze and report tool performance."""
    stats = await generate_tool_stats()

    print("Tool Performance Report")
    print("=" * 60)

    for name, stat in sorted(stats.items()):
        success_rate = (
            stat.successful / stat.total_calls * 100
            if stat.total_calls > 0 else 0
        )

        print(f"\n{name}:")
        print(f"  Total calls:    {stat.total_calls}")
        print(f"  Successful:     {stat.successful}")
        print(f"  Failed:         {stat.failed}")
        print(f"  Success rate:   {success_rate:.1f}%")
        print(f"  Avg duration:   {stat.avg_duration_ms:.2f}ms")

        # Flag slow or failing tools
        if stat.avg_duration_ms > 1000:
            print(f"  ⚠️  Slow tool (>{1000}ms average)")
        if success_rate < 90:
            print(f"  ⚠️  High failure rate (<90%)")
```

## Error Handling Patterns

### Graceful Failure Tracking

```python
async def execute_with_tracking(tool_name: str, func, *args, **kwargs):
    """Execute function with tracking, even if tracking fails."""
    call = None

    try:
        # Create tracking record
        call = ToolCall(
            id=generate_unique_id(),
            name=tool_name,
            parameters={"args": args, "kwargs": kwargs},
            status="pending",
            started_at=datetime.now()
        )
    except Exception as e:
        print(f"Failed to create tracking record: {e}")
        # Continue execution even if tracking fails

    try:
        result = await func(*args, **kwargs)

        if call:
            call.status = "success"
            call.result = {"data": result}

        return result

    except Exception as e:
        if call:
            call.status = "error"
            call.error = str(e)
        raise

    finally:
        if call:
            call.completed_at = datetime.now()
            call.duration_ms = (
                call.completed_at - call.started_at
            ).total_seconds() * 1000

            try:
                await save_tool_call(call)
            except Exception as e:
                print(f"Failed to save tracking record: {e}")
```

## Integration Examples

### LLM Agent Integration

```python
class TrackedAgent:
    """LLM agent with tool call tracking."""

    def __init__(self):
        self.tools = {
            "search": self.search,
            "calculate": self.calculate,
            "summarize": self.summarize
        }

    async def execute_tool(self, tool_name: str, params: dict):
        """Execute a tool with tracking."""
        async with tracked_tool(tool_name, params) as call:
            if tool_name not in self.tools:
                raise ValueError(f"Unknown tool: {tool_name}")

            result = await self.tools[tool_name](**params)
            call.result = result
            return result

    async def search(self, query: str):
        # ... implementation ...
        pass

    async def calculate(self, expression: str):
        # ... implementation ...
        pass

    async def summarize(self, text: str):
        # ... implementation ...
        pass
```

### Performance Monitoring

```python
import asyncio
from datetime import datetime, timedelta

async def monitor_tool_performance():
    """Monitor tool performance in real-time."""
    while True:
        # Get calls from last hour
        one_hour_ago = datetime.now() - timedelta(hours=1)
        recent_calls = await load_tool_calls()
        recent_calls = [
            c for c in recent_calls
            if c.started_at >= one_hour_ago
        ]

        # Calculate metrics
        total = len(recent_calls)
        failed = sum(1 for c in recent_calls if c.status == "error")
        avg_duration = sum(
            c.duration_ms for c in recent_calls if c.duration_ms
        ) / total if total > 0 else 0

        print(f"[{datetime.now()}] Calls: {total}, "
              f"Failed: {failed}, Avg: {avg_duration:.2f}ms")

        # Alert if failure rate is high
        if total > 10 and failed / total > 0.1:
            print("⚠️  High failure rate detected!")

        await asyncio.sleep(60)  # Check every minute
```

## Best Practices

1. **Always record start time**: Create ToolCall immediately before execution
2. **Use try/finally for completion**: Ensure completed_at is always set
3. **Include context in parameters**: Store enough info to reproduce the call
4. **Limit result size**: Truncate large results to prevent storage bloat
5. **Use unique IDs**: Ensure IDs are globally unique (timestamp + counter/UUID)
6. **Batch writes**: Don't save every call immediately in high-throughput scenarios
7. **Archive old data**: Periodically move old calls to compressed archives
8. **Monitor statistics**: Track trends over time to detect issues

## Performance Considerations

### Storage Overhead

- Each ToolCall: ~1-5KB (depending on parameters/results)
- 1000 calls/hour: ~5MB/hour
- Recommendation: Archive calls older than 7 days

### Tracking Overhead

- Minimal CPU impact: <1ms per call
- I/O impact: Depends on storage backend (AgentFS is async)
- Network impact: Local HTTP requests (~1ms)

### Optimization Strategies

1. **Async writes**: Don't block on `save_tool_call()`
2. **Batch updates**: Group multiple saves into one write
3. **Lazy statistics**: Calculate on-demand, not per-call
4. **Sampling**: Track only 10% of high-frequency tools

## Related Skills

- `nixbox.filesystem.query` - Query stored tool call records
- `nixbox.environment.setup` - Set up tracking infrastructure
- `nixbox.data.export` - Export tool call data for analysis

## Version History

- **v0.1.0** (2024-01): Initial skill definition
  - Basic call tracking
  - Statistics generation
  - Decorator and context manager patterns
  - AgentFS integration
