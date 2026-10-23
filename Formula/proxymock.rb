require 'open-uri'

class Proxymock < Formula
  desc "proxymock CLI"
  homepage "https://proxymock.io/"
  version "2.5.1233"

  # which binary do we need
  @@os = ""
  @@arch = ""

  on_macos { @@os = "darwin" }
  on_linux { @@os = "linux" }

  if Hardware::CPU.is_64_bit?
    if Hardware::CPU.intel?
      @@arch = "amd64"
    end

    if Hardware::CPU.arm?
      @@arch = "arm64"
    end
  end

  if @@os != "" and @@arch != ""
    @url = "https://downloads.speedscale.com/proxymock/v#{version}/proxymock-#{@@os}-#{@@arch}"

    url @url

    # grab the checksum file
    URI.open("#{@url}.sha256") { |f| sha256 f.string.strip }
  else
    odie "There is no proxymock support for #{@@os}/#{@@arch}. Please contact support@speedscale.com with your platform details."
  end

  def install
    libexec.install "proxymock-#{@@os}-#{@@arch}" => "proxymock-bin"
    system "chmod", "0755", libexec/"proxymock-bin"

    bin.mkpath
    (bin/"proxymock").write <<~SH
      #!/bin/sh
      binary="#{libexec}/proxymock-bin"
      export SPEEDSCALE_PROXYMOCK_EXECUTABLE="#{opt_bin}/proxymock"
      state="${HOME}/.speedscale/mcp-registration-version"

      register_mcp() {
        if [ -f "$state" ] && [ "$(cat "$state")" = "v#{version}" ]; then
          return 0
        fi

        if "$binary" mcp install --yes; then
          mkdir -p "$(dirname "$state")"
          printf '%s' "v#{version}" > "$state"
        else
          echo "proxymock MCP setup did not complete. Run proxymock mcp install --yes to retry." >&2
        fi
      }

      if [ "${1-}" = "init" ]; then
        "$binary" "$@"
        status=$?
        if [ "$status" -eq 0 ]; then
          register_mcp
        fi
        exit "$status"
      fi

      exec "$binary" "$@"
    SH
    (bin/"proxymock").chmod 0755

    ohai <<-NOTICE

The MCP server and bundled skills are registered for detected AI clients only when `proxymock init` succeeds.
Run `proxymock init` to authenticate with Speedscale.

NOTICE
  ohai ""
  ohai "You can get an api key from https://docs.speedscale.com/proxymock/getting-started/api-key/"
  ohai ""

  end

  test do
    system "#{bin}/proxymock version"
  end
end
