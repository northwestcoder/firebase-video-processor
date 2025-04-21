# Thunk Video Processor

## Overview

Thunk Video Processor is an iOS application that allows users to record videos and upload them to Firebase file storage. We also provide a webhook config for sending a URL reference of the video files to Thunk.AI for processing.

Key features:
- Video recording with camera access
- Google Sign-In authentication
- Real-time upload status tracking
- Swipe-to-delete functionality for videos

## Requirements

### Development Environment
- Xcode 15.0 or later
- macOS 14.0 (Sonoma) or later
- iOS 17.0 or later (target deployment)

### Dependencies
- Firebase SDK
  - FirebaseCore
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseStorage
- Google Sign-In SDK
  - GoogleSignIn
  - GoogleSignInSwift

### Firebase Configuration
- A Firebase project with:
  - Authentication enabled (Google Sign-In provider)
  - Firestore database
  - Storage bucket
  - iOS app registered
  - GoogleService-Info.plist file - you will need to add this file to your Xcode project!

## Installation

1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd thunkvideoprocessor
   ```

2. Install dependencies using Swift Package Manager:
   - Open the project in Xcode
   - Go to File > Add Packages
   - Add the following packages:
     - https://github.com/firebase/firebase-ios-sdk.git
     - https://github.com/google/GoogleSignIn-iOS.git

3. Configure Firebase:
   - Create a new Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/)
   - Add an iOS app to your Firebase project
   - Download the `GoogleService-Info.plist` file
   - Place the file in the ThunkVideoProcessor directory
   - Enable Google Sign-In in the Firebase Authentication section

4. Configure Google Sign-In:
   - Go to the [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select your existing Firebase project
   - Enable the Google Sign-In API
   - Configure the OAuth consent screen
   - Create OAuth 2.0 client credentials
   - Add the client ID to your Firebase project

5. Build and run:
   - Open `ThunkVideoProcessor.xcodeproj` in Xcode
   - Select your target device or simulator
   - Build and run the project (⌘R)

## Troubleshooting

- If you encounter build errors related to Firebase, ensure you've added all required Firebase dependencies
- For Google Sign-In issues, verify your OAuth client ID is correctly configured
- If the app crashes on launch, check that the GoogleService-Info.plist file is properly included in the project

## License

[License information] 