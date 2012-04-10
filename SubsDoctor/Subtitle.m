//
//  Subtitle.m
//  SubsDoctor
//
//  Created by Bruno Ferreira on 11/07/24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Subtitle.h"


@implementation Subtitle

@synthesize subtitle;
@synthesize showTime;
@synthesize period;
@synthesize hasInvalidStartTime;


- (id)init
{
    self = [super init];
    
    if (self)
    {
        subtitle = @"";
        showTime = 0;
        period = 0;
    }
    return self;
}

- (id)subtitleWithContent:(NSString *)newSubtitle show:(float)showAt hide:(float)hideAt
{
    if ([self init])
    {
        [self setSubtitle:newSubtitle];
        showTime = showAt;
        period = hideAt - showAt;
    }
    return self;
}

- (BOOL)hasInvalidPeriod
{
    if (period <= 0)
    {
        return YES;
    }
    
    return NO;
}


+ (NSString *)subtitleTimeToString:(float)subtitleTime
{
    int hour = subtitleTime / 3600;
    int minute = (subtitleTime - (hour * 3600)) / 60;
    float second = subtitleTime;
    while (second >= 60)
    {
        second -= 60;
    }
    
    return [NSString stringWithFormat:@"%02d:%02d:%06.3f", hour, minute, second];
}


- (NSString*)showTimeAsString
{
    float subtitleTime = showTime;
    
    int hour = subtitleTime / 3600;
    int minute = (subtitleTime - (hour * 3600)) / 60;
    float second = subtitleTime;
    while (second >= 60)
    {
        second -= 60;
    }

    NSString *string = [NSString stringWithFormat:@"%02d:%02d:%06.3f", hour, minute, second];

    return string;
}


- (NSString*)hideTimeAsString
{
    float subtitleTime = showTime + period;
    
    int hour = subtitleTime / 3600;
    int minute = (subtitleTime - (hour * 3600)) / 60;
    float second = subtitleTime;
    while (second >= 60)
    {
        second -= 60;
    }
    
    NSString *string = [NSString stringWithFormat:@"%02d:%02d:%06.3f", hour, minute, second];
    
    return string;
}


@end
