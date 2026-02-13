"""Cairn: Execution Layer for Nixbox.

This package implements the execution layer where agent code runs safely
in a Monty sandbox with controlled access to filesystem and LLM operations.
"""

from cairn.code_generator import CodeGenerator
from cairn.executor import AgentExecutor, ExecutionResult
from cairn.external_functions import ExternalFunctions, create_external_functions
from cairn.retry import RetryStrategy

__all__ = [
    "AgentExecutor",
    "CodeGenerator",
    "ExecutionResult",
    "ExternalFunctions",
    "RetryStrategy",
    "create_external_functions",
]

__version__ = "0.1.0"
