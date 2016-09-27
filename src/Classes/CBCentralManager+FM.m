//
// Copyright © 2016 Factory Method. All rights reserved.
//

#import "CBCentralManager+FM.h"
#import "CBPeripheral+FM.h"
#import <objc/runtime.h>



NSString* const FMCoreBluetoothErrorDomain = @"fm.corp.ios.bluetooth";



@implementation CBCentralManager (FM)

+(instancetype) fm_centralManagerWithDelegate:(id<CBCentralManagerDelegate>) delegate
										queue:(dispatch_queue_t) queue
									  options:(NSDictionary<NSString *, id> *) options
{
	FMCentralManagerDelegateProxy* proxy = [[FMCentralManagerDelegateProxy alloc] init];
	CBCentralManager* central = [[self alloc] initWithDelegate:proxy
														 queue:queue
													   options:options];

	objc_setAssociatedObject(central, @selector(fm_delegateProxy), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	proxy.superDelegate = delegate;

	return central;
}

-(void) fm_useDelegateProxy
{
	if (self.delegate == self.fm_delegateProxy)
		return;

	self.fm_delegateProxy.superDelegate = self.delegate;
	self.delegate = self.fm_delegateProxy;
}

-(FMCentralManagerDelegateProxy *) fm_delegateProxy
{
	FMCentralManagerDelegateProxy* proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil)
	{
		proxy = [[FMCentralManagerDelegateProxy alloc] init];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return proxy;
}

-(NSString *) fm_stateName
{
	switch (self.state)
	{
		case CBCentralManagerStateUnknown:		return @"CBCentralManagerStateUnknown";
		case CBCentralManagerStateResetting:	return @"CBCentralManagerStateResetting";
		case CBCentralManagerStateUnsupported:	return @"CBCentralManagerStateUnsupported";
		case CBCentralManagerStateUnauthorized:	return @"CBCentralManagerStateUnauthorized";
		case CBCentralManagerStatePoweredOff:	return @"CBCentralManagerStatePoweredOff";
		case CBCentralManagerStatePoweredOn:	return @"CBCentralManagerStatePoweredOn";

		default:
			return [NSString stringWithFormat:@"unknown CBCentralManagerState(%zd)", self.state];
	}
}

-(RACSignal *) rac_didUpdateStateSignal
{
	RACSignal* signal = [RACSignal concat:@[[RACSignal return:@(self.state)],
											[[self.fm_delegateProxy
											  signalForSelector:@selector(centralManagerDidUpdateState:)]
											 reduceEach:^(CBCentralManager* central) {
												 return @(central.state);
											 }]]];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) rac_didDiscoverPeripheralSignal
{
	RACSignal* signal = [[self.fm_delegateProxy
						  signalForSelector:@selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:)]
						 reduceEach:^(CBCentralManager* central, CBPeripheral* peripheral, NSDictionary<NSString *,id>* advertisementData, NSNumber* RSSI) {
							 RSSI = RSSI && RSSI.intValue < 127 ? RSSI : nil;
							 return RACTuplePack(peripheral, advertisementData, RSSI);
						 }];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) rac_didConnectPeripheralSignal
{
	RACSignal* signal = [[[self.fm_delegateProxy
						   signalForSelector:@selector(centralManager:didConnectPeripheral:)]
						  reduceEach:^(CBCentralManager* central, CBPeripheral* peripheral) {
							  return peripheral;
						  }]
						 takeUntil:self.rac_willDeallocSignal];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) rac_didDisconnectPeripheralSignal
{
	RACSignal* signal = [[[self.fm_delegateProxy
						   signalForSelector:@selector(centralManager:didDisconnectPeripheral:error:)]
						  reduceEach:^(CBCentralManager* central, CBPeripheral* peripheral, NSError* error) {
							  return RACTuplePack(peripheral, error);
						  }]
						 takeUntil:self.rac_willDeallocSignal];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) rac_didFailToConnectPeripheralSignal
{
	RACSignal* signal = [[self.fm_delegateProxy
						  signalForSelector:@selector(centralManager:didFailToConnectPeripheral:error:)]
						 reduceEach:^(CBCentralManager* central, CBPeripheral* peripheral, NSError* error) {
							 return RACTuplePack(peripheral, error);
						 }];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) fm_discoverPeripheralWithServiceUUIDs:(NSArray *) targetServiceUUIDs
											 timeout:(NSTimeInterval) timeout
{
	return [[[self rac_didDiscoverPeripheralSignal]
			 filter:^BOOL(RACTuple* tuple) {
				 NSDictionary<NSString *, id>* advertisementData = tuple.second;

				 NSArray* serviceUUIDs = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
				 if (serviceUUIDs)
				 {
					 for (CBUUID* serviceUUID in serviceUUIDs)
					 {
						 if ([targetServiceUUIDs containsObject:serviceUUID])
						 {
							 return YES;
						 }
					 }
				 }
				 return NO;
			 }]
			timeout:timeout
			onScheduler:[RACScheduler schedulerWithPriority:RACSchedulerPriorityBackground]];
}

-(RACSignal *) fm_connectToPeripheral:(CBPeripheral *) peripheral
							  options:(nullable NSDictionary<NSString *,id> *) options
							  timeout:(NSTimeInterval) timeout
{
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		switch (peripheral.state)
		{
			case CBPeripheralStateConnected:
				[subscriber sendNext:peripheral];
				[subscriber sendCompleted];
				break;

			case CBPeripheralStateDisconnected:
			case CBPeripheralStateConnecting:
			{
				[[[[[RACSignal merge:@[self.rac_didConnectPeripheralSignal,
									   self.rac_didFailToConnectPeripheralSignal]]
					filter:^BOOL(id x) {
						if ([x isKindOfClass:[CBPeripheral class]])
						{
							// rac_didConnectPeripheralSignal
							return x == peripheral;
						}
						else
						{
							// rac_didFailToConnectPeripheralSignal
							RACTupleUnpack(CBPeripheral* failedToConnectPeripheral,
										   NSError* __unused error) = x;
							return failedToConnectPeripheral == peripheral;
						}
					}]
				   timeout:timeout
				   onScheduler:[RACScheduler schedulerWithPriority:RACSchedulerPriorityBackground]]
				  take:1]
				 subscribeNext:^(id x) {
						if ([x isKindOfClass:[CBPeripheral class]])
						{
							// rac_didConnectPeripheralSignal
							[subscriber sendNext:peripheral];
							[subscriber sendCompleted];
						}
						else
						{
							// rac_didFailToConnectPeripheralSignal
							RACTupleUnpack(CBPeripheral* __unused failedToConnectPeripheral,
										   NSError* error) = x;
							[subscriber sendError:error];
						}
				 }
				 error:^(NSError* error) {
					 [self cancelPeripheralConnection:peripheral];
					 [subscriber sendError:error];
				 }];

				if (peripheral.state == CBPeripheralStateDisconnected)
				{
					[self connectPeripheral:peripheral
									options:options];
				}
			}
				break;

			default:
				[subscriber sendError:
				 [NSError errorWithDomain:FMCoreBluetoothErrorDomain
									 code:FMCoreBluetoothPeripheralDisconnectingError
								 userInfo:@{NSLocalizedDescriptionKey: peripheral.fm_stateName}]];
				break;
		}

		// no disposal block needed
		return nil;
	}];
}

-(RACSignal *) fm_cancelPeripheralConnection:(CBPeripheral *) peripheral
{
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		if (peripheral.state == CBPeripheralStateDisconnected)
		{
			[subscriber sendNext:peripheral];
			[subscriber sendCompleted];

			return nil;
		}

		[[self.rac_didDisconnectPeripheralSignal
		  filter:^BOOL(RACTuple* tuple) {
			  RACTupleUnpack(CBPeripheral* p,
							 NSError* __unused err) = tuple;
			  return p == peripheral;
		  }]
		 subscribeNext:^(RACTuple* tuple) {
			 RACTupleUnpack(CBPeripheral* __unused p,
							NSError* err) = tuple;

			 if (!err)
			 {
				 [subscriber sendNext:peripheral];
				 [subscriber sendCompleted];
			 }
			 else
			 {
				 [subscriber sendError:err];
			 }
		 }
		 error:^(NSError *error) {
			 [subscriber sendError:error];
		 }];

		[self cancelPeripheralConnection:peripheral];

		// no disposal block
		return nil;
	}];
}

@end



@implementation FMCentralManagerDelegateProxy

-(RACSignal *) signalForSelector:(SEL) selector
{
	return [self rac_signalForSelector:selector
						  fromProtocol:@protocol(CBCentralManagerDelegate)];
}

-(void) centralManagerDidUpdateState:(CBCentralManager *) central
{
	if ([self.superDelegate respondsToSelector:@selector(centralManagerDidUpdateState:)])
	{
		[self.superDelegate centralManagerDidUpdateState:central];
	}
}

-(void) centralManager:(CBCentralManager *) central
 didDiscoverPeripheral:(CBPeripheral *) peripheral
	 advertisementData:(NSDictionary<NSString *,id> *) advertisementData
				  RSSI:(NSNumber *) RSSI
{
	if ([self.superDelegate respondsToSelector:@selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:)])
	{
		[self.superDelegate centralManager:central
					 didDiscoverPeripheral:peripheral
						 advertisementData:advertisementData
									  RSSI:RSSI];
	}
}

-(void) centralManager:(CBCentralManager *) central
  didConnectPeripheral:(CBPeripheral *) peripheral
{
	if ([self.superDelegate respondsToSelector:@selector(centralManager:didConnectPeripheral:)])
	{
		[self.superDelegate centralManager:central
					  didConnectPeripheral:peripheral];
	}
}

-(void) centralManager:(CBCentralManager *) central
didDisconnectPeripheral:(CBPeripheral *) peripheral
				 error:(NSError *) error
{
	if ([self.superDelegate respondsToSelector:@selector(centralManager:didDisconnectPeripheral:error:)])
	{
		[self.superDelegate centralManager:central
				   didDisconnectPeripheral:peripheral
									 error:error];
	}
}

-(void) centralManager:(CBCentralManager *) central
didFailToConnectPeripheral:(CBPeripheral *) peripheral
				 error:(NSError *) error
{
	if ([self.superDelegate respondsToSelector:@selector(centralManager:didFailToConnectPeripheral:error:)])
	{
		[self.superDelegate centralManager:central
				didFailToConnectPeripheral:peripheral
									 error:error];
	}
}

@end
