#!/bin/bash

# Run the OpenAI Realtime API example app and pull audio files

set -e

if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: Set OPENAI_API_KEY environment variable"
    exit 1
fi

# Add Android SDK to PATH if it exists
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools"

# Start Android emulator if not running
# Use adb to check for emulator instead of flutter devices to avoid broken pipe
if ! adb devices 2>/dev/null | grep -q "emulator"; then
    echo "Starting Android emulator..."

    # Check if emulator exists
    if [ -f "$ANDROID_SDK_ROOT/emulator/emulator" ]; then
        echo "Launching emulator directly..."
        $ANDROID_SDK_ROOT/emulator/emulator -avd Pixel_6_API_33 > /dev/null 2>&1 &
    else
        # Try flutter method as fallback
        echo "Trying Flutter emulator launch..."
        flutter emulators --launch Pixel_6_API_33 2>/dev/null &
    fi

    echo "Waiting for emulator to boot (this can take 1-2 minutes)..."

    # Wait for device to appear in adb
    adb wait-for-device 2>/dev/null || true

    # Wait for boot to complete
    while [ "$(adb shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
        echo -n "."
        sleep 2
    done
    echo ""

    # Wait for package manager to be ready
    while ! adb shell pm list packages 2>/dev/null | grep -q "android" ; do
        echo -n "."
        sleep 2
    done
    echo ""

    # Give it a bit more time for UI to stabilize
    echo "Emulator booted, waiting for UI to stabilize..."
    sleep 10

    echo "Emulator ready!"
fi

# Run the app
echo "Starting app..."
flutter run --dart-define=OPENAI_API_KEY="$OPENAI_API_KEY" &
FLUTTER_PID=$!

echo ""
echo "=================="
echo "App is running!"
echo "1. Tap Connect"
echo "2. Tap Send Audio File"
echo "3. Tap Save Audio Response"
echo "4. Press 'q' here when done"
echo "=================="
echo ""

# Wait for user to press q
while true; do
    read -r -n 1 -s key
    if [[ $key = "q" ]]; then
        break
    fi
done

# Kill flutter
kill $FLUTTER_PID 2>/dev/null || true
sleep 2

# Pull audio files
echo "Pulling audio files..."
mkdir -p audio_output

# Try to pull files from the app
for file in $(adb shell "run-as com.example.openai_realtime_example ls files/*.pcm 2>/dev/null" 2>/dev/null || echo ""); do
    if [ ! -z "$file" ]; then
        filename=$(basename "$file" | tr -d '\r')
        echo "Pulling $filename..."
        adb exec-out "run-as com.example.openai_realtime_example cat files/$filename" > "audio_output/$filename"
    fi
done

# Also check app_flutter directory
for file in $(adb shell "run-as com.example.openai_realtime_example ls app_flutter/*.pcm 2>/dev/null" 2>/dev/null || echo ""); do
    if [ ! -z "$file" ]; then
        filename=$(basename "$file" | tr -d '\r')
        echo "Pulling $filename..."
        adb exec-out "run-as com.example.openai_realtime_example cat app_flutter/$filename" > "audio_output/$filename"
    fi
done

if [ -d "audio_output" ] && [ "$(ls -A audio_output)" ]; then
    echo ""
    echo "Audio files saved to audio_output/"
    ls -la audio_output/
    echo ""
    echo "To play: ffmpeg -f s16le -ar 24000 -ac 1 -i audio_output/*.pcm output.wav"
else
    echo "No audio files found"
fi

echo "Done!"