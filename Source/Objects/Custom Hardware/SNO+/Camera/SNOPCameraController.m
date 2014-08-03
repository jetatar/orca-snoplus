//
//  CameraController.m
//  Orca
//
//  Created by Joulien on 5/4/14.
//
//

#import "SNOPCameraController.h"
#import "SNOPCameraModel.h"


@implementation SNOPCameraController

-( id ) init
{
    self = [super initWithWindowNibName:@"SNOPCamera"];
    
    return self;
}


-( void ) dealloc
{
    [super dealloc];
}


-( void ) updateWindow
{
    [super updateWindow];

    [self cameraCaptureTaskChanged:nil];
}


-( void ) registerNotificationObservers
{
    NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    [super registerNotificationObservers];

	[notifyCenter addObserver : self
                     selector : @selector(cameraCaptureTaskChanged:)
                         name : @"cameraCaptureNotification"
                       object : nil];
}


-( void ) cameraCaptureTaskChanged:(NSNotification*) aNote
{
    BOOL captureRunning = [model cameraCaptureTaskRunning];

    NSLog( @"Task Changed.\n" );
    
    [takePicButton setTitle:captureRunning?@"Stop":@"Start"];
}


-(IBAction)onTakePicAction:(id)sender
{
    [model powerCamera];
    
    [runStateField setStringValue:@"Powering Camera."];

    [model killPTPCameraProcess];

    [runStateField setStringValue:@"Killing PTPCamera Process."];

    [model runCaptureScript];

    [runStateField setStringValue:@"Taking a picture."];
 }
@end