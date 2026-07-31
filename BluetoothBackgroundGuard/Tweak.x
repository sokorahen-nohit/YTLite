#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface YTLUserDefaults : NSUserDefaults
@end

static BOOL BTBGHasBluetoothOutput(void) {
    AVAudioSessionRouteDescription *route =
        [[AVAudioSession sharedInstance] currentRoute];

    for (AVAudioSessionPortDescription *output in route.outputs) {
        NSString *type = output.portType;

        if ([type isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [type isEqualToString:AVAudioSessionPortBluetoothHFP] ||
            [type isEqualToString:AVAudioSessionPortBluetoothLE]) {
            return YES;
        }
    }

    return NO;
}

%hook YTLUserDefaults

- (BOOL)boolForKey:(NSString *)key {
    if ([key isEqualToString:@"backgroundPlayback"]) {
        return BTBGHasBluetoothOutput();
    }

    return %orig;
}

%end
