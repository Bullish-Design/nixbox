"""Tests for Cairn settings resolution and validation."""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from cairn.executor import AgentExecutor
from cairn.orchestrator import CairnOrchestrator
from cairn.settings import ExecutorSettings, OrchestratorSettings, PathsSettings


def test_executor_settings_load_from_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CAIRN_EXECUTOR_MAX_EXECUTION_TIME", "7.5")
    monkeypatch.setenv("CAIRN_EXECUTOR_MAX_MEMORY_BYTES", str(8 * 1024 * 1024))
    monkeypatch.setenv("CAIRN_EXECUTOR_MAX_RECURSION_DEPTH", "250")

    settings = ExecutorSettings()

    assert settings.max_execution_time == 7.5
    assert settings.max_memory_bytes == 8 * 1024 * 1024
    assert settings.max_recursion_depth == 250


def test_orchestrator_and_paths_settings_load_from_env(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("CAIRN_ORCHESTRATOR_MAX_CONCURRENT_AGENTS", "3")
    monkeypatch.setenv("CAIRN_ORCHESTRATOR_ENABLE_SIGNAL_POLLING", "false")
    monkeypatch.setenv("CAIRN_PATHS_PROJECT_ROOT", str(tmp_path / "repo"))
    monkeypatch.setenv("CAIRN_PATHS_CAIRN_HOME", str(tmp_path / "home"))

    orchestrator_settings = OrchestratorSettings()
    path_settings = PathsSettings()

    assert orchestrator_settings.max_concurrent_agents == 3
    assert orchestrator_settings.enable_signal_polling is False
    assert path_settings.project_root == tmp_path / "repo"
    assert path_settings.cairn_home == tmp_path / "home"


def test_settings_invalid_values_raise_validation_error() -> None:
    with pytest.raises(ValidationError):
        ExecutorSettings(max_execution_time=0)

    with pytest.raises(ValidationError):
        ExecutorSettings(max_memory_bytes=1024)

    with pytest.raises(ValidationError):
        ExecutorSettings(max_recursion_depth=0)

    with pytest.raises(ValidationError):
        OrchestratorSettings(max_concurrent_agents=0)


def test_executor_derives_defaults_from_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CAIRN_EXECUTOR_MAX_EXECUTION_TIME", "4")
    monkeypatch.setenv("CAIRN_EXECUTOR_MAX_MEMORY_BYTES", str(12 * 1024 * 1024))

    executor = AgentExecutor()

    assert executor.max_execution_time == 4
    assert executor.max_memory_bytes == 12 * 1024 * 1024


def test_orchestrator_derives_path_defaults_from_settings(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("CAIRN_PATHS_PROJECT_ROOT", str(tmp_path / "settings-root"))
    monkeypatch.setenv("CAIRN_PATHS_CAIRN_HOME", str(tmp_path / "settings-home"))

    orchestrator = CairnOrchestrator(project_root=tmp_path / "cli-root", cairn_home=tmp_path / "cli-home")

    assert orchestrator.project_root == (tmp_path / "settings-root").resolve()
    assert orchestrator.cairn_home == (tmp_path / "settings-home")
