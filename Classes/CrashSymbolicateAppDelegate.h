//
//  CrashSymbolicateAppDelegate.h
//  CrashSymbolicator
//
//  Created by Vikas Jalan on 10/23/13.
//  Copyright 2013 http://www.vikasjalan.com All rights reserved.
//  Conacts on jalanvikas@gmail.com or contact@vikasjalan.com
//

#import <Cocoa/Cocoa.h>
#import "CrashSymbolicate.h"

@interface CrashSymbolicateAppDelegate : NSObject <NSApplicationDelegate> 

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet CrashSymbolicate *crashSymbolicator;

@end
