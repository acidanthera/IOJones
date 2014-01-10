//
//  Document.m
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Document.h"
#import "IOReg.h"
#import "Base.h"
#import <IOKit/kext/KextManager.h>

@implementation Document
@synthesize outlineView;
@synthesize treeView;
@synthesize browseView;
@synthesize findView;
@synthesize propertyView;
@synthesize pathWindow;
@synthesize pathView;
@synthesize systemName;
@synthesize hostname;
@synthesize timestamp;
@synthesize allBundles;
@synthesize allClasses;
@synthesize allObjects;
@synthesize allPlanes;

#pragma mark NSDocument
- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        allObjects = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsIntegerPersonality|NSPointerFunctionsOpaqueMemory valueOptions:NSPointerFunctionsObjectPersonality];
        allClasses = [NSMutableDictionarySet new];
        allBundles = [NSMutableDictionarySet new];
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    treeView.sortDescriptors = @[[[treeView.tableColumns objectAtIndex:0] sortDescriptorPrototype]];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    delayWithNotice(self, title, 0)
    [(NSSplitView *)treeView.superview.superview.superview restore];
}

+ (BOOL)autosavesInPlace
{
    return false;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    self.updating = false;
    [allPlanes makeObjectsPerformSelector:@selector(children)];
    [NSAllMapTableValues(allObjects) makeObjectsPerformSelector:@selector(bundle)];
    [NSAllMapTableValues(allObjects) makeObjectsPerformSelector:@selector(classChain)];
    NSError *err;
    NSData *data;
    if ([typeName isEqualToString:kUTTypeIOJones])
        data = [NSPropertyListSerialization dataWithPropertyList:@{@"system":@{@"hostname":hostname, @"systemName":systemName, @"timestamp":timestamp},@"classes":allClasses.dictionaryRepresentation, @"bundles":allBundles.dictionaryRepresentation, @"objects":[NSAllMapTableValues(allObjects) valueForKey:@"dictionaryRepresentation"], @"planes": [allPlanes valueForKey:@"dictionaryRepresentation"]} format:NSPropertyListBinaryFormat_v1_0 options:0 error:&err];
    else //TODO: add other document support
        err = [NSError errorWithDomain:kIOJonesDomain code:kFileError userInfo:@{NSLocalizedDescriptionKey:@"Filetype Error", NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Unknown Filetype %@", typeName]}];
    if (err && outError != NULL)
        *outError = err;
    return data;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    NSError *err;
    NSDictionary *dict;
    if ([typeName isEqualToString:kUTTypeIOJones]) {
        dict = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&err];
        allClasses = [NSMutableDictionarySet createWithDictionary:[dict objectForKey:@"classes"]];
        allBundles = [NSMutableDictionarySet createWithDictionary:[dict objectForKey:@"bundles"]];
        hostname = [[dict objectForKey:@"system"] objectForKey:@"hostname"];
        systemName = [[dict objectForKey:@"system"] objectForKey:@"systemName"]?:[[[[dict objectForKey:@"system"] objectForKey:@"hostname"] componentsSeparatedByString:@" ("] objectAtIndex:0];
        timestamp = [[dict objectForKey:@"system"] objectForKey:@"timestamp"];
        for (NSDictionary *ioreg in [dict objectForKey:@"objects"]) [self addDict:ioreg];
        NSMutableArray *temp = [NSMutableArray array];
        for (NSDictionary *plane in [dict objectForKey:@"planes"])
            [temp addObject:[IORegRoot createWithDictionary:plane on:allObjects]];
        allPlanes = [temp copy];
    }
    else
        err = [NSError errorWithDomain:kIOJonesDomain code:kFileError userInfo:@{NSLocalizedDescriptionKey:@"Filetype Error", NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Unknown Filetype %@", typeName]}];
    if (err && outError != NULL)
        *outError = err;
    return !err;
}
-(id)initWithType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    self = [self init];
    [self setFileType:typeName];
    timestamp = [NSDate date];
    NSString *nsroot = @"OSObject";
    [allClasses setObject:nsroot forKey:nsroot];
    [allBundles setObject:@"com.apple.kernel" forKey:nsroot];
    hostname = [NSString stringWithFormat:@"%@ (%@)", (systemName = [IORegObj systemName]), [IORegObj systemType]];
    IORegObj *root = [self addObject:IORegistryGetRootEntry(kIOMasterPortDefault)];
    NSMutableArray *temp = [NSMutableArray array];
    for (NSString *plane in [IORegObj systemPlanes])
        [temp addObject:[IORegRoot root:root on:plane]];
    allPlanes = [temp copy];
    self.updating = true;
    return self;
}
-(void)close {
    self.updating = false;
    browseView = nil;
    outlineView = nil;
    [super close];
}
-(NSString *)defaultDraftName {
    return [IORegObj systemName];
}

#pragma mark NSOutlineViewDelegate
-(CGFloat)outlineView:(NSOutlineView *)outline heightOfRowByItem:(id)item{
    if (outline == treeView) return outline.rowHeight;
    NSUInteger row = [outline rowForItem:item], rows = outline.tableColumns.count;
    CGFloat height = outline.rowHeight;
    while (rows-- > 0)
        height = MAX([[outline preparedCellAtColumn:rows row:row] cellSizeForBounds:NSMakeRect(0, 0, [[outline.tableColumns objectAtIndex:rows] width], CGFLOAT_MAX)].height,height);
    return height;
}
-(void)outlineViewColumnDidResize:(NSNotification *)notification {
    if (notification.object != treeView) [notification.object noteNumberOfRowsChanged];
}
-(NSString *)outlineView:(NSOutlineView *)outline toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation {
    if (outline == treeView || [outline.tableColumns indexOfObject:tableColumn] == 2)
        return [[item representedObject] metaData];
    else return nil;
}

#pragma mark GUI
-(IBAction)switchPlane:(id)sender{
    [self revealPath:[sender titleOfSelectedItem]];
}
-(IBAction)expandTree:(id)sender {
    [treeView expandItem:sender expandChildren:true];
    [treeView noteNumberOfRowsChanged];
}
-(IBAction)find:(id)sender {
    [findView.window makeFirstResponder:findView];
}
-(IBAction)filterTree:(id)sender {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(coalesceFilter:) object:sender];
    [self performSelector:@selector(coalesceFilter:) withObject:sender afterDelay:0.5];
}
-(IBAction)coalesceFilter:(id)sender {
    NSString *path = [[[[self.selectedItem representedObject] node] sortedPaths] objectAtIndex:0];
    [self.selectedPlane filter:[sender stringValue]];
    if (![[sender stringValue] length])
        [self performSelector:@selector(expandTree:) withObject:nil afterDelay:0];
    else [treeView performSelector:@selector(expandItem:) withObject:self.selectedRootNode afterDelay:0];
    [self showProperty:nil];
    if (path) [self performSelector:@selector(revealPath:) withObject:path afterDelay:0];
}
-(IBAction)showProperty:(id)sender {
    if (!_drawer) return;
    NSString *property = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"find"] objectForKey:@"property"];
    [[[propertyView.tableColumns objectAtIndex:1] headerCell] setTitle:property?:@"Property"];
    [propertyView.headerView setNeedsDisplay:true];
    muteWithNotice(self, drawerLabel,)
}
-(IBAction)parent:(id)sender {
    [self revealItem:[self.selectedItem parentNode]];
}
-(IBAction)firstChild:(id)sender {
    [self revealItem:[[self.selectedItem childNodes] objectAtIndex:0]];
}
-(IBAction)nextSibling:(id)sender {
    NSArray *children = [[self.selectedItem parentNode] childNodes];
    [self revealItem:[children objectAtIndex:[children indexOfObject:self.selectedItem]+1]];
}
-(IBAction)previousSibling:(id)sender {
    NSArray *children = [[self.selectedItem parentNode] childNodes];
    [self revealItem:[children objectAtIndex:[children indexOfObject:self.selectedItem]-1]];
}
-(IBAction)expandAll:(id)sender {
    [self expandTree:nil];
}
-(IBAction)collapseAll:(id)sender {
    [treeView collapseItem:nil collapseChildren:true];
}
-(IBAction)collapseSelection:(id)sender {
    NSIndexPath *path = [[treeView itemAtRow:treeView.selectedRow] indexPath];
    NSTreeNode *node = [self.selectedRootNode parentNode];
    NSUInteger i = 0;
    [treeView collapseItem:nil collapseChildren:true];
    while (i < path.length) {
        node = [node.childNodes objectAtIndex:[path indexAtPosition:i++]];
        [treeView expandItem:node];
    }
    [self revealItem:node];
}
-(IBAction)nextPath:(id)sender {
    NSTreeNode *node = self.selectedItem;
    NSArray *sortedPaths = [[[[[node.representedObject node] registeredNodes] valueForKey:@"indexPath"] allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger i = [sortedPaths indexOfObject:[node.representedObject indexPath]];
    if (i == NSNotFound || i == sortedPaths.count-1) return;
    [self revealItem:[[self.selectedRootNode parentNode] descendantNodeAtIndexPath:[sortedPaths objectAtIndex:++i]]];
}
-(IBAction)previousPath:(id)sender {
    NSTreeNode *node = self.selectedItem;
    NSArray *sortedPaths = [[[[[node.representedObject node] registeredNodes] valueForKey:@"indexPath"] allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger i = [sortedPaths indexOfObject:[node.representedObject indexPath]];
    if (i == NSNotFound || i == 0) return;
    [self revealItem:[[self.selectedRootNode parentNode] descendantNodeAtIndexPath:[sortedPaths objectAtIndex:--i]]];
}
-(IBAction)nextPathAny:(id)sender {
    [self revealPath:[[[self.selectedItem representedObject] sortedPaths] objectAtIndex:1]];
}
-(IBAction)previousPathAny:(id)sender {
    [self revealPath:[[[self.selectedItem representedObject] sortedPaths] lastObject]];
}
-(IBAction)showPath:(id)sender {
    [NSApp beginSheet:pathWindow modalForWindow:self.windowForSheet modalDelegate:nil didEndSelector:nil contextInfo:nil];
}
-(IBAction)closePath:(id)sender {
    [NSApp endSheet:pathWindow];
    [pathWindow orderOut:sender];
}
-(IBAction)goToPath:(id)sender {
    [self closePath:sender];
    [self revealPath:pathView.stringValue];
}

-(IBAction)revealKext:(id)sender {
    NSString *bundle = [[[self.selectedItem representedObject] node] bundle];
    NSURL *kext = (__bridge_transfer NSURL *)KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, (__bridge CFStringRef)bundle);
    SHOWFILE(kext.path);
}
-(IBAction)finishViews:(id)sender {
    [sender setPosition:([(NSSplitView *)sender isVertical]?[sender frame].size.width:[sender frame].size.height)/2 ofDividerAtIndex:0];
    [sender adjustSubviews];
}
-(IBAction)removeTerminated:(id)sender {
    if ([sender isKindOfClass:IORegNode.class]) {
        for (IORegNode *child in [[sender children] copy])
            if (child.node.removed) {
                NSUInteger i = [[sender children] indexOfObject:child];
                removeWithNotice(sender, children, i)
            }
            else
                [self removeTerminated:child];
        return;
    }
    for (IORegRoot *root in allPlanes)
        if (root.isLoaded)
            [self removeTerminated:root];
    for (IORegObj *obj in allObjects.objectEnumerator)
        if (obj.removed)
            NSMapRemove(allObjects, (void *)obj.entryID);//TODO: undo management?
}

#pragma mark IOService Notifications
-(NSArray *)service:(io_iterator_t)iterator {
    io_service_t service;
    NSMutableArray *array = [NSMutableArray array];
    while ((service = IOIteratorNext(iterator))) {
        IORegObj *obj = [self addObject:service];
        [array addObject:obj];
        if (iterator == _terminate)
            obj.removed = [NSDate date];
        obj.status = iterator == _terminate ? terminated : iterator == _publish ? published : initial;
    }
    return [array copy];
}
-(void)serviceNotification:(io_iterator_t)iterator {
    NSArray *objs;
    if ((objs = [self service:iterator])) {
        NSRect scroll = self.scrollPosition;
        for (IORegObj *obj in objs) {
            for (NSString *path in [obj.planes.allValues valueForKey:@"path"]) {
                if (![[self rootForPath:path] isLoaded]) continue;
                IORegNode *node = [self nodeForPath:path];
                if (node.node == obj) continue;
                muteWithNotice(node, children, [node mutate])
            }
        }
        [self expandTree:nil];
        self.scrollPosition = scroll;
    }
}
void serviceNotification(void *refCon, io_iterator_t iterator) {
    [(__bridge Document *)refCon serviceNotification:iterator];
}
-(void)busyNotification:(io_service_t)service {
    /*for (IORegNode *node in [[self addObject:service] registeredNodes]) {
        [node.children removeAllObjects];
        muteWithNotice(node, children, [node mutate])
    }*/
}
void busyNotification(void *refCon, io_service_t service, uint32_t messageType, void *messageArgument) {
    if (messageType == 0xE0000120 && !messageArgument)
        [(__bridge Document *)refCon busyNotification:service];
}

#pragma mark Nonatomic Properties
-(void)setHiding:(bool)hiding {
    _hiding = hiding;
    IORegRoot *plane = self.selectedPlane;
    muteWithNotice(plane, children,)
}
-(bool)hiding {
    return _hiding;
}
-(void)setScrollPosition:(NSRect)scrollPosition {
    if (treeView.window)
        [treeView scrollRectToVisible:scrollPosition];
    else
        [browseView scrollRectToVisible:scrollPosition];
}
-(NSRect)scrollPosition {
    return treeView.window?treeView.visibleRect:browseView.visibleRect;
}
-(void)setDrawer:(bool)drawer{
    _drawer = drawer;
    if (drawer) [self showProperty:nil];
}
-(bool)drawer {
    return _drawer;
}
-(void)setSelectedPlanes:(NSIndexSet *)selectedPlanes{
    if ([selectedPlanes isEqualToIndexSet:_selectedPlanes]) return;
    [self filterTree:findView];
    _selectedPlanes = selectedPlanes;
}
//TODO: bind selectedObjects to drawer selection
+(NSSet *)keyPathsForValuesAffectingTitle {
    return [NSSet setWithObjects:@"selectedPlane", @"selectedObjects", nil];
}
-(NSString *)title {
    return [NSString stringWithFormat:@"%@ - %@ - %@", systemName, self.selectedPlane.plane, self.selectedItem?[[[self.selectedItem representedObject] node] currentName]:@"(no object selected)"];
}
+(NSSet *)keyPathsForValuesAffectingDrawerLabel {
    return [NSSet setWithObjects:@"selectedPlane", nil];
}
-(NSString *)drawerLabel {
    if ([[findView stringValue] length]) return [NSString stringWithFormat:@"%ld object%s matched", self.selectedPlane.children.count, self.selectedPlane.children.count==1?"":"s"];
    else return @"No search";
}
+(NSSet *)keyPathsForValuesAffectingSelectedPlane {
    return [NSSet setWithObjects:@"selectedPlanes", nil];
}
-(IORegRoot *)selectedPlane {
    return [allPlanes objectAtIndex:_selectedPlanes.firstIndex];
}
-(NSTreeNode *)selectedRootNode {
    return (treeView.window)?[treeView itemAtRow:0]:[[browseView loadedCellAtRow:0 column:0] representedObject];
}
-(void)setUpdating:(bool)updating {
    if (_port && !updating) {
        IONotificationPortDestroy(_port);
        _port = 0;
        if (_publish) IOObjectRelease(_publish);
        if (_notice) IOObjectRelease(_notice);
        if (_terminate) IOObjectRelease(_terminate);
    }
    else if (!_port && updating) {
        _port = IONotificationPortCreate(kIOMasterPortDefault);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(_port), kCFRunLoopDefaultMode);
        if (IOServiceAddMatchingNotification(_port, kIOFirstPublishNotification, IOServiceMatching(kIOServiceClass), serviceNotification, (__bridge void *)self, &_publish) != KERN_SUCCESS) {
            self.updating = false;
            return;
        }
        io_service_t s;
        while ((s = IOIteratorNext(_publish)))
            [self addObject:s];
        io_service_t expert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
        kern_return_t ret = IOServiceAddInterestNotification(_port, expert, kIOBusyInterest, busyNotification, (__bridge void *)self, &_notice);
        IOObjectRelease(expert);
        if (ret != KERN_SUCCESS || IOServiceAddMatchingNotification(_port, kIOTerminatedNotification, IOServiceMatching(kIOServiceClass), serviceNotification, (__bridge void *)self, &_terminate) != KERN_SUCCESS){
            self.updating = false;
            return;
        }
        while ((s = IOIteratorNext(_terminate))) {
            [[self addObject:s] setStatus:terminated];
        }
    }
}
-(bool)isUpdating {
    return (_port);
}
-(void)setOutline:(bool)outline {//TODO: add default?
    NSView *split, *swap;
    if (browseView.window && outline) {
        split = browseView.superview;
        swap = outlineView;
    }
    else if (outlineView.window && !outline) {
        split = outlineView.superview;
        swap = browseView;
    }
    if (!split)
        return;
    bool vertical = ![(NSSplitView *)split isVertical];
    muteWithNotice(self, outline, [split replaceSubview:[split.subviews objectAtIndex:0] with:swap])//FIXME: constraints
    [(NSSplitView *)split setVertical:vertical];
    [self performSelector:@selector(finishViews:) withObject:split afterDelay:0.01];
    
}
-(bool)isOutline {
    return (treeView.window);
}
-(id)selectedItem {
    if (treeView.window) return [treeView itemAtRow:treeView.selectedRow];
    else return [browseView.selectedCell representedObject];
}

#pragma mark Traversal
-(void)revealPath:(NSString *)path {
    self.selectedPlanes = [NSIndexSet indexSetWithIndex:[allPlanes indexOfObjectIdenticalTo:[self rootForPath:path]]];
    [self performSelector:@selector(revealItem:) withObject:[self find:[[self nodeForPath:path] node] on:self.selectedRootNode] afterDelay:0];
}
-(void)revealItem:(NSTreeNode *)item {
    if (treeView.window) {
        NSUInteger i = [treeView rowForItem:item];
        if (i == -1) {
            [self performSelector:_cmd withObject:item afterDelay:1];
            return;
        }
        [treeView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:false];
        [treeView scrollRowToVisible:i];
    }
    else {
        NSInteger i = -1, j = item.indexPath.length;
        while (i++ < j) [browseView selectRow:[item.indexPath indexAtPosition:i] inColumn:i];
        [browseView sendAction];
    }
}
-(IORegRoot *)rootForPath:(NSString *)path {
    for (IORegRoot *root in allPlanes)
        if ([path hasPrefix:root.plane])
            return root;
    return nil;
}
-(IORegNode *)nodeForPath:(NSString *)path {
    IORegRoot *root;
    if (!(root = [self rootForPath:path])) return nil;
    else if ([path hasSuffix:@":"]) return root;
    else if ([path hasSuffix:@"/"]) return [root.children objectAtIndex:0];
    else return [self walkPathComponent:[path.pathComponents subarrayWithRange:NSMakeRange(1, path.pathComponents.count-1)] on:[root.children objectAtIndex:0]];
}
-(IORegNode *)walkPathComponent:(NSArray *)components on:(IORegNode *)parent {
    for (IORegNode *child in parent.children)
        if ([child.node.currentName isEqualToString:[components objectAtIndex:0]]) {
            if (components.count == 1) return child;
            else return [self walkPathComponent:[components subarrayWithRange:NSMakeRange(1, components.count-1)] on:child];
        }
    return parent;
}
-(NSTreeNode *)find:(IORegObj *)obj on:(NSTreeNode *)proxy {
    if ([proxy.representedObject node] == obj) return proxy;
    NSTreeNode *node;
    for (NSTreeNode *child in proxy.childNodes)
        if ((node = [self find:obj on:child]))
            return node;
    return node;
}

#pragma mark Functions
-(IORegObj *)addObject:(io_registry_entry_t)object {
    UInt64 entry;
    IORegObj *temp;
    IORegistryEntryGetRegistryEntryID(object, &entry);
    if (!(temp = (__bridge IORegObj *)NSMapGet(allObjects, (void *)entry))) {
        temp = [IORegObj create:object for:self];
        NSMapInsertKnownAbsent(allObjects, (void *)entry, (__bridge void *)temp);
    }
    else IOObjectRelease(object);
    return temp;
}
- (void)addDict:(NSDictionary *)object{
    IORegObj *temp = [IORegObj createWithDictionary:object for:self];
    NSMapInsertKnownAbsent(allObjects, (void *)temp.entryID, (__bridge void *)temp);
}

@end
