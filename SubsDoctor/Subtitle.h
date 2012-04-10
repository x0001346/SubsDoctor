//
//  Subtitle.h
//  SubsDoctor
//
//  Created by Bruno Ferreira on 11/07/24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Subtitle : NSObject {
    NSString *subtitle;
    float showTime;
    float period;
    BOOL hasInvalidStartTime;
}

@property (readwrite, copy) NSString *subtitle;
@property (readwrite, assign) float showTime;
@property (readwrite, assign) float period;
@property (readwrite, assign) BOOL hasInvalidStartTime;

- (id)subtitleWithContent:(NSString *)newSubtitle show:(float)showAt hide:(float)hideAt;
- (BOOL)hasInvalidPeriod;
+ (NSString *)subtitleTimeToString:(float)subtitleTime;
- (NSString *)showTimeAsString;
- (NSString *)hideTimeAsString;


@end
