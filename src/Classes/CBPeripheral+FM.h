#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <ReactiveCocoa/ReactiveCocoa.h>



@class FMPeripheralDelegateProxy;



@interface CBPeripheral (FM)

@property (nonatomic, readonly, nonnull) FMPeripheralDelegateProxy* fm_delegateProxy;

@property (nonatomic, readonly, nonnull) NSString* fm_stateName;

@property (atomic, readonly, nonnull) RACSignal* rac_didDiscoverServicesSignal;
@property (atomic, readonly, nonnull) RACSignal* rac_didDiscoverCharacteristicsForServiceSignal;
@property (atomic, readonly, nonnull) RACSignal* rac_didUpdateValueForCharacteristicSignal;
@property (atomic, readonly, nonnull) RACSignal* rac_didWriteValueForCharacteristicSignal;

-(nullable CBCharacteristic *) fm_characteristicByUUID:(nonnull CBUUID *) targetUUID;

-(nonnull RACSignal *) fm_discoverServices:(nullable NSArray<CBUUID *> *) serviceUUIDs
							  forceRefresh:(BOOL) forceRefresh;

-(nonnull RACSignal *) fm_discoverCharacteristics:(nullable NSArray<CBUUID *> *) characteristicUUIDs
									   forService:(nonnull CBService *) service
									 forceRefresh:(BOOL) forceRefresh;

-(nonnull RACSignal *) fm_discoverCharacteristics:(nullable NSArray<CBUUID *> *) characteristicUUIDs;

-(nonnull RACSignal *) fm_readValueForCharacteristic:(nonnull CBCharacteristic *) characteristic
										forceRefresh:(BOOL) forceRefresh;

-(nonnull RACSignal *) fm_writeValue:(nonnull NSData *) value
				   forCharacteristic:(nonnull CBCharacteristic *) characteristic;

@end



@interface FMPeripheralDelegateProxy : NSObject <CBPeripheralDelegate>

@property (nonatomic, weak, nullable) id<CBPeripheralDelegate> superDelegate;

-(nonnull RACSignal *) signalForSelector:(nonnull SEL) selector;

@end
