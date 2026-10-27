#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

typedef struct {
    const char *name;
    unsigned char red;
    unsigned char green;
    unsigned char blue;
} TestColor;

static const TestColor kColors[] = {
    {"Black", 0, 0, 0},
    {"White", 255, 255, 255},
    {"Red", 255, 0, 0},
    {"Green", 0, 255, 0},
    {"Blue", 0, 0, 255},
    {"Yellow", 255, 255, 0},
    {"Cyan", 0, 255, 255},
    {"Magenta", 255, 0, 255},
    {"Gray", 128, 128, 128}
};

static const NSTimeInterval kIntervals[] = {0.25, 0.5, 1.0, 2.0};

@interface OvalCameraView : UIView
- (instancetype)initWithSession:(AVCaptureSession *)session;
@end

@implementation OvalCameraView {
    AVCaptureVideoPreviewLayer *_previewLayer;
    CAShapeLayer *_ovalMask;
}

- (instancetype)initWithSession:(AVCaptureSession *)session {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = UIColor.blackColor;
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.layer addSublayer:_previewLayer];
        _ovalMask = [CAShapeLayer layer];
        self.layer.mask = _ovalMask;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _previewLayer.frame = self.bounds;
    _ovalMask.frame = self.bounds;
    _ovalMask.path = [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath;
}
@end

@interface ColorTestController : UIViewController
@end

@implementation ColorTestController {
    UILabel *_colorLabel;
    UILabel *_timeLabel;
    UILabel *_cameraLabel;
    UIButton *_startButton;
    UISegmentedControl *_intervalControl;
    CADisplayLink *_displayLink;
    NSMutableString *_events;
    NSUInteger _colorIndex;
    CFTimeInterval _lastChange;
    AVCaptureSession *_cameraSession;
    dispatch_queue_t _cameraQueue;
    BOOL _cameraConfigured;
    BOOL _permissionRequestPending;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _events = [NSMutableString stringWithString:@"sequence,requested_unix_seconds,requested_monotonic_seconds,name,r,g,b,interval_ms\n"];

    UIView *panel = [[UIView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    panel.layer.cornerRadius = 12;
    [self.view addSubview:panel];

    _colorLabel = [[UILabel alloc] init];
    _colorLabel.textColor = UIColor.whiteColor;
    _colorLabel.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightBold];
    _colorLabel.textAlignment = NSTextAlignmentCenter;
    _timeLabel = [[UILabel alloc] init];
    _timeLabel.textColor = UIColor.whiteColor;
    _timeLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    _timeLabel.numberOfLines = 0;
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    _cameraLabel = [[UILabel alloc] init];
    _cameraLabel.textColor = UIColor.whiteColor;
    _cameraLabel.font = [UIFont systemFontOfSize:11];
    _cameraLabel.numberOfLines = 0;
    _cameraLabel.textAlignment = NSTextAlignmentCenter;
    _cameraLabel.text = @"Camera: starting";

    _intervalControl = [[UISegmentedControl alloc] initWithItems:@[@"250ms", @"500ms", @"1s", @"2s"]];
    _intervalControl.selectedSegmentIndex = 2;
    [_intervalControl addTarget:self action:@selector(intervalChanged) forControlEvents:UIControlEventValueChanged];

    _startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_startButton setTitle:@"Start" forState:UIControlStateNormal];
    [_startButton addTarget:self action:@selector(toggleRunning) forControlEvents:UIControlEventTouchUpInside];
    UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [shareButton setTitle:@"Share CSV" forState:UIControlStateNormal];
    [shareButton addTarget:self action:@selector(shareEvents:) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[_startButton, shareButton]];
    buttons.distribution = UIStackViewDistributionFillEqually;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_colorLabel, _timeLabel, _cameraLabel, _intervalControl, buttons]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [panel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [panel.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [panel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12]
    ]];

    _cameraSession = [[AVCaptureSession alloc] init];
    _cameraQueue = dispatch_queue_create("com.vcam.colortest.camera", DISPATCH_QUEUE_SERIAL);
    OvalCameraView *preview = [[OvalCameraView alloc] initWithSession:_cameraSession];
    preview.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:preview];
    [NSLayoutConstraint activateConstraints:@[
        [preview.topAnchor constraintEqualToAnchor:panel.bottomAnchor constant:12],
        [preview.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [preview.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor multiplier:0.55],
        [preview.heightAnchor constraintEqualToAnchor:preview.widthAnchor multiplier:1.25],
        [preview.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12]
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopRunning)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopCamera)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startCamera)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraRuntimeError:)
                                                 name:AVCaptureSessionRuntimeErrorNotification object:_cameraSession];
    _colorIndex = 0;
    [self showCurrentColorAndRecord:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startCamera];
}

- (void)dealloc {
    [_displayLink invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setCameraStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_cameraLabel.text = status;
    });
}

- (void)startCamera {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusNotDetermined) {
        if (_permissionRequestPending) return;
        _permissionRequestPending = YES;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_permissionRequestPending = NO;
                if (granted) {
                    [self startCamera];
                } else {
                    [self setCameraStatus:@"Camera permission denied. Enable it in Settings."];
                }
            });
        }];
        return;
    }
    if (status != AVAuthorizationStatusAuthorized) {
        [self setCameraStatus:@"Camera permission denied or restricted. Check Settings."];
        return;
    }

    dispatch_async(_cameraQueue, ^{
        if (!self->_cameraConfigured) {
            AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                         mediaType:AVMediaTypeVideo
                                                                          position:AVCaptureDevicePositionFront];
            if (!device) {
                [self setCameraStatus:@"Front camera is unavailable."];
                return;
            }
            NSError *error = nil;
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
            if (!input) {
                [self setCameraStatus:[NSString stringWithFormat:@"Camera error: %@", error.localizedDescription]];
                return;
            }
            if (![self->_cameraSession canAddInput:input]) {
                [self setCameraStatus:@"Unable to add the front camera."];
                return;
            }
            [self->_cameraSession beginConfiguration];
            [self->_cameraSession addInput:input];
            [self->_cameraSession commitConfiguration];
            self->_cameraConfigured = YES;
        }
        if (!self->_cameraSession.isRunning) {
            [self->_cameraSession startRunning];
        }
        if (self->_cameraSession.isRunning) {
            [self setCameraStatus:@"Camera: front preview"];
        } else {
            [self setCameraStatus:@"Camera could not start."];
        }
    });
}

- (void)stopCamera {
    dispatch_async(_cameraQueue, ^{
        if (self->_cameraSession.isRunning) {
            [self->_cameraSession stopRunning];
        }
    });
}

- (void)cameraRuntimeError:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    [self setCameraStatus:[NSString stringWithFormat:@"Camera error: %@", error.localizedDescription ?: @"unknown"]];
}

- (void)showCurrentColorAndRecord:(BOOL)record {
    TestColor color = kColors[_colorIndex];
    NSTimeInterval wallTime = NSDate.date.timeIntervalSince1970;
    CFTimeInterval monotonicTime = CACurrentMediaTime();
    self.view.backgroundColor = [UIColor colorWithRed:color.red / 255.0
                                                green:color.green / 255.0
                                                 blue:color.blue / 255.0
                                                alpha:1.0];
    _colorLabel.text = [NSString stringWithFormat:@"%s  #%02X%02X%02X",
                        color.name, color.red, color.green, color.blue];
    _timeLabel.text = [NSString stringWithFormat:@"RGB %u, %u, %u\nRequest time: %.3f s since boot",
                       color.red, color.green, color.blue, monotonicTime];
    _lastChange = monotonicTime;
    if (record) {
        static unsigned long sequence = 0;
        NSTimeInterval interval = kIntervals[_intervalControl.selectedSegmentIndex];
        [_events appendFormat:@"%lu,%.6f,%.6f,%s,%u,%u,%u,%.0f\n",
         ++sequence, wallTime, monotonicTime, color.name, color.red, color.green, color.blue, interval * 1000.0];
    }
}

- (void)displayTick:(CADisplayLink *)link {
    NSTimeInterval interval = kIntervals[_intervalControl.selectedSegmentIndex];
    if (link.timestamp - _lastChange >= interval) {
        _colorIndex = (_colorIndex + 1) % (sizeof(kColors) / sizeof(kColors[0]));
        [self showCurrentColorAndRecord:YES];
    }
}

- (void)toggleRunning {
    if (_displayLink) {
        [self stopRunning];
        return;
    }
    [self showCurrentColorAndRecord:YES];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayTick:)];
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    [_startButton setTitle:@"Stop" forState:UIControlStateNormal];
}

- (void)stopRunning {
    [_displayLink invalidate];
    _displayLink = nil;
    [_startButton setTitle:@"Start" forState:UIControlStateNormal];
}

- (void)intervalChanged {
    if (_displayLink) {
        [self showCurrentColorAndRecord:YES];
    }
}

- (void)shareEvents:(UIButton *)sender {
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[_events copy]]
                                                                          applicationActivities:nil];
    activity.popoverPresentationController.sourceView = sender;
    activity.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[ColorTestController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
    }
}
