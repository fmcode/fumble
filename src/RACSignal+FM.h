//
//  RACSignal+FM.h
//
//  Created by Daniel Wang on 6/12/15.
//

@import Foundation;
@import ReactiveCocoa;

@interface RACSignal (FM)

-(RACSignal *) eagerThrottleForInterval:(NSTimeInterval) interval
						  afterAllowing:(uint) count;

@end
