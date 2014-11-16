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

@interface Document : NSDocument <NSOutlineViewDelegate>

@property (readonly) NSSearchField *findView;
@property bool drawer, hiding;
@property (readonly) IORegRoot *selectedPlane;
@property (readonly) NSString *title, *drawerLabel;
@property (nonatomic) NSRect scrollPosition;
@property (nonatomic, getter = isUpdating) bool updating;
@property (nonatomic, getter = isOutline) bool outline;
@property (nonatomic) NSIndexSet *selectedPlanes;
@property NSArray *selectedObjects, *allPlanes;
@property NSString *systemName, *hostname;
@property NSDate *timestamp;
@property NSMutableDictionarySet *allClasses, *allBundles;
@property NSMapTable *allObjects;

-(IBAction)showProperty:(id)sender;
-(IBAction)switchPlane:(id)sender;
-(IBAction)filterTree:(id)sender;
-(IBAction)find:(id)sender;
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
-(IBAction)removeTerminated:(id)sender;

-(IORegObj *)addObject:(io_registry_entry_t)object;

@end
