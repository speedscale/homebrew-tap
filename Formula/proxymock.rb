require 'open-uri'

class Proxymock < Formula
  desc "proxymock CLI"
  homepage "https://speedscale.com/"
  version "2.3.314"

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
    bin.install "proxymock-#{@@os}-#{@@arch}" => "proxymock"

    # ensure executable
    system "chmod", "0755", bin/"proxymock"

    ohai <<-NOTICE

If this is a fresh proxymock install, you must run `proxymock init`.

NOTICE
  ohai ""
  ohai "You can get an api key from https://docs.speedscale.com/proxymock/getting-started/api-key/"
  ohai ""

  end

  test do
    system "#{bin}/proxymock version"
  end
end
