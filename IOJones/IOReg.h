//
//  IOReg.h
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

@class Document;

@interface IOReg : NSObject

@property (readonly) NSString *bundle;
@property (readonly) NSArray *classChain;
@property (readonly) NSArray *paths;
@property (readonly) NSArray *sortedPaths;
@property (readonly) NSString *currentName;
@property (assign) Document *document;
@property NSString *ioclass;
@property NSDate *found;
@property NSString *name;
@property NSUInteger entryID;
@property NSArray *properties;
@property NSDictionary *planes;

+(IOReg *)create:(io_registry_entry_t)entry for:(Document *)document;
+(NSArray *)systemPlanes;
+(NSString *)systemName;
+(NSString *)systemType;

@end

@interface IORegNode : NSObject

@property (weak) IORegNode *parent;
@property IOReg *node;
@property NSMutableArray *children;

+(IORegNode *)create:(IOReg *)node on:(IORegNode *)parent;
-(NSSet *)flatten;

@end

@interface IORegRoot : IORegNode

@property NSString *plane;
@property NSMutableArray *pleated;
@property NSSet *flat;
+(IORegRoot *)root:(IOReg *)root on:(NSString *)plane;

@end

@interface IORegProperty : NSObject {
    @private
    id _value;
}

@property NSString *key;
@property NSArray *children;
@property NSUInteger type;
@property (readonly) NSString *typeString;
@property id value;
+(NSArray *)createWithDictionary:(NSDictionary *)dictionary;

@end

@interface NSData (DescriptionAdditions)

-(NSAttributedString *)attributedDescription;

@end