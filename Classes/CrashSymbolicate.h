//
//  CrashSymbolicate.h
//  CrashSymbolicator
//
//  Created by Vikas Jalan on 10/23/13.
//  Copyright 2013 http://www.vikasjalan.com All rights reserved.
//  Conacts on jalanvikas@gmail.com or contact@vikasjalan.com
//

#import <Foundation/Foundation.h>

typedef enum
{
	eAppPathPanel = 11,
	eDsymPathPanel = 12,
	eCrashPathPanel = 13,
}OpenPanelType;

@interface CrashSymbolicate : NSObject 

@property (nonatomic, retain) IBOutlet NSTextField *appPathTextField;
@property (nonatomic, retain) IBOutlet NSTextField *dsymTextField;
@property (nonatomic, retain) IBOutlet NSTextField *crashPathTextField;
@property (nonatomic, retain) IBOutlet NSTextField *addressTextField;
@property (nonatomic, retain) IBOutlet NSScrollView *symbolicateResultScrollView;

#pragma mark - Custom Methods

- (void)showOpenPanelForType:(OpenPanelType)inPanelType;

#pragma mark - Action Methods

- (IBAction)trackItButtonClicked:(id)inSender;
- (IBAction)symbolicateButtonClicked:(id)inSender;
- (IBAction)openFileButtonClicked:(id)inSender;

@end
