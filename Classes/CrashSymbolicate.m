//
//  CrashSymbolicate.m
//  CrashSymbolicator
//
//  Created by Vikas Jalan on 10/23/13.
//  Copyright 2013 http://www.vikasjalan.com All rights reserved.
//  Conacts on jalanvikas@gmail.com or contact@vikasjalan.com
//

#import "CrashSymbolicate.h"


#define THREAD_SEARCH_FORMAT    @"Thread %d"
#define THREAD_KEY              @"Thread"


@interface CrashSymbolicate ()

#pragma mark - Private Methods

- (NSString *)getSymbolicatedStringForAddress:(NSString *)address homeDirectory:(NSString *)homeDirectory error:(NSError **)error;

- (NSMutableDictionary *)getAllPossibleAddressForSymbolicationFromCrashInfo:(NSString *)crashInfo;

@end


@implementation CrashSymbolicate

- (void)dealloc
{
    self.appPathTextField = nil;
    self.dsymTextField = nil;
    self.crashPathTextField = nil;
    self.addressTextField = nil;
    self.symbolicateResultScrollView = nil;
    [super dealloc];
}

#pragma mark - Private Methods

- (NSString *)getSymbolicatedStringForAddress:(NSString *)address homeDirectory:(NSString *)homeDirectory error:(NSError **)error
{
    NSString *symbolicatedString = address;
    
    NSTask *task = [NSTask new];
    [task setCurrentDirectoryPath:homeDirectory];
    [task setLaunchPath:@"/usr/bin/atos"];
    NSString *appName = [[[self.appPathTextField stringValue] lastPathComponent] stringByDeletingPathExtension];
    NSString *appNameWithExtension = [[self.appPathTextField stringValue] lastPathComponent];
    [task setArguments:[NSArray arrayWithObjects:@"-arch", ((10 < [address length])?@"arm64":@"armv7"), @"-o",
                        [NSString stringWithFormat:@"%@/%@", appNameWithExtension, appName],
                        address, nil]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    [task launch];
    
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task release];
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ((nil != string) && (0 < [string length]))
    {
        symbolicatedString = [string stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    }
    else
    {
        NSError *symbolicateError = [[NSError alloc] initWithDomain:@"Cannot load symbols for provided Application."
                                                               code:404 userInfo:nil];
        *error = symbolicateError;
    }
    
    return symbolicatedString;
}

- (NSMutableDictionary *)getAllPossibleAddressForSymbolicationFromCrashInfo:(NSString *)crashInfo
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionary];
    BOOL search = YES;
    int threadIndex = 0;
    
    NSString *currentThread = nil;
    NSRange currentThreadRange;
    NSString *nextThread = nil;
    NSRange nextThreadRange;
    NSInteger totalKeyValues = 0;
    
    while (search)
    {
        currentThread = [NSString stringWithFormat:THREAD_SEARCH_FORMAT, threadIndex];
        currentThreadRange = [crashInfo rangeOfString:currentThread options:NSCaseInsensitiveSearch];
        
        nextThread = [NSString stringWithFormat:THREAD_SEARCH_FORMAT, (threadIndex + 1)];
        nextThreadRange = [crashInfo rangeOfString:nextThread options:NSCaseInsensitiveSearch];
        if (NSNotFound == nextThreadRange.location)
        {
            nextThreadRange = [crashInfo rangeOfString:THREAD_KEY options:NSBackwardsSearch];
        }
        
        if ((NSNotFound != currentThreadRange.location) && (NSNotFound != nextThreadRange.location))
        {
            BOOL blankLineProcessed = NO;
            NSInteger currentThreadStartIndex = currentThreadRange.location + currentThreadRange.length;
            NSString *currentThreadStrings = [crashInfo substringWithRange:NSMakeRange(currentThreadStartIndex, (nextThreadRange.location - currentThreadStartIndex))];
            NSArray *linesArray = [currentThreadStrings componentsSeparatedByString:@"\n"];
            for (NSString *line in linesArray)
            {
                if (0 == [line length])
                {
                    if (!blankLineProcessed)
                        blankLineProcessed = YES;
                    else
                        break;
                }
                
                if ([line hasPrefix:THREAD_KEY])
                    continue;
                
                NSRange addressRange = [line rangeOfString:@"0x" options:NSCaseInsensitiveSearch];
                if (NSNotFound != addressRange.location)
                {
                    NSString *addressString = [line substringFromIndex:addressRange.location];
                    NSRange blankSpaceRange = [addressString rangeOfString:@" "];
                    if (NSNotFound != blankSpaceRange.location)
                    {
                        NSString *key = [addressString substringToIndex:blankSpaceRange.location];
                        NSString *value = [addressString substringFromIndex:(blankSpaceRange.location + 1)];
                        if ((0 < [key length]) && (0 < [value length]))
                        {
                            [addresses setObject:value forKey:key];
                            totalKeyValues++;
                        }
                    }
                }
            }
        }
        
        threadIndex++;
        currentThread = [NSString stringWithFormat:THREAD_SEARCH_FORMAT, threadIndex];
        currentThreadRange = [crashInfo rangeOfString:currentThread options:NSCaseInsensitiveSearch];
        if (NSNotFound == currentThreadRange.location)
        {
            search = NO;
        }
    }
    
    return addresses;
}

#pragma mark -
#pragma mark Custom Methods

- (void)showOpenPanelForType:(OpenPanelType)inPanelType
{
    int result;
    NSArray *fileTypes = nil;
    
    if (eAppPathPanel == inPanelType)
    {
        fileTypes = [NSArray arrayWithObject:@"app"];
    }
    else if (eDsymPathPanel == inPanelType)
    {
        fileTypes = [NSArray arrayWithObject:@"dSYM"];
    }
    else if (eCrashPathPanel == inPanelType)
    {
        fileTypes = [NSArray arrayWithObject:@"crash"];
    }
    
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    
    NSString *folderPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"lastSelectedFolderPath"];
    if (nil != folderPath)
    {
        if (![[NSFileManager defaultManager] fileExistsAtPath:folderPath])
        {
            folderPath = nil;
        }
    }
    
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setDirectoryURL:[NSURL URLWithString:((nil != folderPath)?folderPath:NSHomeDirectory())]];
    [oPanel setAllowedFileTypes:fileTypes];
    result = [oPanel runModal];
    
    NSURL *filePath = nil;
    if (result == NSModalResponseOK)
    {
        NSArray *filesToOpen = [oPanel URLs];
        if (0 < [filesToOpen count])
        {
            filePath = [filesToOpen objectAtIndex:0];
            folderPath = [[filePath relativePath] stringByDeletingLastPathComponent];
            [[NSUserDefaults standardUserDefaults] setObject:folderPath forKey:@"lastSelectedFolderPath"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    
    if (nil != filePath)
    {
        if (eAppPathPanel == inPanelType)
        {
            [self.appPathTextField setStringValue:[filePath relativePath]];
        }
        else if (eDsymPathPanel == inPanelType)
        {
            [self.dsymTextField setStringValue:[filePath relativePath]];
        }
        else if (eCrashPathPanel == inPanelType)
        {
            [self.crashPathTextField setStringValue:[filePath relativePath]];
        }
    }
}

#pragma mark -
#pragma mark Action Methods

- (IBAction)trackItButtonClicked:(id)inSender
{
    //	atos -arch armv7 -o 'Test.app'/'Test' 0x00031f6e
    NSString *alertMessage = nil;
    if (([[self.appPathTextField stringValue] isEqualToString:@""]) ||
        (![[[self.appPathTextField stringValue] pathExtension] isEqualToString:@"app"]))
    {
        alertMessage = @"Please provide proper application path.";
    }
    else if (([[self.dsymTextField stringValue] isEqualToString:@""]) ||
             (![[[self.dsymTextField stringValue] pathExtension] isEqualToString:@"dSYM"]))
    {
        alertMessage = @"Please provide proper dSYM path.";
    }
    else if (([[self.crashPathTextField stringValue] isEqualToString:@""]) ||
             (![[[self.crashPathTextField stringValue] pathExtension] isEqualToString:@"crash"]))
    {
        alertMessage = @"Please provide proper crash path.";
    }
    else if (([[self.addressTextField stringValue] isEqualToString:@""]) ||
             (![[self.addressTextField stringValue] hasPrefix:@"0x"]))
    {
        alertMessage = @"Please provide proper memory address.";
    }
    
    if (nil != alertMessage)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:alertMessage];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
    else
    {
        NSError *error = nil;
        NSString *homeDirectory = NSHomeDirectory();
        NSInteger count = 0;
        NSString *folderName = @"crash";
        BOOL notFound = [[NSFileManager defaultManager] fileExistsAtPath:[homeDirectory stringByAppendingPathComponent:folderName]];
        while (notFound)
        {
            count++;
            folderName = [NSString stringWithFormat:@"/crash%d", (int)count];
            notFound = [[NSFileManager defaultManager] fileExistsAtPath:
                        [homeDirectory stringByAppendingPathComponent:folderName]];
        }
        
        homeDirectory = [homeDirectory stringByAppendingPathComponent:folderName];
        BOOL directoryCreated = [[NSFileManager defaultManager] createDirectoryAtPath:homeDirectory
                                                          withIntermediateDirectories:YES attributes:nil error:&error];
        if (directoryCreated)
        {
            NSString *appPath = [homeDirectory stringByAppendingPathComponent:[[self.appPathTextField stringValue] lastPathComponent]];
            NSString *dsymPath = [homeDirectory stringByAppendingPathComponent:[[self.dsymTextField stringValue] lastPathComponent]];
            NSString *crashPath = [homeDirectory stringByAppendingPathComponent:[[self.crashPathTextField stringValue] lastPathComponent]];
            [[NSFileManager defaultManager] copyItemAtPath:[self.appPathTextField stringValue] toPath:appPath error:&error];
            [[NSFileManager defaultManager] copyItemAtPath:[self.dsymTextField stringValue] toPath:dsymPath error:&error];
            [[NSFileManager defaultManager] copyItemAtPath:[self.crashPathTextField stringValue] toPath:crashPath error:&error];
            
            NSError *error = nil;
            NSString *symbolicatedString = [self getSymbolicatedStringForAddress:[self.addressTextField stringValue]
                                                                   homeDirectory:homeDirectory error:&error];
            if (nil != error)
            {
                [[self.symbolicateResultScrollView documentView] setString:[error domain]];
            }
            else
            {
                [[self.symbolicateResultScrollView documentView] setString:symbolicatedString];
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:homeDirectory error:&error];
        }
    }
}

- (IBAction)symbolicateButtonClicked:(id)inSender
{
    //	atos -arch armv7 -o 'Test.app'/'Test' 0x00031f6e
    NSString *alertMessage = nil;
    if (([[self.appPathTextField stringValue] isEqualToString:@""]) ||
        (![[[self.appPathTextField stringValue] pathExtension] isEqualToString:@"app"]))
    {
        alertMessage = @"Please provide proper application path.";
    }
    else if (([[self.dsymTextField stringValue] isEqualToString:@""]) ||
             (![[[self.dsymTextField stringValue] pathExtension] isEqualToString:@"dSYM"]))
    {
        alertMessage = @"Please provide proper dSYM path.";
    }
    else if (([[self.crashPathTextField stringValue] isEqualToString:@""]) ||
             (![[[self.crashPathTextField stringValue] pathExtension] isEqualToString:@"crash"]))
    {
        alertMessage = @"Please provide proper crash path.";
    }
    
    if (nil != alertMessage)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:alertMessage];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
    else
    {
        NSError *error = nil;
        NSString *homeDirectory = NSHomeDirectory();
        NSInteger count = 0;
        NSString *folderName = @"crash";
        BOOL notFound = [[NSFileManager defaultManager] fileExistsAtPath:[homeDirectory stringByAppendingPathComponent:folderName]];
        while (notFound)
        {
            count++;
            folderName = [NSString stringWithFormat:@"/crash%d", (int)count];
            notFound = [[NSFileManager defaultManager] fileExistsAtPath:
                        [homeDirectory stringByAppendingPathComponent:folderName]];
        }
        
        homeDirectory = [homeDirectory stringByAppendingPathComponent:folderName];
        BOOL directoryCreated = [[NSFileManager defaultManager] createDirectoryAtPath:homeDirectory
                                                          withIntermediateDirectories:YES attributes:nil error:&error];
        if (directoryCreated)
        {
            NSString *appPath = [homeDirectory stringByAppendingPathComponent:[[self.appPathTextField stringValue] lastPathComponent]];
            NSString *dsymPath = [homeDirectory stringByAppendingPathComponent:[[self.dsymTextField stringValue] lastPathComponent]];
            NSString *crashPath = [homeDirectory stringByAppendingPathComponent:[[self.crashPathTextField stringValue] lastPathComponent]];
            [[NSFileManager defaultManager] copyItemAtPath:[self.appPathTextField stringValue] toPath:appPath error:&error];
            [[NSFileManager defaultManager] copyItemAtPath:[self.dsymTextField stringValue] toPath:dsymPath error:&error];
            [[NSFileManager defaultManager] copyItemAtPath:[self.crashPathTextField stringValue] toPath:crashPath error:&error];
            
            NSData *crashInfoData = [NSData dataWithContentsOfFile:crashPath];
            NSString *crashInfo = [[NSString alloc] initWithData:crashInfoData encoding:NSUTF8StringEncoding];
            if (nil != crashInfo)
            {
                NSError *error = nil;
                NSMutableDictionary *allPossibleAddress = [self getAllPossibleAddressForSymbolicationFromCrashInfo:crashInfo];
                NSArray *addresses = [allPossibleAddress allKeys];
                for (NSString *address in addresses)
                {
                    NSString *symbolicatedString = [self getSymbolicatedStringForAddress:address homeDirectory:homeDirectory error:&error];
                    if (nil != error)
                    {
                        break;
                    }
                    else if (![address isEqualToString:symbolicatedString])
                    {
                        crashInfo = [crashInfo stringByReplacingOccurrencesOfString:[allPossibleAddress objectForKey:address] withString:symbolicatedString];
                    }
                }
                
                if (nil != error)
                {
                    [[self.symbolicateResultScrollView documentView] setString:[error domain]];
                }
                else
                {
                    [[self.symbolicateResultScrollView documentView] setString:crashInfo];
                }
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:homeDirectory error:&error];
        }
    }
}

- (IBAction)openFileButtonClicked:(id)inSender
{
    if (eAppPathPanel == [inSender tag])
    {
        [self.appPathTextField becomeFirstResponder];
        [self showOpenPanelForType:eAppPathPanel];
    }
    else if (eDsymPathPanel == [inSender tag])
    {
        [self.dsymTextField becomeFirstResponder];
        [self showOpenPanelForType:eDsymPathPanel];
    }
    else if (eCrashPathPanel == [inSender tag])
    {
        [self.crashPathTextField becomeFirstResponder];
        [self showOpenPanelForType:eCrashPathPanel];
    }
}

@end
