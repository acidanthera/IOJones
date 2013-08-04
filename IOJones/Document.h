//
//  Document.h
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//
@class IORegRoot;
@class IORegObj;
@class NSMutableDictionarySet;

@interface Document : NSDocument <NSOutlineViewDelegate> {
    @private
    bool _drawer;
    bool _hiding;
    NSIndexSet *_selectedPlanes;
    NSArray *_selectedObjects;
    IONotificationPortRef _port;
    io_iterator_t _publish;
    io_iterator_t _terminate;
    io_object_t _notice;
}

@property (strong) IBOutlet NSScrollView *outlineView;
@property (strong) IBOutlet NSBrowser *browseView;
@property (assign) IBOutlet NSOutlineView *treeView;
@property (assign) IBOutlet NSSearchField *findView;
@property (assign) IBOutlet NSTableView *propertyView;
@property (assign) IBOutlet NSWindow *pathWindow;
@property (assign) IBOutlet NSTextField *pathView;
@property bool drawer;
@property bool hiding;
@property (readonly) IORegRoot *selectedPlane;
@property (readonly) NSString *title;
@property (readonly) NSString *drawerLabel;
@property (nonatomic) NSRect scrollPosition;
@property (nonatomic, getter = isUpdating) bool updating;
@property (nonatomic, getter = isOutline) bool outline;
@property NSIndexSet *selectedPlanes;
@property NSArray *selectedObjects;
@property NSString *systemName;
@property NSString *hostname;
@property NSDate *timestamp;
@property NSArray *allPlanes;
@property NSMutableDictionarySet *allClasses;
@property NSMutableDictionarySet *allBundles;
@property NSMapTable *allObjects;

-(IBAction)showProperty:(id)sender;
-(IBAction)switchPlane:(id)sender;
-(IBAction)filterTree:(id)sender;
-(IBAction)find:(id)sender;
-(IBAction)toggleUpdates:(id)sender;
-(IBAction)parent:(id)sender;
-(IBAction)firstChild:(id)sender;
-(IBAction)nextSibling:(id)sender;
-(IBAction)previousSibling:(id)sender;
-(IBAction)expandAll:(id)sender;
-(IBAction)collapseAll:(id)sender;
-(IBAction)collapseSelection:(id)sender;
-(IBAction)nextPath:(id)sender;
-(IBAction)previousPath:(id)sender;
-(IBAction)nextPathAny:(id)sender;
-(IBAction)previousPathAny:(id)sender;
-(IBAction)showPath:(id)sender;
-(IBAction)goToPath:(id)sender;
-(IBAction)revealKext:(id)sender;
-(IBAction)swapViews:(id)sender;
-(IBAction)removeTerminated:(id)sender;

-(IORegObj *)addObject:(io_registry_entry_t)object;

@end
