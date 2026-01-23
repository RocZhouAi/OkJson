class Okjson < Formula
  desc "Native macOS JSON formatter and comparison tool"
  homepage "https://github.com/yourusername/OkJson"
  url "https://github.com/yourusername/OkJson/releases/download/v1.0.0/OkJson-1.0.0.dmg"
  sha256 "your_dmg_sha256_here"

  app "OkJson.app"

  zap trash: [
    "~/Library/Preferences/com.okjson.app.plist",
    "~/Library/Application Support/com.okjson.app",
  ]
end
