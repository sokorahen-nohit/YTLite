#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface YTPlayerViewController : UIViewController
- (void)play;
- (void)pause;
@end

@interface YTMainAppControlsOverlayView : UIView
@property(nonatomic, strong) YTPlayerViewController *playerViewController;
@end

static NSHashTable<YTPlayerViewController *> *BTBGPlayers;

static id BTBGWillResignObserver;
static id BTBGBackgroundObserver;
static id BTBGRouteObserver;

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
    return [UIApplication sharedApplication].applicationState ==
           UIApplicationStateBackground;
}

static void BTBGRememberPlayer(YTPlayerViewController *player) {
    if (!player) {
        return;
    }

    [BTBGPlayers addObject:player];
}

static void BTBGFindPlayersInController(UIViewController *controller) {
    if (!controller) {
        return;
    }

    Class playerClass = NSClassFromString(@"YTPlayerViewController");

    if (playerClass && [controller isKindOfClass:playerClass]) {
        BTBGRememberPlayer((YTPlayerViewController *)controller);
    }

    for (UIViewController *child in controller.childViewControllers) {
        BTBGFindPlayersInController(child);
    }

    if (controller.presentedViewController) {
        BTBGFindPlayersInController(
            controller.presentedViewController
        );
    }
}

static void BTBGDiscoverVisiblePlayers(void) {
    for (UIScene *scene in
         [UIApplication sharedApplication].connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        for (UIWindow *window in windowScene.windows) {
            BTBGFindPlayersInController(
                window.rootViewController
            );
        }
    }
}

static void BTBGPauseNow(void) {
    if (!BTBGAppIsInBackground()) {
        return;
    }

    if (BTBGHasBluetoothOutput()) {
        return;
    }

    BTBGDiscoverVisiblePlayers();

    for (YTPlayerViewController *player in BTBGPlayers.allObjects) {
        if ([player respondsToSelector:@selector(pause)]) {
            [player pause];
        }
    }
}

static void BTBGSchedulePauseChecks(void) {
    NSArray<NSNumber *> *delays = @[
        @0.05,
        @0.20,
        @0.50,
        @1.00,
        @1.60
    ];

    for (NSNumber *delayValue in delays) {
        NSTimeInterval delay = delayValue.doubleValue;

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(delay * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                BTBGPauseNow();
            }
        );
    }
}

%hook YTPlayerViewController

- (void)loadWithPlayerTransition:(id)transition
                  playbackConfig:(id)config {
    BTBGRememberPlayer(self);

    %orig;

    BTBGRememberPlayer(self);
}

- (void)play {
    BTBGRememberPlayer(self);

    %orig;

    /*
     * YouTubeがバックグラウンド移行後に再度playを呼んでも、
     * Bluetooth未接続なら再び停止する。
     */
    if (BTBGAppIsInBackground() &&
        !BTBGHasBluetoothOutput()) {
        BTBGSchedulePauseChecks();
    }
}

%end

%hook YTMainAppControlsOverlayView

- (void)setPlayerViewController:
    (YTPlayerViewController *)playerViewController {

    %orig;

    BTBGRememberPlayer(playerViewController);
}

- (void)didMoveToWindow {
    %orig;

    BTBGRememberPlayer(self.playerViewController);
}

%end

%ctor {
    @autoreleasepool {
        BTBGPlayers = [NSHashTable weakObjectsHashTable];

        NSNotificationCenter *center =
            [NSNotificationCenter defaultCenter];

        BTBGWillResignObserver =
            [center
                addObserverForName:
                    UIApplicationWillResignActiveNotification
                object:nil
                queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *notification) {
                    (void)notification;
                    BTBGSchedulePauseChecks();
                }];

        BTBGBackgroundObserver =
            [center
                addObserverForName:
                    UIApplicationDidEnterBackgroundNotification
                object:nil
                queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *notification) {
                    (void)notification;
                    BTBGSchedulePauseChecks();
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
                        BTBGSchedulePauseChecks();
                    }
                }];
    }
}
