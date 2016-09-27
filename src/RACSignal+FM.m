//
//  RACSignal+FM.m
//
//  Created by Daniel Wang on 6/12/15.
//

#import "RACSignal+FM.h"
@import ReactiveCocoa.RACSignal_Operations;

@implementation RACSignal (FM)

-(RACSignal *) eagerThrottleForInterval:(NSTimeInterval) interval
						  afterAllowing:(uint) count
{
	__block NSTimeInterval timeFirstEventPassedThrough;
	__block NSTimeInterval timeFirstEventThrottled = 0;
	__block uint numberEventsPassedThrough = 0;

	return [self throttle:interval
		valuesPassingTest:^BOOL(id next) {
			NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

			if (numberEventsPassedThrough == 0)
			{
				timeFirstEventPassedThrough = now;
				numberEventsPassedThrough = 1;
				return NO;
			}

			if (timeFirstEventThrottled)
			{
				if (now > (timeFirstEventThrottled + interval))
				{
					// First event after most recent interval. No throttle
					timeFirstEventPassedThrough = now;
					timeFirstEventThrottled = 0;
					numberEventsPassedThrough = 1;
					return NO;
				}

				// Still inside current throttle interval. Keep throttling
				return YES;
			}
			else if (timeFirstEventPassedThrough)
			{
				if (now > (timeFirstEventPassedThrough + interval))
				{
					// First event after most recent interval. No throttle
					timeFirstEventPassedThrough = now;
					timeFirstEventThrottled = 0;
					numberEventsPassedThrough = 1;
					return NO;
				}

				if (numberEventsPassedThrough < count) {
					numberEventsPassedThrough++;
					return NO;
				}
			}

			timeFirstEventThrottled = now;
			return YES;
		}];
}

@end