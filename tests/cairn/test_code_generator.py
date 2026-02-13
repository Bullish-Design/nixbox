"""Unit tests for CodeGenerator.

Tests implement contracts from ROADMAP-STEP_2.md.
"""

import pytest

from cairn.code_generator import CodeGenerator


class TestCodeGenerator:
    """Test LLM code generation."""

    def test_extract_code_from_markdown(self):
        """Contract 2: Extract code from markdown."""
        response = """```python
result = 2 + 2
```"""
        generator = CodeGenerator()
        code = generator.extract_code(response)

        assert code == "result = 2 + 2"

    def test_extract_code_plain(self):
        """Contract 3: Extract code without markdown."""
        response = "result = 2 + 2"
        generator = CodeGenerator()
        code = generator.extract_code(response)

        assert code == "result = 2 + 2"

    def test_extract_code_strips_whitespace(self):
        """Test that extract_code strips leading/trailing whitespace."""
        response = "\n\n  result = 2 + 2  \n\n"
        generator = CodeGenerator()
        code = generator.extract_code(response)

        assert code == "result = 2 + 2"

    def test_extract_code_with_language_tag(self):
        """Test extracting code with language tag in fence."""
        response = """```python
result = 2 + 2
```"""
        generator = CodeGenerator()
        code = generator.extract_code(response)

        assert code == "result = 2 + 2"

    def test_validate_code_syntax(self):
        """Test code syntax validation."""
        generator = CodeGenerator()

        valid_code = "result = 2 + 2\nsubmit_result('done', [])"
        is_valid, error = generator.validate_code(valid_code)
        assert is_valid is True
        assert error is None

        invalid_code = "def broken("
        is_valid, error = generator.validate_code(invalid_code)
        assert is_valid is False
        assert "Syntax error" in error

    def test_validate_code_no_imports(self):
        """Test that import statements are rejected."""
        generator = CodeGenerator()

        code_with_import = "import os\nresult = 42"
        is_valid, error = generator.validate_code(code_with_import)
        assert is_valid is False
        assert "Import" in error

        code_with_from = "from os import path\nresult = 42"
        is_valid, error = generator.validate_code(code_with_from)
        assert is_valid is False
        assert "Import" in error

    def test_validate_code_no_open(self):
        """Test that open() is rejected."""
        generator = CodeGenerator()

        code = "with open('file.txt') as f:\n    content = f.read()"
        is_valid, error = generator.validate_code(code)
        assert is_valid is False
        assert "open()" in error

    def test_validate_code_no_eval(self):
        """Test that eval() is rejected."""
        generator = CodeGenerator()

        code = "result = eval('2 + 2')"
        is_valid, error = generator.validate_code(code)
        assert is_valid is False
        assert "eval()" in error

    def test_validate_code_no_exec(self):
        """Test that exec() is rejected."""
        generator = CodeGenerator()

        code = "exec('print(42)')"
        is_valid, error = generator.validate_code(code)
        assert is_valid is False
        assert "exec()" in error

    def test_validate_code_requires_submit_result(self):
        """Test that code must call submit_result()."""
        generator = CodeGenerator()

        code_without_submit = "result = 2 + 2"
        is_valid, error = generator.validate_code(code_without_submit)
        assert is_valid is False
        assert "submit_result" in error

        code_with_submit = "result = 2 + 2\nsubmit_result('done', [])"
        is_valid, error = generator.validate_code(code_with_submit)
        assert is_valid is True

    def test_prompt_template_includes_constraints(self):
        """Test that prompt template includes all constraints."""
        generator = CodeGenerator()
        prompt = generator.PROMPT_TEMPLATE.format(task="Test task")

        # Check that all external functions are listed
        assert "read_file" in prompt
        assert "write_file" in prompt
        assert "ask_llm" in prompt
        assert "submit_result" in prompt

        # Check that constraints are mentioned
        assert "CANNOT" in prompt
        assert "import" in prompt
        assert "submit_result()" in prompt
