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

@implementation Document {
    @private
    bool _drawer, _hiding;
    NSIndexSet *_selectedPlanes;
    NSArray *_selectedObjects;
    IONotificationPortRef _port;
    io_iterator_t _publish, _terminate;
    io_object_t _notice;
    IBOutlet NSScrollView *_outlineView;
    IBOutlet NSBrowser *_browseView;
    __unsafe_unretained IBOutlet NSOutlineView *_treeView;
    __unsafe_unretained IBOutlet NSSearchField *_findView;
    __unsafe_unretained IBOutlet NSTableView *_propertyView;
    __unsafe_unretained IBOutlet NSWindow *_pathWindow;
    __unsafe_unretained IBOutlet NSTextField *_pathView;
}

#pragma mark NSDocument
- (instancetype)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        _allObjects = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsIntegerPersonality|NSPointerFunctionsOpaqueMemory valueOptions:NSPointerFunctionsObjectPersonality];
        _allClasses = [NSMutableDictionarySet new];
        _allBundles = [NSMutableDictionarySet new];
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
    _treeView.sortDescriptors = @[[_treeView.tableColumns.firstObject sortDescriptorPrototype]];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    delayWithNotice(self, title, 0)
    [(NSSplitView *)_treeView.superview.superview.superview restore];
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
    [_allPlanes makeObjectsPerformSelector:@selector(children)];
    [NSAllMapTableValues(_allObjects) makeObjectsPerformSelector:@selector(bundle)];
    [NSAllMapTableValues(_allObjects) makeObjectsPerformSelector:@selector(classChain)];
    IORegObj *expert = nil;
    for (IORegRoot *r in _allPlanes)
        if ([r.plane isEqualToString:@kIOServicePlane]) {
            for (IORegNode *n in [r.children.firstObject children])
                if ([n.node.name isEqualToString:@"AppleACPIPlatformExpert"]) {
                    expert = n.node;
                    break;
                }
        }
        else if (expert)
            break;
    if (![[expert.properties valueForKey:@"key"] containsObject:@"ACPI Tables"] && !self.fileURL) {
        io_service_t e = IOServiceGetMatchingService(kIOMasterPortDefault, IORegistryEntryIDMatching(expert.entryID));
        [expert addProperties:[NSSet setWithObject:[IORegProperty arrayWithDictionary:@{@"ACPI Tables":(__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(e, CFSTR("ACPI Tables"), kCFAllocatorDefault, 0)}]]];
        IOObjectRelease(e);
    }
    NSError *err;
    NSData *data;
    if ([typeName isEqualToString:kUTTypeIOJones])
        data = [NSPropertyListSerialization dataWithPropertyList:@{@"system":@{@"hostname":_hostname, @"systemName":_systemName, @"timestamp":_timestamp},@"classes":_allClasses.dictionaryRepresentation, @"bundles":_allBundles.dictionaryRepresentation, @"objects":[NSAllMapTableValues(_allObjects) valueForKey:@"dictionaryRepresentation"], @"planes": [_allPlanes valueForKey:@"dictionaryRepresentation"]} format:NSPropertyListBinaryFormat_v1_0 options:0 error:&err];
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
        _allClasses = [[NSMutableDictionarySet alloc] initWithDictionary:[dict objectForKey:@"classes"]];
        _allBundles = [[NSMutableDictionarySet alloc] initWithDictionary:[dict objectForKey:@"bundles"]];
        _hostname = [[dict objectForKey:@"system"] objectForKey:@"hostname"];
        _systemName = [[dict objectForKey:@"system"] objectForKey:@"systemName"]?:[[[[dict objectForKey:@"system"] objectForKey:@"hostname"] componentsSeparatedByString:@" ("] firstObject];
        _timestamp = [[dict objectForKey:@"system"] objectForKey:@"timestamp"];
        for (NSDictionary *ioreg in [dict objectForKey:@"objects"]) [self addDict:ioreg];
        NSMutableArray *temp = [NSMutableArray array];
        for (NSDictionary *plane in [dict objectForKey:@"planes"])
            [temp addObject:[[IORegRoot alloc] initWithDictionary:plane on:_allObjects]];
        _allPlanes = [temp copy];
    }
    else
        err = [NSError errorWithDomain:kIOJonesDomain code:kFileError userInfo:@{NSLocalizedDescriptionKey:@"Filetype Error", NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Unknown Filetype %@", typeName]}];
    if (err && outError != NULL)
        *outError = err;
    return !err;
}
-(instancetype)initWithType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    self = [self init];
    [self setFileType:typeName];
    _timestamp = [NSDate date];
    NSString *nsroot = @"OSObject";
    [_allClasses setObject:nsroot forKey:nsroot];
    [_allBundles setObject:@"com.apple.kernel" forKey:nsroot];
    _hostname = [NSString stringWithFormat:@"%@ (%@)", (_systemName = [IORegObj systemName]), [IORegObj systemType]];
    IORegObj *root = [self addObject:IORegistryGetRootEntry(kIOMasterPortDefault)];
    NSMutableArray *temp = [NSMutableArray array];
    for (NSString *plane in [IORegObj systemPlanes])
        [temp addObject:[[IORegRoot alloc] initWithNode:root on:plane]];
    _allPlanes = [temp copy];
    self.updating = true;
    return self;
}
-(void)close {
    self.updating = false;
    _browseView = nil;
    _outlineView = nil;
    [super close];
}
-(NSString *)defaultDraftName {
    return [IORegObj systemName];
}

#pragma mark NSOutlineViewDelegate
-(CGFloat)outlineView:(NSOutlineView *)outline heightOfRowByItem:(id)item{
    if (outline == _treeView) return outline.rowHeight;
    NSUInteger row = [outline rowForItem:item], rows = outline.tableColumns.count;
    CGFloat height = outline.rowHeight;
    while (rows-- > 0)
        height = MAX([[outline preparedCellAtColumn:rows row:row] cellSizeForBounds:NSMakeRect(0, 0, [[outline.tableColumns objectAtIndex:rows] width], CGFLOAT_MAX)].height,height);
    return height;
}
-(void)outlineViewColumnDidResize:(NSNotification *)notification {
    if (notification.object != _treeView) [notification.object noteNumberOfRowsChanged];
}
-(NSString *)outlineView:(NSOutlineView *)outline toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation {
    if (outline == _treeView || [outline.tableColumns indexOfObject:tableColumn] == 2)
        return [[item representedObject] metaData];
    else return nil;
}

#pragma mark GUI
-(IBAction)switchPlane:(id)sender{
    [self revealPath:[sender titleOfSelectedItem]];
}
-(IBAction)expandTree:(id)sender {
    [_treeView expandItem:sender expandChildren:true];
    [_treeView noteNumberOfRowsChanged];
}
-(IBAction)find:(id)sender {
    [_findView.window makeFirstResponder:_findView];
}
-(IBAction)filterTree:(id)sender {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(coalesceFilter:) object:sender];
    [self performSelector:@selector(coalesceFilter:) withObject:sender afterDelay:0.5];
}
-(IBAction)coalesceFilter:(id)sender {
    NSString *path = [[[[self.selectedItem representedObject] node] sortedPaths] firstObject];
    [self.selectedPlane filter:[sender stringValue]];
    if (![[sender stringValue] length])
        [self performSelector:@selector(expandTree:) withObject:nil afterDelay:0];
    else [_treeView performSelector:@selector(expandItem:) withObject:self.selectedRootNode afterDelay:0];
    [self showProperty:nil];
    if (path) [self performSelector:@selector(revealPath:) withObject:path afterDelay:0];
}
-(IBAction)showProperty:(id)sender {
    if (!_drawer) return;
    NSString *property = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"find"] objectForKey:@"property"];
    [[[_propertyView.tableColumns objectAtIndex:1] headerCell] setTitle:property?:@"Property"];
    [_propertyView.headerView setNeedsDisplay:true];
    muteWithNotice(self, drawerLabel,)
}
-(IBAction)parent:(id)sender {
    [self revealItem:[self.selectedItem parentNode]];
}
-(IBAction)firstChild:(id)sender {
    [self revealItem:[[self.selectedItem childNodes] firstObject]];
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
    [_treeView collapseItem:nil collapseChildren:true];
}
-(IBAction)collapseSelection:(id)sender {
    NSIndexPath *path = [[_treeView itemAtRow:_treeView.selectedRow] indexPath];
    NSTreeNode *node = [self.selectedRootNode parentNode];
    NSUInteger i = 0;
    [_treeView collapseItem:nil collapseChildren:true];
    while (i < path.length) {
        node = [node.childNodes objectAtIndex:[path indexAtPosition:i++]];
        [_treeView expandItem:node];
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
    [NSApp beginSheet:_pathWindow modalForWindow:self.windowForSheet modalDelegate:nil didEndSelector:nil contextInfo:nil];
}
-(IBAction)closePath:(id)sender {
    [NSApp endSheet:_pathWindow];
    [_pathWindow orderOut:sender];
}
-(IBAction)goToPath:(id)sender {
    [self closePath:sender];
    [self revealPath:_pathView.stringValue];
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
                NSUInteger i = [[(IORegNode *)sender children] indexOfObject:child];
                removeWithNotice(sender, children, i)
            }
            else
                [self removeTerminated:child];
        return;
    }
    for (IORegRoot *root in _allPlanes)
        if (root.isLoaded)
            [self removeTerminated:root];
    for (IORegObj *obj in _allObjects.objectEnumerator)
        if (obj.removed)
            NSMapRemove(_allObjects, (void *)obj.entryID);
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
        obj.status = iterator == _terminate ? IORegStatusTerminated : iterator == _publish ? IORegStatusPublished : IORegStatusInitial;
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
    if (_treeView.window)
        [_treeView scrollRectToVisible:scrollPosition];
    else
        [_browseView scrollRectToVisible:scrollPosition];
}
-(NSRect)scrollPosition {
    return _treeView.window?_treeView.visibleRect:_browseView.visibleRect;
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
    [self filterTree:_findView];
    _selectedPlanes = selectedPlanes;
}
//TODO: bind selectedObjects to drawer selection
+(NSSet *)keyPathsForValuesAffectingTitle {
    return [NSSet setWithObjects:@"selectedPlane", @"selectedObjects", nil];
}
-(NSString *)title {
    return [NSString stringWithFormat:@"%@ - %@ - %@", _systemName, self.selectedPlane.plane, self.selectedItem?[[[self.selectedItem representedObject] node] currentName]:@"(no object selected)"];
}
+(NSSet *)keyPathsForValuesAffectingDrawerLabel {
    return [NSSet setWithObjects:@"selectedPlane", nil];
}
-(NSString *)drawerLabel {
    if ([[_findView stringValue] length]) return [NSString stringWithFormat:@"%ld object%s matched", self.selectedPlane.children.count, self.selectedPlane.children.count==1?"":"s"];
    else return @"No search";
}
+(NSSet *)keyPathsForValuesAffectingSelectedPlane {
    return [NSSet setWithObjects:@"selectedPlanes", nil];
}
-(IORegRoot *)selectedPlane {
    return [_allPlanes objectAtIndex:_selectedPlanes.firstIndex];
}
-(NSTreeNode *)selectedRootNode {
    return (_treeView.window)?[_treeView itemAtRow:0]:[[_browseView loadedCellAtRow:0 column:0] representedObject];
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
            [[self addObject:s] setStatus:IORegStatusTerminated];
        }
    }
}
-(bool)isUpdating {
    return (_port);
}
-(void)setOutline:(bool)outline {//TODO: add default?
    NSView *split, *swap;
    if (_browseView.window && outline) {
        split = _browseView.superview;
        swap = _outlineView;
    }
    else if (_outlineView.window && !outline) {
        split = _outlineView.superview;
        swap = _browseView;
    }
    if (!split)
        return;
    bool vertical = ![(NSSplitView *)split isVertical];
    muteWithNotice(self, outline, [split replaceSubview:split.subviews.firstObject with:swap])//FIXME: constraints
    [(NSSplitView *)split setVertical:vertical];
    [self performSelector:@selector(finishViews:) withObject:split afterDelay:0.01];
    
}
-(bool)isOutline {
    return (_treeView.window);
}
-(id)selectedItem {
    if (_treeView.window) return [_treeView itemAtRow:_treeView.selectedRow];
    else return [_browseView.selectedCell representedObject];
}

#pragma mark Traversal
-(void)revealPath:(NSString *)path {
    self.selectedPlanes = [NSIndexSet indexSetWithIndex:[_allPlanes indexOfObjectIdenticalTo:[self rootForPath:path]]];
    [self performSelector:@selector(revealItem:) withObject:[self find:[[self nodeForPath:path] node] on:self.selectedRootNode] afterDelay:0];
}
-(void)revealItem:(NSTreeNode *)item {
    if (_treeView.window) {
        NSUInteger i = [_treeView rowForItem:item];
        if (i == -1) {
            [self performSelector:_cmd withObject:item afterDelay:1];
            return;
        }
        [_treeView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:false];
        [_treeView scrollRowToVisible:i];
    }
    else {
        NSInteger i = -1, j = item.indexPath.length;
        while (i++ < j) [_browseView selectRow:[item.indexPath indexAtPosition:i] inColumn:i];
        [_browseView sendAction];
    }
}
-(IORegRoot *)rootForPath:(NSString *)path {
    for (IORegRoot *root in _allPlanes)
        if ([path hasPrefix:root.plane])
            return root;
    return nil;
}
-(IORegNode *)nodeForPath:(NSString *)path {
    IORegRoot *root;
    if (!(root = [self rootForPath:path])) return nil;
    else if ([path hasSuffix:@":"]) return root;
    else if ([path hasSuffix:@"/"]) return root.children.firstObject;
    else return [self walkPathComponent:[path.pathComponents subarrayWithRange:NSMakeRange(1, path.pathComponents.count-1)] on:root.children.firstObject];
}
-(IORegNode *)walkPathComponent:(NSArray *)components on:(IORegNode *)parent {
    for (IORegNode *child in parent.children)
        if ([child.node.currentName isEqualToString:components.firstObject]) {
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
    if (!(temp = (__bridge IORegObj *)NSMapGet(_allObjects, (void *)entry))) {
        temp = [[IORegObj alloc] initWithEntry:object for:self];
        NSMapInsertKnownAbsent(_allObjects, (void *)entry, (__bridge void *)temp);
    }
    else IOObjectRelease(object);
    return temp;
}
- (void)addDict:(NSDictionary *)object{
    IORegObj *temp = [[IORegObj alloc] initWithDictionary:object for:self];
    NSMapInsertKnownAbsent(_allObjects, (void *)temp.entryID, (__bridge void *)temp);
}

@end
