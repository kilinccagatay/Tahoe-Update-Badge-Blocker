#import <Foundation/Foundation.h>

static NSString * const AttentionKey = @"AttentionPrefBundleIDs";
static NSString * const SoftwareUpdateID = @"com.apple.Software-Update-Settings.extension";
static NSNotificationName const RefreshDockTileNotification =
    @"com.apple.systempreferences.refreshdocktile";

static NSString *systemSettingsPreferencesPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Preferences/com.apple.systempreferences.plist"];
}

static NSString *systemSettingsContainerPreferencesPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Containers/com.apple.systempreferences/Data/Library/Preferences/com.apple.systempreferences.plist"];
}

static void refreshDockTile(void) {
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:RefreshDockTileNotification
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
}

static BOOL deleteAttentionPreference(NSString *preferencesPath) {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/defaults"];
    task.arguments = @[@"delete", preferencesPath, AttentionKey];
    task.standardOutput = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
    task.standardError = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];

    @try {
        [task launch];
        [task waitUntilExit];
        return task.terminationStatus == 0;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static NSData *exportPreferences(NSString *preferencesPath) {
    NSTask *task = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/defaults"];
    task.arguments = @[@"export", preferencesPath, @"-"];
    task.standardOutput = output;
    task.standardError = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];

    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (__unused NSException *exception) {
        return nil;
    }

    if (task.terminationStatus != 0) {
        return nil;
    }
    return [output.fileHandleForReading readDataToEndOfFile];
}

static BOOL importPreferences(NSDictionary *preferences, NSString *preferencesPath) {
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization
        dataWithPropertyList:preferences
                      format:NSPropertyListXMLFormat_v1_0
                     options:0
                       error:&error];
    if (!data || error) {
        return NO;
    }

    NSURL *temporaryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
        URLByAppendingPathComponent:[NSString stringWithFormat:
            @"TahoeUpdateBadgeBlocker-%@.plist", NSUUID.UUID.UUIDString]];
    if (![data writeToURL:temporaryURL options:NSDataWritingAtomic error:&error]) {
        return NO;
    }

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/defaults"];
    task.arguments = @[@"import", preferencesPath, temporaryURL.path];
    task.standardOutput = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
    task.standardError = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];

    BOOL succeeded = NO;
    @try {
        [task launch];
        [task waitUntilExit];
        succeeded = task.terminationStatus == 0;
    } @catch (__unused NSException *exception) {
        succeeded = NO;
    }

    [[NSFileManager defaultManager] removeItemAtURL:temporaryURL error:nil];
    return succeeded;
}

static BOOL updatePreferences(NSString *action, NSString *preferencesPath) {
    NSData *exportedData = exportPreferences(preferencesPath);
    NSMutableDictionary *preferences = nil;

    if (exportedData) {
        NSError *error = nil;
        preferences = [[NSPropertyListSerialization
            propertyListWithData:exportedData
                         options:NSPropertyListMutableContainersAndLeaves
                          format:nil
                           error:&error] mutableCopy];
        if (!preferences || error) {
            return NO;
        }
    } else if ([action isEqualToString:@"hide"]) {
        preferences = [[NSMutableDictionary alloc] init];
    } else {
        return YES;
    }

    id storedAttention = preferences[AttentionKey];
    NSMutableDictionary *attention = [storedAttention isKindOfClass:NSDictionary.class]
        ? [storedAttention mutableCopy]
        : [[NSMutableDictionary alloc] init];

    if ([action isEqualToString:@"hide"]) {
        attention[SoftwareUpdateID] = @0;
        preferences[AttentionKey] = attention;
        return importPreferences(preferences, preferencesPath);
    }

    [attention removeObjectForKey:SoftwareUpdateID];
    if (storedAttention != nil && !deleteAttentionPreference(preferencesPath)) {
        return NO;
    }
    if (attention.count == 0) {
        return YES;
    }

    preferences[AttentionKey] = attention;
    return importPreferences(preferences, preferencesPath);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            return 64;
        }

        NSString *action = [NSString stringWithUTF8String:argv[1]];
        if ([action isEqualToString:@"refresh"]) {
            refreshDockTile();
            return 0;
        }

        if (![action isEqualToString:@"hide"] &&
            ![action isEqualToString:@"restore"]) {
            return 64;
        }

        NSArray<NSString *> *preferencePaths = @[
            systemSettingsPreferencesPath(),
            systemSettingsContainerPreferencesPath()
        ];
        for (NSString *preferencesPath in preferencePaths) {
            if (!updatePreferences(action, preferencesPath)) {
                return 1;
            }
        }

        refreshDockTile();
        return 0;
    }
}
