#!/bin/bash
mkdir -p Sleeper.app/Contents/MacOS
swiftc -framework Cocoa -framework ServiceManagement Sleeper.swift -o Sleeper.app/Contents/MacOS/Sleeper

cat > Sleeper.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Sleeper</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

chmod +x Sleeper.app/Contents/MacOS/Sleeper
echo "The build has been completed"