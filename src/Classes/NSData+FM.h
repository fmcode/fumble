#import <Foundation/Foundation.h>



typedef NS_ENUM(NSInteger, FMDataEndian) {
	FMDataEndianNormal,
	FMDataEndianCSR
};



@interface NSData (FM)

+(nullable instancetype) fm_dataWithHexString:(nonnull NSString *) hexString
									   endian:(FMDataEndian) endian;

-(nullable instancetype) initWithHexString:(nonnull NSString *) hexString
									endian:(FMDataEndian) endian;

@end
