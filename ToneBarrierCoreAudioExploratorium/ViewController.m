//
//  ViewController.m
//  ToneBarrierCoreAudioExploratorium
//
//  Created by Xcode Developer on 12/3/22.
//

#import "ViewController.h"

#import <AudioToolbox/AudioToolbox.h>

static double leftChannelFrequency;
static double * leftChannelFrequency_t = &leftChannelFrequency;
static double rightChannelFrequency;
static double * rightChannelFrequency_t = &rightChannelFrequency;
static Float32 left_channel_sample;
static Float32 * left_channel_sample_t = &left_channel_sample;
static Float32 right_channel_sample;
static Float32 * right_channel_sample_t = &right_channel_sample;
static double channelSwap;
static double * channelSwap_t = &channelSwap;
static double sampleRate;
static double left_channel_theta;
static double right_channel_theta;
static double left_channel_theta_increment;
static double * left_channel_theta_increment_t  = &left_channel_theta_increment;
static double right_channel_theta_increment;
static double * right_channel_theta_increment_t = &right_channel_theta_increment;
const double l_amplitude = 1.0;
const double r_amplitude = 1.0;

static void (^frequency_modulator)(void) = ^{
    ({
        *left_channel_theta_increment_t  = (2.0 * M_PI * *leftChannelFrequency_t / sampleRate);
        *right_channel_theta_increment_t = (2.0 * M_PI * *rightChannelFrequency_t  / sampleRate);
    });
};

static void (^amplitude_modulator)(void) = ^{
    ({
        
    });
};

static void (^phase_modulator)(void) = ^{
    ({
        
    });
};

static Float32 (^scale)(Float32, Float32, Float32, Float32, Float32) = ^ Float32 (Float32 val_old, Float32 min_new, Float32 max_new, Float32 min_old, Float32 max_old) {
   Float32 val_new = min_new + ((((val_old - min_old) * (max_new - min_new))) / (max_old - min_old));
   return val_new;
};

OSStatus RenderTone(
                    void *inRefCon,
                    AudioUnitRenderActionFlags * ioActionFlags,
                    const AudioTimeStamp       * inTimeStamp,
                    UInt32                       inBusNumber,
                    UInt32                       inNumberFrames,
                    AudioBufferList            * ioData)

{
    printf("inNumberFrames == %u\n", inNumberFrames);
    
    Float32 *buffer_left  = (Float32 *)ioData->mBuffers[0].mData;
    Float32 *buffer_right = (Float32 *)ioData->mBuffers[1].mData;
    
    // Generate the samples
    for (UInt32 frame = 0; frame < inNumberFrames; frame++)
    {
        double left_a  = ((1.0 - *channelSwap_t) * sin(left_channel_theta)) + (*channelSwap_t * sin(right_channel_theta));
        double right_a = ((1.0 - *channelSwap_t) * sin(right_channel_theta)) + (*channelSwap_t * sin(left_channel_theta));;
        buffer_left[frame]  = left_a;
        buffer_right[frame] = right_a;
        
        left_channel_theta += left_channel_theta_increment;
        if (left_channel_theta > 2.0 * M_PI)
        {
            left_channel_theta -= 2.0 * M_PI;
        }
        
        right_channel_theta += right_channel_theta_increment;
        if (right_channel_theta > 2.0 * M_PI)
        {
            right_channel_theta -= 2.0 * M_PI;
        }
    }
    
    return noErr;
}

void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
    ViewController *viewController =
    (__bridge ViewController *)inClientData;
    
    [viewController stop];
}

@implementation ViewController

@synthesize leftFrequencySlider, rightFrequencySlider, channelBalanceSlider;
@synthesize playButton;
@synthesize frequencyLabel;

- (IBAction)rightChannelFrequencySliderChanged:(UISlider *)sender {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{
        *rightChannelFrequency_t = sender.value;
        frequency_modulator();
    });
    
}

- (IBAction)leftChannelFrequencySliderChanged:(UISlider *)sender {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{
        *leftChannelFrequency_t = sender.value;
        frequency_modulator();
    });
    
}

- (void)createToneUnit
{
    // Configure the search parameters to find the default playback output unit
    // (called the kAudioUnitSubType_RemoteIO on iOS but
    // kAudioUnitSubType_DefaultOutput on Mac OS X)
    AudioComponentDescription defaultOutputDescription;
    defaultOutputDescription.componentType = kAudioUnitType_Output;
    defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    defaultOutputDescription.componentFlags = 0;
    defaultOutputDescription.componentFlagsMask = 0;
    
    // Get the default playback output unit
    AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
    NSAssert(defaultOutput, @"Can't find default output");
    
    // Create a new unit based on this that we'll use for output
    OSErr err = AudioComponentInstanceNew(defaultOutput, &toneUnit);
    NSAssert1(toneUnit, @"Error creating unit: %hd", err);
    
    // Set our tone rendering function on the unit
    AURenderCallbackStruct input;
    input.inputProc = RenderTone;
    input.inputProcRefCon = (__bridge void * _Nullable)(self);
    err = AudioUnitSetProperty(toneUnit,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input,
                               0,
                               &input,
                               sizeof(input));
    NSAssert1(err == noErr, @"Error setting callback: %hd", err);
    
    // Set the format to 32 bit, single channel, floating point, linear PCM
    const int four_bytes_per_float = 4;
    const int eight_bits_per_byte = 8;
    AudioStreamBasicDescription streamFormat;
    streamFormat.mSampleRate = sampleRate;
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    streamFormat.mBytesPerPacket = four_bytes_per_float;
    streamFormat.mFramesPerPacket = 1;
    streamFormat.mBytesPerFrame = four_bytes_per_float;
    streamFormat.mChannelsPerFrame = 2;
    streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
    err = AudioUnitSetProperty (toneUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &streamFormat,
                                sizeof(AudioStreamBasicDescription));
    NSAssert1(err == noErr, @"Error setting stream format: %hd", err);
}

- (IBAction)togglePlay:(UIButton *)selectedButton
{
    
    // kAudioSessionOutputRoute_AirPlay
    
    
    if (toneUnit)
    {
        AudioOutputUnitStop(toneUnit);
        AudioUnitUninitialize(toneUnit);
        AudioComponentInstanceDispose(toneUnit);
        toneUnit = nil;
        
        [selectedButton setTitle:NSLocalizedString(@"Play", nil) forState:0];
    }
    else
    {
        printf("%s\n", __PRETTY_FUNCTION__);
        
        
        
        [self createToneUnit];
        
        // Stop changing parameters on the unit
        OSErr err = AudioUnitInitialize(toneUnit);
        NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
        
        // Start playback
        err = AudioOutputUnitStart(toneUnit);
        NSAssert1(err == noErr, @"Error starting unit: %hd", err);
        
        [selectedButton setTitle:NSLocalizedString(@"Stop", nil) forState:0];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [selectedButton setSelected:toneUnit];
        [selectedButton setHighlighted:toneUnit];
    });
    
}

- (IBAction)channelBalanceSliderValueChanged:(UISlider *)sender {
    dispatch_barrier_async(dispatch_get_main_queue(), ^{
        *channelSwap_t = sender.value;
        frequency_modulator();
    });
    
}

- (void)stop
{
    if (toneUnit)
    {
        [self togglePlay:playButton];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.playButton setImage:[UIImage systemImageNamed:@"stop"] forState:UIControlStateSelected];
    [self.playButton setImage:[UIImage systemImageNamed:@"play"] forState:UIControlStateNormal];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.leftFrequencySlider  setValue:440.0];
        [self.rightFrequencySlider setValue:880.0];
        [self.channelBalanceSlider setValue:0.5];
        
        *leftChannelFrequency_t  = self.leftFrequencySlider.value;
        *rightChannelFrequency_t = self.rightFrequencySlider.value;
        *channelSwap_t           = pow(self.channelBalanceSlider.value, 0.5);
        frequency_modulator();
    });
    
    sampleRate = 192512;
    
    OSStatus result = AudioSessionInitialize(NULL, NULL, ToneInterruptionListener, (__bridge void *)(self));
    if (result == kAudioSessionNoError)
    {
        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
        AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
    }
    AudioSessionSetActive(true);
}

- (void)viewDidUnload {
    self.frequencyLabel = nil;
    self.playButton = nil;
    self.leftFrequencySlider = nil;
    self.rightFrequencySlider = nil;
    
    AudioSessionSetActive(false);
}

@end
