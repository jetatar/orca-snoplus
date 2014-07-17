//
//  CameraModel.h
//  Orca
//
//  Created by Joulien on 5/7/14.
//
//

#import <Foundation/Foundation.h>
#import "SNOPCameraController.h"

// Create a class SNOPCameraModel which inherits from OrcaObject
@interface SNOPCameraModel : OrcaObject
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
