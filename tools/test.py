"""Run the actual Lua source and a mocked engine lifecycle. No installed game needed."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools/python"))
from lupa.lua54 import LuaRuntime


class LuaTests(unittest.TestCase):
    def test_core_and_lifecycle(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().source_root = (ROOT / "cargo_distribution_1/content/cargo_distribution").as_posix()
        lua.execute((ROOT / "tests/probe_test.lua").read_text(encoding="utf-8"))

    def test_all_lua_compiles(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        compiler = lua.eval("function(s,n) local f,e=load(s,n); assert(f,e); return true end")
        for file in (ROOT / "cargo_distribution_1").rglob("*.lua"):
            with self.subTest(file=file.name):
                self.assertTrue(compiler(file.read_text(encoding="utf-8"), str(file)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
