#!/bin/bash

# Launch the OpenAI Realtime API example app.

set -e

if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: Set OPENAI_API_KEY environment variable"
    exit 1
fi

flutter pub get
flutter run --dart-define=OPENAI_API_KEY="$OPENAI_API_KEY"
