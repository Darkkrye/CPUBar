//
//  AppDelegate.m
//  CPUBar
//
//  Created by BlueCocoa on 2016/11/8.
//  Copyright © 2016 BlueCocoa. All rights reserved.
//

#import "AppDelegate.h"
#import <mach/mach.h>

#define CPU_STATUS_MASK 0x1000

@implementation AppDelegate {
    mach_port_t port;
    host_priv_t priv_port;
    processor_port_array_t processor_list;
    mach_msg_type_number_t processor_count;
    NSInteger masterCPU;
}

#pragma mark
#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    masterCPU = -1;
    processor_count = 0;
    processor_list = (processor_port_array_t)0;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    NSResponder * next = [self nextResponder];
    while (next) {
        // Is NSTouchBar provider?
        //  - YES, break
        //  - NO,
        next = [next nextResponder];
    }
}

#pragma mark
#pragma mark - NSTouchBarDelegate

- (NSTouchBar *)makeTouchBar {
    [NSApplication sharedApplication];
    [[[NSApplication sharedApplication] keyWindow] windowController];
    self.touchBar = [[NSTouchBar alloc] init];
    [self.touchBar setCustomizationIdentifier:@"com.0xBBC.CPUBar"];
    [self.touchBar setDelegate:self];
    
    if ([self retriveProcessorInfo]) {
        NSMutableArray<NSString *> * defaultItemIdentifiers = [[NSMutableArray alloc] init];
        for (int i = 0; i < processor_count; i++) {
            [defaultItemIdentifiers addObject:[[NSString alloc] initWithFormat:@"com.0xBBC.CPUBar.CPU%d", i]];
        }
        [self.touchBar setDefaultItemIdentifiers:defaultItemIdentifiers];
    } else {
        [self alertMessage:@"Oops, CPUBar needs root privilege to run/" informative:@"Try to run CPUBar with root privilege"];
        [NSApp terminate:nil];
    }
    
    return self.touchBar;
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    NSCustomTouchBarItem * item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
    NSButton * button = [NSButton buttonWithTitle:@"" target:self action:@selector(setProcessor:)];
    button.tag = [[identifier substringFromIndex:@"com.0xBBC.CPUBar.CPU".length] integerValue];
    
    processor_basic_info_data_t basic_info;
    mach_msg_type_number_t info_count = PROCESSOR_BASIC_INFO_COUNT;
    processor_info(processor_list[button.tag], PROCESSOR_BASIC_INFO, &port, (processor_info_t)&basic_info, &info_count);
    if (basic_info.is_master) {
        // normally, it would be number 0
        // but just in case...
        masterCPU = button.tag;
    }
    button.attributedTitle = [self stringForCPU:button.tag status:basic_info.running];
    
    item.view = button;
    return item;
}

#pragma mark
#pragma mark - Private Methods

- (BOOL)retriveProcessorInfo {
    port = mach_host_self();
    kern_return_t rc;
    
    rc = host_get_host_priv_port(port, &priv_port);
    if (rc != KERN_SUCCESS) return NO;
    
    rc = host_processors(priv_port, &processor_list, &processor_count);
    if (rc != KERN_SUCCESS) return NO;
    
    return YES;
}

- (void)alertMessage:(NSString *)msg informative:(NSString *)info {
    NSAlert * alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = msg;
    alert.informativeText = info;
    [alert runModal];
}

- (NSAttributedString *)stringForCPU:(NSInteger)index status:(BOOL)on {
    NSMutableAttributedString * string = [[NSMutableAttributedString alloc] initWithString:@"●" attributes:@{NSForegroundColorAttributeName: on ? [NSColor greenColor] : [NSColor redColor]}];
    [string appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" CPU %ld ", index] attributes:@{NSForegroundColorAttributeName: [NSColor whiteColor]}]];
    [string setAlignment:NSTextAlignmentCenter range:NSMakeRange(0, string.length)];
    return string;
}

- (void)setProcessor:(NSButton *)button {
    kern_return_t kr;
    if (button.tag & CPU_STATUS_MASK) {
        button.tag &= ~CPU_STATUS_MASK;
        kr = processor_start(processor_list[button.tag]);
        if (kr != KERN_SUCCESS) {
            [self alertMessage:[NSString stringWithFormat:@"∑(ﾟДﾟ) Cannot restart CPU %ld", button.tag] informative:@"Perhaps wait for a moment and retry it"];
            button.tag |= CPU_STATUS_MASK;
        } else {
            button.attributedTitle = [self stringForCPU:button.tag status:YES];
        }
    } else {
        if (button.tag == masterCPU) {
            // trust me, no one really wants to stop the master CPU
            return;
        }
        kr = processor_exit(processor_list[button.tag]);
        if (kr != KERN_SUCCESS) {
            [self alertMessage:[NSString stringWithFormat:@"∑(ﾟДﾟ) Cannot stop CPU %ld", button.tag] informative:@"Perhaps wait for a moment and retry it"];
        } else {
            button.attributedTitle = [self stringForCPU:button.tag status:NO];
            button.tag |= CPU_STATUS_MASK;
        }
    }
}

@end
