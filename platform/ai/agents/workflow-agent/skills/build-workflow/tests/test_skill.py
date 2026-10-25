"""Offline contract checks for build_workflow documentation.

These are not a substitute for live kagent/n8n MCP integration tests.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SkillContractTests(unittest.TestCase):
    def test_frontmatter_and_name(self):
        content = (ROOT / "SKILL.md").read_text()
        self.assertTrue(content.startswith("---\n"))
        metadata = content.split("---\n", 2)[1]
        self.assertIn("name: build_workflow\n", metadata)
        self.assertIn("description:", metadata)

    def test_full_workflow_lifecycle_documented(self):
        content = (ROOT / "SKILL.md").read_text()
        for token in (
            "n8n_create_workflow", "n8n_get_workflow", "n8n_update_partial_workflow",
            "n8n_validate_workflow", "n8n_test_workflow", "n8n_executions",
            "k8s_get_resources", "READY_TO_ACTIVATE", "ACTIVE_VERIFIED",
            "Secret", "rollback", "approval",
        ):
            self.assertIn(token.lower(), content.lower(), token)

    def test_package_references_resolve(self):
        content = (ROOT / "SKILL.md").read_text()
        for ref in re.findall(r"references/[a-z-]+\.md", content):
            self.assertTrue((ROOT / ref).is_file(), ref)

    def test_example_requires_immutable_git_source(self):
        content = (ROOT / "examples" / "workflow-builder.agenttemplate.yaml").read_text()
        self.assertIn("api.kagent.dev/v1alpha3", content)
        self.assertIn("path: platform/ai/skills/build_workflow", content)
        self.assertIn("REPLACE_WITH_EXACT_40_CHARACTER_COMMIT_SHA", content)
        self.assertIn("kind: RemoteMCPServer", content)
        self.assertIn("namespace: ai", content)


if __name__ == "__main__":
    unittest.main()
