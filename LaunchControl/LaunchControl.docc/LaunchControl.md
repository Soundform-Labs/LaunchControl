# ``LaunchControl``

A robust CoreMIDI-based framework for communicating with Launchpad and other MIDI hardware on Apple platforms.

@Metadata { 
    @Available(macOS, introduced: "26.0")
    @Available(Swift, introduced: "6.2")
    
    @SupportedLanguage(swift)
    @SupportedLanguage(objc)
}

## Overview

LaunchControl is a CoreMIDI-based framework for managing communication between your app and MIDI hardware, with specific support for Novation Launchpads and similar devices.

It provides a streamlined interface for discovering endpoints, establishing connections, and sending or receiving MIDI messages—all with performance and reliability suitable for real-time, latency-sensitive environments.

Designed with both developers and performers in mind, LaunchControl includes:

- Automatic discovery of MIDI input and output devices
- Efficient message transmission with packet size validation and structured logging
- Live monitoring of connection changes, enabling dynamic responses to device attachment or removal
- Integrated support for displaying hex dumps for inspection and debugging

LaunchControl abstracts the complexities of CoreMIDI, helping you focus on your app's creative functionality.

### Sample Applications

Explore how LaunchControl integrates into real-world scenarios with sample apps that demonstrate device interaction, grid control, velocity input handling, and visual feedback.

@Links(visualStyle: detailedGrid) { 
    - <doc:midigridanimator>
    - <doc:launchcontrolplayground>
}

## Topics

### Getting Started

- <doc:LCMIDIDeviceManager>
- <doc:midi>

### MIDI Communication

### Device Interaction

### Launchpad Actions

### DIagnostics and Debugging
