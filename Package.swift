// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EventScheduleApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .iOSApplication(
            name: "EventSchedule",
            targets: ["EventScheduleApp"],
            bundleIdentifier: "com.example.eventschedule",
            teamIdentifier: nil,
            displayVersion: "0.1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .calendar),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .portraitUpsideDown
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "EventScheduleApp",
            path: "Sources/EventScheduleApp"
        )
    ]
)
