# OpenAI Realtime API Example

An interactive Flutter demo showcasing the OpenAI Realtime API with WebRTC for real-time voice conversations.

## About

This example app demonstrates the OpenAI Realtime API's capabilities, allowing you to have natural, low-latency voice conversations with an AI assistant using WebRTC technology.

## Features

### Interactive Voice Conversations

- **Real-time WebRTC Audio**: Experience ultra-low latency voice communication
- **Natural Turn-Taking**: Automatic speech detection for smooth back-and-forth conversation
- **Visual Feedback**: See when you're speaking and when the assistant is responding

### AI Assistant

The AI assistant is programmed to be helpful and conversational:

- Responds naturally to a wide range of topics and questions
- Provides informative and engaging conversations
- Maintains context throughout the conversation
- Adapts to your communication style and preferences

### Developer Features

- **Event Log Display**: Real-time visualization of all API events for debugging
- **Connection Status**: Clear visual indicators of connection state
- **Simple Start/Stop**: One-tap connection control through the interface

## Running the Example

### Prerequisites

1. **OpenAI API Key**: Get your API key from [OpenAI Platform](https://platform.openai.com)
2. **Flutter SDK**: Ensure Flutter is installed and configured
3. **Platform Setup**:
   - iOS: Xcode and iOS development tools
   - Android: Android Studio and Android SDK
   - macOS: Enable microphone permissions in system settings

### Running

```bash
# Navigate to the example directory
cd flutter_openai_realtime_api/example

# Install dependencies
flutter pub get

# Run with your API key
flutter run --dart-define=OPENAI_API_KEY="your-api-key-here"
```

### Platform-specific notes

#### iOS

Microphone permissions are already configured in Info.plist

#### Android

Microphone permissions are already configured in AndroidManifest.xml

#### macOS

You may need to grant microphone permissions when first running the app

## How to Use

1. **Launch the app** - You'll see the voice chat interface
2. **Tap the connect button** - This establishes a connection to the OpenAI Realtime API
3. **Start talking!** - Once connected, just speak naturally. The assistant will hear you and respond
4. **Topics to explore**:
   - Ask questions about any topic
   - Have casual conversations
   - Request help with tasks or problems
   - Discuss current events or personal interests
   - Get explanations on complex topics
5. **Watch the event log** - See real-time API events for debugging
6. **Tap the button again** - Disconnects from the API

## Architecture

The example demonstrates:

- WebRTC connection setup and management
- Real-time audio streaming
- Event handling and state management
- Clean session lifecycle (connect/disconnect)
- Visual feedback for conversation state

## API Features Used

- **WebRTC Connection**: Low-latency audio streaming
- **Server VAD**: Automatic voice activity detection
- **Turn Detection**: Natural conversation flow
- **Real-time Events**: Comprehensive event handling
- **Session Management**: Clean connection lifecycle

## Customization

You can modify the assistant's personality by editing the `instructions` in the `RealtimeSessionConfig` in `lib/main.dart`. Customize the conversation style and behavior to match your needs!

## Troubleshooting

- **No connection**: Check your API key is correctly set
- **No audio**: Ensure microphone permissions are granted
- **Connection drops**: Check your internet connection stability
- **Events not showing**: The event log shows the last 100 events

## Learn More

This example is part of the OpenAI Realtime API Flutter package. For more information:

- [Package Documentation](../README.md)
- [OpenAI Realtime API Docs](https://platform.openai.com/docs/guides/realtime)
