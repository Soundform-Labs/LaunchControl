//
//  LCMIDILogger.h
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

typedef NS_ENUM(NSUInteger, LCMIDILogLevel) {
    LCMIDILogLevelInfo,
    LCMIDILogLevelWarning,
    LCMIDILogLevelError,
    LCMIDILogLevelFatal
};

/// Writes a log message with specified level, file, line, and function context.
/// Use the provided macro `LCMIDI_LOG` for convenient calls.
FOUNDATION_EXPORT void LCMIDIWriteLog(LCMIDILogLevel level,
                                      const char *file,
                                      int line,
                                      const char *function,
                                      NSString *message);

/// Convenience macro for logging with automatic file, line, and function.
/// Use like: LCMIDI_LOG(LCMIDILogLevelError, @"Error happened: %@", error);
#define LCMIDI_LOG(level, fmt, ...) \
LCMIDIWriteLog(level, __FILE_NAME__, __LINE__, __PRETTY_FUNCTION__, [NSString stringWithFormat:(fmt), ##__VA_ARGS__])
