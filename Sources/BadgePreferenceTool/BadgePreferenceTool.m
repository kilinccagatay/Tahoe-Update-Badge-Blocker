#import <Foundation/Foundation.h>

static NSString * const SystemSettingsDomain = @"com.apple.systempreferences";
static NSString * const AttentionKey = @"AttentionPrefBundleIDs";
static NSString * const SoftwareUpdateID = @"com.apple.Software-Update-Settings.extension";
static NSNotificationName const RefreshDockTileNotification =
    @"com.apple.systempreferences.refreshdocktile";

static void refreshDockTile(void) {
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:RefreshDockTileNotification
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
}

static BOOL deleteAttentionPreference(void) {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/defaults"];
    task.arguments = @[@"delete", SystemSettingsDomain, AttentionKey];
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

static NSData *exportPreferences(void) {
    NSTask *task = [[NSTask alloc] init];
    NSPipe *output = [NSPipe pipe];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/defaults"];
    task.arguments = @[@"export", SystemSettingsDomain, @"-"];
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

static BOOL importPreferences(NSDictionary *preferences) {
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
    task.arguments = @[@"import", SystemSettingsDomain, temporaryURL.path];
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

        NSData *exportedData = exportPreferences();
        if (!exportedData) {
            return 1;
        }

        NSError *error = nil;
        NSMutableDictionary *preferences = [[NSPropertyListSerialization
            propertyListWithData:exportedData
                         options:NSPropertyListMutableContainersAndLeaves
                          format:nil
                           error:&error] mutableCopy];
        if (!preferences || error) {
            return 1;
        }

        id storedAttention = preferences[AttentionKey];
        NSMutableDictionary *attention = [storedAttention isKindOfClass:NSDictionary.class]
            ? [storedAttention mutableCopy]
            : [[NSMutableDictionary alloc] init];

        if ([action isEqualToString:@"hide"]) {
            attention[SoftwareUpdateID] = @0;
            preferences[AttentionKey] = attention;
        } else if ([action isEqualToString:@"restore"]) {
            [attention removeObjectForKey:SoftwareUpdateID];
            BOOL hadAttentionPreference = storedAttention != nil;
            if (hadAttentionPreference && !deleteAttentionPreference()) {
                return 1;
            }
            if (attention.count == 0) {
                refreshDockTile();
                return 0;
            } else {
                preferences[AttentionKey] = attention;
            }
        } else {
            return 64;
        }

        if (!importPreferences(preferences)) {
            return 1;
        }
        refreshDockTile();
        return 0;
    }
}
