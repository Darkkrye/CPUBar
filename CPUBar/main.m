//
//  main.m
//  CPUBar
//
//  Created by BlueCocoa on 2016/11/8.
//  Copyright © 2016 BlueCocoa. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    uid_t uid = getuid();
    if (uid == 0) {
        return NSApplicationMain(argc, argv);
    } else {
        NSString * script = [NSString stringWithFormat:@"do shell script \"%s\" with administrator privileges", argv[0]];
        NSAppleScript * appleScript = [[NSAppleScript alloc] initWithSource:script];
        [appleScript executeAndReturnError:nil];
        return 0;
    }
}
