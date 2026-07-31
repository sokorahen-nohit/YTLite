#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

static BOOL BTBGHasBluetoothOutput(void) {
    AVAudioSessionRouteDescription *route =
        [AVAudioSession sharedInstance].currentRoute;

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

%hook YTIPlayabilityStatus

- (BOOL)isPlayableInBackground {
    return BTBGHasBluetoothOutput();
}

%end

%hook MLVideo

- (BOOL)playableInBackground {
    return BTBGHasBluetoothOutput();
}

%end
