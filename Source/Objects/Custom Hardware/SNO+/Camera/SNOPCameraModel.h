//
//  CameraModel.h
//  Orca
//
//  Created by Joulien on 5/7/14.
//
//

#import <Foundation/Foundation.h>
#import "SNOPCameraController.h"
#import "ORVmeIOCard.h"

// Create a class SNOPCameraModel which inherits from OrcaObject
@interface SNOPCameraModel : OrcaObject
//@interface SNOPCameraModel : ORVmeIOCard
{
    BOOL isRunning;
}

- (void) setUpImage;
- (void) makeMainController;
- (void) wakeUp;
- (void) sleep;
- (void) dealloc;
- (id)   sbcLink;
- (void) killPTPCameraProcess;
- (void) powerCamera;
- (void) runCaptureScript;

@end
