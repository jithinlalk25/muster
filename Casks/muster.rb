# Homebrew cask for Muster. The canonical copy lives in your tap repo
# (jithinlalk25/homebrew-tap → Casks/muster.rb); this in-repo copy is the template.
# Per release, bump `version` and `sha256` (Scripts/release.sh prints both), then push the tap.
cask "muster" do
  version "0.2.0"
  sha256 "85c41b7ed4c00e86747207d7080673ea17d4237451d81b0af77f056b239bb1f2"

  url "https://github.com/jithinlalk25/muster/releases/download/v#{version}/Muster-#{version}.dmg"
  name "Muster"
  desc "Menu-bar roll call of your Claude Code sessions"
  homepage "https://github.com/jithinlalk25/muster"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura # macOS 13+

  app "Muster.app"

  # Muster's hooks live in ~/.claude/settings.json — remove them from inside the app
  # (right-click → Settings… → Uninstall hooks) BEFORE uninstalling, so the cask doesn't
  # leave dangling hook entries. `zap` only clears Muster's own socket dir.
  zap trash: "~/.muster"

  caveats <<~EOS
    Muster runs as a menu-bar item (no Dock icon). On first launch it opens a setup
    window to add its hooks to ~/.claude/settings.json — your existing settings are merged,
    never replaced. To fully remove it later, open Settings… → Uninstall hooks first.
  EOS
end
