//
//  IOReg.h
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

@class Document;

typedef NS_ENUM(NSUInteger, IORegStatus) {
    IORegStatusInitial,
    IORegStatusPublished,
    IORegStatusTerminated
};

@interface IORegObj : NSObject

@property (readonly) NSString *bundle, *currentName, *filteredProperty;
@property (readonly) NSArray *classChain, *paths, *sortedPaths;
@property (readonly) id displayName;
@property (readonly) NSDictionary *dictionaryRepresentation;
@property (readonly) bool isActive, isMatched, isRegistered, isService;
@property (readonly) NSSet *registeredNodes;
@property (assign) Document *document;
@property IORegStatus status;
@property NSString *ioclass, *name;
@property NSDate *added, *removed;
@property NSUInteger entryID, kernel, user, busy, state;
@property (readonly) NSArray *properties;
@property NSDictionary *planes;

-(instancetype)initWithEntry:(io_registry_entry_t)entry for:(Document *)document;
-(instancetype)initWithDictionary:(NSDictionary *)dictionary for:(Document *)document;
+(NSArray *)systemPlanes;
+(NSString *)systemName;
+(NSString *)systemType;

-(void)addProperties:(NSSet *)objects;

@end

@interface IORegNode : NSObject

@property (assign) IORegNode *parent;
@property IORegObj *node;
@property (nonatomic) NSMutableArray *children;
@property NSString *plane;
@property (readonly) NSIndexPath *indexPath;
@property (readonly) NSString *metaData;
@property (readonly) NSMutableSet *flat;
@property (readonly) NSDictionary *dictionaryRepresentation;

-(instancetype)initWithNode:(IORegObj *)node on:(IORegNode *)parent;
-(instancetype)initWithDictionary:(NSDictionary *)dictionary on:(IORegNode *)parent;
-(void)mutate;

@end

@interface IORegRoot : IORegNode

@property (readonly) bool isLoaded;
-(instancetype)initWithNode:(IORegObj *)root on:(NSString *)plane;
-(instancetype)initWithDictionary:(NSDictionary *)dictionary on:(NSMapTable *)table;
-(void)filter:(NSString *)filter;

@end

@interface IORegProperty : NSObject

@property NSString *key;
@property NSArray *children;
@property (readonly) NSInteger type, subtype;
@property (readonly) NSString *typeString, *description, *metaData, *briefDescription;
@property (readonly) NSColor *descriptionColor;
@property (readonly) NSFont *descriptionFont;
@property (readonly) NSDictionary *dictionaryRepresentation;

+(NSArray *)arrayWithDictionary:(NSDictionary *)dictionary;

@end
