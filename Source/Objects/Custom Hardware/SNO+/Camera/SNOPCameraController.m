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
}


-( void ) registerNotificationObservers
{
    [super registerNotificationObservers];
}


-(IBAction)onTakePicAction:(id)sender
{
    [model powerCamera];
    
    [runStateField setStringValue:@"Powering Camera."];

    sleep( 30 );
    
    [model killPTPCameraProcess];

    [runStateField setStringValue:@"Killing PTPCamera Process."];

    [model runCaptureScript];

    [runStateField setStringValue:@"Taking a picture."];
 }
@end