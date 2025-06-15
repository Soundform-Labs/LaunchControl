//
//  LCMIDIDeviceManager.m
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
#import <LaunchControl/LCMIDIDeviceManager.h>
#import <LaunchControl/LCMIDILogger.h>

@interface LCMIDIDeviceManager () {
    MIDIClientRef _client;
    MIDIPortRef _inputPort;
    MIDIPortRef _outputPort;
    
    dispatch_queue_t _callbackQueue;
    dispatch_queue_t _syncQueue;
    
    // name => endpoint number (uintptr_t)
    // source endpoint => device name
    NSMutableDictionary<NSString *, NSNumber *> *_outputEndpoints;
    NSMutableDictionary<NSNumber *, NSString *> *_inputEndpointNames;
    
    void (^_inputHandler)(NSString *, NSData *);
    void (^_deviceChangeHandler)(NSArray<NSString *> *);
    
    BOOL _debugLoggingEnabled;
    
    NSMutableArray<NSString *> *_connectedDevicesMutable;
    
    dispatch_source_t _rescanTimer;
    
    NSUInteger _clientCreateRetryCount;
    NSUInteger _portCreateRetryCount;
}

@property (nonatomic, assign, readwrite) size_t maxMIDIPacketDataSize;

@end

@implementation LCMIDIDeviceManager

@synthesize connectedDevices = _connectedDevicesMutable;
@synthesize maxMIDIPacketDataSize = _maxMIDIPacketDataSize;

#pragma mark - Initialization

- (instancetype)initWithClientName:(nullable NSString *)clientName {
    self = [super init];
    if (self) {
        _callbackQueue = dispatch_get_main_queue();
        _syncQueue = dispatch_queue_create("com.soundform.lcmididevicemanager.sync", DISPATCH_QUEUE_SERIAL);
        _connectedDevicesMutable = [NSMutableArray array];
        _outputEndpoints = [NSMutableDictionary dictionary];
        _inputEndpointNames = [NSMutableDictionary dictionary];
        _debugLoggingEnabled = NO;
        self.maxMIDIPacketDataSize = 4096;
        
        if (!clientName) {
            clientName = @"LaunchControlMIDIClient";
        }
        
        _clientCreateRetryCount = 0;
        _portCreateRetryCount = 0;
        
        BOOL created = [self createMIDIClientWithName:clientName];
        if (!created) {
            return nil;
        }
    }
    return self;
}

- (void)setMaxMIDIPacketDataSize:(size_t)maxSize {
    dispatch_sync(_syncQueue, ^{
        _maxMIDIPacketDataSize = maxSize;
    });
}

- (size_t)maxMIDIPacketDataSize {
    __block size_t size;
    dispatch_sync(_syncQueue, ^{
        size = _maxMIDIPacketDataSize;
    });
    return size;
}

#pragma mark - Client and Port Creation with Retry Logic

- (BOOL)createMIDIClientWithName:(NSString *)clientName {
    OSStatus status = MIDIClientCreateWithBlock(
    (__bridge CFStringRef)clientName, &_client, ^(const MIDINotification *message) {
        [self scheduleRescanDevices];
                                                    
        if (self->_deviceChangeHandler) {
            NSArray *devices = [self connectedDevices];
            dispatch_async(self->_callbackQueue, ^{
                self->_deviceChangeHandler(devices);
            });
        }
    });
    
    if (status != noErr) {
        LCMIDI_LOG(LCMIDILogLevelError, @"Failed to create MIDI client (error %d)", (int)status);
        
        if (_clientCreateRetryCount++ < 3) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                [self createMIDIClientWithName:clientName];
            });
        }
        return NO;
    }
    _clientCreateRetryCount = 0;
    return YES;
}

- (BOOL)createPorts {
    OSStatus inStatus = MIDIInputPortCreateWithBlock(_client, CFSTR("LaunchControlInput"), &_inputPort,
    ^(const MIDIPacketList *pktlist, void *srcConnRefCon) {
        [self handleIncomingPacketList:pktlist sourceConnectionRefCon:srcConnRefCon];
    });
    
    OSStatus outStatus = MIDIOutputPortCreate(_client, CFSTR("LaunchControlOutput"), &_outputPort);
    
    if (inStatus != noErr || outStatus != noErr) {
        LCMIDI_LOG(LCMIDILogLevelError, @"Failed to create ports (in: %d, out: %d)",
                   (int)inStatus, (int)outStatus);
        
        if (_portCreateRetryCount++ < 3) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                [self createPorts];
            });
        }
        return NO;
    }
    
    _portCreateRetryCount = 0;
    return YES;
}

#pragma mark - Start / Stop

- (void)start {
    if (!_client) return;
    
    BOOL portsCreated = [self createPorts];
    if (!portsCreated) {
        LCMIDI_LOG(LCMIDILogLevelError, @"Failed to start due to port creation failure");
        return;
    }
    
    [self rescanDevices];
    [self rescanInputEndpoints];
}

- (void)stop {
    if (_inputPort != 0) {
        MIDIPortDispose(_inputPort);
        _inputPort = 0;
    }
    
    if (_outputPort != 0) {
        MIDIPortDispose(_outputPort);
        _outputPort = 0;
    }
    
    if (_client != 0) {
        MIDIClientDispose(_client);
        _client = 0;
    }
    
    dispatch_sync(_syncQueue, ^{
        [_connectedDevicesMutable removeAllObjects];
        [_outputEndpoints removeAllObjects];
        [_inputEndpointNames removeAllObjects];
    });
    
    _inputHandler = nil;
    _deviceChangeHandler = nil;
    
    if (_rescanTimer) {
        dispatch_source_cancel(_rescanTimer);
        _rescanTimer = nil;
    }
}

#pragma mark - Device Rescanning with Throttling

- (void)scheduleRescanDevices {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _rescanTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _syncQueue);
        dispatch_source_set_timer(_rescanTimer, DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC, 50 * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(_rescanTimer, ^{
            [self rescanDevices];
            [self rescanInputEndpoints];
        });
        dispatch_resume(_rescanTimer);
    });
}

- (void)rescanDevices {
    dispatch_sync(_syncQueue, ^{
        [_connectedDevicesMutable removeAllObjects];
        [_outputEndpoints removeAllObjects];
        
        ItemCount destCount = MIDIGetNumberOfDestinations();
        for (ItemCount i = 0; i < destCount; i++) {
            MIDIEndpointRef endpoint = MIDIGetDestination(i);
            if (!endpoint) continue;
            
            NSString *name = [self nameForEndpoint:endpoint];
            if (name.length > 0) {
                [_connectedDevicesMutable addObject:name];
                _outputEndpoints[name] = @((uintptr_t)endpoint);
            }
        }
    });
}

- (void)rescanInputEndpoints {
    dispatch_sync(_syncQueue, ^{
        [_inputEndpointNames removeAllObjects];
        
        ItemCount sourceCount = MIDIGetNumberOfSources();
        for (ItemCount i = 0; i < sourceCount; i++) {
            MIDIEndpointRef endpoint = MIDIGetSource(i);
            if (!endpoint) continue;
            
            NSString *name = [self nameForEndpoint:endpoint];
            if (name.length > 0) {
                _inputEndpointNames[@((uintptr_t)endpoint)] = name;
            }
        }
    });
}

#pragma mark - Device Info

- (NSArray<NSString *> *)connectedDevices {
    __block NSArray<NSString *> *devices;
    dispatch_sync(_syncQueue, ^{
        devices = [_connectedDevicesMutable copy];
    });
    return devices;
}

- (BOOL)isDeviceAvailable:(NSString *)deviceName {
    __block BOOL available;
    dispatch_sync(_syncQueue, ^{
        available = _outputEndpoints[deviceName] != nil;
    });
    return available;
}

- (NSInteger)indexOfOutputDeviceNamed:(NSString *)deviceName {
    __block NSInteger index;
    dispatch_sync(_syncQueue, ^{
        index = [_connectedDevicesMutable indexOfObject:deviceName];
    });
    return index;
}

- (MIDIEndpointRef)outputEndpointForDeviceNamed:(NSString *)deviceName {
    __block MIDIEndpointRef endpoint = 0;
    dispatch_sync(_syncQueue, ^{
        NSNumber *num = _outputEndpoints[deviceName];
        if (num) {
            endpoint = (MIDIEndpointRef)[num unsignedLongLongValue];
        }
    });
    return endpoint;
}

- (nullable NSString *)deviceNameForEndpoint:(MIDIEndpointRef)endpoint {
    return [self nameForEndpoint:endpoint];
}

- (NSArray<NSString *> *)allMIDIDeviceNames {
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    
    ItemCount outputCount = MIDIGetNumberOfDestinations();
    for (ItemCount i = 0; i < outputCount; i++) {
        MIDIEndpointRef endpoint = MIDIGetDestination(i);
        NSString *name = [self nameForEndpoint:endpoint];
        if (name) [names addObject:name];
    }
    
    ItemCount inputCount = MIDIGetNumberOfSources();
    for (ItemCount i = 0; i < inputCount; i++) {
        MIDIEndpointRef endpoint = MIDIGetSource(i);
        NSString *name = [self nameForEndpoint:endpoint];
        if (name) [names addObject:name];
    }
    
    return [names allObjects];
}

#pragma mark - Sending MIDI Data

- (void)sendData:(NSData *)data toDeviceNamed:(NSString *)deviceName {
    MIDIEndpointRef endpoint = [self outputEndpointForDeviceNamed:deviceName];
    if (endpoint) {
        [self sendData:data toEndpoint:endpoint];
    }
}

- (void)sendData:(NSData *)data toEndpoint:(MIDIEndpointRef)endpoint {
    if (!endpoint || data.length == 0 || !_outputPort) return;
    
    if (data.length > self.maxMIDIPacketDataSize) {
        LCMIDI_LOG(LCMIDILogLevelWarning, @"MIDI data size %lu exceeds max allowed %lu bytes; message discarded",
                   (unsigned long)data.length, (unsigned long)self.maxMIDIPacketDataSize);
        return;
    }
    
    size_t bufferSize = sizeof(MIDIPacketList) + data.length + 100;
    MIDIPacketList *packetList = (MIDIPacketList *)malloc(bufferSize);
    if (!packetList) {
        LCMIDI_LOG(LCMIDILogLevelError, @"Failed to allocate memory for MIDI packet list");
        return;
    }
    
    MIDIPacket *packet = MIDIPacketListInit(packetList);
    packet = MIDIPacketListAdd(packetList, bufferSize, packet, 0, data.length, data.bytes);
    if (!packet) {
        LCMIDI_LOG(LCMIDILogLevelError, @"Failed to add MIDI packet to packet list");
        free(packetList);
        return;
    }
    
    OSStatus status = MIDISend(_outputPort, endpoint, packetList);
    if (status != noErr) {
        LCMIDI_LOG(LCMIDILogLevelError, @"MIDISend failed with error %d", (int)status);
    }
    
    if (_debugLoggingEnabled) {
        LCMIDI_LOG(LCMIDILogLevelInfo, @"Sent %lu bytes to endpoint %#llx: %@",
                   (unsigned long)data.length, (unsigned long long)endpoint, data);
    }
    
    free(packetList);
}

#pragma mark - Handling Incoming MIDI Packets

- (void)handleIncomingPacketList:(const MIDIPacketList *)packetList sourceConnectionRefCon:(void *)srcConnRefCon {
    __block NSString *deviceName = @"<unknown>";
    
    if (srcConnRefCon != NULL) {
        NSNumber *endpointKey = @((uintptr_t)srcConnRefCon);
        dispatch_sync(_syncQueue, ^{
            NSString *name = self->_inputEndpointNames[endpointKey];
            if (name.length > 0) {
                deviceName = name;
            }
        });
    }
    
    const MIDIPacket *packet = &packetList->packet[0];
    for (NSUInteger i = 0; i < packetList->numPackets; i++) {
        NSData *data = [NSData dataWithBytes:packet->data length:packet->length];
        if (_debugLoggingEnabled) {
            LCMIDI_LOG(LCMIDILogLevelInfo, @"Received %lu bytes from %@: %@",
                       (unsigned long)data.length, deviceName, data);
        }
        if (_inputHandler) {
            dispatch_async(_callbackQueue, ^{
                self->_inputHandler(deviceName, data);
            });
        }
        packet = MIDIPacketNext(packet);
    }
}

#pragma mark - Handlers and Logging

- (void)setInputHandler:(void (^)(NSString *, NSData *))handler {
    _inputHandler = [handler copy];
}

- (void)setDispatchQueue:(dispatch_queue_t)queue {
    _callbackQueue = queue ?: dispatch_get_main_queue();
}

- (void)setDeviceListDidChangeHandler:(void (^)(NSArray<NSString *> *))handler {
    _deviceChangeHandler = [handler copy];
}

- (void)enableDebugLogging {
    _debugLoggingEnabled = YES;
}

- (void)disableDebugLogging {
    _debugLoggingEnabled = NO;
}

#pragma mark - Utilities

- (NSString *)nameForEndpoint:(MIDIEndpointRef)endpoint {
    if (!endpoint) return nil;
    CFStringRef name = nil;
    if (MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name) == noErr && name) {
        return (__bridge_transfer NSString *)name;
    }
    return nil;
}

#pragma mark - Runtime Reset Support (optional)

- (void)resetMIDIClient {
    [self stop];
    
    if (_clientCreateRetryCount == 0) {
        BOOL created = [self createMIDIClientWithName:@"LaunchControlMIDIClient"];
        if (!created) {
            LCMIDI_LOG(LCMIDILogLevelError, @"Failed to recreate MIDI client during reset");
            return;
        }
    }
    
    BOOL portsCreated = [self createPorts];
    if (!portsCreated) {
        LCMIDI_LOG(LCMIDILogLevelError, @"Failed to recreate MIDI ports during reset");
        return;
    }
    
    [self rescanDevices];
    [self rescanInputEndpoints];
    [self start];
}

@end
