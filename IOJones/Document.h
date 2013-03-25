//
//  Document.h
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//
@class IORegRoot;

@interface Document : NSDocument <NSOutlineViewDelegate> {
    @private
    NSIndexSet *_selectedPlanes;
    NSArray *_selectedObjects;
}

@property (assign) IBOutlet NSOutlineView *treeView;
@property (assign) IBOutlet NSSearchField *findView;
@property (readonly) IORegRoot *currentPlane;
@property (readonly) NSString *title;
@property NSIndexSet *selectedPlanes;
@property NSArray *selectedObjects;
@property NSString *hostname;
@property NSDate *timestamp;
@property NSArray *allPlanes;
@property NSMutableDictionary *allClasses;
@property NSMutableDictionary *allBundles;
@property NSMapTable *allObjects;

-(IBAction)switchPlane:(id)sender;
-(IBAction)filterTree:(id)sender;
-(IBAction)find:(id)sender;

@end
