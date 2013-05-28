//
//  IOReg.h
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

@class Document;

@interface IOReg : NSObject
enum iostatus {
    initial,
    published,
    terminated
};

@property (readonly) NSString *bundle;
@property (readonly) NSArray *classChain;
@property (readonly) NSArray *paths;
@property (readonly) NSArray *sortedPaths;
@property (readonly) NSString *currentName;
@property (readonly) id displayName;
@property (readonly) NSDictionary *dictionaryRepresentation;
@property (readonly) bool isActive;
@property (readonly) bool isMatched;
@property (readonly) bool isRegistered;
@property (readonly) bool isService;
@property (readonly) NSString *filteredProperty;
@property (assign) Document *document;
@property enum iostatus status;
@property NSString *ioclass;
@property NSDate *added;
@property NSDate *removed;
@property NSString *name;
@property NSUInteger entryID;
@property NSUInteger kernel;
@property NSUInteger user;
@property NSUInteger busy;
@property NSUInteger state;
@property NSArray *properties;
@property NSDictionary *planes;

+(IORegObj *)create:(io_registry_entry_t)entry for:(Document *)document;
+(IORegObj *)createWithDictionary:(NSDictionary *)dictionary for:(Document *)document;
+(NSArray *)systemPlanes;
+(NSString *)systemName;
+(NSString *)systemType;

@end

@interface IORegNode : NSObject

@property (weak) IORegNode *parent;
@property IORegObj *node;
@property NSMutableArray *children;
@property NSString *plane;
@property (readonly) NSString *metaData;
@property (readonly) NSMutableSet *flat;
@property (readonly) NSDictionary *dictionaryRepresentation;

+(IORegNode *)create:(IORegObj *)node on:(IORegNode *)parent;
+(IORegNode *)createWithDictionary:(NSDictionary *)dictionary on:(IORegNode *)parent;
-(void)mutate;

@end

@interface IORegRoot : IORegNode {
    @private
    NSMutableArray *_pleated;
}
@property (readonly) bool isLoaded;
+(IORegRoot *)root:(IORegObj *)root on:(NSString *)plane;
+(IORegRoot *)createWithDictionary:(NSDictionary *)dictionary on:(NSMapTable *)table;
-(void)filter:(NSString *)filter;

@end

@interface IORegProperty : NSObject {
    @private
    id _value;
    NSInteger _type;
    NSInteger _subtype;
}

@property NSString *key;
@property NSArray *children;
@property (readonly) NSInteger type;
@property (readonly) NSInteger subtype;
@property (readonly) NSString *typeString;
@property (readonly) id description;
@property (readonly) NSString *briefDescription;
@property (readonly) NSString *metaData;
@property (readonly) NSDictionary *dictionaryRepresentation;

+(NSArray *)createWithDictionary:(NSDictionary *)dictionary;

@end
