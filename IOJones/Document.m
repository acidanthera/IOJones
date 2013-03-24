//
//  Document.m
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Document.h"
#import "IOReg.h"

@implementation Document
@synthesize treeView;
@synthesize findView;
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
        allClasses = [NSMutableDictionary dictionary];
        allBundles = [NSMutableDictionary dictionary];//FIXME: deduplicate this too
        if (!self.fileURL) [self system];
    }
    return self;
}

-(void)dealloc {
    allObjects = nil;
    allPlanes = nil;
    allBundles = allClasses = nil;
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
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    muteWithNotice(self, selectedPlanes, [self setSelectedPlanes:[NSIndexSet indexSetWithIndex:[allPlanes.allKeys indexOfObject:@"IOService"]]])
    delayWithNotice(self, title, 0)
    //FIXME: search
    //FIXME: updates
    //FIXME: archive/unarchive
}

+ (BOOL)autosavesInPlace
{
    return false;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return YES;
}

#pragma mark NSOutlineViewDelegate
-(CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item{
    NSUInteger row = [outlineView rowForItem:item], rows = outlineView.tableColumns.count;
    CGFloat height = outlineView.rowHeight;
    while (rows-- > 0)
        height = MAX([[outlineView preparedCellAtColumn:rows row:row] cellSizeForBounds:NSMakeRect(0, 0, [[outlineView.tableColumns objectAtIndex:rows] width], CGFLOAT_MAX)].height,height);
    return height;
}
-(void)outlineViewColumnDidResize:(NSNotification *)notification {
    [notification.object noteNumberOfRowsChanged];
}

#pragma mark GUI
-(IBAction)switchPlane:(id)sender{
    id item = [[[treeView itemAtRow:treeView.selectedRow] representedObject] node];
    NSString *path = [sender titleOfSelectedItem];
    NSUInteger i = 0;
    for (NSString *plane in [allPlanes.allKeys sortedArrayUsingSelector:@selector(compare:)])//FIXME: not the right order here!
        if (++i && [path hasPrefix:plane]) {
            muteWithNotice(self, selectedPlanes, [self setSelectedPlanes:[NSIndexSet indexSetWithIndex:i-1]])
            break;
        }
    [self performSelector:@selector(findNode:) withObject:item afterDelay:0];
}
-(IBAction)expandTree:(id)sender {
    [treeView expandItem:nil expandChildren:true];
    [treeView setNeedsDisplay];
}
-(IBAction)find:(id)sender {
    [findView.window makeFirstResponder:findView];
}
-(IBAction)filterTree:(id)sender {
    IORegRoot *root = [allPlanes objectForKey:self.currentPlane];
    if (![[sender stringValue] length]) {
        root.children = root.pleated;
        [self performSelector:@selector(expandTree:) withObject:nil afterDelay:0];
    }
    else {
        root.children = [[root.flatten filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"node.name BEGINSWITH[c] %@", [sender stringValue], [sender stringValue]]] mutableCopy];
        [treeView performSelector:@selector(expandItem:) withObject:[treeView itemAtRow:0] afterDelay:0];
    }
    muteWithNotice(root, children,)
}

#pragma mark Nonatomic Properties
-(void)setSelectedPlanes:(NSIndexSet *)selectedPlanes{
    [findView setStringValue:@""];
    [self filterTree:findView];
    _selectedPlanes = selectedPlanes;
    muteWithNotice(self, title,)
}
-(NSIndexSet *)selectedPlanes{
    return _selectedPlanes;
}
-(void)setSelectedObjects:(NSArray *)selectedObjects{
    _selectedObjects = selectedObjects;
    muteWithNotice(self, title,)
}
-(NSArray *)selectedObjects{
    return _selectedObjects;
}
-(NSString *)title {
    return [NSString stringWithFormat:@"%@ - %@ - %@", [IOReg systemName], self.currentPlane, [[[[treeView itemAtRow:treeView.selectedRow] representedObject] node] currentName]];
}
-(NSString *)currentPlane {
    return [allPlanes.allKeys objectAtIndex:_selectedPlanes.firstIndex];
}

#pragma mark Functions
- (void)system {
    timestamp = [NSDate date];
    NSString *nsroot = @"OSObject";
    [allClasses setObject:nsroot forKey:nsroot];
    [allBundles setObject:@"com.apple.kernel" forKey:nsroot];
    hostname = [NSString stringWithFormat:@"%@ (%@)", [IOReg systemName], [IOReg systemType]];
    IOReg *root = [IOReg create:IORegistryGetRootEntry(kIOMasterPortDefault) for:self];
    NSArray *planes = [IOReg systemPlanes];
    NSMutableArray *temp = [NSMutableArray array];
    for (NSString *plane in planes) {
        [temp addObject:[IORegRoot root:root on:plane]];
        io_iterator_t it;
        IORegistryCreateIterator(kIOMasterPortDefault, plane.UTF8String, 0, &it);
        [self walk:it for:temp.lastObject];
        IOObjectRelease(it);
    }
    allPlanes = [NSDictionary dictionaryWithObjects:temp forKeys:planes];
}
- (void)walk:(io_iterator_t)iterator for:(IORegNode *)parent {
    io_object_t obj;
    while ((obj = IOIteratorNext(iterator))) {
        IORegNode *current = [IORegNode create:[self add:obj] on:parent];
        if (IORegistryIteratorEnterEntry(iterator) == KERN_SUCCESS) [self walk:iterator for:current];
    }
    IORegistryIteratorExitEntry(iterator);
}
- (IOReg *)add:(io_object_t)object{
    UInt64 entry;
    IOReg *temp;
    IORegistryEntryGetRegistryEntryID(object, &entry);
    if (!(temp = (__bridge IOReg *)NSMapGet(allObjects, (void *)entry))) {
        temp = [IOReg create:object for:self];
        NSMapInsertKnownAbsent(allObjects, (void *)entry, (__bridge void *)temp);
    }
    return temp;
}
-(void)findNode:(IOReg *)node {//FIXME: does not traverse, requires full expansion
    NSUInteger i = 0;
    while (i < treeView.numberOfRows) if ([[[treeView itemAtRow:i++] representedObject] node] == node) break;
    [treeView selectRowIndexes:[NSIndexSet indexSetWithIndex:i-1] byExtendingSelection:false];
    [treeView scrollRowToVisible:i-1];
}

@end
