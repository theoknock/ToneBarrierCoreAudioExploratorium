//
//  ViewController.h
//  ToneBarrierCoreAudioExploratorium
//
//  Created by Xcode Developer on 12/3/22.
//

#import <UIKit/UIKit.h>

@import CoreAudio;
@import AudioUnit;

@interface ViewController : UIViewController
{
    UILabel  * frequencyLabel;
    UIButton * playButton;
    UISlider * leftFrequencySlider;
    UISlider * rightFrequencySlider;
    UISlider * channelBalanceSlider;
    AudioComponentInstance toneUnit;
}

@property (retain, nonatomic) IBOutlet UISlider * leftFrequencySlider;
@property (retain, nonatomic) IBOutlet UISlider * rightFrequencySlider;
@property (retain, nonatomic) IBOutlet UISlider * channelBalanceSlider;

@property (nonatomic, retain) IBOutlet UIButton * playButton;
@property (nonatomic, retain) IBOutlet UILabel  * frequencyLabel;

- (IBAction)leftChannelFrequencySliderChanged:(UISlider *)sender;
- (IBAction)rightChannelFrequencySliderChanged:(UISlider *)sender;
- (IBAction)channelBalanceSliderValueChanged:(UISlider *)sender;

- (IBAction)togglePlay:(UIButton *)selectedButton;
- (void)stop;

@end

