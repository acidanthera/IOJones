//
//  IOReg.m
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "IOReg.h"
#import "Document.h"
#import "Base.h"
#import "IOKitLibPrivate.h"
#include <mach/mach.h>

@implementation IORegObj
static NSArray *systemPlanes;
static NSString *systemName;
static NSString *systemType;
static NSDictionary *red;
static NSDictionary *green;

@synthesize name;
@synthesize ioclass;
@synthesize entryID;
@synthesize properties;
@synthesize planes;
@synthesize document;
@synthesize added;
@synthesize removed;
@synthesize kernel;
@synthesize user;
@synthesize busy;
@synthesize state;
@synthesize status;

+(void)initialize {
    red = @{NSForegroundColorAttributeName:[NSColor redColor], NSStrikethroughStyleAttributeName:@1};
    green = @{NSForegroundColorAttributeName:[NSColor colorWithCalibratedRed:0 green:0.75 blue:0 alpha:1], NSUnderlineStyleAttributeName:@1};
    struct host_basic_info info;
    UInt32 size = sizeof(struct host_basic_info);
    char *type, *subtype;
    host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&info, &size);
    systemName = [NSHost.currentHost localizedName];
    slot_name(info.cpu_type, info.cpu_subtype, &type, &subtype);
    systemType = [NSString stringWithCString:type encoding:NSMacOSRomanStringEncoding];
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMasterPortDefault);
    NSMutableArray *planes = [NSMutableArray array];
    for (NSString *plane in [(__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(root, CFSTR("IORegistryPlanes"), kCFAllocatorDefault, 0) allValues]) {
        if ([plane isEqualToString:@"IOService"]) [planes insertObject:plane atIndex:0];
        else [planes addObject:plane];
    }
    systemPlanes = [planes copy];
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

+(IORegObj *)create:(io_registry_entry_t)entry for:(Document *)document{
    IORegObj *temp = [IORegObj new];
    temp.added = [NSDate date];
    temp->_nodes = [NSHashTable weakObjectsHashTable];
    temp.document = document;
    io_name_t globalname = {};
    IORegistryEntryGetName(entry, globalname);
    temp.name = [NSString stringWithCString:globalname encoding:NSMacOSRomanStringEncoding];
    IOObjectGetClass(entry, globalname);
    temp.ioclass = [NSString stringWithCString:globalname encoding:NSMacOSRomanStringEncoding];
    temp.kernel = IOObjectGetKernelRetainCount(entry);
    temp.user = IOObjectGetUserRetainCount(entry);
    uint64_t entryid = 0, state = 0;
    uint32_t busy = 0;
    IORegistryEntryGetRegistryEntryID(entry, &entryid);
    temp.entryID = entryid;
    CFMutableDictionaryRef properties;
    IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0);
    temp.properties = [IORegProperty createWithDictionary:(__bridge_transfer NSMutableDictionary *)properties];
    NSMutableDictionary *planes = [NSMutableDictionary dictionary];
    for (NSString *plane in systemPlanes) {
        if (!IORegistryEntryInPlane(entry, [plane cStringUsingEncoding:NSMacOSRomanStringEncoding])) continue;
        if ([plane isEqualToString:@"IOService"]) {
            IOServiceGetState(entry, &state);
            IOServiceGetBusyState(entry, &busy);
        }
        io_name_t location = {}, name = {};
        io_string_t path = {};
        IORegistryEntryGetLocationInPlane(entry, [plane cStringUsingEncoding:NSMacOSRomanStringEncoding], location);
        IORegistryEntryGetNameInPlane(entry, [plane cStringUsingEncoding:NSMacOSRomanStringEncoding], name);
        IORegistryEntryGetPath(entry, [plane cStringUsingEncoding:NSMacOSRomanStringEncoding], path);
        [planes setObject:@{@"name":[NSString stringWithCString:name encoding:NSMacOSRomanStringEncoding], @"location":[NSString stringWithCString:location encoding:NSMacOSRomanStringEncoding], @"path":[NSString stringWithCString:path encoding:NSMacOSRomanStringEncoding]} forKey:plane];
    }
    temp.busy = busy;
    temp.state = state;
    temp.planes = [planes copy];
    IOObjectRelease(entry);
    return temp;
}
+(IORegObj *)createWithDictionary:(NSDictionary *)dictionary for:(Document *)document {
    IORegObj *temp = [IORegObj new];
    temp.document = document;
    temp.ioclass = [dictionary objectForKey:@"class"];
    temp.added = [dictionary objectForKey:@"added"];
    temp.removed = [dictionary objectForKey:@"removed"];
    temp.name = [dictionary objectForKey:@"name"];
    temp.status = [[dictionary objectForKey:@"status"] longLongValue];
    temp.state = [[dictionary objectForKey:@"state"] longLongValue];
    temp.busy = [[dictionary objectForKey:@"busy"] longLongValue];
    temp.kernel = [[dictionary objectForKey:@"kernel"] longLongValue];
    temp.user = [[dictionary objectForKey:@"user"] longLongValue];
    temp.entryID = [[dictionary objectForKey:@"id"] longLongValue];
    temp.planes = [dictionary objectForKey:@"planes"];
    temp.properties = [IORegProperty createWithDictionary:[dictionary objectForKey:@"properties"]];
    return temp;
}
-(void)registerNode:(IORegNode *)node {
    [_nodes addObject:node];
}
-(NSSet *)registeredNodes {
    return _nodes.setRepresentation;
}

-(NSDictionary *)dictionaryRepresentation {
    if (removed)
        return @{@"class":ioclass, @"added":added, @"removed":removed, @"name":name, @"status":@(status), @"state":@(state), @"busy":@(busy), @"kernel":@(kernel), @"user":@(user), @"id":@(entryID), @"properties":[NSDictionary dictionaryWithObjects:[properties valueForKey:@"dictionaryRepresentation"] forKeys:[properties valueForKey:@"key"]], @"planes":planes};
    return @{@"class":ioclass, @"added":added, @"name":name, @"status":@(status), @"state":@(state), @"busy":@(busy), @"kernel":@(kernel), @"user":@(user), @"id":@(entryID), @"properties":[NSDictionary dictionaryWithObjects:[properties valueForKey:@"dictionaryRepresentation"] forKeys:[properties valueForKey:@"key"]], @"planes":planes};
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
    NSString *plane = document.selectedPlane.plane;
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
    NSDictionary *plane;
    NSString *planeName;
    if ((plane = [planes objectForKey:document.selectedPlane.plane]) && (planeName = [plane objectForKey:@"name"])) {
        NSString *location;
        if ((location = [plane objectForKey:@"location"]).length)
            return [NSString stringWithFormat:@"%@@%@", planeName, location];
        else return planeName;
    }
    else return name;
}
-(id)displayName {
    switch (status) {
        case initial: return self.currentName;
        case published: return [[NSAttributedString alloc] initWithString:self.currentName attributes:green];
        case terminated: return [[NSAttributedString alloc] initWithString:self.currentName attributes:red];
    }
}
-(bool)isActive {
    return (state & kIOServiceInactiveState) == 0;
}
-(bool)isRegistered {
    return (state & kIOServiceRegisteredState) != 0;
}
-(bool)isMatched {
    return (state & kIOServiceMatchedState) != 0;
}
-(bool)isService {
    return [self.classChain containsObject:@"IOService"];
}
-(NSString *)filteredProperty {
    NSString *property = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"find"] objectForKey:@"property"];
    for (IORegProperty *obj in properties)
        if ([obj.key isEqualToString:property])
            return obj.briefDescription;
    return nil;
}

@end

@implementation IORegNode
static NSDateFormatter *dateFormatter;
static NSPredicate *hideBlock;

@synthesize parent;
@synthesize node;
@synthesize plane;
@synthesize children;
+(void)initialize{
    dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    hideBlock = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings){
        return [[evaluatedObject node] status] != terminated;
    }];
}

+(IORegNode *)create:(IORegObj *)node on:(IORegNode *)parent{
    IORegNode *temp = [IORegNode new];
    temp.node = node;
    temp.plane = parent.plane;
    temp.parent = parent;
    if (parent.children) [parent.children addObject:temp];
    else parent.children = [NSMutableArray arrayWithObject:temp];
    return temp;
}
+(IORegNode *)createWithDictionary:(NSDictionary *)dictionary on:(IORegNode *)parent {
    IORegNode *temp = [IORegNode new];
    temp.parent = parent;
    temp.plane = parent.plane;
    temp.node = (__bridge IORegObj *)(NSMapGet(parent.node.document.allObjects, (void *)[[dictionary objectForKey:@"node"] longLongValue]));
    if ([[dictionary objectForKey:@"children"] count]) {
        temp.children = [NSMutableArray array];
        for (NSDictionary *ioreg in [dictionary objectForKey:@"children"])
            [temp.children addObject:[IORegNode createWithDictionary:ioreg on:temp]];
    }
    return temp;
}
-(void)setNode:(IORegObj *)aNode {
    [aNode registerNode:self];
    self->node = aNode;
}
-(IORegObj *)node {
    return self->node;
}
-(NSMutableArray *)children {
    return node.document.hiding?[[children filteredArrayUsingPredicate:hideBlock] mutableCopy]:children;
}
-(NSDictionary *)dictionaryRepresentation {
    return @{@"node":@(node.entryID), @"children": children.count?[children valueForKey:@"dictionaryRepresentation"]:@[]};
}
-(NSIndexPath *)indexPath {
    NSUInteger length = 1, index = 0;
    IORegNode *temp = self;
    while (![temp isKindOfClass:IORegRoot.class] && length++) temp = temp.parent;
    NSUInteger indexes[(index = length)];
    temp = self;
    while (index > 0) {
        indexes[--index]=[temp.parent.children indexOfObject:temp];
        temp = temp.parent;
    }
    return [NSIndexPath indexPathWithIndexes:indexes length:length];
}
-(NSMutableSet *)flat {
    NSMutableSet *flat = [NSMutableSet setWithObject:self];
    for (IORegNode *child in children) [flat unionSet:child.flat];
    return flat;
}
-(NSString *)metaData {
    if (node.status == terminated)
        return [NSString stringWithFormat:@"%@\nDiscovered: %@\nTerminated: %@", node.name, [dateFormatter stringFromDate:node.added], [dateFormatter stringFromDate:node.removed]];
    return [NSString stringWithFormat:@"%@\nDiscovered: %@", node.name, [dateFormatter stringFromDate:node.added]];
}
-(void)walk:(io_iterator_t)iterator {
    io_registry_entry_t object;
    while ((object = IOIteratorNext(iterator))) {
        bool stop = false;
        IORegObj *obj = [node.document addObject:object];
        for (IORegNode *child in children)
            if (child.node == obj) {
                stop = true;
                break;
            }
        if (stop) continue;
        IORegNode *child = [IORegNode create:obj on:self];
        if (IORegistryIteratorEnterEntry(iterator) == KERN_SUCCESS) [child walk:iterator];
    }
    IORegistryIteratorExitEntry(iterator);
}
-(void)mutate {
    io_iterator_t it;
    io_registry_entry_t entry = IOServiceGetMatchingService(kIOMasterPortDefault, IORegistryEntryIDMatching(node.entryID));
    IORegistryEntryCreateIterator(entry, [plane cStringUsingEncoding:NSMacOSRomanStringEncoding], 0, &it);
    [self walk:it];
    IOObjectRelease(it);
}

@end

@implementation IORegRoot
static NSPredicate *filterBlock;

+(void)initialize {
    filterBlock = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings){
        evaluatedObject = [evaluatedObject node];
        NSString *value = [bindings objectForKey:@"value"];
        for (NSString *key in [bindings objectForKey:@"keys"]) {
            if ([key isEqualToString:@"name"]) {
                if ([[evaluatedObject name] rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound)
                    return true;}
            else if ([key isEqualToString:@"bundle"]) {
                if ([[evaluatedObject bundle] rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound)
                    return true;}
                else if ([key isEqualToString:@"class"]) {
                    if ([[evaluatedObject ioclass] rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound)
                        return true;}
                else if ([key isEqualToString:@"inheritance"]) {
                    if ([[evaluatedObject classChain] containsRange:value])
                return true;}
                else if ([key isEqualToString:@"keys"]) {
                    if ([[[evaluatedObject properties] valueForKey:@"key"] containsRange:value])
                return true;}
                else if ([key isEqualToString:@"values"]) {
                    if ([[[evaluatedObject properties] valueForKey:@"value"] containsRange:value])
                   return true;}
            else if ([key isEqualToString:@"state"]) {
                if ([evaluatedObject isActive]) {
                    if ([@"Active" rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound) return true;}
                else if ([evaluatedObject isRegistered]) {
                    if ([@"Registered" rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound) return true;}
                else if ([evaluatedObject isMatched]) {
                    if ([@"Matched" rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound) return true;}
            }
        }
        return false;
    }];
}

+(IORegRoot *)root:(IORegObj *)root on:(NSString *)plane{
    IORegRoot *temp = [IORegRoot new];
    temp.node = root;
    temp.plane = plane;
    return temp;
}
+(IORegRoot *)createWithDictionary:(NSDictionary *)dictionary on:(NSMapTable *)table {
    IORegRoot *temp = [IORegRoot new];
    temp.node = (__bridge IORegObj *)(NSMapGet(table, (void *)[[dictionary objectForKey:@"root"] longLongValue]));
    temp.plane = [dictionary objectForKey:@"plane"];
    if ([[dictionary objectForKey:@"children"] count]) {
        temp.children = [NSMutableArray array];
        for (NSDictionary *ioreg in [dictionary objectForKey:@"children"])
            [temp.children addObject:[IORegNode createWithDictionary:ioreg on:temp]];
    }
    return temp;
}
-(void)filter:(NSString *)filter {
    if (filter.length) {
        NSDictionary *bindings = @{@"value":filter, @"keys":[[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"find"] keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop){
            return [obj boolValue] && ![key isEqualToString:@"property"] && ![key isEqualToString:@"showAll"];
        }] allObjects]};
        self.children = [[[self.flat objectsPassingTest:^BOOL(id obj, BOOL *stop){
            return [filterBlock evaluateWithObject:obj substitutionVariables:bindings];
        }] allObjects] mutableCopy];
    }
    else if (_pleated) self.children = _pleated;
}
-(NSDictionary *)dictionaryRepresentation {
    return @{@"root":@(self.node.entryID), @"plane":self.plane, @"children":[self.children valueForKey:@"dictionaryRepresentation"]};
}
-(NSMutableArray *)children{
    if (![super children]) {
        _pleated = super.children = [NSMutableArray array];
        [self mutate];
    }
    else if (!_pleated) _pleated = super.children;
    return [super children];
}
-(NSMutableSet *)flat {//TODO: cache for speed, invalidate on notification
    NSMutableSet *flat = [NSMutableSet setWithObject:self];
    for (IORegNode *child in _pleated) [flat unionSet:child.flat];
    return flat;
}
-(bool)isLoaded {
    return (_pleated);
}
-(void)mutate {
    io_iterator_t it;
    IORegistryCreateIterator(kIOMasterPortDefault, [self.plane cStringUsingEncoding:NSMacOSRomanStringEncoding], 0, &it);
    [self walk:it];
    IOObjectRelease(it);
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

+(NSArray *)createWithDictionary:(NSDictionary *)dictionary {
    NSMutableArray *properties = [NSMutableArray array];
    for (NSString *key in dictionary)
        [properties addObject:[IORegProperty create:[dictionary objectForKey:key] forKey:key]];
    return [properties copy];
}
+(IORegProperty *)create:(id)value forKey:(id)key {//TODO: unpack dicts dynamically?
    IORegProperty *temp = [IORegProperty new];
    temp.key = [key copy];
    temp->_type = CFGetTypeID((__bridge CFTypeRef)value);
    if (temp->_type == dictType && [value count]) {
        NSMutableArray *array = [NSMutableArray array];
        for (NSString *str in value)
            [array addObject:[IORegProperty create:[value objectForKey:str] forKey:str]];
        temp.children = [array copy];
    }
    else if (temp->_type == arrType && [value count]) {
        NSMutableArray *array = [NSMutableArray array];
        NSUInteger i = 0;
        for (id obj in value)
            [array addObject:[IORegProperty create:obj forKey:@(i++)]];
        temp.children = [array copy];
    }
    else temp->_value = value;
    if (temp->_type == dataType) temp->_subtype = [temp->_value isTextual] ? [[temp->_value macromanStrings] count] : -1;
    else if (temp->_type == numType) temp->_subtype = [temp->_value nSize];
    return temp;
}

-(NSDictionary *)dictionaryRepresentation {
    if (_type == dictType)
        return children.count?[NSDictionary dictionaryWithObjects:[children valueForKey:@"dictionaryRepresentation"] forKeys:[children valueForKey:@"key"]]:@{};
    else if (_type == arrType)
        return children.count?[children valueForKey:@"dictionaryRepresentation"]:@[];
    return _value;
}
-(NSString *)description {
    if (_type == boolType) return [_value boolValue]?@"True":@"False";
    else if (_type == dictType || _type == arrType)
        return [NSString stringWithFormat:@"%ld value%s", children.count, children.count==1?"":"s"];
    else if (_type == numType)
        return [NSString stringWithFormat:@"0x%llx", [_value longLongValue]];
    else if (_type == dataType) {
        if (_subtype > 0) return [NSString stringWithFormat:@"<\"%@\">", [[_value macromanStrings] componentsJoinedByString:@"\",\""]];
        else return [_value groupedDescription:2];
    }
    else return [_value description];
}
-(NSColor *)descriptionColor {
    return _type == dictType || _type == arrType?NSColor.grayColor:NSColor.blackColor;
}
-(NSFont *)descriptionFont {
    return _type == dataType && _subtype <= 0?[NSFont userFixedPitchFontOfSize:NSFont.smallSystemFontSize-1]:[NSFont systemFontOfSize:NSFont.smallSystemFontSize];
}
-(NSString *)briefDescription {
    if (_type == boolType) return [_value boolValue]?@"True":@"False";
    else if (_type == dictType || _type == arrType)
        return [NSString stringWithFormat:@"%@ of %ld value%s", self.typeString, children.count, children.count==1?"":"s"];
    else if (_type == numType)
        return [NSString stringWithFormat:@"0x%llx", [_value longLongValue]];
    else if (_type == dataType)
        return [NSString stringWithFormat:@"Data of %ld byte%s", [_value length], [_value length]==1?"":"s"];
    else return [_value description];
}
-(NSString *)metaData {
    if (_type == strType) return @"NUL-terminated ASCII string";
    else if (_type == dataType) {
        if (_subtype == 1) return [NSString stringWithFormat:@"%ld bytes interpreted as a string in MacRoman encoding", [_value length]];
        else if (_subtype > 1) return [NSString stringWithFormat:@"%ld bytes interpreted as %ld strings in MacRoman encoding", [_value length], _subtype];
        else return [NSString stringWithFormat:@"%ld byte%s autoformatted as hexadecimal bytes in host byte order", [_value length], [_value length]==1?"":"s"];
    }
    else if (_type == numType) return [NSString stringWithFormat:@"%ld-byte number interpreted in native byte order", _subtype];
    else return nil;
}
-(NSInteger)type {
    return _type;
}
-(NSInteger)subtype {
    return _subtype;
}
-(NSString *)typeString{
    if (_type == boolType) return @"Boolean";
    else if (_type == dictType) return @"Dictionary";
    else if (_type == strType) return @"String";
    else if (_type == arrType) return @"Array";
    else if (_type == numType) return @"Number";
    else if (_type == dataType) return @"Data";
    else if (_type == dateType) return @"Date";
    else return @"Unknown";
}

@end
