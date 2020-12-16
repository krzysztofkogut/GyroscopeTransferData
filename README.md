# GyroscopeTransferData

iOS application to transfer gyro data using TCP. Application is written in Swift 5.

## Installation

Project uses the [CocoaPods](https://cocoapods.org). 

Frameworks used in project:
- [SwiftSocket](https://github.com/swiftsocket/SwiftSocket)

To install the dependencies in your project type: 

```bash
pod install
```

in project directory.

## Usage

- Open in Xcode **GyroscopeTransferData.xcworkspace** file. 
- Type **Server Domain** or **IPV4** and **Port** you want to connect.
- Type **Interval** for refreshing gyro data.
- Press **Start**.

Done! Now you can transfer Quaternions and Euler Angles from your device. 
