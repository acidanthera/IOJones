//
//  main.m
//  IOJones
//
//  Created by PHPdev32 on 3/13/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import <Cocoa/Cocoa.h>

void handle_exception(NSException *exception) {
    @try {
    NSString *file = [NSString stringWithFormat:@"/tmp/%ld.plist", roundtol([[NSDate date] timeIntervalSince1970])];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (exception.name) [d setObject:exception.name forKey:@"name"];
    if (exception.reason) [d setObject:exception.reason forKey:@"reason"];
    if (exception.userInfo) [d setObject:exception.userInfo forKey:@"userInfo"];
    if (exception.callStackReturnAddresses) [d setObject:exception.callStackReturnAddresses forKey:@"callStackReturnAddresses"];
    if (exception.callStackSymbols) [d setObject:exception.callStackSymbols forKey:@"callStackSymbols"];
    [d writeToFile:file atomically:true];
    NSRunAlertPanel(@"Uncaught Exception", @"An uncaught exception has occurred, and the program will now terminate. Please post the revealed file (may contain personal information), to %@", nil, nil, nil, @"http://sourceforge.net/projects/iojones/support");
    [NSWorkspace.sharedWorkspace selectFile:file inFileViewerRootedAtPath:file];
    } @catch (NSException *e) {}
}

int main(int argc, char *argv[])
{
    NSSetUncaughtExceptionHandler(&handle_exception);
    return NSApplicationMain(argc, (const char **)argv);
}
