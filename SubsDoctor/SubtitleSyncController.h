//
//  SubtitleSyncController.h
//  SubsDoctor
//
//  Created by Bruno Ferreira on 11/08/15.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SubtitleSyncController : NSObject {

    IBOutlet NSSegmentedControl *syncPoints;

@private
    
    
}

- (IBAction) syncronizeSubtitles:(id)sender;

@end
