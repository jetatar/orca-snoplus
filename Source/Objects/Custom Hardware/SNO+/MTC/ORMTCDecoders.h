//
//  ORMTCDecoders.h
//  Orca
//
//Created by Mark Howe on Fri, May 2, 2008
//Copyright (c) 2008 CENPA, University of Washington. All rights reserved.
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



#import "ORVmeCardDecoder.h"

@class ORDataPacket;
@class ORDataSet;

@interface ORMTCDecoderForMTC : ORVmeCardDecoder {
    @private 
}
- (unsigned long) decodeData:(void*)someData fromDecoder:(ORDecoder*)aDecoder intoDataSet:(ORDataSet*)aDataSet;
- (NSString*) dataRecordDescription:(unsigned long*)dataPtr;
@end

@interface ORMTCDecoderForMTCStatus : ORVmeCardDecoder {
@private
    NSDate* _baseDate;
    NSDateFormatter* _mtcDateFormatter;
    BOOL _isGetRatesFromDecodeStage;
    id _mtcModel;
}
@property (retain,nonatomic) NSDate* baseDate;
@property (retain,nonatomic) NSDateFormatter* mtcDateFormatter;
@property (assign,nonatomic) BOOL isGetRatesFromDecodeStage;
@property (assign,nonatomic) id mtcModel;

- (unsigned long) decodeData:(void*)someData fromDecoder:(ORDecoder*)aDecoder intoDataSet:(ORDataSet*)aDataSet;
- (NSString*) dataRecordDescription:(unsigned long*)dataPtr;
@end
