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

@implementation IORegObj {
    @private
    NSHashTable *_nodes;
}
static NSArray *systemPlanes;
static NSString *systemName, *systemType;
static NSDictionary *red, *green;

+(void)load {
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
        if ([plane isEqualToString:@kIOServicePlane]) [planes insertObject:plane atIndex:0];
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

-(instancetype)initWithEntry:(io_registry_entry_t)entry for:(Document *)document{
    self = [super init];
    if (self) {
        _added = [NSDate date];
        _nodes = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsOpaqueMemory];
        _document = document;
        io_name_t globalname = {};
        IORegistryEntryGetName(entry, globalname);
        _name = [NSString stringWithCString:globalname encoding:NSMacOSRomanStringEncoding];
        IOObjectGetClass(entry, globalname);
        _ioclass = [NSString stringWithCString:globalname encoding:NSMacOSRomanStringEncoding];
        _kernel = IOObjectGetKernelRetainCount(entry) - 1;
        _user = IOObjectGetUserRetainCount(entry) - 1;
        uint64_t entryid = 0, state = 0;
        uint32_t busy = 0;
        IORegistryEntryGetRegistryEntryID(entry, &entryid);
        _entryID = entryid;
        CFMutableDictionaryRef properties;
        IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0);
        _properties = [IORegProperty arrayWithDictionary:(__bridge_transfer NSMutableDictionary *)properties];
        NSMutableDictionary *planes = [NSMutableDictionary dictionary];
        for (NSString *plane in systemPlanes) {
            if (!IORegistryEntryInPlane(entry, [plane cStringUsingEncoding:NSMacOSRomanStringEncoding])) continue;
            if ([plane isEqualToString:@kIOServicePlane]) {
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
        _busy = busy;
        _state = state;
        _planes = [planes copy];
        IOObjectRelease(entry);
    }
    return self;
}
-(instancetype)initWithDictionary:(NSDictionary *)dictionary for:(Document *)document {
    self = [super init];
    if (self) {
        _document = document;
        _ioclass = [dictionary objectForKey:@"class"];
        _added = [dictionary objectForKey:@"added"];
        _removed = [dictionary objectForKey:@"removed"];
        _name = [dictionary objectForKey:@"name"];
        _status = [[dictionary objectForKey:@"status"] intValue];
        _state = [[dictionary objectForKey:@"state"] longLongValue];
        _busy = [[dictionary objectForKey:@"busy"] longLongValue];
        _kernel = [[dictionary objectForKey:@"kernel"] longLongValue];
        _user = [[dictionary objectForKey:@"user"] longLongValue];
        _entryID = [[dictionary objectForKey:@"id"] longLongValue];
        _planes = [dictionary objectForKey:@"planes"];
        _properties = [IORegProperty arrayWithDictionary:[dictionary objectForKey:@"properties"]];
    }
    return self;
}
-(void)addProperties:(NSSet *)objects {
    muteWithNotice(self, properties, _properties = [self.properties arrayByAddingObjectsFromArray:objects.allObjects]);
}
-(void)registerNode:(IORegNode *)node {
    [_nodes addObject:node];
}
-(NSSet *)registeredNodes {
    return _nodes.setRepresentation;
}

-(NSDictionary *)dictionaryRepresentation {
    if (_removed)
        return @{@"class":_ioclass, @"added":_added, @"removed":_removed, @"name":_name, @"status":@(_status), @"state":@(_state), @"busy":@(_busy), @"kernel":@(_kernel), @"user":@(_user), @"id":@(_entryID), @"properties":[NSDictionary dictionaryWithObjects:[_properties valueForKey:@"dictionaryRepresentation"] forKeys:[_properties valueForKey:@"key"]], @"planes":_planes};
    return @{@"class":_ioclass, @"added":_added, @"name":_name, @"status":@(_status), @"state":@(_state), @"busy":@(_busy), @"kernel":@(_kernel), @"user":@(_user), @"id":@(_entryID), @"properties":[NSDictionary dictionaryWithObjects:[_properties valueForKey:@"dictionaryRepresentation"] forKeys:[_properties valueForKey:@"key"]], @"planes":_planes};
}
-(NSArray *)classChain {
    NSArray *chain;
    if ((chain = [_document.allClasses chainForKey:_ioclass]))
        return chain;
    NSMutableArray *temp = [NSMutableArray arrayWithObject:_ioclass];
    NSString *superclass, *class = _ioclass;
    while (![_document.allClasses objectForKey:class] && (superclass = (__bridge_transfer NSString *)IOObjectCopySuperclassForClass((__bridge CFStringRef)class)))
        if ((class = [_document.allClasses setObject:superclass forKey:class]) == superclass)
            [temp addObject:class];
        else
            break;
    [temp addObjectsFromArray:[_document.allClasses chainForKey:class]];
    return [temp copy];
}
-(NSString *)bundle {
    NSString *bundle;
    if ((bundle = [_document.allBundles objectForEquivalentKey:_ioclass])) return bundle;
    bundle = (__bridge_transfer NSString *)IOObjectCopyBundleIdentifierForClass((__bridge CFStringRef)_ioclass);
    return [_document.allBundles setObject:[bundle isEqualToString:@"__kernel__"]?[_document.allBundles objectForKey:@"OSObject"]:bundle forKey:_ioclass];
}
-(NSArray *)paths {
    return [_planes.allValues valueForKeyPath:@"path"];
}
-(NSArray *)sortedPaths {
    NSString *plane = _document.selectedPlane.plane;
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
    if ((plane = [_planes objectForKey:_document.selectedPlane.plane]) && (planeName = [plane objectForKey:@"name"])) {
        NSString *location;
        if ((location = [plane objectForKey:@"location"]).length)
            return [NSString stringWithFormat:@"%@@%@", planeName, location];
        else return planeName;
    }
    else return _name;
}
+(NSSet *)keyPathsForValuesAffectingDisplayName {
    return [NSSet setWithObjects:@"status", nil];
}
-(id)displayName {
    switch (_status) {
        case IORegStatusInitial: return self.currentName;
        case IORegStatusPublished: return [[NSAttributedString alloc] initWithString:self.currentName attributes:green];
        case IORegStatusTerminated: return [[NSAttributedString alloc] initWithString:self.currentName attributes:red];
    }
}
-(bool)isActive {
    return (_state & kIOServiceInactiveState) == 0;
}
-(bool)isRegistered {
    return (_state & kIOServiceRegisteredState) != 0;
}
-(bool)isMatched {
    return (_state & kIOServiceMatchedState) != 0;
}
-(bool)isService {
    return ![_ioclass isEqualToString:@"IORegistryEntry"];
}
-(NSString *)filteredProperty {
    NSString *property = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"find"] objectForKey:@"property"];
    for (IORegProperty *obj in _properties)
        if ([obj.key isEqualToString:property])
            return obj.briefDescription;
    return nil;
}

@end

@implementation IORegNode
static NSDateFormatter *dateFormatter;
static NSPredicate *hideBlock;

@synthesize node = _node;
+(void)load{
    dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    hideBlock = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings){
        return [[evaluatedObject node] status] != IORegStatusTerminated;
    }];
}

-(instancetype)initWithNode:(IORegObj *)node on:(IORegNode *)parent{
    self = [super init];
    if (self) {
        _node = node;
        _plane = parent.plane;
        _parent = parent;
        if (parent.children) [parent.children addObject:self];
        else parent.children = [NSMutableArray arrayWithObject:self];
    }
    return self;
}
-(instancetype)initWithDictionary:(NSDictionary *)dictionary on:(IORegNode *)parent {
    self = [super init];
    if (self) {
        _parent = parent;
        _plane = parent.plane;
        _node = (__bridge IORegObj *)(NSMapGet(parent.node.document.allObjects, (void *)[[dictionary objectForKey:@"node"] longLongValue]));
        if ([[dictionary objectForKey:@"children"] count]) {
            _children = [NSMutableArray array];
            for (NSDictionary *ioreg in [dictionary objectForKey:@"children"])
                [_children addObject:[[IORegNode alloc] initWithDictionary:ioreg on:self]];
        }
    }
    return self;
}
-(void)setNode:(IORegObj *)aNode {
    [aNode registerNode:self];
    _node = aNode;
}
-(IORegObj *)node {
    return _node;
}
-(NSMutableArray *)children {
    return _node.document.hiding?[[_children filteredArrayUsingPredicate:hideBlock] mutableCopy]:_children;
}
-(NSDictionary *)dictionaryRepresentation {
    return _children.count
    ? @{@"node":@(_node.entryID), @"children": [_children valueForKey:@"dictionaryRepresentation"]}
    : @{@"node":@(_node.entryID)};
}
-(NSIndexPath *)indexPath {
    NSUInteger length = 1, index = 0;
    IORegNode *node = self;
    while (![node isKindOfClass:IORegRoot.class] && length++)
        node = node->_parent;
    NSUInteger indexes[(index = length)];
    node = self;
    while (index > 0) {
        indexes[--index]=[node->_parent->_children indexOfObject:node];
        node = node->_parent;
    }
    return [NSIndexPath indexPathWithIndexes:indexes length:length];
}
-(NSMutableSet *)flat {
    NSMutableSet *flat = [NSMutableSet setWithObject:self];
    for (IORegNode *child in _children) [flat unionSet:child.flat];
    return flat;
}
-(NSString *)metaData {
    if (_node.status == IORegStatusTerminated)
        return [NSString stringWithFormat:@"%@\nDiscovered: %@\nTerminated: %@", _node.name, [dateFormatter stringFromDate:_node.added], [dateFormatter stringFromDate:_node.removed]];
    return [NSString stringWithFormat:@"%@\nDiscovered: %@", _node.name, [dateFormatter stringFromDate:_node.added]];
}
-(void)walk:(io_iterator_t)iterator {
    io_registry_entry_t object;
    while ((object = IOIteratorNext(iterator))) {
        bool stop = false;
        IORegObj *obj = [_node.document addObject:object];
        for (IORegNode *child in _children)
            if (child.node == obj) {
                stop = true;
                break;
            }
        if (stop) continue;
        IORegNode *child = [[IORegNode alloc] initWithNode:obj on:self];
        if (IORegistryIteratorEnterEntry(iterator) == KERN_SUCCESS) [child walk:iterator];
    }
    IORegistryIteratorExitEntry(iterator);
}
-(void)mutate {
    io_iterator_t it;
    io_registry_entry_t entry = IOServiceGetMatchingService(kIOMasterPortDefault, IORegistryEntryIDMatching(_node.entryID));
    IORegistryEntryCreateIterator(entry, [_plane cStringUsingEncoding:NSMacOSRomanStringEncoding], 0, &it);
    [self walk:it];
    IOObjectRelease(it);
}

@end

@implementation IORegRoot {
    @private
    NSMutableArray *_pleated;
}
static NSPredicate *filterBlock;

+(void)load {
    filterBlock = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings){
        evaluatedObject = [evaluatedObject node];
        NSString *value = [bindings objectForKey:@"value"];
        for (NSString *key in [bindings objectForKey:@"keys"]) {
            if ([key isEqualToString:@"name"]) {
                if ([[evaluatedObject name] rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound)
                    return true;}
            else if ([key isEqualToString:@"bundle"]) {
                if ([[(IORegObj *)evaluatedObject bundle] rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound)
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

-(instancetype)initWithNode:(IORegObj *)root on:(NSString *)plane{
    self = [super init];
    if (self) {
        self.node = root;
        self.plane = plane;
    }
    return self;
}
-(instancetype)initWithDictionary:(NSDictionary *)dictionary on:(NSMapTable *)table {
    self = [super init];
    if (self) {
        self.node = (__bridge IORegObj *)(NSMapGet(table, (void *)[[dictionary objectForKey:@"root"] longLongValue]));
        self.plane = [dictionary objectForKey:@"plane"];
        if ([[dictionary objectForKey:@"children"] count]) {
            self.children = [NSMutableArray array];
            for (NSDictionary *ioreg in [dictionary objectForKey:@"children"])
                [self.children addObject:[[IORegNode alloc] initWithDictionary:ioreg on:self]];
        }
    }
    return self;
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
    return @{@"root":@(self.node.entryID), @"plane":self.plane, @"children":[_pleated valueForKey:@"dictionaryRepresentation"]};
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

@implementation IORegProperty {
    @private
    id _value;
    NSInteger _type, _subtype;
}

static NSUInteger boolType, dictType, arrType, dataType, strType, numType, dateType;

+(void)load {
    boolType = CFBooleanGetTypeID();
    dictType = CFDictionaryGetTypeID();
    arrType = CFArrayGetTypeID();
    dataType = CFDataGetTypeID();
    strType = CFStringGetTypeID();
    numType = CFNumberGetTypeID();
    dateType = CFDateGetTypeID();
}

+(NSArray *)arrayWithDictionary:(NSDictionary *)dictionary {
    NSMutableArray *properties = [NSMutableArray array];
    for (NSString *key in dictionary)
        [properties addObject:[[IORegProperty alloc] initWithValue:[dictionary objectForKey:key] forKey:key]];
    return [properties copy];
}
-(instancetype)initWithValue:(id)value forKey:(id)key {
    self = [super init];
    if (self) {
        _key = [key copy];
        _type = CFGetTypeID((__bridge CFTypeRef)value);
        if (_type == dictType && [value count]) {
            NSMutableArray *array = [NSMutableArray array];
            for (NSString *str in value)
                [array addObject:[[IORegProperty alloc] initWithValue:[value objectForKey:str] forKey:str]];
            _children = [array copy];
        }
        else if (_type == arrType && [value count]) {
            NSMutableArray *array = [NSMutableArray array];
            NSUInteger i = 0;
            for (id obj in value)
                [array addObject:[[IORegProperty alloc] initWithValue:obj forKey:@(i++)]];
            _children = [array copy];
        }
        else _value = value;
        if (_type == dataType) _subtype = [_value isTextual] ? [[_value macromanStrings] count] : -1;
        else if (_type == numType) _subtype = [_value nSize];
    }
    return self;
}

-(NSDictionary *)dictionaryRepresentation {
    if (_type == dictType)
        return _children.count?[NSDictionary dictionaryWithObjects:[_children valueForKey:@"dictionaryRepresentation"] forKeys:[_children valueForKey:@"key"]]:@{};
    else if (_type == arrType)
        return _children.count?[_children valueForKey:@"dictionaryRepresentation"]:@[];
    return _value;
}
-(NSString *)description {
    if (_type == boolType) return [_value boolValue]?@"True":@"False";
    else if (_type == dictType || _type == arrType)
        return [NSString stringWithFormat:@"%ld value%s", _children.count, _children.count==1?"":"s"];
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
        return [NSString stringWithFormat:@"%@ of %ld value%s", self.typeString, _children.count, _children.count==1?"":"s"];
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
