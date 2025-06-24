#!/bin/bash

# Health Exporter Release Build Script
# This script builds the app locally for testing before pushing to GitHub Actions

set -e  # Exit on any error

# Configuration
PROJECT_NAME="HealthExporter"
SCHEME_NAME="HealthExporter"
ARCHIVE_PATH="./build/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="./build/export"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Health Exporter Release Build Script${NC}"
echo "================================================"

# Check if we're in the right directory
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: ${PROJECT_NAME}.xcodeproj not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf ./build
mkdir -p ./build

# Get current version info
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ${PROJECT_NAME}/Info.plist)
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${PROJECT_NAME}/Info.plist)

echo -e "${BLUE}📱 Current Version: ${CURRENT_VERSION} (${CURRENT_BUILD})${NC}"

# Option to update build number
read -p "Update build number? (y/N): " update_build
if [[ $update_build =~ ^[Yy]$ ]]; then
    NEW_BUILD=$(date +%Y%m%d%H%M)
    echo -e "${YELLOW}📈 Updating build number to: ${NEW_BUILD}${NC}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" ${PROJECT_NAME}/Info.plist
    
    # Also update in project.pbxproj
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" ${PROJECT_NAME}.xcodeproj/project.pbxproj
fi

# Build for simulator first (faster, no code signing required)
echo -e "${YELLOW}🔨 Building for iOS Simulator...${NC}"
xcodebuild clean build \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME_NAME} \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    | xcpretty

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Simulator build successful${NC}"
else
    echo -e "${RED}❌ Simulator build failed${NC}"
    exit 1
fi

# Ask if user wants to build for device (requires code signing)
read -p "Build for device? This requires code signing certificates (y/N): " build_device
if [[ $build_device =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}📱 Building archive for device...${NC}"
    
    xcodebuild clean archive \
        -project ${PROJECT_NAME}.xcodeproj \
        -scheme ${SCHEME_NAME} \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "${ARCHIVE_PATH}" \
        | xcpretty
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Device archive successful${NC}"
        echo -e "${BLUE}📦 Archive location: ${ARCHIVE_PATH}${NC}"
        
        # Option to export for different destinations
        echo ""
        echo "Export options:"
        echo "1) Ad Hoc (for testing on registered devices)"
        echo "2) App Store (for submission)"
        echo "3) Skip export"
        read -p "Choose option (1-3): " export_option
        
        case $export_option in
            1)
                echo -e "${YELLOW}📤 Exporting for Ad Hoc distribution...${NC}"
                create_export_plist "ad-hoc"
                export_archive
                ;;
            2)
                echo -e "${YELLOW}📤 Exporting for App Store...${NC}"
                create_export_plist "app-store"
                export_archive
                ;;
            3)
                echo -e "${BLUE}ℹ️  Archive created but not exported${NC}"
                ;;
            *)
                echo -e "${YELLOW}⚠️  Invalid option, skipping export${NC}"
                ;;
        esac
    else
        echo -e "${RED}❌ Device archive failed${NC}"
        echo "Make sure you have valid code signing certificates and provisioning profiles"
        exit 1
    fi
fi

# Run SwiftLint if available
if command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}🔍 Running SwiftLint...${NC}"
    swiftlint lint --config .swiftlint.yml
else
    echo -e "${YELLOW}⚠️  SwiftLint not installed, skipping code quality check${NC}"
    echo "Install with: brew install swiftlint"
fi

# Summary
echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
echo "================================================"
echo -e "${BLUE}📱 App: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}📊 Version: ${CURRENT_VERSION}${NC}"
echo -e "${BLUE}🔢 Build: $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${PROJECT_NAME}/Info.plist)${NC}"

if [ -d "${EXPORT_PATH}" ]; then
    echo -e "${BLUE}📦 Export: ${EXPORT_PATH}${NC}"
    echo -e "${BLUE}📁 Files:${NC}"
    ls -la "${EXPORT_PATH}/"
fi

echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "1. Test the build thoroughly"
echo "2. If ready for release, create a git tag: git tag v${CURRENT_VERSION}"
echo "3. Push the tag to trigger App Store deployment: git push origin v${CURRENT_VERSION}"

# Function to create export plist
create_export_plist() {
    local method=$1
    cat > ./build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>${method}</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
}

# Function to export archive
export_archive() {
    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportOptionsPlist ./build/ExportOptions.plist \
        -exportPath "${EXPORT_PATH}" \
        | xcpretty
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Export successful${NC}"
    else
        echo -e "${RED}❌ Export failed${NC}"
        exit 1
    fi
}