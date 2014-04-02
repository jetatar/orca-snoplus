//--------------------------------------------------------
// ORVarianTPSModel
// Created by Mark  A. Howe on Wed 12/2/09
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2009 University of North Carolina. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//Washington at the Center for Experimental Nuclear Physics and 
//Astrophysics (CENPA) sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//Washington reserve all rights in the program. Neither the authors,
//University of Washington, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#pragma mark •••Imported Files
#import "ORSerialPortModel.h"

@class ORSafeQueue;
@class ORTimeRate;
@class ORAlarm;

@interface ORVarianTPSModel : ORSerialPortModel
{
    @private
        unsigned long	dataId;
		NSData*			lastRequest;
		ORSafeQueue*	cmdQueue;
		NSMutableData*	inComingData;
		int				controllerTemp;
		int				actualRotorSpeed;
		int				pressureScale;
		int				pollTime;
		float			motorCurrent;
		float			pressure;
		unsigned long	timeMeasured;

		float			pressureScaleValue;
		BOOL			stationPower;
		ORTimeRate*		timeRate;
	
		NSString*		statusString;
		BOOL			remote;
}

#pragma mark •••Initialization
- (void) dealloc;

#pragma mark •••Accessors
- (BOOL) remote;
- (void) setRemote:(BOOL)aRemote;
- (int) controllerTemp;
- (void) setControllerTemp:(int)aValue;
- (int)  pollTime;
- (void) setPollTime:(int)aPollTime;
- (float) pressureScaleValue;
- (int) pressureScale;
- (void) setPressureScale:(int)aPressureScale;
- (ORTimeRate*)timeRate;
- (BOOL) stationPower;
- (void) setStationPower:(BOOL)aStationPower;
- (float) pressure;
- (void) setPressure:(float)aPressure;
- (float) motorCurrent;
- (void) setMotorCurrent:(float)aMotorCurrent;
- (int) actualRotorSpeed;
- (void) setActualRotorSpeed:(int)aActualRotorSpeed;
- (NSData*) lastRequest;
- (void) setLastRequest:(NSData*)aCmdString;
- (void) openPort:(BOOL)state;
- (NSString*) statusString;

#pragma mark •••Data Records
- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(id)userInfo;
- (NSDictionary*) dataRecordDescription;
- (unsigned long) dataId;
- (void) setDataId: (unsigned long) DataId;
- (void) setDataIds:(id)assigner;
- (void) syncDataIdsWith:(id)anotherVarianTPS;
- (void) shipPressure;

#pragma mark •••Archival
- (id)   initWithCoder:(NSCoder*)decoder;
- (void) encodeWithCoder:(NSCoder*)encoder;

#pragma mark •••Command Methods
- (void) write:(int)window logicValue:(BOOL)aValue;
- (void) read:(int)window;
- (int) crc:(unsigned char*)aCmd length:(int)len;
- (void) showWindowDisabled:(NSData*)aCommand;

- (void) sendDataSet:(int)aParamNum bool:(BOOL)aState;
- (void) sendDataSet:(int)aParamNum integer:(unsigned int)anInt; 
- (void) sendDataSet:(int)aParamNum real:(float)aFloat; 
- (void) sendDataSet:(int)aParamNum expo:(float)aFloat; 
- (void) sendDataSet:(int)aParamNum shortInteger:(unsigned short)aShort;

#pragma mark •••Port Methods
- (void) dataReceived:(NSNotification*)note;

#pragma mark •••HW Methods
- (void) getControllerTemp;
- (void) getActualSpeed	;
- (void) getMotorCurrent;
- (void) getPressure;	
- (void) updateAll;
- (void) sendRemoteMode;
- (void) turnStationOn;
- (void) turnStationOff;
- (void) sendReadSpeedMode;

@end

extern NSString* ORVarianTPSModelRemoteChanged;
extern NSString* ORVarianTPSModelPressureScaleChanged;
extern NSString* ORVarianTPSModelStationPowerChanged;
extern NSString* ORVarianTPSModelPressureChanged;
extern NSString* ORVarianTPSModelMotorCurrentChanged;
extern NSString* ORVarianTPSModelMotorCurrentChanged;
extern NSString* ORVarianTPSModelActualRotorSpeedChanged;
extern NSString* ORVarianTPSLock;
extern NSString* ORVarianTPSModelPollTimeChanged;
extern NSString* ORVarianTPSModelWindowStatusChanged;
extern NSString* ORVarianTPSModelControllerTempChanged;
