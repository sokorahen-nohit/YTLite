#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface YTPlayerViewController : UIViewController
- (void)play;
- (void)pause;
@end

static __weak YTPlayerViewController *BTBGCurrentPlayer = nil;

static id BTBGBackgroundObserver = nil;
static id BTBGRouteObserver = nil;

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

static BOOL BTBGAppIsInBackground(void) {
    UIApplicationState state =
        [UIApplication sharedApplication].applicationState;

    return state != UIApplicationStateActive;
}

static void BTBGPauseIfNeeded(void) {
    if (!BTBGAppIsInBackground()) {
        return;
    }

    if (BTBGHasBluetoothOutput()) {
        return;
    }

    YTPlayerViewController *player = BTBGCurrentPlayer;

    if (player &&
        [player respondsToSelector:@selector(pause)]) {
        [player pause];
    }
}

static void BTBGSchedulePauseCheck(void) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.25 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
            BTBGPauseIfNeeded();
        }
    );
}

%hook YTPlayerViewController

- (void)loadWithPlayerTransition:(id)transition
                  playbackConfig:(id)config {
    %orig;

    BTBGCurrentPlayer = self;
}

- (void)play {
    BTBGCurrentPlayer = self;

    %orig;
}

%end

%ctor {
    @autoreleasepool {
        NSNotificationCenter *center =
            [NSNotificationCenter defaultCenter];

        BTBGBackgroundObserver =
            [center
                addObserverForName:
                    UIApplicationDidEnterBackgroundNotification
                object:nil
                queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *notification) {
                    (void)notification;

                    BTBGSchedulePauseCheck();
                }];

        BTBGRouteObserver =
            [center
                addObserverForName:
                    AVAudioSessionRouteChangeNotification
                object:nil
                queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *notification) {
                    (void)notification;

                    if (BTBGAppIsInBackground()) {
                        BTBGSchedulePauseCheck();
                    }
                }];
    }
}
