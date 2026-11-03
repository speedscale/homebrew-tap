import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


FORMULA_FIXTURE = r'''
require "formula"
require "open-uri"
require "stringio"

URI.define_singleton_method(:open) do |url, &block|
  raise "Unexpected download: #{url}" unless url.end_with?(".sha256")
  block.call(StringIO.new("0" * 64))
end

formula_path, destination = ARGV
load formula_path
formula = Proxymock.new("proxymock", Pathname.new(formula_path), :stable)
root = Pathname.new(destination)
formula.define_singleton_method(:libexec) { root/"libexec" }
formula.define_singleton_method(:bin) { root/"bin" }
formula.define_singleton_method(:opt_bin) { root/"opt/bin" }
formula.define_singleton_method(:ohai) { |*messages| nil }
formula.define_singleton_method(:system) do |*args|
  raise "Unexpected install command: #{args.inspect}" unless args.first == "chmod"
  raise "chmod failed" unless Kernel.system(*args)
end
Dir.chdir(root) do
  Dir.glob("proxymock-*").each { |path| File.delete(path) }
  name = "proxymock-#{Hardware::CPU.arm? ? 'darwin-arm64' : 'darwin-amd64'}"
  name = name.sub("darwin", "linux") if OS.linux?
  File.write(name, <<~PYTHON)
    #!/usr/bin/env python3
    import json, os, pathlib, sys
    with open(os.environ['WRAPPER_CALL_LOG'], 'a') as log:
        log.write(json.dumps({'args':sys.argv[1:], 'executable':os.environ.get('SPEEDSCALE_PROXYMOCK_EXECUTABLE')}) + '\\n')
    if sys.argv[1:2] == ['mcp']:
        pathlib.Path(os.environ['HOME'], '.claude.json').write_text('unexpected registration')
    print('fixture stdout')
    print('fixture stderr', file=sys.stderr)
    sys.exit(int(os.environ.get('WRAPPER_EXIT_STATUS', '0')))
  PYTHON
  formula.install
end
'''


class ProxymockWrapperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="proxymock-brew-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.agent = self.home / ".claude.json"
        self.agent.write_text('{"preserve":true}')
        self.marker = self.home / ".speedscale/mcp-registration-version"
        self.marker.parent.mkdir()
        self.marker.write_text("existing-marker")
        self.log = self.root / "calls.jsonl"
        self.prefix = self.root / "formula with spaces"
        self.prefix.mkdir()
        self.brew = os.environ.get("HOMEBREW_BREW_FILE") or shutil.which("brew")
        self.assertIsNotNone(self.brew, "Run with Homebrew available on PATH")
        self.env = dict(os.environ, HOME=str(self.home), WRAPPER_CALL_LOG=str(self.log),
                        HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_INSTALL_FROM_API="1",
                        HOMEBREW_NO_ANALYTICS="1")
        self.formula = Path(__file__).resolve().parents[1] / "Formula/proxymock.rb"
        self.install_formula()

    def install_formula(self):
        result = subprocess.run([self.brew, "ruby", "--", "-e", FORMULA_FIXTURE,
                                 str(self.formula), str(self.prefix)], env=self.env,
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_no_registration(self):
        self.assertEqual(self.agent.read_text(), '{"preserve":true}')
        self.assertEqual(self.marker.read_text(), "existing-marker")

    def invoke(self, args, exit_status=0):
        self.log.unlink(missing_ok=True)
        result = subprocess.run([str(self.prefix / "bin/proxymock"), *args],
                                env=dict(self.env, WRAPPER_EXIT_STATUS=str(exit_status)),
                                capture_output=True, text=True, timeout=10)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(calls, [{"args": args,
                                 "executable": str(self.prefix / "opt/bin/proxymock")}])
        self.assertEqual(result.returncode, exit_status)
        self.assertEqual(result.stdout, "fixture stdout\n")
        self.assertEqual(result.stderr, "fixture stderr\n")
        self.assert_no_registration()

    def test_install_and_upgrade_do_not_run_cli_or_register_agents(self):
        self.install_formula()
        self.assertFalse(self.log.exists())
        self.assert_no_registration()

    def test_successful_init_is_forwarded_once(self):
        self.invoke(["init", "--api-key", "fixture key", "--yes"])

    def test_failed_init_preserves_exit_status(self):
        self.invoke(["init", "--no-rcfile-update"], exit_status=23)

    def test_other_commands_keep_exact_arguments(self):
        for args in [["version", "--client"], ["--config", "path with spaces", "init"],
                     ["record", "--", "app", "argument with spaces"], []]:
            with self.subTest(args=args):
                self.invoke(args)

    def test_successful_init_without_marker_creates_no_state(self):
        self.marker.unlink()
        self.log.unlink(missing_ok=True)
        result = subprocess.run([str(self.prefix / "bin/proxymock"), "init"],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(len(calls), 1)
        self.assertFalse(self.marker.exists())
        self.assertEqual(self.agent.read_text(), '{"preserve":true}')


if __name__ == "__main__":
    unittest.main()
