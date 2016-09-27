//
// Copyright © 2016 Factory Method. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>



@interface RACSignal (FM)

-(RACSignal *) eagerThrottleForInterval:(NSTimeInterval) interval
						  afterAllowing:(uint) count;

@end
