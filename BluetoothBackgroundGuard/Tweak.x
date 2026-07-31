#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

static BOOL BTBGDidEnterBackground = NO;
static BOOL BTBGHadBluetoothOutput = NO;

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

static void BTBGShowMessage(NSString *title, NSString *message) {
    UIWindow *activeWindow = nil;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        if (scene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                activeWindow = window;
                break;
            }
        }

        if (activeWindow) {
            break;
        }
    }

    UIViewController *controller = activeWindow.rootViewController;

    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }

    if (!controller) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                               handler:nil]];

    [controller presentViewController:alert
                             animated:YES
                           completion:nil];
}

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                               handler:nil]];

    [controller presentViewController:alert animated:YES completion:nil];
}

%ctor {
    @autoreleasepool {
        NSNotificationCenter *center =
            [NSNotificationCenter defaultCenter];

        [center addObserverForName:UIApplicationDidFinishLaunchingNotification
                           object:nil
                            queue:[NSOperationQueue mainQueue]
                       usingBlock:^(__unused NSNotification *notification) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    BTBGShowMessage(
                        @"Bluetooth Guard",
                        @"補助Tweakの読み込みに成功しました。"
                    );
                }
            );
        }];

        [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                           object:nil
                            queue:[NSOperationQueue mainQueue]
                       usingBlock:^(__unused NSNotification *notification) {
            BTBGDidEnterBackground = YES;
            BTBGHadBluetoothOutput = BTBGHasBluetoothOutput();
        }];

        [center addObserverForName:UIApplicationWillEnterForegroundNotification
                           object:nil
                            queue:[NSOperationQueue mainQueue]
                       usingBlock:^(__unused NSNotification *notification) {
            if (!BTBGDidEnterBackground) {
                return;
            }

            BTBGDidEnterBackground = NO;

            NSString *result = BTBGHadBluetoothOutput
                ? @"バックグラウンド移行時：Bluetoothあり"
                : @"バックグラウンド移行時：Bluetoothなし";

            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    BTBGShowMessage(@"診断結果", result);
                }
            );
        }];
    }
}
