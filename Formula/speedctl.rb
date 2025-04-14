require 'open-uri'

class Speedctl < Formula
  desc "Speedscale CLI"
  homepage "https://speedscale.com/"
  version "2.3.396"

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
    @url = "https://downloads.speedscale.com/speedctl/v#{version}/speedctl-#{@@os}-#{@@arch}"

    url @url

    # grab the checksum file
    URI.open("#{@url}.sha256") { |f| sha256 f.string.strip }
  else
    odie "There is no speedctl support for #{@@os}/#{@@arch}. Please contact support@speedscale.com with your platform details."
  end

  def install
    bin.install "speedctl-#{@@os}-#{@@arch}" => "speedctl"

    # ensure executable
    system "chmod", "0755", bin/"speedctl"

    ohai <<-NOTICE


!! IMPORTANT !!

If this is a fresh speedctl install, you must run `speedctl init`

NOTICE
  end

  test do
    system "#{bin}/speedctl version"
  end
end
