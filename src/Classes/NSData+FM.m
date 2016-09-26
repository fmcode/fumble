#import "NSData+FM.h"



static uint8_t const INVALID_NIBBLE = 128;

#define NIBBLE_FROM_CHAR(c)	( \
								((c)>='0' && (c)<='9') \
								? ((c)-'0') \
								: ( \
									((c) >= 'A' && (c) <= 'F') \
									? ((c)-'A'+10) \
									: ( \
										((c)>='a' && (c)<='f') \
										? ((c)-'a'+10) \
										: INVALID_NIBBLE \
									) \
								) \
							)



@implementation NSData (FM_CSR)

+(instancetype) fm_dataWithHexString:(NSString *) hexString
							  endian:(FMDataEndian) endian
{
	return [[self alloc] initWithHexString:hexString
									endian:endian];
}

-(instancetype) initWithHexString:(NSString *) hexString
						   endian:(FMDataEndian) endian
{
	if (!hexString)
		return nil;
	
	const NSUInteger charLength = hexString.length;
	NSUInteger buflen = charLength / 2;
	if (endian == FMDataEndianCSR)
	{
		buflen = ((buflen % 2) + (buflen / 2)) * 2;
	}

	Byte* const bytes = malloc(buflen);
	memset(bytes, 0, buflen);
	Byte* p_byte = bytes;
	
	CFStringInlineBuffer inlineBuffer;
	CFStringInitInlineBuffer((CFStringRef)hexString, &inlineBuffer, CFRangeMake(0, charLength));
	
	// Each byte is made up of two hex characters; store the outstanding half-byte until we read the second
	uint8_t hiNibble = INVALID_NIBBLE;
	for (CFIndex i = 0; i < charLength; ++i) {
		unichar c = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, i);
		uint8_t nextNibble = NIBBLE_FROM_CHAR(c);
		
		if (nextNibble == INVALID_NIBBLE)
		{
			free(bytes);
			return nil;
		}
		
		if (hiNibble == INVALID_NIBBLE)
		{
			hiNibble = nextNibble;
		}
		else
		{
			// Have next full byte
			*p_byte++ = (hiNibble << 4) | nextNibble;
			hiNibble = INVALID_NIBBLE;
		}
	}
	
	if (hiNibble != INVALID_NIBBLE)
	{
		// trailing hex character
		free(bytes);
		return nil;
	}
	
	if (endian == FMDataEndianCSR)
	{
		for (CFIndex i=0; i<buflen; i+=2)
		{
			Byte b = bytes[i];
			bytes[i] = bytes[i+1];
			bytes[i+1] = b;
		}
	}
	
	return [self initWithBytesNoCopy:bytes
							  length:buflen
						freeWhenDone:YES];
}

@end
