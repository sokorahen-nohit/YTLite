#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface NSObject (BTBGPlayerControl)
- (void)pause;
@end

static __weak id BTBGCurrentPlayer = nil;
static id BTBGBackgroundObserver = nil;
static id BTBGRouteObserver = nil;

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

static BOOL BTBGAppIsNotActive(void) {
    UIApplicationState state =
        [UIApplication sharedApplication].applicationState;

    return state != UIApplicationStateActive;
}

static void BTBGPauseCurrentPlayer(void) {
    if (BTBGHasBluetoothOutput()) {
        return;
    }

    id player = BTBGCurrentPlayer;

    if (player && [player respondsToSelector:@selector(pause)]) {
        [player pause];
    }
}

%hook YTPlayerViewController

- (void)loadWithPlayerTransition:(id)transition
                  playbackConfig:(id)config {
    %orig;
    BTBGCurrentPlayer = self;
}

- (void)dealloc {
    if (BTBGCurrentPlayer == self) {
        BTBGCurrentPlayer = nil;
    }

    %orig;
}

%end

%ctor {
    @autoreleasepool {
        NSNotificationCenter *center =
            [NSNotificationCenter defaultCenter];

        BTBGBackgroundObserver =
            [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                                object:nil
                                 queue:[NSOperationQueue mainQueue]
                            usingBlock:^(__unused NSNotification *notification) {
                BTBGPauseCurrentPlayer();
            }];

        BTBGRouteObserver =
            [center addObserverForName:AVAudioSessionRouteChangeNotification
                                object:nil
                                 queue:[NSOperationQueue mainQueue]
                            usingBlock:^(__unused NSNotification *notification) {
                if (BTBGAppIsNotActive()) {
                    BTBGPauseCurrentPlayer();
                }
            }];
    }
}
