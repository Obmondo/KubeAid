"""The kubesoc-content prompts must not drift from the modules' built-in defaults.

    python3 -m unittest discover -s argocd-helm-charts/dfir-iris/tests

Replaces tests/test_ai_triage.py: files/ai-triage.py was split into files/ai/*.py,
whose behaviour tests/test_ai_jobs.py covers. What is left, and still worth a test,
is that the content package ships exactly the prompts and schemas the code falls back
to, so enabling kubesoc-content cannot silently change the model's answers.
"""
import json
import os
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "files" / "ai"))

import kubesoc_ai as ai  # noqa: E402

PROMPTS = HERE.parents[1] / "kubesoc-content" / "ai" / "prompts"


class ContentPrompts(unittest.TestCase):
    def test_every_mode_ships_a_prompt_and_schema(self):
        for mode, (system, schema) in ai.DEFAULTS.items():
            with self.subTest(mode=mode):
                text, js = PROMPTS / f"{mode}-system.txt", PROMPTS / f"{mode}-schema.json"
                self.assertTrue(text.is_file(), f"{mode}: no prompt in kubesoc-content")
                self.assertTrue(js.is_file(), f"{mode}: no schema in kubesoc-content")
                self.assertEqual(text.read_text(encoding="utf-8").strip(), system.strip())
                self.assertEqual(json.loads(js.read_text(encoding="utf-8")), schema)

    def test_load_prompt_reads_the_content_package(self):
        for mode, (system, schema) in ai.DEFAULTS.items():
            with self.subTest(mode=mode):
                got = ai.load_prompt(mode, str(PROMPTS))
                self.assertEqual(got.system.strip(), system.strip())
                self.assertEqual(got.schema, schema)


if __name__ == "__main__":
    unittest.main()
