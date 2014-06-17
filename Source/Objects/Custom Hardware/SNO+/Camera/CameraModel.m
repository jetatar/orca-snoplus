//
//  CameraModel.m
//  Orca
//
//  Created by Joulien on 5/7/14.
//
//

#import "CameraModel.h"
#import "SBC_Link.h"
#import "SNOCmds.h"


@implementation ORCamModel


- (void) setUpImage
{
    [self setImage:[NSImage imageNamed:@"CameraPic"]];
}


- (void) makeMainController
{
    [self linkToController:@"CameraController"];
}


- (void) wakeUp
{
    if( [self aWake] )
        return;
    
    [super wakeUp];
}


- (void) sleep
{
    [super sleep];
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}


// implementation of adapter method
- (id) adapter
{
    // create an ambiguous pointer anAdapter that points to 
	id anAdapter = [ [self guardian] adapter ];

	if( anAdapter )
        return anAdapter;
    
    else
        [NSException raise:@"No XL2" format:@"Check that the crate has an XL2"];

	return nil;
}


- (BOOL) adapterIsSBC
{
	return [[self adapter] isKindOfClass:NSClassFromString(@"ORVmecpuModel")];
}


- (void) killPTPCameraProcess
{
    // Kill PTPCamera Process
    NSTask* task = [[NSTask alloc] init];
    
    task.launchPath = @"/usr/bin/killall";
    
    NSString* arg   = @"PTPCamera";
    task.arguments  = @[arg];
    
    [task launch];
    
    [task waitUntilExit];    
}


- (void) powerCamera
{
    if( [self adapterIsSBC] )
    {
        long errorCode = 0;
        SBC_Packet aPacket;
        
        aPacket.cmdHeader.destination           = kSNO;
        aPacket.cmdHeader.cmdID                 = kSNOCameraResetAll;
        aPacket.cmdHeader.numberBytesinPayload  = 1 * sizeof( long );
        
        unsigned long* payloadPtr   = (unsigned long*) aPacket.payload;
        payloadPtr[0]               = 0;
        
        @try
        {
            [ [[self adapter] sbcLink] send: &aPacket receive: &aPacket];
            unsigned long* responsePtr  = (unsigned long*) aPacket.payload;
            errorCode                   = responsePtr[0];
            
            if( errorCode )
            {
                @throw [NSException exceptionWithName:@"Reset All MTCA+ error" reason:@"SBC and/or LabJack failed.\n" userInfo:nil];
            }
        }
        
        @catch( NSException* e )
        {
            NSLog( @"SBC failed reset Cameras\n" );
            NSLog( @"Error: %@ with reason: %@\n", [e name], [e reason] );
            //@throw e;
        }
    }
    
    else
    {
        NSLog( @"Not implemented. Requires SBC with LabJack\n" );
    }
}


- (void) runCaptureScript
{
    NSTask* task = [[NSTask alloc] init];
    
    task.launchPath = @"/usr/bin/python";
    
    NSString* arg   = @"/Users/snotdaq/Dev/cameracode/capture_script.py -r";
    task.arguments  = @[arg];
    
    [task launch];

    NSDate* terminateDate = [[NSDate date] addTimeInterval:300.0];
    
    while( (task != nil) && ([task isRunning]) )
    {
        if( [[NSDate date] compare:(id) terminateDate] == NSOrderedDescending )
        {
            [task terminate];
            
            NSLog( @"Error: runCaptureScript is timing out." );
        }
        
        [NSThread sleepForTimeInterval:1.0];
    }
    
//    [task waitUntilExit];
}
@end