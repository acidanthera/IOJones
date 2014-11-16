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
    while (i < j) [temp addObject:[NSNumber numberWithUnsignedLong:i++]];
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

@implementation NSMutableDictionarySet {
    @private
    NSMapTable *_map;
    NSMutableSet *_set;
}

-(instancetype)initWithDictionary:(NSDictionary *)dictionary{
    self = [self init];
    if (self)
        for (NSString *key in dictionary)
            [self setObject:[dictionary objectForKey:key] forKey:key];
    return self;
}
-(instancetype)init {
    self = [super init];
    if (self) {
        _map = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory|NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsOpaqueMemory|NSPointerFunctionsObjectPointerPersonality];
        _set = [NSMutableSet set];
    }
    return self;
}

-(NSDictionary *)dictionaryRepresentation {
    return [_map dictionaryRepresentation];
}
-(NSDictionary *)invertedDictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *key in _map) {
        id obj;
        if ((obj = [dict objectForKey:[_map objectForKey:key]]))
            [obj addObject:key];
        else
            [dict setObject:[NSMutableArray arrayWithObject:key] forKey:[_map objectForKey:key]];
    }
    return [dict copy];
}

-(NSString *)description {
    return [_map description];
}

-(id)setObject:(id)anObject forKey:(id)aKey {
    id obj;
    if ((obj = [_set member:aKey]))
        aKey = obj;
    else
        [_set addObject:aKey];
    if ((obj = [_set member:anObject]))
        anObject = obj;
    else
        [_set addObject:anObject];
    [_map setObject:anObject forKey:aKey];
    return anObject;
}

-(id)objectForKey:(id)aKey {
    return [_map objectForKey:aKey];
}

-(id)objectForEquivalentKey:(id)aKey {
    return [_map objectForKey:[_set member:aKey]];
}

-(NSArray *)chainForKey:(id)aKey {
    if (!(aKey = [_set member:aKey]))
        return nil;
    NSMutableArray *chain = [NSMutableArray array];
    while (chain.lastObject != aKey) {
        [chain addObject:aKey];
        aKey = [_map objectForKey:aKey];
    }
    return [chain copy];
}

@end