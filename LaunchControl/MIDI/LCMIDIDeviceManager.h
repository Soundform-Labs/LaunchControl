//
//  LCMIDIDeviceManager.h
//  LaunchControl
//
//  Copyright (c) 2025 - Soundform Labs. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

NS_ASSUME_NONNULL_BEGIN

/// A MIDI device manager based on CoreMIDI, designed to facilitate communication with connected MIDI hardware.
///
/// `LCMIDIDeviceManager` provides a centralized interface for interacting with CoreMIDI endpoints.
/// It supports device enumeration, name-to-endpoint resolution, inbound message reception, and outbound data transmission.
/// This manager abstracts the CoreMIDI C APIs into an Objective-C interface suitable for both Objective-C and Swift applications.
@interface LCMIDIDeviceManager : NSObject

/// An array of connected and available output device names currently visible to the system.
///
/// This array is updated automatically after invoking ``start``, ``rescanDevices``,
/// or when system MIDI notifications indicate device connections or disconnections.
@property (nonatomic, readonly) NSArray<NSString *> *connectedDevices;

/// Maximum allowed size in bytes for a single MIDI packet data message.
/// Messages larger than this will be rejected and logged as warnings.
/// Default is 4096 bytes.
@property (nonatomic, assign, readonly) size_t maxMIDIPacketDataSize;

/// Creates and configures a new instance of the MIDI device manager with a client name to register with CoreMIDI.
///
/// - Parameter clientName: The client name used to identify this MIDI session with the system.
///   If `nil`, a default name is generated internally.
/// - Returns: A new instance of ``LCMIDIDeviceManager`` ready for use.
- (instancetype)initWithClientName:(nullable NSString *)clientName;

/// Initializes the internal CoreMIDI client and allocates input and output ports.
///
/// This method must be invoked before performing any MIDI communication operations,
/// including sending data or registering input handlers.
- (void)start;

/// Tears down the CoreMIDI client and releases all allocated ports and endpoint references.
///
/// This method effectively deactivates the MIDI manager. MIDI communication will remain unavailable
/// until `start` is called again.
- (void)stop;

/// Sets the maximum allowed size in bytes for a single MIDI packet data message.
/// Messages larger than this will be rejected and logged as warnings.
///
/// @param maxSize The new maximum packet data size in bytes.
- (void)setMaxMIDIPacketDataSize:(size_t)maxSize;

/// Resets the internal MIDI client and ports, reinitializing them.
/// Useful for recovering from errors or device changes without restarting the app.
- (void)resetMIDIClient;

/// Sends a MIDI message to a connected output device identified by its name.
///
/// Internally, this method resolves the device name to a `MIDIEndpointRef` before dispatching the message.
/// If the device is not found in the current list of output endpoints, this call is silently ignored.
///
/// - Parameters:
///   - data: A binary data object containing a complete MIDI message (e.g., Note On, SysEx).
///   - deviceName: The exact display name of the output device to send data to. Matching is case-sensitive.
- (void)sendData:(nonnull NSData *)data toDeviceNamed:(nonnull NSString *)deviceName;

/// Sends a MIDI message directly to the specified CoreMIDI output endpoint.
///
/// - Parameters:
///    - data: A binary data object containing a complete MIDI message.
///    - endpoint: A valid `MIDIEndpointRef` corresponding to an output destination.
/// - Warning: This method bypasses the device name abstraction and sends raw data directly to the specified endpoint.
///   The caller is responsible for ensuring that the endpoint is valid and operational.
- (void)sendData:(nonnull NSData *)data toEndpoint:(MIDIEndpointRef)endpoint;

/// Assigns a handler block to receive incoming MIDI messages from all connected input sources.
///
/// - Parameter handler: A callback block invoked whenever data is received on any input device.
///   The block receives the sending device’s display name and the raw MIDI data.
///
/// - Important: By default, the handler executes on the main dispatch queue.
///   To change the execution context, use `setDispatchQueue:` before assigning this handler.
- (void)setInputHandler:(nullable void (^)(NSString *deviceName, NSData *data))handler;

/// Specifies the dispatch queue on which the input handler block should execute.
///
/// If not explicitly set, messages are delivered on the main queue. This method allows fine-grained
/// control over concurrency and execution context. 
///
/// - Parameter queue: A `dispatch_queue_t` instance that will receive the input handler invocations.
/// - Note: The default queue is the main queue if this method is not called.
- (void)setDispatchQueue:(dispatch_queue_t)queue;

/// Manually initiates a device rescan to refresh the list of available endpoints.
///
/// This method is useful when hardware devices are connected or disconnected and automatic CoreMIDI
/// notifications are insufficient or delayed.
- (void)rescanDevices;

/// Checks whether a specific output device is currently available by name.
///
/// - Parameter deviceName: The exact name of the output device to verify.
/// - Returns: `YES` if the device is currently available and active; otherwise, `NO`.
- (BOOL)isDeviceAvailable:(NSString *)deviceName;

/// Retrieves a combined list of all known MIDI device names, including both input and output endpoints.
///
/// - Returns: An array of `NSString` instances representing the display names of available MIDI devices.
- (NSArray<NSString *> *)allMIDIDeviceNames;

/// Returns the index of a named output device within the internal output device list.
///
/// - Parameter deviceName: The output device name to search for.
/// - Returns: A valid index if the device is found, or `-1` if it is not present in the list.
- (NSInteger)indexOfOutputDeviceNamed:(NSString *)deviceName;

/// Resolves the specified output device name to a `MIDIEndpointRef` that can be used for direct transmission.
///
/// - Parameter deviceName: The exact name of the output device.
/// - Returns: A `MIDIEndpointRef` representing the endpoint associated with the device, or `NULL` if unavailable.
- (MIDIEndpointRef)outputEndpointForDeviceNamed:(NSString *)deviceName;

/// Resolves the device name associated with a given MIDI endpoint reference.
///
/// - Parameter endpoint: The endpoint reference to resolve.
/// - Returns: A string containing the device name, or `nil` if no name could be determined.
- (nullable NSString *)deviceNameForEndpoint:(MIDIEndpointRef)endpoint;

/// Registers a block to be executed when the list of connected devices changes due to system notifications or manual rescan.
///
/// - Parameter handler: A block that receives the newly updated list of connected device names.
- (void)setDeviceListDidChangeHandler:(nullable void (^)(NSArray<NSString *> *connectedDevice))handler;

/// Enables debug output for MIDI message transmission and reception to assist with development and troubleshooting.
///
/// Logged messages include the contents of outgoing and incoming MIDI packets.
- (void)enableDebugLogging;

/// Disables debug output previously enabled with ``enableDebugLogging``.
- (void)disableDebugLogging;

@end

NS_ASSUME_NONNULL_END
