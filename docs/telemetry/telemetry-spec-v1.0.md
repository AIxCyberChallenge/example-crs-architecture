# OpenTelemetry Semantic Specification for OTEL
https://opentelemetry.io/docs/specs/semconv/gen-ai/

## Resource Attributes

These attributes describe the overarching context of the telemetry data.

| Attribute Key | Type   | Description                          |
|--------------|--------|--------------------------------------|
| `team.id`   | string | Unique identifier for the team.     |
| `team.name` | string | Name of the team.                   |

## Span Attributes

These attributes capture the details of individual tasks or activities.

### Mandatory Attributes

| Attribute Key            | Type      | Description                                                                                  |
|--------------------------|-----------|----------------------------------------------------------------------------------------------|
| `task.category`         | string    | Category of the task. Values: `static_analysis`, `dynamic_analysis`, `fuzzing`, `program_analysis`, `building`, `input_generation`, `patch_generation`, `testing`, `scoring_submission`. |
| `task.name`             | string    | Descriptive name of the task. User-defined unless otherwise agreed upon.                     |
| `task.timestamp.current` | datetime  | Current time when the telemetry is recorded.                                                 |
| `task.timestamp.start`   | datetime  | Start time of the task.                                                                      |

### Optional Attributes

| Attribute Key          | Type     | Description                                                  |
|------------------------|---------|--------------------------------------------------------------|
| `task.code.files`     | array   | List of code files involved in the task.                    |
| `task.code.lines`     | string  | Line numbers involved in the task, if applicable.           |
| `task.target.harness` | string  | Identifier for the target harness involved.                 |
| `task.effort.weight`  | integer | Measure of effort, e.g., number of processes or cores used. |

## Specialized Attributes for LLM Requests

| Attribute Key             | Type   | Description                                          |
|--------------------------|--------|------------------------------------------------------|
| `llm.parent.task.id`    | string | ID of the parent task or analysis this LLM request supports. |
| `llm.parent.task.category` | string | Category of the parent task.                         |
| `llm.gen_ai.response.id` | string | GenAI Response ID.                                  |
| `llm.code.files`        | array  | List of code files involved, if applicable.        |
| `llm.code.lines`        | string | Line numbers involved, if applicable.              |

## Specialized Attributes for Fuzzing

| Attribute Key               | Type     | Description                                                       |
|-----------------------------|---------|-------------------------------------------------------------------|
| `fuzz.corpus.update.method` | string  | Update method for the input corpus: `periodic`, `on_change`, etc. |
| `fuzz.corpus.update.time`   | datetime | Timestamp of the corpus update.                                   |
| `fuzz.corpus.size`          | integer | Size of the input corpus at the time of logging.                  |
| `fuzz.corpus.additions`     | array   | List of new inputs added to the corpus.                           |
| `fuzz.corpus.full_snapshot` | boolean | Indicates whether this is a full snapshot of the corpus.          |


---
---
## Usage Examples

Static Analysis
```
{
  "task.category": "static_analysis",
  "task.name": "check_security_flaws",
  "task.timestamp.current": "2025-01-27T14:00:00Z",
  "task.timestamp.start": "2025-01-27T13:50:00Z",
  "task.code.files": ["security_module.c", "auth_utils.c"],
  "task.code.lines": "15-300"
}
```
Dynamic Analysis
```
{
  "task.category": "dynamic_analysis",
  "task.name": "monitor_runtime_errors",
  "task.timestamp.current": "2025-01-27T14:10:00Z",
  "task.timestamp.start": "2025-01-27T13:55:00Z",
  "task.target.harness": "runtime_harness_1"
}
```
Fuzzing
```
{
  "task.category": "fuzzing",
  "task.name": "fuzz_test_network_inputs",
  "task.timestamp.current": "2025-01-27T12:45:00Z",
  "task.timestamp.start": "2025-01-27T12:00:00Z",
  "task.target.harness": "network_harness",
  "fuzz.corpus.update.method": "periodic",
  "fuzz.corpus.size": 1500,
  "fuzz.corpus.additions": ["inputA", "inputB"]
}
```
Program Analysis
```
{
  "task.category": "program_analysis",
  "task.name": "analyze_control_flow",
  "task.timestamp.current": "2025-01-27T14:30:00Z",
  "task.timestamp.start": "2025-01-27T14:15:00Z",
  "task.code.files": ["main.c", "utils.c"]
}
```
Building
```
{
  "task.category": "building",
  "task.name": "compile_source_code",
  "task.timestamp.current": "2025-01-27T14:35:00Z",
  "task.timestamp.start": "2025-01-27T14:25:00Z",
  "task.code.files": ["module1.c", "module2.c"]
}
```
Input Generation
```
{
  "task.category": "input_generation",
  "task.name": "generate_test_cases",
  "task.timestamp.current": "2025-01-27T14:45:00Z",
  "task.timestamp.start": "2025-01-27T14:30:00Z",
  "task.code.files": ["input_parser.c"]
}
```
Patch Generation
```
{
  "task.category": "patch_generation",
  "task.name": "generate_security_patch",
  "task.timestamp.current": "2025-01-27T15:00:00Z",
  "task.timestamp.start": "2025-01-27T14:45:00Z",
  "task.code.files": ["vuln_module.c"]
}
```
Testing
```
{
  "task.category": "testing",
  "task.name": "run_unit_tests",
  "task.timestamp.current": "2025-01-27T15:15:00Z",
  "task.timestamp.start": "2025-01-27T15:00:00Z"
}
```
Scoring Submission
```
{
  "task.category": "scoring_submission",
  "task.name": "submit_final_results",
  "task.timestamp.current": "2025-01-27T13:15:00Z",
  "task.timestamp.start": "2025-01-27T13:10:00Z"
}
```

---
---
## Example Python Implementation
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor

# Set up tracer provider and exporter
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)
exporter = ConsoleSpanExporter()
span_processor = SimpleSpanProcessor(exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Start a trace for the scoring submission
with tracer.start_as_current_span("scoring_submission") as span:
    # Add mandatory attributes
    span.set_attribute("task.category", "scoring_submission")
    span.set_attribute("task.name", "submit_final_results")
    span.set_attribute("task.timestamp.current", "2025-01-27T15:30:00Z")
    span.set_attribute("task.timestamp.start", "2025-01-27T15:25:00Z")
    

print("Scoring submission telemetry recorded.")
```

## Alternative Python Implementation 
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.trace import Status, StatusCode

# Set up the OpenTelemetry tracer provider
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)
exporter = ConsoleSpanExporter()
span_processor = SimpleSpanProcessor(exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

def log_task(task_category, task_name, extra_attributes={}):
    with tracer.start_as_current_span(task_category) as span:
        span.set_attribute("task.category", task_category)
        span.set_attribute("task.name", task_name)
        span.set_attribute("task.timestamp.current", "2025-01-27T14:00:00Z")
        span.set_attribute("task.timestamp.start", "2025-01-27T13:50:00Z")
        
        for key, value in extra_attributes.items():
            span.set_attribute(key, value)
        
        span.set_status(Status(StatusCode.OK))
    print(f"Logged task: {task_category} - {task_name}")

# Example usage for each task category
log_task("static_analysis", "check_security_flaws", {"task.code.files": ["security_module.c","auth_utils.c"],"task.code.lines": "15-300"})

log_task("dynamic_analysis", "monitor_runtime_errors", {"task.target.harness": "runtime_harness_1"})

log_task("fuzzing", "fuzz_test_network_inputs", {
"task.target.harness": "network_harness",
    "fuzz.corpus.update.method": "periodic",
    "fuzz.corpus.size": 1500,
    "fuzz.corpus.additions": ["inputA", "inputB"]
})

log_task("program_analysis", "analyze_control_flow", {"task.code.files": ["main.c", "utils.c"]})

log_task("building", "compile_source_code", {"task.code.files": ["module1.c", "module2.c"]})

log_task("input_generation", "generate_test_cases", {"task.code.files": ["input_parser.c"]})

log_task("patch_generation", "generate_security_patch", {"task.code.files": ["vuln_module.c"]})

log_task("testing", "run_unit_tests")

log_task("scoring_submission", "submit_final_results")

```

