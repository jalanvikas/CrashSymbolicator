//
//  CrashSymbolicate.m
//  CrashSymbolicator
//
//  Created by Vikas Jalan on 10/23/13.
//  Copyright 2013 http://www.vikasjalan.com All rights reserved.
//  Conacts on jalanvikas@gmail.com or contact@vikasjalan.com
//

#import "CrashSymbolicate.h"


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
	if (result == NSOKButton) 
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
	else if (([[self.addressTextField stringValue] isEqualToString:@""]) || 
			 (![[self.addressTextField stringValue] hasPrefix:@"0x"]))
	{
		alertMessage = @"Please provide proper memory address.";
	}
	
	if (nil != alertMessage)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:nil
										 defaultButton:@"OK"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:alertMessage];
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
			
			NSTask *task = [NSTask new];
			[task setCurrentDirectoryPath:homeDirectory];
			[task setLaunchPath:@"/usr/bin/atos"];
			NSString *appName = [[[self.appPathTextField stringValue] lastPathComponent] stringByDeletingPathExtension];
			NSString *appNameWithExtension = [[self.appPathTextField stringValue] lastPathComponent];
			[task setArguments:[NSArray arrayWithObjects:@"-arch", @"armv7", @"-o", 
								[NSString stringWithFormat:@"%@/%@", appNameWithExtension, appName], 
								[self.addressTextField stringValue], nil]];
			
			NSPipe *pipe = [NSPipe pipe];
			[task setStandardOutput:pipe];

			[task launch];
			
			NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
			[task release];
			
			NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			if ([string isEqualToString:@""])
				[[self.symbolicateResultScrollView documentView] setString:@"cannot load symbols for the file Untitled.app"];
			else
				[[self.symbolicateResultScrollView documentView] setString:string];
			[string release];	
			
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
