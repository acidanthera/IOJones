//
//  Base.h
//  IOJones
//
//  Created by PHPdev32 on 3/24/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

@interface NSSplitView (RestorationAdditions)

-(void)restore;

@end

@interface NSArray (DescriptionAdditions)

+(NSArray *)range:(NSRange)range;
-(bool)containsRange:(NSString *)string;

@end

@interface NSData (DescriptionAdditions)

-(bool)isTextual;
-(NSString *)groupedDescription:(NSUInteger)group;
-(NSArray *)macromanStrings;

@end

@interface NSNumber (DescriptionAdditions)

-(NSUInteger)nSize;

@end

@interface NSMutableDictionarySet : NSObject {
    @private
    NSMutableDictionary *_dict;
    NSMutableSet *_set;
}

@property (readonly) NSDictionary *invertedDictionaryRepresentation;
@property (readonly) NSDictionary *dictionaryRepresentation;
+(NSMutableDictionarySet *)createWithDictionary:(NSDictionary *)dictionary;
-(id)setObject:(id)anObject forKey:(id<NSCopying>)aKey;
-(id)objectForKey:(id)aKey;

@end