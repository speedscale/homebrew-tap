require 'open-uri'

class Speedctl < Formula
  desc "Speedscale CLI"
  homepage "https://speedscale.com/"
  version "0.12.117"

  # which binary do we need
  @os = ""
  @arch = ""

  on_macos { @os = "darwin" }
  on_linux { @os = "linux" }

  if Hardware::CPU.is_64_bit?
    if Hardware::CPU.intel?
      @arch = "amd64"
    end

    if Hardware::CPU.arm?
      @arch = "arm64"
    end
  end

  if @os != "" and @arch != ""
    url "https://downloads.speedscale.com/speedctl/v#{version}/speedctl-#{@os}-#{@arch}"

    # grab the checksum file
    # URI.open("#{url}.sha256") { |f| sha256 f.body.strip }
  end

  def install
    bin.install "speedctl-#{@os}-#{@arch}" => "speedctl"

    # generate the completions
    (bash_completion/"speedctl").write Utils.safe_popen_read(bin/"speedctl", "completion", "bash")
    (zsh_completion/"_speedctl").write Utils.safe_popen_read(bin/"speedctl", "completion", "zsh")
    (fish_completion/"speedctl.fish").write Utils.safe_popen_read(bin/"speedctl", "completion", "fish")

    ohai "Please run `speedctl init` if this is your first installation"
  end

  test do
    system "#{bin}/speedctl version"
  end
end
