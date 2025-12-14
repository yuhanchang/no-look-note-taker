# No-Look Note Taker - Planning Document

## Overview

A voice note-taking app for Apple Watch, designed for quick capture with minimal interaction - ideally without needing to look at the watch.

## Development Requirements

### Apple Developer Account

- **Not required** for development and testing
- Free Apple ID creates a "Personal Team" in Xcode
- Can build and install directly to physical Apple Watch
- **Limitations of free provisioning:**
  - Provisioning profile expires every 7 days (just re-build)
  - Maximum 3 connected devices
  - No App Store distribution or TestFlight

- **Paid account ($99/year) only needed for:**
  - App Store distribution
  - TestFlight beta testing

### Testing Setup

1. Enable Developer Mode on Apple Watch (Settings → Privacy & Security → Developer Mode)
2. Pair iPhone to Mac, open Xcode
3. Watch appears as run destination
4. Build and run - app installs on watch

## Quick Access Methods

### Apple Watch Ultra (Action Button)

**Recommended: Action Button** - Single physical press, no looking required

- watchOS 11 improved action button functionality
- Can assign Shortcuts or apps via App Intents
- Single press → action triggers immediately
- Works without raising wrist or looking at screen
- Truly "no-look" interaction

### Non-Ultra Apple Watches

**Recommended: Complication + Siri**

| Method | Interaction | No-Look? | Notes |
|--------|-------------|----------|-------|
| Complication | Raise wrist + tap | No | One tap from watch face, muscle memory helps |
| Siri | "Hey Siri, [shortcut name]" | Yes | Truly hands-free, works with arms full |
| Smart Stack | Swipe up + tap widget | No | Available on watchOS 10+ |

### Double Tap Gesture (Not Recommended)

Evaluated but rejected for this use case:

- Only available on Series 9+ (native) or Series 3+ (via AssistiveTouch)
- **Cannot be customized** to launch arbitrary apps/shortcuts
- Limited to contextual "primary action" on current screen
- Would require multiple gestures to navigate to app
- **Disabled during active workouts** - a key use case for quick voice notes

## App Architecture

### Integration Points (Priority Order)

1. **App Intents** - Enables:
   - Action button support (Ultra)
   - Siri voice commands (all watches)
   - Shortcuts integration

2. **Complication** - Quick tap access on any watch face

3. **Shortcut Integration** - Covers action button, Siri, and Smart Stack

### Target Compatibility

- watchOS 11+ (for latest action button features)
- Works on all Apple Watch models that support watchOS 11:
  - Apple Watch Series 6+
  - Apple Watch SE (2nd gen)+
  - Apple Watch Ultra / Ultra 2

## User Experience Goals

- **Ultra users:** Single action button press → recording starts
- **Non-Ultra users:** Single complication tap OR "Hey Siri" → recording starts
- No navigation required
- Minimal/no visual attention needed

## Decisions

### Storage: Firebase

- Audio files stored in Firebase Storage
- Note metadata and transcriptions stored in Firestore
- Enables sync across all platforms (watch, phone, web)

### Client Apps

1. **Apple Watch app** - Primary capture device
2. **iPhone companion app** - View and manage transcribed notes
3. **Firebase-hosted web app** - View and manage notes from any browser

### Transcription: OpenAI Whisper API

- Start with OpenAI's Whisper API for transcription
- Architecture should allow swapping in other models later
- Output: Well-structured plain text

## Technical Specifications

### Audio Recording (Apple Watch)

**Recommended settings:**
```swift
let settings = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100,
    AVNumberOfChannelsKey: 1,  // Mono is fine for voice
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

- **Format:** M4A (MPEG4 AAC) - supported by Whisper API
- **File size:** ~1MB per minute at these settings
- **Requirement:** Add `NSMicrophoneUsageDescription` to iPhone companion app Info.plist

### OpenAI Whisper API Limits

- **Max file size:** 25MB
- **Supported formats:** m4a, mp3, webm, mp4, mpga, wav, mpeg
- **At ~1MB/min:** Can transcribe ~25 minutes per file
- **No streaming:** Must upload complete file
- **For longer recordings:** Split into chunks before upload

### Firebase Architecture

```
Firebase Project
├── Storage
│   └── /recordings/{userId}/{recordingId}.m4a
├── Firestore
│   └── /users/{userId}/notes/{noteId}
│       ├── audioUrl: string
│       ├── transcription: string
│       ├── createdAt: timestamp
│       ├── duration: number
│       └── status: "recording" | "uploading" | "transcribing" | "complete" | "error"
└── Hosting
    └── Web app (React/Vue/etc.)
```

### Data Flow

```
1. Watch: Record audio → Save locally
2. Watch/Phone: Upload to Firebase Storage
3. Cloud Function: Triggered on upload
   → Send audio to OpenAI Whisper API
   → Save transcription to Firestore
4. All clients: Real-time sync via Firestore listeners
```

### Recording Stop Behavior

- Same trigger to stop: tap complication again OR press action button again
- Toggle behavior: first tap starts, second tap stops and uploads

### Authentication

- Firebase Authentication
- Start with Apple Sign-In (native, no password needed)

### Scope Decisions (Keep Simple Initially)

| Feature | Now | Later |
|---------|-----|-------|
| Offline support | No | Yes - queue uploads |
| Note organization | Flat list | Folders, tags, search |
| Edit transcriptions | No | Yes - manual corrections |

## Future Enhancements

- [ ] Offline support with upload queue
- [ ] Folders/tags for organization
- [ ] Search across transcriptions
- [ ] Edit/correct transcriptions
- [ ] Alternative transcription models
- [ ] Share notes

## References

### Apple Watch Development
- [Apple Developer - Responding to the Action button](https://developer.apple.com/documentation/appintents/actionbuttonarticle)
- [Apple Developer - Creating independent watchOS apps](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps)
- [Apple - Use the Action button on Apple Watch Ultra](https://support.apple.com/guide/watch/use-the-action-button-apda005904ef/watchos)
- [Apple - Use shortcuts on Apple Watch](https://support.apple.com/guide/watch/shortcuts-apd99050d435/watchos)
- [WWDC20 - Create quick interactions with Shortcuts on watchOS](https://developer.apple.com/videos/play/wwdc2020/10190/)
- [AVAudioRecorder settings](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/1390903-settings)
- [Creating a Watch App that Supports Audio Recording](https://medium.com/@ios_guru/creating-a-watch-app-supports-audio-recording-906af9806db0)

### OpenAI Whisper API
- [OpenAI Whisper API Limits](https://www.transcribetube.com/blog/openai-whisper-api-limits)
- [Audio API FAQ - OpenAI](https://help.openai.com/en/articles/7031512-audio-api-faq)
