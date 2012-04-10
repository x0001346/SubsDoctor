//
//  SubsDoctorAppDelegate.m
//  SubsDoctor
//
//  Created by Bruno Ferreira on 11/07/24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SubsDoctorAppDelegate.h"

@implementation SubsDoctorAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp terminate:self];
}

- (void)windowDidExpose:(NSNotification *)notification
{
    [previewWindow makeKeyAndOrderFront:self];
}

@end
