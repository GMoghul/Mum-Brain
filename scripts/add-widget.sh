#!/bin/bash
# Run on GitHub's Mac after `npx cap sync ios`: copies the widget files in and wires them up.
set -euo pipefail
cp -R ios-widget/MumBrainWidget ios/App/MumBrainWidget
cp -R ios-widget/MumBrainNotify ios/App/MumBrainNotify
cp ios-widget/App/*.swift ios-widget/App/App.entitlements ios/App/App/

# Main screen uses MainViewController (registers the widget bridge plugin)
SB=ios/App/App/Base.lproj/Main.storyboard
sed -i '' 's/customClass="CAPBridgeViewController" customModule="Capacitor"/customClass="MainViewController" customModule="App" customModuleProvider="target"/' "$SB"
grep -q 'customClass="MainViewController"' "$SB" || { echo "::error::Couldn't switch the main screen to MainViewController"; grep -n customClass "$SB"; exit 1; }

# mumbrain:// links, so tapping the widget opens Today
PLIST=ios/App/App/Info.plist
/usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string com.gmoghul.mumbrainsorted" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string mumbrain" "$PLIST"

ruby -e "require 'xcodeproj'" 2>/dev/null || sudo gem install xcodeproj --no-document
ruby scripts/add-widget.rb
ruby scripts/add-notify.rb
