# WebRTC Videochat 
This simple app demonstrates the use use of WebRTC. It allows the communication between Android and iOS devices.

## Prerequisites
You need to create a Firebase project and add the `GoogleService-Info.plist` file to the app directory.

Before running the project, make sure you have installed [Cocoapods](https://cocoapods.org). You can install it using the following command
```
$ sudo gem install cocoapods
```

## Updating dependencies
Once you have installed both Cocoapods and Rome, you can now install the required dependencies using
```
$ pod install
```
## Running the project
Once you have installed all the dependencies, you can run the project.
Keep in mind that there's no support for background functionality. The app only works on foreground. 

## Credits
The signaling part of the app is based on the [Firebase + WebRTC Codelab](https://webrtc.org/getting-started/firebase-rtc-codelab), which is a great intro into WebRTC.

This project uses the official version of WebRTC that can be found [here.](https://cocoapods.org/pods/GoogleWebRTC) 

The WebRTCClient is based on the [SwiftyWebRTC project](https://github.com/Ankit-Aggarwal/SwiftyWebRTC). They have done a great job creating a wrapper that works on Swift. [Check it out](https://hackernoon.com/swiftywebrtc-789936b0e39b) 
