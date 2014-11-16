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

@property (readonly, getter = isTextual) bool textual;
@property (readonly) NSArray *macromanStrings;
-(NSString *)groupedDescription:(NSUInteger)group;

@end

@interface NSNumber (DescriptionAdditions)

@property (readonly) NSUInteger nSize;

@end

@interface NSMutableDictionarySet : NSObject

@property (readonly) NSDictionary *invertedDictionaryRepresentation;
@property (readonly) NSDictionary *dictionaryRepresentation;
-(instancetype)initWithDictionary:(NSDictionary *)dictionary;
-(id)setObject:(id)anObject forKey:(id)aKey;
-(id)objectForKey:(id)aKey;
-(id)objectForEquivalentKey:(id)aKey;
-(NSArray *)chainForKey:(id)aKey;

@end