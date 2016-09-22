//
// Copyright © 2016 Factory Method. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <ReactiveCocoa/ReactiveCocoa.h>



FOUNDATION_EXPORT NSString* __nonnull const FMCoreBluetoothErrorDomain;
enum {
	FMCoreBluetoothPeripheralDisconnectingError = 1000,
	FMCoreBluetoothPeripheralNotConnectedError
};



@class FMCentralManagerDelegateProxy;



@interface CBCentralManager (FM)

+(nonnull instancetype) fm_centralManagerWithDelegate:(nullable id<CBCentralManagerDelegate>) delegate
												queue:(nullable dispatch_queue_t) queue
											  options:(nullable NSDictionary<NSString *, id> *) options;

@property (nonatomic, readonly, nonnull) FMCentralManagerDelegateProxy* fm_delegateProxy;

@property (nonatomic, readonly, nonnull) NSString* fm_stateName;

@property (atomic, readonly, nonnull) RACSignal* rac_didUpdateStateSignal;
@property (atomic, readonly, nonnull) RACSignal* rac_didDiscoverPeripheralSignal;
@property (atomic, readonly, nonnull) RACSignal* rac_didConnectPeripheralSignal;
@property (atomic, readonly, nonnull) RACSignal* rac_didDisconnectPeripheralSignal;
@property (atomic, readonly, nonnull) RACSignal* rac_didFailToConnectPeripheralSignal;

-(nonnull RACSignal *) fm_discoverPeripheralWithServiceUUIDs:(nonnull NSArray *) targetServiceUUIDs
													 timeout:(NSTimeInterval) timeout;

-(nonnull RACSignal *) fm_connectToPeripheral:(nonnull CBPeripheral *) peripheral
									  options:(nullable NSDictionary<NSString *,id> *) option
									  timeout:(NSTimeInterval) timeout;

-(nonnull RACSignal *) fm_cancelPeripheralConnection:(nonnull CBPeripheral *) peripheral;

@end



@interface FMCentralManagerDelegateProxy : NSObject <CBCentralManagerDelegate>

@property (nonatomic, weak, nullable) id<CBCentralManagerDelegate> superDelegate;

-(nonnull RACSignal *) signalForSelector:(nonnull SEL) selector;

@end
