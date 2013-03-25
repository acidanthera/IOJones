//
//  IOReg.m
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "IOReg.h"
#import "Document.h"
#include <mach/mach.h>
static NSArray *systemPlanes;
static NSString *systemName;
static NSString *systemType;

@implementation IOReg
@synthesize name;
@synthesize ioclass;
@synthesize entryID;
@synthesize properties;
@synthesize planes;
@synthesize document;
@synthesize found;

+(void)initialize {
    struct host_basic_info info;
    UInt32 size = sizeof(struct host_basic_info);
    char *type, *subtype;
    host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&info, &size);
    systemName = [NSHost.currentHost localizedName];
    slot_name(info.cpu_type, info.cpu_subtype, &type, &subtype);
    systemType = [NSString stringWithUTF8String:type];
    io_service_t root = IORegistryGetRootEntry(kIOMasterPortDefault);
    systemPlanes = [(__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(root, CFSTR("IORegistryPlanes"), kCFAllocatorDefault, 0) allValues];
    IOObjectRelease(root);
}
+(NSArray *)systemPlanes {
    return systemPlanes;
}
+(NSString *)systemName {
    return systemName;
}
+(NSString *)systemType {
    return systemType;
}

+(IOReg *)create:(io_registry_entry_t)entry for:(Document *)document{
    IOReg *temp = [IOReg new];
    temp.found = [NSDate date];
    temp.document = document;
    temp.ioclass = (__bridge_transfer NSString *)IOObjectCopyClass(entry);
    io_name_t globalname = {};
    IORegistryEntryGetName(entry, globalname);
    temp.name = [NSString stringWithUTF8String:globalname];
    uint64_t entryid;
    IORegistryEntryGetRegistryEntryID(entry, &entryid);
    temp.entryID = entryid;
    CFMutableDictionaryRef properties;
    IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0);
    temp.properties = [IORegProperty createWithDictionary:(__bridge_transfer NSMutableDictionary *)properties];
    NSMutableDictionary *planes = [NSMutableDictionary dictionary];
    for (NSString *plane in systemPlanes) {
        if (!IORegistryEntryInPlane(entry, plane.UTF8String)) continue;
        io_name_t location = {}, name = {};
        io_string_t path = {};
        IORegistryEntryGetLocationInPlane(entry, plane.UTF8String, location);
        IORegistryEntryGetNameInPlane(entry, plane.UTF8String, name);
        IORegistryEntryGetPath(entry, plane.UTF8String, path);
        [planes setObject:@{@"name":[NSString stringWithUTF8String:name], @"location":[NSString stringWithUTF8String:location], @"path":[NSString stringWithUTF8String:path]} forKey:plane];
    }
    temp.planes = [planes copy];
    IOObjectRelease(entry);
    return temp;
}

-(IOReg *)copyWithZone:(NSZone *)zone{
    return [self copy];
}
-(IOReg *)copy {
    return self;
}
-(NSArray *)classChain {
    NSString *superclass, *class = ioclass;
    NSMutableArray *chain = [NSMutableArray arrayWithObject:class];
    while (![document.allClasses objectForKey:class] && (superclass = (__bridge_transfer NSString *)IOObjectCopySuperclassForClass((__bridge CFStringRef)class))) {
        [document.allClasses setObject:superclass forKey:class];
        class = superclass;
        [chain addObject:class];
    }
    while (![[document.allClasses objectForKey:class] isEqualToString:class] && (class = [document.allClasses objectForKey:class]))
        [chain addObject:class];
    return [chain copy];
}
-(NSString *)bundle {
    NSString *bundle;
    if ((bundle = [document.allBundles objectForKey:ioclass])) return bundle;
    bundle = (__bridge_transfer NSString *)IOObjectCopyBundleIdentifierForClass((__bridge CFStringRef)ioclass);
    if ([bundle isEqualToString:@"__kernel__"]) bundle = [document.allBundles objectForKey:@"OSObject"];
    [document.allBundles setObject:bundle forKey:ioclass];
    return bundle;
}
-(NSArray *)paths {
    return [planes.allValues valueForKeyPath:@"path"];
}
-(NSArray *)sortedPaths {
    NSString *plane = document.currentPlane.plane;
    NSMutableArray *paths = [self.paths mutableCopy];
    if (paths.count > 1) {
        for (NSString *path in paths)
            if ([path hasPrefix:plane]) {
                [paths removeObject:path];
                [paths insertObject:path atIndex:0];
                break;
            }
    }
    return [paths copy];
}
-(NSString *)currentName {
    NSDictionary *plane = [planes objectForKey:document.currentPlane.plane];
    NSString *planeName = [plane objectForKey:@"name"];
    NSString *location;
    if (plane && planeName) {
        if ((location = [plane objectForKey:@"location"]).length)
            return [NSString stringWithFormat:@"%@@%@", planeName, location];
        else return planeName;
    }
    return name;
}

@end

@implementation IORegNode

@synthesize parent;
@synthesize node;
@synthesize children;

+(IORegNode *)create:(IOReg *)node on:(IORegNode *)parent{
    IORegNode *temp = [IORegNode new];
    temp.node = node;
    temp.parent = parent;
    if (parent.children) [parent.children addObject:temp];
    else parent.children = [NSMutableArray arrayWithObject:temp];
    return temp;
}

-(IORegNode *)copyWithZone:(NSZone *)zone {
    return [self copy];
}
-(IORegNode *)copy {
    return self;
}
-(NSSet *)flatten {
    NSMutableSet *flat = [NSMutableSet setWithObject:self];
    for (IORegNode *child in children) [flat unionSet:child.flatten];
    return [flat copy];
}

@end

@implementation IORegRoot
@synthesize plane;
@synthesize flat;
@synthesize pleated;

+(IORegRoot *)root:(IOReg *)root on:(NSString *)plane{
    IORegRoot *temp = [IORegRoot new];
    temp.node = root;
    temp.plane = plane;
    temp.children = [NSMutableArray array];
    temp.pleated = temp.children;
    return temp;
}
-(NSSet *)flatten {
    if (!flat) {
        NSMutableSet *temp = [NSMutableSet setWithObject:self];
        for (IORegNode *child in pleated) [temp unionSet:child.flatten];
        flat = [temp copy];
    }
    return flat;
}

@end

@implementation IORegProperty
static NSUInteger boolType;
static NSUInteger dictType;
static NSUInteger arrType;
static NSUInteger dataType;
static NSUInteger strType;
static NSUInteger numType;
static NSUInteger dateType;
@synthesize type;
@synthesize key;
@synthesize children;

+(void)initialize {
    boolType = CFBooleanGetTypeID();
    dictType = CFDictionaryGetTypeID();
    arrType = CFArrayGetTypeID();
    dataType = CFDataGetTypeID();
    strType = CFStringGetTypeID();
    numType = CFNumberGetTypeID();
    dateType = CFDateGetTypeID();
}

+(NSArray *)numberRange:(NSRange)range {
    NSUInteger i = range.location, j = NSMaxRange(range);
    NSMutableArray *temp = [NSMutableArray array];
    while (i < j) [temp addObject:[NSNumber numberWithLong:i++]];
    return [temp copy];
}

+(NSArray *)createWithDictionary:(NSDictionary *)dictionary {//FIXME: unpack dicts dynamically?
    NSMutableArray *temp = [NSMutableArray array];
    for (NSString *key in dictionary) {
        id value = [dictionary objectForKey:key];
        NSUInteger type = CFGetTypeID((__bridge CFTypeRef)value);
        if (type == dictType)
            [temp addObject:[self create:key value:nil type:type children:[self createWithDictionary:value]]];
        else if (type == arrType)
            [temp addObject:[self create:key value:nil type:type children:[self createWithDictionary:[NSDictionary dictionaryWithObjects:value forKeys:[self numberRange:NSMakeRange(0, [value count])]]]]];
        else [temp addObject:[self create:key value:value type:type children:nil]];
    }
    return [temp copy];
}

+(IORegProperty *)create:(NSString *)key value:(id)value type:(NSUInteger)type children:(NSArray *)children{
    IORegProperty *temp = [IORegProperty new];
    temp.key = key;
    temp.type = type;
    temp.value = value;
    temp.children = children;
    return temp;
}
-(void)setValue:(id)value {
    _value = value;
}
-(id)value {
    if (type == boolType) return [_value boolValue]?@"True":@"False";
    else if (type == dictType || type == arrType)
        return [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld value%s", children.count, children.count==1?"":"s"] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}];
    else if (type == numType)
        return [NSString stringWithFormat:@"0x%lx", [_value longValue]];
    else if (type == dataType) return [_value attributedDescription];
    else return [_value description];
}
-(NSString *)typeString{
    if (type == boolType) return @"Boolean";
    else if (type == dictType) return @"Dictionary";
    else if (type == strType) return @"String";
    else if (type == arrType) return @"Array";
    else if (type == numType) return @"Number";
    else if (type == dataType) return @"Data";
    else if (type == dateType) return @"Date";
    else return @"Unknown";
}

@end

@implementation NSData (DescriptionAdditions)
static NSDictionary *fixedPitch;
+(void)initialize {
    fixedPitch = @{NSFontAttributeName:[NSFont userFixedPitchFontOfSize:NSFont.smallSystemFontSize-1]};
}

-(bool)isTextual{
    NSUInteger i = 0, j = self.length;
    if (j < 3) return false;
    const char *bytes = self.bytes;
    while (i < j)
        if (bytes[i] >= 0x80 || (bytes[i] < 0x20 && bytes[i] != 0)) return false;
        else i++;
    return true;
}
-(NSString *)groupedDescription:(NSUInteger)group{
    NSUInteger i = 0, j = self.length, k = j*(group+1)+1;
    char description[k];
    description[0] = '<';
    while (i < j) sprintf(description+(i*(group+1))+1, "%02x ", ((UInt8 *)self.bytes)[i++]);
    description[k-1] = '>';
    return [[NSString alloc] initWithBytes:description length:k encoding:NSASCIIStringEncoding];
}

-(NSAttributedString *)attributedDescription {
    if (self.isTextual)
        return [NSString stringWithFormat:@"<\"%@\">", [[[[[NSString alloc] initWithData:self encoding:NSASCIIStringEncoding] stringByTrimmingCharactersInSet:NSCharacterSet.controlCharacterSet] componentsSeparatedByString:@"\0"] componentsJoinedByString:@"\",\""]];
    else
        return [[NSAttributedString alloc] initWithString:[self groupedDescription:2] attributes:fixedPitch];
}

@end