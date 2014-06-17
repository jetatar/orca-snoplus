//
//  CameraModel.h
//  Orca
//
//  Created by Joulien on 5/7/14.
//
//

#import <Foundation/Foundation.h>

// Create a class ORCamModel which inherits from OrcaObject
@interface ORCamModel : OrcaObject
{
    BOOL isRunning;
}

- (void) setUpImage;
- (void) makeMainController;
- (void) wakeUp;
- (void) sleep;
- (void) dealloc;
- (id)   adapter;
- (BOOL) adapterIsSBC;
- (void) killPTPCameraProcess;
- (void) powerCamera;
- (void) runCaptureScript;

@end
