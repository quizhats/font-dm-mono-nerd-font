cask "font-dm-mono-nerd-font" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/quizhats/font-dm-mono-nerd-font/releases/download/v#{version}/DMMonoNerdFont-v#{version}.zip"
  name "DM Mono Nerd Font"
  desc "DM Mono patched with Nerd Fonts glyphs"
  homepage "https://github.com/quizhats/font-dm-mono-nerd-font"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Expected --makegroups output - reconcile against the real patched
  # filenames (ls out/) after the first CI build/release.
  # Standard flavor
  font "DMMonoNerdFont-Regular.ttf"
  font "DMMonoNerdFont-Italic.ttf"
  font "DMMonoNerdFont-Light.ttf"
  font "DMMonoNerdFont-LightItalic.ttf"
  font "DMMonoNerdFont-Medium.ttf"
  font "DMMonoNerdFont-MediumItalic.ttf"

  # Mono flavor
  font "DMMonoNerdFontMono-Regular.ttf"
  font "DMMonoNerdFontMono-Italic.ttf"
  font "DMMonoNerdFontMono-Light.ttf"
  font "DMMonoNerdFontMono-LightItalic.ttf"
  font "DMMonoNerdFontMono-Medium.ttf"
  font "DMMonoNerdFontMono-MediumItalic.ttf"
end
