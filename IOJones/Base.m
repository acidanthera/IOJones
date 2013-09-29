//
//  Base.m
//  IOJones
//
//  Created by PHPdev32 on 3/24/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Base.h"

@implementation NSSplitView (RestorationAdditions)

-(void)restore {
    NSUInteger i = 0;
    for (NSString *frame in [NSUserDefaults.standardUserDefaults stringArrayForKey:[@"NSSplitView Subview Frames " stringByAppendingString:self.autosaveName]])
        [[self.subviews objectAtIndex:i++] setFrame:NSRectFromString(frame)];
    [self adjustSubviews];
}

@end

@implementation NSArray (DescriptionAdditions)

+(NSArray *)range:(NSRange)range{
    NSUInteger i = range.location, j = NSMaxRange(range);
    NSMutableArray *temp = [NSMutableArray array];
    while (i < j) [temp addObject:[NSNumber numberWithLong:i++]];
    return [temp copy];
}
-(bool)containsRange:(NSString *)string {
    for (NSString *item in self)
        if ([item isKindOfClass:NSString.class] && [item rangeOfString:string options:NSCaseInsensitiveSearch].location != NSNotFound)
        return true;
    return false;
}

@end

@implementation NSData (DescriptionAdditions)

-(bool)isTextual{
    NSUInteger i = 0, j = self.length, k = 0;
    if (j < 5) return false;
    const UInt8 *bytes = self.bytes;
    while (i < j)
        if (bytes[i] >= 0x80 || bytes[i] < 0x20) {
            if (bytes[i++] == 0) k++;
            else return false;
        }
        else i++;
    return k != j;
}
-(NSString *)groupedDescription:(NSUInteger)group{
    NSUInteger i = 0, j = self.length, k = j*(group+1)+1+!j;
    char description[k];
    description[0] = '<';
    while (i < j) {
        sprintf(description+(i*(group+1))+1, "%02x ", ((UInt8 *)self.bytes)[i]);
        i++;
    }
    description[k-1] = '>';
    return [[NSString alloc] initWithBytes:description length:k encoding:NSMacOSRomanStringEncoding];
}
-(NSArray *)macromanStrings {
    NSUInteger i;
    if (!(i = self.length)) return @[];
    while (i && ((UInt8 *)self.bytes)[--i] == 0) ;
    return [[[NSString alloc] initWithBytes:self.bytes length:i+1 encoding:NSMacOSRomanStringEncoding] componentsSeparatedByString:@"\0"];
}

@end

@implementation NSNumber (DescriptionAdditions)

-(NSUInteger)nSize {
    switch (self.objCType[0]) {
        case 'c':
            return sizeof(char);
        case 'i':
            return sizeof(int);
        case 's':
            return sizeof(short);
        case 'l':
            return sizeof(long);
        case 'q':
            return sizeof(long long);
        case 'f':
            return sizeof(float);
        case 'd':
            return sizeof(double);
        case 'C':
            return sizeof(unsigned char);
        case 'I':
            return sizeof(unsigned int);
        case 'S':
            return sizeof(unsigned short);
        case 'L':
            return sizeof(unsigned long);
        case 'Q':
            return sizeof(unsigned long long);
        default:
            return 0;
    }
}

@end

@implementation NSAttributedString (ComparisonAdditions)

-(NSComparisonResult)compare:(NSString *)comparison {
    return [self.string compare:comparison];
}

@end

@implementation NSString (ComparisonAdditions)

-(NSComparisonResult)compare:(id)string {
    return [self compare:([string isKindOfClass:[NSString class]])?string:[string string] options:0 range:NSMakeRange(0, [string length])];
}

@end

@implementation NSNumber (ComparisonAdditions)

-(NSComparisonResult)localizedStandardCompare:(id)obj {
    return [self compare:obj];
}

@end

@implementation NSMutableDictionarySet

+(NSMutableDictionarySet *)createWithDictionary:(NSDictionary *)dictionary{
    NSMutableDictionarySet *temp = [NSMutableDictionarySet new];
    for (NSString *key in dictionary) [temp setObject:[dictionary objectForKey:key] forKey:key];
    return temp;
}
-(id)init {
    self = [super init];
    if (self) {
        _dict = [NSMutableDictionary dictionary];
        _set = [NSMutableSet set];
    }
    return self;
}

-(NSDictionary *)dictionaryRepresentation {
    return [_dict copy];
}
-(NSDictionary *)invertedDictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *key in _dict) {
        id obj;
        if ((obj = [dict objectForKey:[_dict objectForKey:key]]))
            [obj addObject:key];
        else
            [dict setObject:[NSMutableArray arrayWithObject:key] forKey:[_dict objectForKey:key]];
    }
    return [dict copy];
}

-(NSString *)description {
    return [_dict description];
}

-(id)setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    id obj;
    if ((obj = [_set member:anObject])) [_dict setObject:obj forKey:aKey];
    else [_dict setObject:anObject forKey:aKey];
    return obj?:anObject;
}

-(id)objectForKey:(id)aKey {
    return [_dict objectForKey:aKey];
}

@end