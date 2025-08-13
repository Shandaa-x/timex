#!/bin/bash

# iOS Code Signing Configuration Script for Timex App
# Run this script to configure your development team for iPhone testing

echo "🍎 Configuring iOS Code Signing for iPhone Testing..."

# Get your Apple Developer Team ID (if you have one)
echo ""
echo "📋 First, let's check your available development teams:"
security find-identity -v -p codesigning | grep "iPhone Development\|Apple Development"

echo ""
echo "⚙️  Option 1: Use Xcode (Recommended)"
echo "1. Open the Xcode workspace: ios/Runner.xcworkspace"
echo "2. Select 'Runner' project in the navigator"
echo "3. Select 'Runner' target"
echo "4. Go to 'Signing & Capabilities' tab"
echo "5. Check 'Automatically manage signing'"
echo "6. Select your team (b.delger2018@gmail.com)"
echo ""

echo "⚙️  Option 2: Use Free Apple Developer Account"
echo "If you don't have a paid developer account:"
echo "1. Use your Apple ID (b.delger2018@gmail.com)"
echo "2. Xcode will create a free development profile"
echo "3. This allows 7-day app installs on your device"
echo ""

echo "🔧 Option 3: Manual Team ID Configuration"
read -p "Do you have a Team ID? (y/n): " has_team

if [ "$has_team" = "y" ]; then
    read -p "Enter your Team ID (10 characters): " team_id
    
    # Update the project.pbxproj file
    sed -i '' "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Automatic;\
				DEVELOPMENT_TEAM = $team_id;/g" ios/Runner.xcodeproj/project.pbxproj
    
    echo "✅ Team ID $team_id configured!"
else
    echo "💡 No problem! Use Xcode to set up automatic signing with your Apple ID."
fi

echo ""
echo "📱 Next Steps:"
echo "1. Connect your iPhone via USB"
echo "2. Trust this computer on your iPhone"
echo "3. Run: flutter run -d [your-device-id]"
echo ""
echo "🆔 Your device ID: 00008101-000C318224B82C3A"
echo "📁 Your bundle ID will be: com.example.timex (or change it to something unique)"
echo ""
echo "🔐 For Google Sign-In to work, make sure to:"
echo "1. Change bundle ID to something unique like: com.yourname.timex"
echo "2. Update Firebase console with new bundle ID"
echo "3. Download new GoogleService-Info.plist"
