//
// Copyright © 2016 Factory Method. All rights reserved.
//

#import "CBPeripheral+FM.h"
#import "CBCentralManager+FM.h"
#import <objc/runtime.h>



@implementation CBPeripheral (FM)

-(NSString *) fm_stateName
{
	switch (self.state)
	{
		case CBPeripheralStateConnecting:		return @"CBPeripheralStateConnecting";
		case CBPeripheralStateConnected:		return @"CBPeripheralStateConnected";
		case CBPeripheralStateDisconnecting:	return @"CBPeripheralStateDisconnecting";
		case CBPeripheralStateDisconnected:		return @"CBPeripheralStateDisconnected";

		default:
			return [NSString stringWithFormat:@"unknown CBPeripheralState(%zd)", self.state];
	}
}

-(void) fm_useDelegateProxy
{
	if (self.delegate == self.fm_delegateProxy)
		return;

	self.fm_delegateProxy.superDelegate = self.delegate;
	self.delegate = self.fm_delegateProxy;
}

-(FMPeripheralDelegateProxy *) fm_delegateProxy
{
	FMPeripheralDelegateProxy* proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil)
	{
		proxy = [[FMPeripheralDelegateProxy alloc] init];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return proxy;
}

-(RACSignal *) rac_didDiscoverServicesSignal
{
	RACSignal* signal = [[self.fm_delegateProxy
						  rac_signalForSelector:@selector(peripheral:didDiscoverServices:)]
						 reduceEach:^(CBPeripheral* peripheral, NSError* error) {
							 return error;
						 }];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) rac_didDiscoverCharacteristicsForServiceSignal
{
	RACSignal* signal = [[self.fm_delegateProxy
						  signalForSelector:@selector(peripheral:didDiscoverCharacteristicsForService:error:)]
						 reduceEach:^(CBPeripheral* peripheral, CBService* service, NSError* error) {
							 return RACTuplePack(service, error);
						 }];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) rac_didUpdateValueForCharacteristicSignal
{
	RACSignal* signal = [[self.fm_delegateProxy
						  signalForSelector:@selector(peripheral:didUpdateValueForCharacteristic:error:)]
						 reduceEach:^(CBPeripheral* peripheral, CBCharacteristic* characteristic, NSError* error) {
							 return RACTuplePack(characteristic, error);
						 }];

	[self fm_useDelegateProxy];
	return signal;
}

-(RACSignal *) rac_didWriteValueForCharacteristicSignal
{
	RACSignal* signal = [[self.fm_delegateProxy
						  signalForSelector:@selector(peripheral:didWriteValueForCharacteristic:error:)]
						 reduceEach:^(CBPeripheral* peripheral, CBCharacteristic* characteristic, NSError* error) {
							 return RACTuplePack(characteristic, error);
						 }];

	[self fm_useDelegateProxy];
	return signal;
}

-(CBCharacteristic *) fm_characteristicByUUID:(CBUUID *) targetUUID
{
	for (CBService* s in self.services)
	{
		for (CBCharacteristic* c in s.characteristics)
		{
			if ([c.UUID isEqual:targetUUID])
				return c;
		}
	}
	return nil;
}

-(RACSignal *) fm_discoverServices:(NSArray<CBUUID *> *) serviceUUIDs
					  forceRefresh:(BOOL) forceRefresh;
{
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		if (self.state != CBPeripheralStateConnected)
		{
			[subscriber sendError:
			 [NSError errorWithDomain:FMCoreBluetoothErrorDomain
								 code:FMCoreBluetoothPeripheralNotConnectedError
							 userInfo:@{NSLocalizedDescriptionKey: self.fm_stateName}]];

			// no need for disposal block
			return nil;
		}

		if (!forceRefresh && self.services)
		{
			[subscriber sendNext:self];
			[subscriber sendCompleted];

			// no need for disposal block
			return nil;
		}

		[[[self rac_didDiscoverServicesSignal]
		  take:1]
		 subscribeNext:^(NSError* error) {
			 if (error)
			 {
				 [subscriber sendError:error];
			 }
			 else
			 {
				 [subscriber sendNext:self];
				 [subscriber sendCompleted];
			 }
		 }];

		// start discovery
		[self discoverServices:serviceUUIDs];

		// no need for disposal block
		return nil;
	}];
}

-(RACSignal *) fm_discoverCharacteristics:(NSArray<CBUUID *> *) characteristicUUIDs
							   forService:(CBService *) service
							 forceRefresh:(BOOL) forceRefresh;
{
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		if (self.state != CBPeripheralStateConnected)
		{
			[subscriber sendError:
			 [NSError errorWithDomain:FMCoreBluetoothErrorDomain
								 code:FMCoreBluetoothPeripheralNotConnectedError
							 userInfo:@{NSLocalizedDescriptionKey: self.fm_stateName}]];

			// no need for disposal block
			return nil;
		}

		if (!forceRefresh && service.characteristics)
		{
			[subscriber sendNext:service];
			[subscriber sendCompleted];

			// no need for disposal block
			return nil;
		}

		[[[[self rac_didDiscoverCharacteristicsForServiceSignal]
		   filter:^BOOL(RACTuple* tuple) {
			   RACTupleUnpack(CBService* s,
							  NSError* __unused err) = tuple;
			   return s == service;
		   }]
		  take:1]
		 subscribeNext:^(RACTuple* tuple) {
			 RACTupleUnpack(CBService* __unused s,
							NSError* err) = tuple;
			 if (err)
			 {
				 [subscriber sendError:err];
			 }
			 else
			 {
				 [subscriber sendNext:service];
				 [subscriber sendCompleted];
			 }
		 }];

		[self discoverCharacteristics:characteristicUUIDs
						   forService:service];

		// no need for disposal block
		return nil;
	}];
}

-(nonnull RACSignal *) fm_discoverCharacteristics:(nullable NSArray<CBUUID *> *) characteristicUUIDs
{
	return [[self fm_discoverServices:nil
						 forceRefresh:YES]
			flattenMap:^RACStream *(CBPeripheral* peripheral) {
				NSMutableArray* signals = [NSMutableArray array];
				for (CBService* s in peripheral.services)
				{
					[signals addObject:[peripheral fm_discoverCharacteristics:characteristicUUIDs
																   forService:s
																 forceRefresh:YES]];
				}

				return [[[RACSignal combineLatest:signals]
						 take:1]
						map:^id(RACTuple* servicesTuple) {
							return peripheral;
						}];
			}];
}

-(RACSignal *) fm_readValueForCharacteristic:(CBCharacteristic *) characteristic
								forceRefresh:(BOOL) forceRefresh
{
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		if (self.state != CBPeripheralStateConnected)
		{
			[subscriber sendError:
			 [NSError errorWithDomain:FMCoreBluetoothErrorDomain
								 code:FMCoreBluetoothPeripheralNotConnectedError
							 userInfo:@{NSLocalizedDescriptionKey: self.fm_stateName}]];

			// no need for disposal block
			return nil;
		}

		if (!forceRefresh && characteristic.value)
		{
			[subscriber sendNext:characteristic];
			[subscriber sendCompleted];

			// no need for disposal block
			return nil;
		}

		[[[[self rac_didUpdateValueForCharacteristicSignal]
		   filter:^BOOL(RACTuple* tuple) {
			   RACTupleUnpack(CBCharacteristic* c,
							  NSError* __unused err) = tuple;
			   return c == characteristic;
		   }]
		  take:1]
		 subscribeNext:^(RACTuple* tuple) {
			 RACTupleUnpack(CBCharacteristic* __unused c,
							NSError* error) = tuple;
			 if (error)
			 {
				 [subscriber sendError:error];
			 }
			 else
			 {
				 [subscriber sendNext:characteristic];
				 [subscriber sendCompleted];
			 }
		 }];

		[self readValueForCharacteristic:characteristic];

		// no need for disposal block
		return nil;
	}];
}

-(RACSignal *) fm_writeValue:(NSData *) value
		   forCharacteristic:(CBCharacteristic *) characteristic
{
	return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		if (self.state != CBPeripheralStateConnected)
		{
			[subscriber sendError:
			 [NSError errorWithDomain:FMCoreBluetoothErrorDomain
								 code:FMCoreBluetoothPeripheralNotConnectedError
							 userInfo:@{NSLocalizedDescriptionKey: self.fm_stateName}]];

			// no need for disposal block
			return nil;
		}

		[[[[self rac_didWriteValueForCharacteristicSignal]
		   filter:^BOOL(RACTuple* tuple) {
			   RACTupleUnpack(CBCharacteristic* c,
							  NSError* __unused err) = tuple;
			   return c == characteristic;
		   }]
		  take:1]
		 subscribeNext:^(RACTuple* tuple) {
			 RACTupleUnpack(CBCharacteristic* __unused c,
							NSError* error) = tuple;
			 if (error)
			 {
				 [subscriber sendError:error];
			 }
			 else
			 {
				 [subscriber sendNext:characteristic];
				 [subscriber sendCompleted];
			 }
		 }];

		[self writeValue:value
	   forCharacteristic:characteristic
					type:CBCharacteristicWriteWithResponse];

		// no need for disposal block
		return nil;
	}];
}

@end



@implementation FMPeripheralDelegateProxy

-(RACSignal *) signalForSelector:(SEL) selector
{
	return [self rac_signalForSelector:selector
						  fromProtocol:@protocol(CBPeripheralDelegate)];
}

-(void) peripheral:(CBPeripheral *) peripheral
didDiscoverServices:(NSError *) error
{
	if ([self.superDelegate respondsToSelector:@selector(peripheral:didDiscoverServices:)])
	{
		[self.superDelegate peripheral:peripheral
				   didDiscoverServices:error];
	}
}

-(void) peripheral:(CBPeripheral *) peripheral
didDiscoverCharacteristicsForService:(CBService *) service
			 error:(NSError *) error
{
	if ([self.superDelegate respondsToSelector:@selector(peripheral:didDiscoverCharacteristicsForService:error:)])
	{
		[self.superDelegate peripheral:peripheral
  didDiscoverCharacteristicsForService:service
								 error:error];
	}
}

-(void) peripheral:(CBPeripheral *) peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *) characteristic
			 error:(NSError *) error
{
	if ([self.superDelegate respondsToSelector:@selector(peripheral:didUpdateValueForCharacteristic:error:)])
	{
		[self.superDelegate peripheral:peripheral
	   didUpdateValueForCharacteristic:characteristic
								 error:error];
	}
}

-(void) peripheral:(CBPeripheral *) peripheral
didWriteValueForCharacteristic:(CBCharacteristic *) characteristic
			 error:(NSError *) error
{
	if ([self.superDelegate respondsToSelector:@selector(peripheral:didWriteValueForCharacteristic:error:)])
	{
		[self.superDelegate peripheral:peripheral
		didWriteValueForCharacteristic:characteristic
								 error:error];
	}
}

@end
