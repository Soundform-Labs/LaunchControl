//
//  LCMIDILogger.m
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
#import <LaunchControl/LCMIDILogger.h>

static inline NSString *LCMIDILogLevelString(LCMIDILogLevel level) {
    switch (level) {
        case LCMIDILogLevelInfo: return @"[INFO]:";
        case LCMIDILogLevelWarning: return @"[WARN]:";
        case LCMIDILogLevelError: return @"[ERROR]:";
        case LCMIDILogLevelFatal: return @"[FATAL]:";
    }
    
    return @"[UNKNOWN]";
}

void LCMIDIWriteLog(
    LCMIDILogLevel level,
    const char *file,
    int line,
    const char *function,
    NSString *message
) {
    NSString *levelStr = LCMIDILogLevelString(level);
    NSString *timestamp = [[NSDate date] descriptionWithLocale:[NSLocale currentLocale]];
    
    fprintf(stderr, "[%s] [%s] [%s:%d] %s — %s\n",
        levelStr.UTF8String,
        timestamp.UTF8String,
        file,
        line,
        function,
        message.UTF8String
    );
}
