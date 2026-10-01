#import <notify.h>
#import <substrate.h>
#import <libcolorpicker.h>
#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>


enum FPSMode{
	kModeAverage=1,
	kModePerSecond
};

static BOOL enabled;
static enum FPSMode fpsMode;

static dispatch_source_t _timer;
static UILabel *fpsLabel;

// Preference lookup that also works outside of a jailbreak:
//  - Jailbroken: kPrefPath ("/var/mobile/Library/Preferences/com.brend0n.fpsindicator.plist")
//  - Injected (LiveContainer / sideload dylib): <App Documents>/FPSIndicator.plist
// Returns nil when no config file exists at all (fresh injected install).
static NSMutableDictionary *prefsDictionary(){
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	if(!prefs){
		NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
		if(documents.length > 0){
			prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:[documents stringByAppendingPathComponent:@"FPSIndicator.plist"]];
		}
	}
	return prefs;
}

static void loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = prefsDictionary();

	enabled=prefs[@"enabled"]?[prefs[@"enabled"] boolValue]:YES;
	fpsMode=prefs[@"fpsMode"]?[prefs[@"fpsMode"] intValue]:0;
	if(fpsMode==0) fpsMode++; //0.0.2 compatibility 

	NSString *colorString = prefs[@"color"]?:@"#ffff00"; 
    UIColor *color = LCPParseColorString(colorString, nil);

	[fpsLabel setHidden:!enabled];
	[fpsLabel setTextColor:color];

}
static BOOL isEnabledApp(){
	NSMutableDictionary *prefs = prefsDictionary();
	if(!prefs){
		// No preference file: injected build with default settings -> enabled.
		return YES;
	}
	NSArray *apps = prefs[@"apps"];
	if([apps isKindOfClass:[NSArray class]]){
		return [apps containsObject:[[NSBundle mainBundle] bundleIdentifier]];
	}
	// Preference file exists but no whitelist was configured -> keep usable.
	return YES;
}

double FPSavg = 0;
double FPSPerSecond = 0;

static void startRefreshTimer(){
	_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), (1.0/5.0) * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(_timer, ^{
    	switch(fpsMode){
		    case kModeAverage:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSavg]];
		    	break;
		    case kModePerSecond:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSPerSecond]];
		    	break;
		    default:
		    	break;
    	}

    	NSLog(@"%.1lf %.1lf",FPSavg,FPSPerSecond);

    });
    dispatch_resume(_timer); 
}

#pragma mark ui
#define kFPSLabelWidth 50
#define kFPSLabelHeight 20
%group ui
%hook UIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds=[self bounds];
        CGFloat safeOffsetY=0;
        CGFloat safeOffsetX=0;
        if(@available(iOS 11.0,*)) {
            if(self.frame.size.width<self.frame.size.height){
                safeOffsetY=self.safeAreaInsets.top;    
            }
            else{
                safeOffsetX=self.safeAreaInsets.right;
            }
            
        }
        fpsLabel= [[UILabel alloc] initWithFrame:CGRectMake(bounds.size.width-kFPSLabelWidth-5.-safeOffsetX, safeOffsetY, kFPSLabelWidth, kFPSLabelHeight)];
        fpsLabel.font=[UIFont fontWithName:@"Helvetica-Bold" size:16];
        fpsLabel.textAlignment=NSTextAlignmentRight;
        fpsLabel.userInteractionEnabled=NO;
        
        [self addSubview:fpsLabel];
        loadPref();
        startRefreshTimer();
    });
	return %orig;
}
%end
%end//ui

// credits to https://github.com/masagrator/NX-FPS/blob/master/source/main.cpp#L64
void frameTick(){
	static double FPS_temp = 0;
	static double starttick = 0;
	static double endtick = 0;
	static double deltatick = 0;
	static double frameend = 0;
	static double framedelta = 0;
	static double frameavg = 0;
	
	if (starttick == 0) starttick = CACurrentMediaTime()*1000.0;
	endtick = CACurrentMediaTime()*1000.0;
	framedelta = endtick - frameend;
	frameavg = ((9*frameavg) + framedelta) / 10;
	FPSavg = 1000.0f / (double)frameavg;
	frameend = endtick;
	
	FPS_temp++;
	deltatick = endtick - starttick;
	if (deltatick >= 1000.0f) {
		starttick = CACurrentMediaTime()*1000.0;
		FPSPerSecond = FPS_temp - 1;
		FPS_temp = 0;
	}
	
	return;
}

#pragma mark gl
%group gl
%hook EAGLContext 
- (BOOL)presentRenderbuffer:(NSUInteger)target{
	BOOL ret=%orig;
	frameTick();
	return ret;
}
%end
%end//gl

#pragma mark metal
%group metal
// NOTE: upstream hooked `CAMetalDrawable`, but that name is an ObjC *protocol*
// (declared in <QuartzCore/CAMetalLayer.h>), not a class -- objc_getClass()
// never found it, so Metal frames were silently never counted.
// `CAMetalLayer -nextDrawable` is a real method called once per rendered frame.
%hook CAMetalLayer
- (id<CAMetalDrawable>)nextDrawable{
	id<CAMetalDrawable> drawable=%orig;
	if(drawable) frameTick();
	return drawable;
}
%end
%end//metal


%ctor{
	if(!isEnabledApp()) return;
	NSLog(@"ctor: FPSIndicator");

	%init(ui);
	%init(gl);
	%init(metal);

	int token = 0;
	notify_register_dispatch("com.brend0n.fpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
		loadPref();
	});
}
