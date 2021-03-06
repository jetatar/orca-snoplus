
//
//  ORnEDMCoilModel.m
//  Orca
//
//  Created by Michael Marino 15 Mar 2012 
//  Copyright © 2002 CENPA, University of Washington. All rights reserved.
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
#import "ORnEDMCoilModel.h"
#import "ORTTCPX400DPModel.h"
#import "ORAdcProcessing.h"
#import "ORXYCom564Model.h"

NSString* ORnEDMCoilPollingActivityChanged = @"ORnEDMCoilPollingActivityChanged";
NSString* ORnEDMCoilPollingFrequencyChanged    = @"ORnEDMCoilPollingFrequencyChanged";
NSString* ORnEDMCoilADCListChanged = @"ORnEDMCoilADCListChanged";
NSString* ORnEDMCoilHWMapChanged   = @"ORnEDMCoilHWMapChanged";
NSString* ORnEDMCoilDebugRunningHasChanged = @"ORnEDMCoilDebugRunningHasChanged";
NSString* ORnEDMCoilVerboseHasChanged = @"ORnEDMCoilVerboseHasChanged";
NSString* ORnEDMCoilRealProcessTimeHasChanged = @"ORnEDMCoilRealProcessTimeHasChanged";
NSString* ORnEDMCoilTargetFieldHasChanged = @"ORnEDMCoilTargetFieldHasChanged";

bool useIntegralTerm=TRUE;
int currentMemorySize=40;
double integralTermFraction=0.3;
NSMutableArray* CurrentMemory;

@interface ORnEDMCoilModel (private) // Private interface
#pragma mark •••Running
- (void) _runThread;
- (void) _setFieldTargetWithArray:(NSArray*)array;
- (void) _setFieldTarget:(NSMutableData*)data;
- (void) _runProcess;
- (void) _stopRunning;
- (void) _startRunning;
- (void) _setUpRunning:(BOOL)verbose;

#pragma mark •••Read/Write
- (void) _readADCValues;
//- (void) _writeValuesToDatabase;
- (NSData*) _calcPowerSupplyValues;
- (NSData*) _readCurrentValues;
- (void)    _syncPowerSupplyValues:(NSData*)currentVector;
- (double)  _fieldAtMagnetometer:(int)index;
- (void)    _setCurrent:(double)current forSupply:(int)index;
- (double)  _getCurrent:(int)supply;
- (void)    _setADCList:(NSMutableArray*)anArray;
- (void)    _setRealProcessingTime:(NSTimeInterval)interv;

- (void) _setOrientationMatrix:(NSMutableArray*)anArray;
- (void) _setMagnetometerMatrix:(NSMutableArray*)anArray;
- (void) _setConversionMatrix:(NSMutableData*)anArray;

- (BOOL) _verifyMatrixSizes:(NSArray*)feedBackMatrix orientationMatrix:(NSArray*)orMax magnetometerMap:(NSArray*)magMap;

- (void) _checkForErrors; // throws exceptions
- (void) _runAlertOnMainThread:(NSException *)exc;
@end

#define CALL_SELECTOR_ONALL_POWERSUPPLIES(x)      \
{                                                 \
NSEnumerator* anEnum = [objMap objectEnumerator]; \
for (id obj in anEnum) [obj x];                   \
}

#define CALL_SELECTOR_ONALL_ADCS(x)               \
{                                                 \
for (id obj in listOfADCs) [obj x];               \
}


#define ORnEDMCoil_DEBUG 1

@implementation ORnEDMCoilModel (private)

- (void) _runThread
{
    [self initializeForRunning];
    CALL_SELECTOR_ONALL_POWERSUPPLIES(resetTrips);
    
    // Actively shut everything off.
    if (debugRunning) {
        CALL_SELECTOR_ONALL_POWERSUPPLIES(setAllOutputToBeOn:NO);
    } else {
        CALL_SELECTOR_ONALL_POWERSUPPLIES(setAllOutputToBeOn:YES);
    };

    //Wait for everything to start up.
    [NSThread sleepForTimeInterval:1.0];
    
    NSRunLoop* rl = [NSRunLoop currentRunLoop];
    
    [lastProcessStartDate release];
    lastProcessStartDate = nil;
    [self _setRealProcessingTime:0.0];
    // make sure we schedule the run
    [self performSelector:@selector(_runProcess) withObject:nil afterDelay:0.5];
    
    // perform the run loop, but cancel every second to check whether we should still run.
    while( isRunning && [rl runMode:NSDefaultRunLoopMode
                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]]);
    
    [self cleanupForRunning];
    [self _setRealProcessingTime:0.0];
    
    // Finally notify that we've finished.
    [[NSNotificationCenter defaultCenter]
     postNotificationOnMainThreadWithName:ORnEDMCoilPollingActivityChanged
                                   object:self];
}
- (void) _setFieldTarget:(NSMutableData*)data
{
    [data retain];
    [FieldTarget release];
    FieldTarget = data;
    [[NSNotificationCenter defaultCenter]
     postNotificationOnMainThreadWithName:ORnEDMCoilTargetFieldHasChanged
                                   object:self];
}

- (void) _setFieldTargetWithArray:(NSArray *)anArray
{
    //Possibility to grab field values and set a target of a fraction of the background field
    NSMutableData* ft = [NSMutableData dataWithLength:(NumberOfChannels*sizeof(double))];
    double* ptr = (double*)[ft bytes];
    if (anArray != nil && [anArray count] != NumberOfChannels) NSLog(@"Array doesn't have the correct channels!\n");
    if (anArray == nil || [anArray count] != NumberOfChannels) {
        // means we are resetting
        memset(ptr, 0, sizeof(ptr[0])*NumberOfChannels);
    } else {
        int i;
        for (i=0; i<NumberOfChannels;i++) ptr[i] = [[anArray objectAtIndex:i] floatValue];
    }
    [self _setFieldTarget:ft];

}

- (void) _runProcess
{
    // The current calculation process
    @try {
        NSDate* now = [[NSDate date] retain];
        if (lastProcessStartDate != nil){
            [self _setRealProcessingTime:[now timeIntervalSinceDate:lastProcessStartDate]];
            [lastProcessStartDate release];
        }
        lastProcessStartDate = now;
        for (id adc in listOfADCs) {
            if (![adc isPolling]) {
                [NSException raise:@"nEDM Coil" format:@"ADC %@, Crate: %d, Slot: %d not polling.",[adc objectName],[adc crateNumber],[adc slot]];
            }
        }
        NSData* currentVector = [self _calcPowerSupplyValues];
        if (verbose) NSLog(@"Currents updated\n");

        [self _syncPowerSupplyValues:currentVector];

        // Force a readback of all values.
        CALL_SELECTOR_ONALL_POWERSUPPLIES(readback:NO);
        if(pollingFrequency!=0){
            // Wait until every command has completed so that we stay synchronized with the device.
            [self _checkForErrors];
            NSTimeInterval delay = (1.0/pollingFrequency) + [lastProcessStartDate timeIntervalSinceNow];
            if (delay < 0) delay = 0.0;
            [self performSelector:@selector(_runProcess)
                       withObject:nil
                       afterDelay:delay];
        } else {
            [self _stopRunning];
        }
    }
    @catch(NSException* localException) {
        [self performSelectorOnMainThread:@selector(_runAlertOnMainThread:)
                               withObject:localException
                            waitUntilDone:NO];
        [self _stopRunning];
        return;
    }
}


- (void) _readADCValues
{
    // Reads current ADC values, creating a list of channels (128 for each ADC)


    unsigned long sizeOfArray = 0;
    for (id obj in listOfADCs) {
        sizeOfArray += [obj numberOfChannels];
    }
    assert(NumberOfChannels <= sizeOfArray);
    
    sizeOfArray *= sizeof(double);

    if (!currentADCValues || [currentADCValues length] != sizeOfArray) {
        [currentADCValues release];
        currentADCValues = [[NSMutableData dataWithLength:sizeOfArray] retain];
    }
    double* ptr = (double*)[currentADCValues bytes];
    int j = 0;
    for (id obj in listOfADCs){
        int i;
        for (i=0; i<[obj numberOfChannels]; i++) ptr[i+j] = [obj convertedValue:i];
        j += [obj numberOfChannels];
    }        
    
}

- (NSData*) _calcPowerSupplyValues
{
    // Calculates the desired power supply currents given.  Johannes, you should start here,
    // grabbing desired field values using [self _fieldAtMagnetometer:index]; and setting the 
    // current using [self _setCurrent:currentValue forSupply:index];
    
    //init FieldVectormutabl
    
    NSData* CurrentVector = [self _readCurrentValues];
    
    //Grab field values (including subtraction of target field)
    NSData* FieldVector = [NSMutableData dataWithLength:(NumberOfChannels*sizeof(double))];
    double* ptr = (double*)[FieldVector bytes];
    [self _readADCValues];    
    int i;
    for (i=0; i<NumberOfChannels;i++) ptr[i] = [self _fieldAtMagnetometer:i] -  [self targetFieldAtMagnetometer:i];
    
    
    // Perform multiplication with FeedbackMatrix, product is automatically added to CurrentVector
    // Y = alpha*A*X + beta*Y
    cblas_dgemv(CblasRowMajor,      // Row-major ordering
                CblasNoTrans,       // Don't transpose
                NumberOfCoils,      // Row number (A)
                NumberOfChannels,   // Column number (A)
                1,                  // Scaling Factor alpha
                [FeedbackMatData bytes], // Matrix A
                NumberOfChannels,   // Size of first dimension
                ptr,                // vector X
                1,                  // Stride (should be 1)
                1,                  // Scaling Factor beta
                (double*)[CurrentVector bytes],// vector Y
                1                   // Stride (should be 1)
                );
    
    // Proportional-Integral Control Loop
    if(!useIntegralTerm){
        return CurrentVector;        
    }
    else{
        
        NSData* retCur=[NSData dataWithData:CurrentVector];
        double* ptr = (double*)[retCur bytes];

        // Find average past current values
        NSData* avrCur=[NSData dataWithData:CurrentVector]; //initialized for size and no-memory case
        double* avrCurptr = (double*)[avrCur bytes];
 
        if(CurrentMemory){
            double *memptr[[CurrentMemory count]];
            
            int i;
            for(i=0; i<[CurrentMemory count];i++){
                memptr[i]=(double*)[[CurrentMemory objectAtIndex:i] bytes];
            }
            int j;
            //NSLog(@"Values read from current memory:\n");
            for(i=0;i<NumberOfCoils;i++){
                double sum=0;
                for(j=0;j<[CurrentMemory count];j++){
                    sum+= memptr[j][i];
                    //NSLog(@"%f\t",memptr[j][i]);
                }
                avrCurptr[i]=sum/[CurrentMemory count];
                //NSLog(@"\t%f\n",avrCurptr[i]);
            }
        }
        // Calculate PI-value for next current
        for (i=0; i<NumberOfCoils;i++) ptr[i] = (1-integralTermFraction)*ptr[i]+integralTermFraction*avrCurptr[i];

        // Adding current to memory, deleting oldest current if necessary
        if(CurrentMemory){
            [CurrentMemory addObject:retCur];
        }
        else{
            CurrentMemory=[[NSMutableArray arrayWithObject:retCur] retain];
        }
        if([CurrentMemory count]>currentMemorySize){
            [CurrentMemory removeObjectAtIndex:0]; 
        }
        
        // For testing: print out CurrentMemory
        /*double *memptr[[CurrentMemory count]];
        
        int i;
        for(i=0; i<[CurrentMemory count];i++){
            memptr[i]=(double*)[[CurrentMemory objectAtIndex:i] bytes];
        }
        int j;
        NSLog(@"Current Memory: \n");
        for(j=0;j<[CurrentMemory count];j++){
            for(i=0;i<NumberOfCoils;i++){
                NSLog(@"%f, ",memptr[j][i]);
            }
            NSLog(@"\n");
        }
         */

        
        return retCur;
    }
    
}

- (NSData*) _readCurrentValues
{
    // The following tells the power supplies to read the current value, we don't wait for the actual value.
    CALL_SELECTOR_ONALL_POWERSUPPLIES(sendCommandReadBackGetCurrentSetWithOutput:0);
    CALL_SELECTOR_ONALL_POWERSUPPLIES(sendCommandReadBackGetCurrentSetWithOutput:1);
    
    NSData* CurrentVector = [[[NSMutableData alloc] initWithLength:(NumberOfCoils*sizeof(double))] autorelease];
    double* ptr = (double*)[CurrentVector bytes];
    
    // Also waits to ensure that the commands have finished
    [self _checkForErrors];
    
	int i;
    for (i=0; i<NumberOfCoils;i++){
        ptr[i] = [self _getCurrent:i];
    }
    return CurrentVector;
}

- (void) _syncPowerSupplyValues:(NSData*) currentVector
{
    // Will write the saved power supply values to the hardware

    
    double* dblPtr = (double*)[currentVector bytes];
    double Current[NumberOfCoils];
    int i;
    for(i=0;i<NumberOfCoils;i++)
    {
        Current[i]=dblPtr[i];
    }
  
    for (i=0; i<NumberOfCoils;i++){
        [self _setCurrent:dblPtr[i] forSupply:i];
    }
    [self _checkForErrors];

}

- (double) _fieldAtMagnetometer:(int)index
{
    // Returns the field at a given magnetometer, index is mapped.
    
    // MagnetometerMap is to contain list of channels of magnetometers in order of appearance in FM
    // Channel values are as in currentADCValues: 128 slots for each ADC
    
    // ToBeFixed: in current setup, z-channels are reading inverted values. Where to account for orientation? -> FluxGate object will be created
    if (index >= [MagnetometerMap count]) {
        NSLog(@"Index (%i) out of range of magnetometer map (%i)\n",index,[MagnetometerMap count]);
        return 0.0;
    }
    const double* ptr = [currentADCValues bytes];
    assert([[MagnetometerMap objectAtIndex:index] intValue] < [currentADCValues length]/sizeof(ptr[0]));
    double raw = ptr[[[MagnetometerMap objectAtIndex:index] intValue]];

    if (verbose) NSLog(@"Field %i: %f\n",index,raw);
    return raw;
    
}

- (void) _setCurrent:(double)current forSupply:(int)index 
{
    // Will save the current for a given supply,
    // magnetometers and channels naturally ordered
    // Mapping will be taken care of at GUI level
    
    //Account for reversed wiring in PowerSupplies
    current=current*[[OrientationMatrix objectAtIndex:index] intValue];

    // Check if current ranges of power supplies are exceeded, cancel
    if (current>MaxCurrent) {
        //[NSException raise:@"Current Exceeded in Coil" format:@"Current Exceeded in Coil Channel: %d",index];
        current = MaxCurrent;
    }
    if (current<0) {
        //[NSException raise:@"Current Negative in Coil" format:@"Current Negative in Coil Channel:%d",index];
        current = 0.0;
    }
    

    
    [[objMap objectForKey:[NSNumber numberWithInt:(index/2)]]
     setWriteToSetCurrentLimit:current
                    withOutput:(index%2)];
    
    if (verbose) NSLog(@"Set Current (%@,%@): %f\n",
                       [[objMap objectForKey:[NSNumber numberWithInt:(index/2)]] ipAddress],
                       [[objMap objectForKey:[NSNumber numberWithInt:(index/2)]] serialNumber],
                       current);
}

- (double) _getCurrent:(int)index
{
    double retVal = [[objMap objectForKey:[NSNumber numberWithInt:(index/2)]] readBackGetCurrentSetWithOutput:(index%2)];
    
    //Account for reversed wiring in PowerSupplies
    retVal=retVal*[[OrientationMatrix objectAtIndex:index] intValue];
    
    if (verbose) NSLog(@"Read back current (%@,%@): %f\n",[[objMap objectForKey:[NSNumber numberWithInt:(index/2)]] ipAddress],
          [[objMap objectForKey:[NSNumber numberWithInt:(index/2)]] serialNumber],retVal);
    return retVal;

}

#pragma mark •••Running
- (void) _stopRunning
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(_runProcess)
                                               object:nil];
	isRunning = NO;
    NSLog(@"Stopping nEDM Coil Compensation processing.\n");
}

- (void) _startRunning
{
    [self connectAllPowerSupplies];
    if (FeedbackMatData != nil && OrientationMatrix != nil &&
        MagnetometerMap != nil &&
        [self _verifyMatrixSizes:nil
               orientationMatrix:OrientationMatrix
                 magnetometerMap:MagnetometerMap] ) {
        [self _setUpRunning:YES];    
    } else {
        [[NSAlert alertWithMessageText:@"Error"
                         defaultButton:nil
                       alternateButton:nil
                           otherButton:nil
             informativeTextWithFormat:@"Input matrices are inconsistent or non-existent.  Process can not be started."] runModal];
    }
}

- (void) _setUpRunning:(BOOL)aVerb
{
	
	if(isRunning && pollingFrequency != 0)return;
    
    if(pollingFrequency!=0){  
		isRunning = YES;
        if(aVerb) NSLog(@"Running nEDM Coil compensation at a rate of %.2f Hz.\n",pollingFrequency);
        [NSThread detachNewThreadSelector:@selector(_runThread)
                                 toTarget:self
                               withObject:nil];
    }
    else {
        if(aVerb) NSLog(@"Not running nEDM Coil compensation, polling frequency set to 0\n");
    }
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilPollingActivityChanged
	 object: self];
}

- (void) _setADCList:(NSMutableArray*)anArray
{
    [anArray retain];
    [listOfADCs release];
    listOfADCs = anArray;
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilADCListChanged
	 object: self];        
}


- (void) _setOrientationMatrix:(NSMutableArray*)anArray
{
    [anArray retain];
    [OrientationMatrix release];
    OrientationMatrix = anArray;
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilHWMapChanged object: self];
}

- (void) _setMagnetometerMatrix:(NSMutableArray*)anArray
{
    [anArray retain];
    [MagnetometerMap release];
    MagnetometerMap = anArray;
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilHWMapChanged object: self];
}
- (void) _setConversionMatrix:(NSMutableData*)anArray
{
    [anArray retain];
    [FeedbackMatData release];
    FeedbackMatData = anArray;
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilHWMapChanged object: self];
}


- (BOOL) _verifyMatrixSizes:(NSArray*)feedBackMatrix orientationMatrix:(NSArray*)orMax magnetometerMap:(NSArray*)magMap
{
    // Returns YES when matrix sizes are OK.
    
    @try {
        if (feedBackMatrix != nil) {
            // Means the feedback matrix is being defined.
            for (id e in feedBackMatrix) {
                if (![e isKindOfClass:[NSArray class]]) {
                    [NSException raise:@"MatrixReadInError"
                                format:@"Feedback Matrix is mal-formed."];
                }
                for (id var in e) {
                    if (![var isKindOfClass:[NSNumber class]]) {
                        [NSException raise:@"MatrixReadInError"
                                    format:@"Feedback Matrix is mal-formed."];
                    }
                }
            }
            NumberOfChannels   = [[feedBackMatrix objectAtIndex: 0] count];
            NumberOfCoils      = [feedBackMatrix count];
        }

        for (id e in orMax) {
            if (![e isKindOfClass:[NSNumber class]]) {
                [NSException raise:@"MatrixReadInError"
                            format:@"Input matrices are malformed."];
            }
        }
        for (id e in magMap) {
            if (![e isKindOfClass:[NSNumber class]]) {
                [NSException raise:@"MatrixReadInError"
                            format:@"Input matrices are malformed."];
            }
        }
        
        // Can't test if we don't know the number of coils or channels
        if (NumberOfCoils == 0 || NumberOfChannels == 0) return YES;
        if ((orMax != nil && [orMax count] != NumberOfCoils) &&
            (magMap != nil && [magMap count] != NumberOfChannels)) {
            [NSException raise:@"MatrixReadInError"
                        format:@"Input matrices are inconsistent.  Either try again, or reset the already input data."];
        }

    } @catch(NSException *e) {
        // This means something was wrong with the data, return NO!
        [[NSAlert alertWithMessageText:@"Error"
                         defaultButton:nil
                       alternateButton:nil
                           otherButton:nil
             informativeTextWithFormat:@"%@",[e reason]] runModal];
        return NO;
    }
    return YES;
}

- (void) _checkForErrors
{
    NSEnumerator* e = [objMap objectEnumerator];
    for (ORTTCPX400DPModel* i in e) {
        if (![i isConnected]) {
            [NSException raise:@"Not connected"
                        format:@"Not connected: (%@,%@,%@)",[i objectName],[i ipAddress],[i serialNumber]];
        }
        [i checkAndClearErrors:NO];

    }
    e = [objMap objectEnumerator];    
    for (ORTTCPX400DPModel* i in e) {
        [i waitUntilCommandsDone];
        if ([i currentErrorCondition]) {
            [NSException raise:@"Error in nEDM Coil"
                        format:@"Error in nEDM Coil (%@,%@,%@)",[i objectName],[i ipAddress],[i serialNumber]];
        }
    }
}

- (void) _runAlertOnMainThread:(NSException*) exc
{
    [[NSAlert alertWithMessageText:nil
                    defaultButton:nil
                  alternateButton:nil
                      otherButton:nil
        informativeTextWithFormat:@"%@",exc] runModal];
}

- (void) _setRealProcessingTime:(NSTimeInterval)timeint
{
    realProcessingTime = timeint;
    [[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:ORnEDMCoilRealProcessTimeHasChanged
	 object: self];
}

@end

@implementation ORnEDMCoilModel

#pragma mark •••initialization

- (id) init
{
    self = [super init];
    [self _setFieldTargetWithArray:nil];
    return self;
}

- (void) dealloc
{
    [objMap release];
    [listOfADCs release];
    [currentADCValues release];  
    [FeedbackMatData release];
    [lastProcessStartDate release];
    [CurrentMemory release];
    [FieldTarget release];
    [super dealloc];
}

- (void) makeConnectors
{	
}

- (void) setUpImage
{
    [self setImage:[NSImage imageNamed:@"nEDMCoil"]];
    // The following code might still be useful, hold on to it for the time being.  - M. Marino
}

- (void) makeMainController
{
    [self linkToController:@"ORnEDMCoilController"];
}

- (BOOL) isRunning
{
    return isRunning;
}

- (float) realProcessingTime
{
    return realProcessingTime;
}

- (float) pollingFrequency
{
    return pollingFrequency;
}

- (BOOL) debugRunning
{
    return debugRunning;
}

- (void) setDebugRunning:(BOOL)debug
{
    if (debug == debugRunning) return;
    debugRunning = debug;
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilDebugRunningHasChanged
	 object: self];     
}

- (void) connectAllPowerSupplies
{
    CALL_SELECTOR_ONALL_POWERSUPPLIES(connect);
}

- (void) addADC:(id)adc
{
    if (!listOfADCs) listOfADCs = [[NSMutableArray array] retain];
    // FixME Add protection for double entries
    [listOfADCs addObject:adc];
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilADCListChanged
	 object: self];     
}

- (void) removeADC:(id)adc
{
    [listOfADCs removeObject:adc];
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilADCListChanged
	 object: self];         
}

- (NSArray*) listOfADCs
{
    if (!listOfADCs) listOfADCs = [[NSMutableArray array] retain];
    return listOfADCs;
}

- (int) numberOfChannels
{
    return NumberOfChannels;
}

- (int) numberOfCoils
{
    return NumberOfCoils;
}

- (int) mappedChannelAtChannel:(int)aChan
{
    if (aChan >= [MagnetometerMap count]) return -1;
    return [[MagnetometerMap objectAtIndex:aChan] intValue];
}

- (double) conversionMatrix:(int)channel coil:(int)aCoil
{
    if (aCoil > NumberOfCoils || channel > NumberOfChannels) return 0.0;
    double* dblPtr = (double*)[FeedbackMatData bytes];
    return dblPtr[aCoil*NumberOfChannels + channel];
}

- (void) setPollingFrequency:(float)aFrequency
{
    if (pollingFrequency == aFrequency) return;
    pollingFrequency = aFrequency;
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilPollingFrequencyChanged
	 object: self];
}

- (BOOL) verbose
{
    return verbose;
}

- (void) setVerbose:(BOOL)aVerb
{
    if (verbose == aVerb) return;
    verbose = aVerb;
    [[NSNotificationCenter defaultCenter]
	 postNotificationName:ORnEDMCoilVerboseHasChanged
	 object: self];
}

- (void) initializeForRunning
{
    CALL_SELECTOR_ONALL_POWERSUPPLIES(setUserLock:YES withString:@"nEDM Coil Process");
    int i;
    for (i=0; i<NumberOfCoils;i++){
        [self _setCurrent:0 forSupply:i];
        [self setVoltage:MaxVoltage atCoil:i];
    }
    
    CALL_SELECTOR_ONALL_ADCS(setUserLock:YES withString:@"nEDM Coil Process");
    CALL_SELECTOR_ONALL_ADCS(startPollingActivity);
}

- (void) cleanupForRunning
{
    CALL_SELECTOR_ONALL_ADCS(stopPollingActivity);
    CALL_SELECTOR_ONALL_ADCS(setUserLock:NO withString:@"nEDM Coil Process");
    
    int i;
    for (i=0; i<NumberOfCoils;i++){
        [self _setCurrent:0 forSupply:i];
        [self setVoltage:1.0 atCoil:i];
    }
    CALL_SELECTOR_ONALL_POWERSUPPLIES(setAllOutputToBeOn:NO);
    CALL_SELECTOR_ONALL_POWERSUPPLIES(setUserLock:NO withString:@"nEDM Coil Process");
    CALL_SELECTOR_ONALL_POWERSUPPLIES(readback);
    [CurrentMemory release];
    CurrentMemory = nil;
}

- (void) toggleRunState
{
    if (isRunning) [self _stopRunning];
    else [self _startRunning];
}


- (void) initializeConversionMatrixWithPlistFile:(NSString*)plistFile
{
    NSLog(@"Reading FeedbackMatrix\n");

    // reads FeedbackMatrix from GUI
    // FeedbackMatrix is 24 x 180 (Coils x Channels), unused columns filled with 0s
    
    // Build the array from the plist  
    NSArray *RawFeedbackMatrix = [NSArray arrayWithContentsOfFile:plistFile];
    
    
    // Verify matrix sizes
    if (![self _verifyMatrixSizes:RawFeedbackMatrix
                orientationMatrix:OrientationMatrix
                  magnetometerMap:MagnetometerMap]) return;
    
    // If we get here, NumberOfChannels and NumberOfCoils are properly set.

    // Bring contents of RawFeedbackMatrix to FeedbackMatrix
    // While RFM is two-dimensional, FM is a simple double Array, dimensions are handled by cblas
    
    // Initialise FeedbackMatData
    NSMutableData* matData = [NSMutableData dataWithLength:NumberOfChannels*NumberOfCoils*sizeof(double)];
    double* dblPtr = (double*)[matData bytes];
    
    int line,i;
    for(line=0; line<[RawFeedbackMatrix count]; line++){
        for (i=0; i<NumberOfChannels;i++){
            dblPtr[line*NumberOfChannels + i] = [[[RawFeedbackMatrix objectAtIndex:line] objectAtIndex:i] doubleValue];
        }
    }
    [self _setConversionMatrix:matData];    
    
#ifdef ORnEDMCoil_DEBUG
    NSLog(@"Filled FeedbackMatData\n");
    for (i=0; i<NumberOfCoils*NumberOfChannels;i++) NSLog(@"%f\n",dblPtr[i]);
    NSLog(@"output complete\n");
#endif
    

    
}

- (void) initializeOrientationMatrixWithPlistFile:(NSString*)plistFile
{
    
    NSMutableArray* orientMat = [NSMutableArray arrayWithContentsOfFile:plistFile];

    if( ![self _verifyMatrixSizes:nil orientationMatrix:orientMat magnetometerMap:MagnetometerMap] ) return;
    [self _setOrientationMatrix:orientMat];
    
#ifdef ORnEDMCoil_DEBUG
    NSLog(@"OrientationMatrix read:");
    int i;
    for (i=0; i<[orientMat count]; i++) {
        NSLog([NSString stringWithFormat:@"element: %f\n",[[orientMat objectAtIndex:i] floatValue]]);
    }
#endif

    
}

- (void) initializeMagnetometerMapWithPlistFile:(NSString*)plistFile
{
    NSMutableArray* magMap = [NSMutableArray arrayWithContentsOfFile:plistFile];
    if( ![self _verifyMatrixSizes:nil orientationMatrix:OrientationMatrix magnetometerMap:magMap] ) return;
    [self _setMagnetometerMatrix:magMap];
    
#ifdef ORnEDMCoil_DEBUG
    NSLog(@"MagnetometerMap read:\n");
    int i;
    for (i=0; i<[magMap count]; i++) {
        NSLog([NSString stringWithFormat:@"element: %f\n",[[magMap objectAtIndex:i] floatValue]]);
    }
#endif
}

- (void) saveCurrentFieldInPlistFile:(NSString*)plistFile
{
    NSMutableArray* tempArray = [NSMutableArray arrayWithCapacity:NumberOfChannels];
    
    int i;
    for(i=0;i<NumberOfChannels;i++) [tempArray insertObject:[NSNumber numberWithDouble:[self fieldAtMagnetometer:i]] atIndex:i];
    
    [tempArray writeToFile:plistFile atomically:YES];
}

- (void) loadTargetFieldWithPlistFile:(NSString*)plistFile
{
    NSArray* targetField = [NSArray arrayWithContentsOfFile:plistFile];
    if( ![self _verifyMatrixSizes:nil orientationMatrix:OrientationMatrix magnetometerMap:targetField] ) return;
    [self _setFieldTargetWithArray:targetField];
}

- (void) setTargetFieldToZero
{
    [self _setFieldTargetWithArray:nil];
}

- (void) resetConversionMatrix
{
    [self _setConversionMatrix:nil];
    NumberOfChannels = 0;
    NumberOfCoils    = 0;
    [self resetMagnetometerMap];
    [self resetOrientationMatrix];
}
- (void) resetMagnetometerMap
{
    [self _setMagnetometerMatrix:nil];
}
- (void) resetOrientationMatrix
{
    [self _setOrientationMatrix:nil];
}

- (NSArray*) magnetometerMap
{
    return MagnetometerMap;
}

- (NSArray*) orientationMatrix
{
    return OrientationMatrix;
}

- (NSData*)  feedbackMatData
{
    return FeedbackMatData;
}

#pragma mark •••ORGroup
- (void) objectCountChanged
{
    // Recalculate the obj map
    if (!objMap) objMap = [[NSMutableDictionary dictionary] retain];
    [objMap removeAllObjects];
    NSEnumerator* e = [self objectEnumerator];
    for (id anObject in e) {
        [objMap setObject:anObject forKey:[NSNumber numberWithInt:[anObject tag]]];
    }
}

- (int) rackNumber
{
	return [self uniqueIdNumber];
}

- (void) viewChanged:(NSNotification*)aNotification
{
    [self setUpImage];
}

- (NSString*) identifier
{
    return [NSString stringWithFormat:@"nEDM Coil %d",[self rackNumber]];
}

- (NSComparisonResult)sortCompare:(OrcaObject*)anObj
{
    return [self uniqueIdNumber] - [anObj uniqueIdNumber];
}

#pragma mark •••CardHolding Protocol
#define objHeight 71
#define objectsInRow 2
- (int) maxNumberOfObjects	{ return 12; }	//default
- (int) objWidth			{ return 100; }	//default
- (int) groupSeparation		{ return 0; }	//default
- (NSString*) nameForSlot:(int)aSlot	
{ 
    return [NSString stringWithFormat:@"Slot %d",aSlot]; 
}

- (NSRange) legalSlotsForObj:(id)anObj
{
	return NSMakeRange(0,[self maxNumberOfObjects]);
}

- (BOOL) slot:(int)aSlot excludedFor:(id)anObj 
{ 
    return NO;
}

- (int)slotAtPoint:(NSPoint)aPoint 
{
	float y = aPoint.y;
    float x = aPoint.x;
	int objWidth = [self objWidth];
    int columnNumber = (int)x/objWidth;
	int rowNumber = (int)y/objHeight;
	
    if (rowNumber >= [self maxNumberOfObjects]/objectsInRow ||
        columnNumber >= objectsInRow) return -1;
    return rowNumber*objectsInRow + columnNumber;
}

- (NSPoint) pointForSlot:(int)aSlot 
{
    int rowNumber = aSlot/objectsInRow;
    int columnNumber = aSlot % objectsInRow;
    return NSMakePoint(columnNumber*[self objWidth],rowNumber*objHeight);
}

- (void) place:(id)aCard intoSlot:(int)aSlot
{
    [aCard setTag:aSlot];
	[aCard moveTo:[self pointForSlot:aSlot]];
}
- (int) slotForObj:(id)anObj
{
    return [anObj tag];
}
- (int) numberSlotsNeededFor:(id)anObj
{
	return [anObj numberSlotsUsed];
}

#pragma mark •••Archival
- (id)initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    
    [[self undoManager] disableUndoRegistration];

    [self setPollingFrequency:[decoder decodeFloatForKey:@"kORnEDMCoilPollingFrequency"]];
    [self setDebugRunning:[decoder decodeBoolForKey:@"kORnEDMCoilDebugRunning"]]; 
    [self _setMagnetometerMatrix:[decoder decodeObjectForKey:@"kORnEDMCoilMagnetometerMap"]];
    [self _setOrientationMatrix:[decoder decodeObjectForKey:@"kORnEDMCoilOrientationMatrix"]];
    [self _setConversionMatrix:[decoder decodeObjectForKey:@"kORnEDMCoilFeedbackMatrixData"]];
    [self _setFieldTarget:[decoder decodeObjectForKey:@"kORnEDMCoilFieldTarget"]];
    NumberOfChannels = [decoder decodeIntForKey:@"kORnEDMCoilNumChannels"];    
    NumberOfCoils = [decoder decodeIntForKey:@"kORnEDMCoilNumCoils"]; 
    
    [self _setADCList:[decoder decodeObjectForKey:@"kORnEDMCoilListOfADCs"]];
    [self _setADCList:[decoder decodeObjectForKey:@"kORnEDMCoilListOfADCs"]];    
    [self setVerbose:[decoder decodeIntForKey:@"kORnEDMCoilVerbose"]];
    [[self undoManager] enableUndoRegistration];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeFloat:pollingFrequency forKey:@"kORnEDMCoilPollingFrequency"];
    [encoder encodeBool:debugRunning forKey:@"kORnEDMCoilDebugRunning"];
    [encoder encodeObject:MagnetometerMap forKey:@"kORnEDMCoilMagnetometerMap"];
    [encoder encodeObject:OrientationMatrix forKey:@"kORnEDMCoilOrientationMatrix"];
    [encoder encodeObject:FeedbackMatData forKey:@"kORnEDMCoilFeedbackMatrixData"];
    [encoder encodeInt:NumberOfChannels forKey:@"kORnEDMCoilNumChannels"];    
    [encoder encodeInt:NumberOfCoils forKey:@"kORnEDMCoilNumCoils"];        
    [encoder encodeInt:verbose forKey:@"kORnEDMCoilVerbose"];
    [encoder encodeObject:listOfADCs forKey:@"kORnEDMCoilListOfADCs"];
    [encoder encodeObject:FieldTarget forKey:@"kORnEDMCoilFieldTarget"];
}

#pragma mark •••Holding ADCs
- (NSArray*) validObjects
{
    return [[self document] collectObjectsConformingTo:@protocol(ORAdcProcessing)];
}

#pragma mark •••Held objects
- (int) magnetometerChannels
{
    [self _readADCValues];
    return (int)([currentADCValues length]/sizeof(double));
}

- (int) coilChannels
{
    return [objMap count]*kORTTCPX400DPOutputChannels;
}

- (void) enableOutput:(BOOL)enab atCoil:(int)coil
{
    [[objMap objectForKey:[NSNumber numberWithInt:(coil/2)]]
     setWriteToSetOutput:(int)enab withOutput:(coil%2)];
}

- (void) setVoltage:(double)volt atCoil:(int)coil
{
    [[objMap objectForKey:[NSNumber numberWithInt:(coil/2)]]
     setWriteToSetVoltage:volt withOutput:(coil%2)];
}

- (void) setCurrent:(double)current atCoil:(int)coil
{
    [self _setCurrent:current forSupply:coil];
}

- (double) readBackSetCurrentAtCoil:(int)coil
{
    return [[objMap objectForKey:[NSNumber numberWithInt:(coil/2)]]
            readAndBlockGetCurrentSetWithOutput:coil%2];
}

- (double) readBackSetVoltageAtCoil:(int)coil
{
    return [[objMap objectForKey:[NSNumber numberWithInt:(coil/2)]]
            readAndBlockGetVoltageSetWithOutput:coil%2];

}

- (double) fieldAtMagnetometer:(int)magn
{
    [self _readADCValues];
    return [self _fieldAtMagnetometer:magn];
}

- (double) targetFieldAtMagnetometer:(int)magn
{
    if (magn >= [FieldTarget length]/sizeof(double)) return 0.0;
    double* ptr2= (double*)[FieldTarget bytes];
    return ptr2[magn];
}

@end

