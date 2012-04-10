//
//  SubsDoctorAppDelegate.h
//  SubsDoctor
//
//  Created by Bruno Ferreira on 11/07/24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SubsDoctorAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate> {
@private
    NSWindow *window;
    NSWindow *previewWindow;
}

@property (assign) IBOutlet NSWindow *window;

@end
