# HiLight-Capture
Transmitter and Receiver for HiLight-Capture System based on the HighLight paper [1].

Transmitter (Python): uses BFSK to create flashing static image which carry the data

Receiver (Swift): analyzes signals recorded from camera frame by frame to decode the original data.

## Run
Simply compile and run in xcode!

Transmitter is in Pre-processing folder while the receiver is an Xcode project

## Main interface
The main interface is a real-time preview of the video capture. Tap to focus on the relevant subjects!

## Requirement
This code uses SwiftUI, so it requires target devices to be at IOS 13 or later.

## Limitations
This code has been tested thoroughly on iPhone 10, but may not work on an iPad

## References
[1] Li, Tianxing, et al. “Real-Time Screen-Camera Communication Behind Any Scene.” Proceedings of the 13th Annual International Conference on Mobile Systems, Applications, and Services - MobiSys ’15, ACM Press, 2015, pp. 197–211. DOI.org (Crossref), doi:10.1145/2742647.2742667.
