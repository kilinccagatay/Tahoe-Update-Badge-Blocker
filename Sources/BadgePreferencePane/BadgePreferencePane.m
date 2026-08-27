#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>

static NSString * const SettingsDomain = @"com.cagatay.BadgeHider";

@interface BadgePreferencePane : NSPreferencePane
@property (nonatomic, strong) NSSwitch *enabledSwitch;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *changeHint;
@end

@implementation BadgePreferencePane

- (NSString *)text:(NSString *)key fallback:(NSString *)fallback {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    return [bundle localizedStringForKey:key value:fallback table:nil];
}

- (NSView *)loadMainView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 370)];

    NSTextField *title = [NSTextField labelWithString:
        [self text:@"badge_title" fallback:@"Tahoe Update Badge Blocker"]];
    title.font = [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
    title.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *description = [NSTextField wrappingLabelWithString:[self
        text:@"badge_description"
        fallback:@"Blocks the red System Settings Dock badge when macOS Tahoe 26 is the only available upgrade. Sequoia 15.x, Safari, security, iCloud, and Apple Account badges remain enabled."]];
    description.font = [NSFont systemFontOfSize:13];
    description.textColor = NSColor.secondaryLabelColor;
    description.translatesAutoresizingMaskIntoConstraints = NO;

    self.enabledSwitch = [[NSSwitch alloc] initWithFrame:NSZeroRect];
    self.enabledSwitch.target = self;
    self.enabledSwitch.action = @selector(toggleChanged:);
    self.enabledSwitch.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *switchLabel = [NSTextField labelWithString:[self
        text:@"toggle_label"
        fallback:@"Block the Tahoe update badge"]];
    switchLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    switchLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.font = [NSFont systemFontOfSize:12];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.changeHint = [NSTextField wrappingLabelWithString:@""];
    self.changeHint.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.changeHint.textColor = NSColor.systemOrangeColor;
    self.changeHint.hidden = YES;
    self.changeHint.translatesAutoresizingMaskIntoConstraints = NO;

    NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *uninstallButton = [NSButton buttonWithTitle:
        [self text:@"uninstall_button" fallback:@"Uninstall…"]
                                                    target:self
                                                    action:@selector(uninstall:)];
    uninstallButton.bezelStyle = NSBezelStyleRounded;
    uninstallButton.contentTintColor = NSColor.systemRedColor;
    uninstallButton.translatesAutoresizingMaskIntoConstraints = NO;

    [view addSubview:title];
    [view addSubview:description];
    [view addSubview:self.enabledSwitch];
    [view addSubview:switchLabel];
    [view addSubview:self.statusLabel];
    [view addSubview:self.changeHint];
    [view addSubview:separator];
    [view addSubview:uninstallButton];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:28],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:view.trailingAnchor constant:-28],
        [title.topAnchor constraintEqualToAnchor:view.topAnchor constant:28],

        [description.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [description.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-28],
        [description.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],

        [self.enabledSwitch.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.enabledSwitch.topAnchor constraintEqualToAnchor:description.bottomAnchor constant:26],
        [switchLabel.leadingAnchor constraintEqualToAnchor:self.enabledSwitch.trailingAnchor constant:10],
        [switchLabel.centerYAnchor constraintEqualToAnchor:self.enabledSwitch.centerYAnchor],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:switchLabel.trailingAnchor constant:10],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.enabledSwitch.centerYAnchor],

        [self.changeHint.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.changeHint.trailingAnchor constraintLessThanOrEqualToAnchor:view.trailingAnchor constant:-28],
        [self.changeHint.topAnchor constraintEqualToAnchor:self.enabledSwitch.bottomAnchor constant:14],

        [separator.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-28],
        [separator.topAnchor constraintEqualToAnchor:self.changeHint.bottomAnchor constant:28],

        [uninstallButton.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [uninstallButton.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:18]
    ]];

    self.mainView = view;
    [self refreshState];
    return view;
}

- (void)willSelect {
    [self refreshState];
}

- (void)refreshState {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:SettingsDomain];
    if ([defaults objectForKey:@"Enabled"] == nil) {
        [defaults setBool:YES forKey:@"Enabled"];
    }
    BOOL enabled = [defaults boolForKey:@"Enabled"];
    self.enabledSwitch.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.statusLabel.stringValue = enabled
        ? [self text:@"status_enabled" fallback:@"Enabled"]
        : [self text:@"status_disabled" fallback:@"Off"];
    self.changeHint.hidden = YES;
}

- (void)uninstall:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = [self
        text:@"uninstall_title"
        fallback:@"Uninstall Tahoe Update Badge Blocker?"];
    alert.informativeText = [self
        text:@"uninstall_message"
        fallback:@"This removes the preference pane and its background helper, then restores native badge handling."];
    [alert addButtonWithTitle:[self
        text:@"uninstall_confirm"
        fallback:@"Uninstall"]];
    [alert addButtonWithTitle:[self text:@"cancel" fallback:@"Cancel"]];

    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSString *script = [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Application Support/HideSystemSettingsBadge/uninstall.sh"];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
    task.arguments = @[script];
    @try {
        [task launch];
        self.statusLabel.stringValue = [self
            text:@"uninstalling"
            fallback:@"Uninstalling…"];
    } @catch (__unused NSException *exception) {
        self.statusLabel.stringValue = [self
            text:@"uninstall_failed"
            fallback:@"Uninstall could not be started"];
    }
}

- (void)toggleChanged:(NSSwitch *)sender {
    BOOL enabled = sender.state == NSControlStateValueOn;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:SettingsDomain];
    [defaults setBool:enabled forKey:@"Enabled"];
    [defaults synchronize];
    self.changeHint.stringValue = [self
        text:@"applying_change"
        fallback:@"Applying badge setting…"];
    self.changeHint.textColor = NSColor.systemOrangeColor;
    self.changeHint.hidden = NO;
    [self applyImmediately:YES];
    self.statusLabel.stringValue = enabled
        ? [self text:@"status_enabled" fallback:@"Enabled"]
        : [self text:@"status_disabled" fallback:@"Off"];
}

- (void)applyImmediately:(BOOL)forceRefresh {
    NSString *script = @"$HOME/Library/Application Support/HideSystemSettingsBadge/hide-badge.sh";
    if (forceRefresh) {
        script = [script stringByAppendingString:@" --force-refresh"];
    }
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
    task.arguments = @[@"-c", script];
    NSFileHandle *nullHandle = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
    task.standardOutput = nullHandle;
    task.standardError = nullHandle;
    __weak typeof(self) weakSelf = self;
    task.terminationHandler = ^(NSTask *completedTask) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completedTask.terminationStatus == 0) {
                weakSelf.changeHint.hidden = YES;
            } else {
                weakSelf.changeHint.stringValue = [weakSelf
                    text:@"apply_failed"
                    fallback:@"The badge setting could not be applied. Try again."];
                weakSelf.changeHint.textColor = NSColor.systemRedColor;
                weakSelf.changeHint.hidden = NO;
            }
        });
    };
    @try {
        [task launch];
    } @catch (__unused NSException *exception) {
        self.changeHint.stringValue = [self
            text:@"apply_failed"
            fallback:@"The badge setting could not be applied. Try again."];
        self.changeHint.textColor = NSColor.systemRedColor;
        self.changeHint.hidden = NO;
    }
}

@end
