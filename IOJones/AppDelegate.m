//
//  AppDelegate.m
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "AppDelegate.h"
#import "IOReg.h"
#import "Document.h"

@implementation AppDelegate

-(void)awakeFromNib {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"find":@{@"showAll":@(NO), @"name":@(YES), @"bundle":@(NO), @"inheritance":@(NO), @"class":@(NO), @"keys":@(NO), @"values":@(NO), @"state":@(NO), @"property":@""}}];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:@"find" options:0 context:0];
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    for (Document *document in [NSDocumentController.sharedDocumentController documents])
        [document filterTree:document.findView];
}

-(IBAction)copy:(id)sender{
    NSResponder *obj = [[NSApp keyWindow] firstResponder];
    if ([obj isKindOfClass:NSTableView.class]) {
        if (![(NSTableView *)obj numberOfSelectedRows]) return;
        bool viewBased = ([(NSTableView *)obj rowViewAtRow:[(NSTableView *)obj selectedRow] makeIfNecessary:false]);
        __block NSMutableArray *rows = [NSMutableArray array];
        [[(NSTableView *)obj selectedRowIndexes] enumerateIndexesUsingBlock:^void(NSUInteger idx, BOOL *stop){
            NSUInteger i = 0, j = [(NSTableView *)obj numberOfColumns];
            NSMutableArray *row = [NSMutableArray array];
            if (viewBased) {
                NSText *view;
                while (i < j)
                    if ((view = [(NSTableView *)obj viewAtColumn:i++ row:idx makeIfNecessary:false]) && [view isKindOfClass:NSText.class])
                        [row addObject:[view.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
            }
            else {
                NSCell *cell;
                while (i < j)
                    if ((cell = [(NSTableView *)obj preparedCellAtColumn:i++ row:idx]) && [cell isKindOfClass:NSTextFieldCell.class])
                        [row addObject:[cell.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
            }
            [row removeObject:@""];
            [rows addObject:[row componentsJoinedByString:@", "]];
        }];
        [NSPasteboard.generalPasteboard clearContents];
        [NSPasteboard.generalPasteboard writeObjects:@[[rows componentsJoinedByString:@"\n"]]];
    }
}

@end

@implementation ArrayTransformer

+(Class)transformedValueClass{
    return [NSString class];
}
+(BOOL)allowsReverseTransformation{
    return false;
}
-(id)transformedValue:(id)value{
    if (!value) return nil;
    else return [value componentsJoinedByString:@" : "];
}

@end

@implementation ShouldEnable

+(Class)transformedValueClass{
    return [NSNumber class];
}
+(BOOL)allowsReverseTransformation{
    return false;
}
-(id)transformedValue:(id)value{
    if (!value) return nil;
    else return [NSNumber numberWithBool:([value count] > 1)];
}

@end
