cask "ride" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/ReOpsIL/ride/releases/download/v#{version}/Ride-#{version}.zip"
  name "Ride"
  desc "Native macOS IDE for Rust, C and C++"
  homepage "https://github.com/ReOpsIL/ride"

  app "Ride.app"

  zap trash: "~/Library/Application Support/Ride"
end
