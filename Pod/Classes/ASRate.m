//
//  ASRate.m
//  ASRate
//
//  Created by Yor on 6/24/15.
//  Copyright (c) 2015 Yor. All rights reserved.
//

#import "ASRate.h"

#import "AXRatingView.h"

#import <DQAlertView/DQAlertView.h>
#import <Parse/Parse.h>

@interface ASRate () <AXRatingViewDelegate, DQAlertViewDelegate, UITextViewDelegate>
{
    CGPoint centerAlert;
}
@property (assign, nonatomic) NSInteger sessionCount;
@property (assign, nonatomic) BOOL didFirstShow;

@property (strong, nonatomic) AXRatingView *ratingView;
@property (strong, nonatomic) DQAlertView *rateAlertView;
@property (strong, nonatomic) DQAlertView *commentAlertView;

@property (nonatomic, assign) BOOL checkingForAppStoreID;
@property (assign, nonatomic) CGFloat ratingValue;

@property (strong, nonatomic) NSString *parseApplicationID;
@property (strong, nonatomic) NSString *parseClientID;

@end

static NSString *const ASRateSessionCountKey = @"ASRateSessionCountKey";
static NSString *const ASRateDidFirstShowKey = @"ASRateDidFirstShowKey";
static NSString *const ASRateShouldShowAgainKey = @"ASRateShouldShowAgainKey";
static NSString *const ASRateAppLookupURLFormat = @"http://itunes.apple.com/%@/lookup";

static NSString *const ASRateiOSAppStoreURLFormat = @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@&pageNumber=0&sortOrdering=2&mt=8";
static NSString *const ASRateiOS7AppStoreURLFormat = @"itms-apps://itunes.apple.com/app/id%@";
NSString *const ASRateErrorDomain = @"ASRateErrorDomain";
static NSString *const ASRateAppStoreIDKey = @"iRateAppStoreID";
NSUInteger const ASRateAppStoreGameGenreID = 6014;

@implementation ASRate

+ (instancetype)sharedInstance
{
    static ASRate *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance prepareSessionCount];
    });
    return sharedInstance;
}

- (NSUInteger)appStoreID
{
    return _appStoreID ?: [[[NSUserDefaults standardUserDefaults] objectForKey:ASRateAppStoreIDKey] unsignedIntegerValue];
}

- (ASRate *)init
{
    self = [super init];
    if (self) {
        //register for iphone application events
        //bundle id
        self.applicationBundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        //get country
        self.appStoreCountry = [(NSLocale *)[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        if ([self.appStoreCountry isEqualToString:@"150"])
        {
            self.appStoreCountry = @"eu";
        }
        else if (!self.appStoreCountry || [[self.appStoreCountry stringByReplacingOccurrencesOfString:@"[A-Za-z]{2}" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, 2)] length])
        {
            self.appStoreCountry = @"us";
        }
        
        //localised application name
        self.applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if ([self.applicationName length] == 0)
        {
            self.applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
        }
        
        // set default session count
        self.sessionCountFirstShow = 5;
        self.sessionCountShowAgain = 10;
        
        [self prepareRatingAlertView];
        [self prepareCommentAlertView];
        
        if (&UIApplicationWillEnterForegroundNotification)
        {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(applicationWillEnterForeground)
                                                         name:UIApplicationWillEnterForegroundNotification
                                                       object:nil];
        }
        
        //app launched
        [self performSelectorOnMainThread:@selector(applicationDidFinishLaunching) withObject:nil waitUntilDone:NO];
        
        [self addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    }
    
    return self;
}

- (void)setParseApplicationId:(NSString *)applicationId ParseClientKey:(NSString *)clientKey
{
    self.parseApplicationID = applicationId;
    self.parseClientID = clientKey;
    [Parse setApplicationId:applicationId clientKey:clientKey];
}

#pragma mark - Parse

- (void)sentParseRateValueWithComment:(NSString *)comment
                            withBlock:(void (^)(void))block
{
    if (!self.parseApplicationID || !self.parseClientID) {
        NSLog(@"[ASRate] #warning You should set 'ParseApplicationId' and ParseClientKey");
        block();
        return;
    }
    PFObject *object = [PFObject objectWithClassName:@"Rate"];
    object[@"rating"] = @(self.ratingValue);
    if (comment) {
        object[@"comment"] = comment;
    }
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        block();
        if (succeeded) {
            // The object has been saved.
        } else {
            // There was a problem, check error.description
            NSLog(@"[ASRate] parse error : %@",error);
        }
    }];
}

#pragma mark - Action

- (void)didTapMaybeLater
{
    self.shouldShowAgain = YES;
    [self.rateAlertView dismiss];
    if ([self.delegate respondsToSelector:@selector(ASRateDidTapMaybeLaterInRateAlertView)]) {
        [self.delegate ASRateDidTapMaybeLaterInRateAlertView];
    }
}

#pragma mark - UI

- (void)prepareRatingAlertView
{
    // Prepare Rating AlertView
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 140)];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 200, 30)];
    titleLabel.text = @"Please rate this app";
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    [contentView addSubview:titleLabel];
    
    AXRatingView *stepRatingView = [[AXRatingView alloc] initWithFrame:CGRectMake(0, 0, 100, 20)];
    [stepRatingView sizeToFit];
    [stepRatingView setStepInterval:1.0];
    [stepRatingView setMinimumValue:1.0];
    [stepRatingView setValue:0.0];
    [stepRatingView setNumberOfStar:5];
    stepRatingView.baseColor = [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0];
    stepRatingView.delegate = self;
    
    self.ratingView = stepRatingView;
    [contentView addSubview:self.ratingView];
    self.ratingView.center = CGPointMake(contentView.frame.size.width/2.0, titleLabel.center.y + 40);
    
    UIButton *laterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [laterButton setFrame:CGRectMake(0, contentView.frame.size.height-44, contentView.frame.size.width, 44)];
    [laterButton setTitle:@"Maybe Later" forState:UIControlStateNormal];
    [laterButton setTitleColor:[UIColor colorWithRed:0 green:0.478431 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [laterButton.titleLabel setFont:[UIFont systemFontOfSize:17]];
    [laterButton setBackgroundColor:[UIColor clearColor]];
    [laterButton setUserInteractionEnabled:YES];
    [laterButton addTarget:self action:@selector(didTapMaybeLater) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:laterButton];
    
    UIView *seperateView = [[UIView alloc] initWithFrame:CGRectMake(0, laterButton.frame.origin.y, contentView.frame.size.width, 0.5)];
    seperateView.backgroundColor = [UIColor colorWithRed:196.0/255 green:196.0/255 blue:201.0/255 alpha:1.0];
    [contentView addSubview:seperateView];
    
    DQAlertView *rateAlertView = [[DQAlertView alloc] initWithTitle:@"" message:nil cancelButtonTitle:@"Don't Ask Again" otherButtonTitle:nil];
    rateAlertView.contentView = contentView;
    rateAlertView.delegate = self;
    [rateAlertView.cancelButton.titleLabel setFont:[UIFont systemFontOfSize:17]];
    self.rateAlertView = rateAlertView;
    
    __weak typeof(self) this = self;
    this.rateAlertView.cancelButtonAction = ^{
        this.shouldShowAgain = NO;
        [this.rateAlertView dismiss];
        if ([this.delegate respondsToSelector:@selector(ASRateDidTapDontAskInRateAlertView)]) {
            [this.delegate ASRateDidTapDontAskInRateAlertView];
        }
    };
}

- (void)prepareCommentAlertView
{
    // Prepare Rating AlertView
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 170)];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 8, 184, 60)];
    titleLabel.text = @"Thank for your rating.\n Do you want to provide any feedback?";
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont systemFontOfSize:15];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    [contentView addSubview:titleLabel];
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(8, 76, 184, 80)];
    textView.layer.borderColor = [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0].CGColor;
    textView.layer.borderWidth = 0.5;
    textView.font = [UIFont systemFontOfSize:15];
    textView.delegate = self;
    [contentView addSubview:textView];
    
    DQAlertView *commentAlertView = [[DQAlertView alloc] initWithTitle:@"" message:nil cancelButtonTitle:@"Dissmiss" otherButtonTitle:@"Send"];
    commentAlertView.contentView = contentView;
    commentAlertView.delegate = self;
    self.commentAlertView = commentAlertView;
    
    __weak typeof(self) this = self;
    this.commentAlertView.cancelButtonAction = ^{
        [this.commentAlertView dismiss];
        if ([self.delegate respondsToSelector:@selector(ASRateDidTapDismissInCommentAlertView)]) {
            [self.delegate ASRateDidTapDismissInCommentAlertView];
        }
        [this sentParseRateValueWithComment:nil withBlock:^{
            
        }];
    };
    this.commentAlertView.otherButtonAction = ^{
        [this.commentAlertView dismiss];
        if ([this.delegate respondsToSelector:@selector(ASRateUserDidSendCommentWithText:)]) {
            [this.delegate ASRateUserDidSendCommentWithText:textView.text];
        }
        [this sentParseRateValueWithComment:textView.text withBlock:^{
            
        }];
    };
    
}

#pragma mark - Setter Getter

- (NSInteger)sessionCount
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:ASRateSessionCountKey];
}

- (void)setSessionCount:(NSInteger)sessionCount
{
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)sessionCount forKey:ASRateSessionCountKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)shouldShowAgain
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:ASRateShouldShowAgainKey];
}

- (void)setShouldShowAgain:(BOOL)shouldShowAgain
{
    [[NSUserDefaults standardUserDefaults] setInteger:(BOOL)shouldShowAgain forKey:ASRateShouldShowAgainKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)didFirstShow
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:ASRateDidFirstShowKey];
}

- (void)setDidFirstShow:(BOOL)didFirstShow
{
    [[NSUserDefaults standardUserDefaults] setInteger:(BOOL)didFirstShow forKey:ASRateDidFirstShowKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Data

- (void)prepareSessionCount
{
    if (![[NSUserDefaults standardUserDefaults] objectForKey:ASRateSessionCountKey]) {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:ASRateSessionCountKey];
    }
}

- (void)incrementSessionCount
{
    self.sessionCount++;
}

- (void)decrementSessionCount
{
    self.sessionCount--;
}

#pragma mark - Application Notification

- (void)applicationWillEnterForeground
{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
    {
        [self incrementSessionCount];
        [self checkForConnectivityInBackground];
        if ([self shouldAlertRate]) {
            [self showRateView];
        }
    }
}

- (void)applicationDidFinishLaunching
{
    [self incrementSessionCount];
    [self checkForConnectivityInBackground];
    if ([self shouldAlertRate]) {
        [self showRateView];
    }
}

#pragma mark - Rate State

- (void)showRateView
{
    [self.rateAlertView show];
}

- (void)showCommentView
{
    [self.rateAlertView dismiss];
    [self.commentAlertView show];
}

- (BOOL)shouldAlertRate
{
    NSLog(@"[ASRate] sessionCount [%li]",(long)self.sessionCount);
    if (self.sessionCount == self.sessionCountFirstShow) {
        if (!self.didFirstShow) {
            self.didFirstShow = YES;
            return YES;
        } else {
            return NO;
        }
    } else if (self.sessionCount > self.sessionCountFirstShow) {
        if (!self.didFirstShow) {
            return YES;
        } else if (self.shouldShowAgain) {
            if ((self.sessionCount - self.sessionCountFirstShow)%self.sessionCountShowAgain == 0) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)rateWithValue:(float)value
{
    self.ratingValue = value;
    
    if ([self.delegate respondsToSelector:@selector(ASRateUserDidRateWithValue:)]) {
        [self.delegate ASRateUserDidRateWithValue:value];
    }
    
    if (value > 3.0) {
        [self sentParseRateValueWithComment:nil withBlock:^{
            [self openRatingsPageInAppStore];
        }];
    } else {
        [self showCommentView];
    }
    self.shouldShowAgain = NO;
}

#pragma mark - Class from iRate

- (void)openRatingsPageInAppStore
{
    if (!self.appStoreID)
    {
        self.checkingForAppStoreID = YES;
        [self checkForConnectivityInBackground];
        return;
    } else {
        NSString *URLString;
        
        float iOSVersion = [[UIDevice currentDevice].systemVersion floatValue];
        if (iOSVersion >= 7.0f && iOSVersion < 7.1f)
        {
            URLString = ASRateiOS7AppStoreURLFormat;
        }
        else
        {
            URLString = ASRateiOSAppStoreURLFormat;
        }
        
        self.shouldShowAgain = NO;
        [self.rateAlertView dismiss];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:URLString, @(self.appStoreID)]]];
    }
}

- (void)checkForConnectivityInBackground
{
    if ([NSThread isMainThread])
    {
        [self performSelectorInBackground:@selector(checkForConnectivityInBackground) withObject:nil];
        return;
    }
    
    @autoreleasepool
    {
        //prevent concurrent checks
        static BOOL checking = NO;
        if (checking) return;
        checking = YES;
        
        //first check iTunes
        NSString *iTunesServiceURL = [NSString stringWithFormat:ASRateAppLookupURLFormat, self.appStoreCountry];
        if (_appStoreID) //important that we check ivar and not getter in case it has changed
        {
            iTunesServiceURL = [iTunesServiceURL stringByAppendingFormat:@"?id=%@", @(_appStoreID)];
        }
        else
        {
            iTunesServiceURL = [iTunesServiceURL stringByAppendingFormat:@"?bundleId=%@", self.applicationBundleID];
        }
        
        NSError *error = nil;
        NSURLResponse *response = nil;
        NSLog(@"[ASRate] look up url : %@",iTunesServiceURL);
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:iTunesServiceURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:600];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        if (data && statusCode == 200)
        {
            //in case error is garbage...
            error = nil;
            
            id json = nil;
            if ([NSJSONSerialization class])
            {
                json = [[NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:&error][@"results"] lastObject];
            }
            else
            {
                //convert to string
                json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
        
            if (!error)
            {
                //check bundle ID matches
                NSString *bundleID = [self valueForKey:@"bundleId" inJSON:json];
                if (bundleID)
                {
                    if ([bundleID isEqualToString:self.applicationBundleID])
                    {
                        //get genre
                        if (self.appStoreGenreID == 0)
                        {
                            self.appStoreGenreID = [[self valueForKey:@"primaryGenreId" inJSON:json] integerValue];
                        }
                        
                        //get app id
                        if (!_appStoreID)
                        {
                            NSString *appStoreIDString = [self valueForKey:@"trackId" inJSON:json];
                            [self performSelectorOnMainThread:@selector(setAppStoreIDOnMainThread:) withObject:appStoreIDString waitUntilDone:YES];
                        }
                    }
                    else
                    {
                        error = [NSError errorWithDomain:ASRateErrorDomain code:ASRateAppStoreGameGenreID userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Application bundle ID does not match expected value of %@", bundleID]}];
                    }
                } else if (_appStoreID) {
                    NSLog(@"[ASRate] %@",[NSString stringWithFormat:@"Application appstore ID does not match expected value of %lu", (unsigned long)_appStoreID]);
                } else {
                    NSLog(@"[ASRate] can't find bundle id");
                }
            
            }
        }
        else if (statusCode >= 400)
        {
            //http error
            NSString *message = [NSString stringWithFormat:@"The server returned a %@ error", @(statusCode)];
            error = [NSError errorWithDomain:@"HTTPResponseErrorDomain" code:statusCode userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        
        //handle errors (ignoring sandbox issues)
        if (error && !(error.code == EPERM && [error.domain isEqualToString:NSPOSIXErrorDomain] && _appStoreID))
        {
            [self performSelectorOnMainThread:@selector(connectionError:) withObject:error waitUntilDone:YES];
        }
        else if (self.appStoreID)
        {
            //show prompt
            [self performSelectorOnMainThread:@selector(connectionSucceeded) withObject:nil waitUntilDone:YES];
        }
        
        //finished
        checking = NO;
    }
}

- (void)setAppStoreIDOnMainThread:(NSString *)appStoreIDString
{
    _appStoreID = [appStoreIDString integerValue];
    NSLog(@"[ASRate] appstore ID : %@",appStoreIDString);
    [[NSUserDefaults standardUserDefaults] setInteger:_appStoreID forKey:ASRateAppStoreIDKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)connectionSucceeded
{
    if (self.checkingForAppStoreID)
    {
        //no longer checking
        self.checkingForAppStoreID = NO;
        
        //open app store
        [self openRatingsPageInAppStore];
    }
}

- (void)connectionError:(NSError *)error
{
    if (self.checkingForAppStoreID)
    {
        //no longer checking
        self.checkingForAppStoreID = NO;
        
        //log the error
        if (error)
        {
            NSLog(@"[ASRate] rating process failed because: %@", [error localizedDescription]);
        }
        else
        {
            NSLog(@"[ASRate] rating process failed because an unknown error occured");
        }
    }
}

- (NSString *)valueForKey:(NSString *)key inJSON:(id)json
{
    if ([json isKindOfClass:[NSString class]])
    {
        //use legacy parser
        NSRange keyRange = [json rangeOfString:[NSString stringWithFormat:@"\"%@\"", key]];
        if (keyRange.location != NSNotFound)
        {
            NSInteger start = keyRange.location + keyRange.length;
            NSRange valueStart = [json rangeOfString:@":" options:(NSStringCompareOptions)0 range:NSMakeRange(start, [(NSString *)json length] - start)];
            if (valueStart.location != NSNotFound)
            {
                start = valueStart.location + 1;
                NSRange valueEnd = [json rangeOfString:@"," options:(NSStringCompareOptions)0 range:NSMakeRange(start, [(NSString *)json length] - start)];
                if (valueEnd.location != NSNotFound)
                {
                    NSString *value = [json substringWithRange:NSMakeRange(start, valueEnd.location - start)];
                    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    while ([value hasPrefix:@"\""] && ![value hasSuffix:@"\""])
                    {
                        if (valueEnd.location == NSNotFound)
                        {
                            break;
                        }
                        NSInteger newStart = valueEnd.location + 1;
                        valueEnd = [json rangeOfString:@"," options:(NSStringCompareOptions)0 range:NSMakeRange(newStart, [(NSString *)json length] - newStart)];
                        value = [json substringWithRange:NSMakeRange(start, valueEnd.location - start)];
                        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    }
                    
                    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
                    value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
                    value = [value stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
                    value = [value stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
                    value = [value stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
                    value = [value stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
                    value = [value stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
                    value = [value stringByReplacingOccurrencesOfString:@"\\f" withString:@"\f"];
                    value = [value stringByReplacingOccurrencesOfString:@"\\b" withString:@"\f"];
                    
                    while (YES)
                    {
                        NSRange unicode = [value rangeOfString:@"\\u"];
                        if (unicode.location == NSNotFound || unicode.location + unicode.length == 0)
                        {
                            break;
                        }
                        
                        uint32_t c = 0;
                        NSString *hex = [value substringWithRange:NSMakeRange(unicode.location + 2, 4)];
                        NSScanner *scanner = [NSScanner scannerWithString:hex];
                        [scanner scanHexInt:&c];
                        
                        if (c <= 0xffff)
                        {
                            value = [value stringByReplacingCharactersInRange:NSMakeRange(unicode.location, 6) withString:[NSString stringWithFormat:@"%C", (unichar)c]];
                        }
                        else
                        {
                            //convert character to surrogate pair
                            uint16_t x = (uint16_t)c;
                            uint16_t u = (c >> 16) & ((1 << 5) - 1);
                            uint16_t w = (uint16_t)u - 1;
                            unichar high = 0xd800 | (w << 6) | x >> 10;
                            unichar low = (uint16_t)(0xdc00 | (x & ((1 << 10) - 1)));
                            
                            value = [value stringByReplacingCharactersInRange:NSMakeRange(unicode.location, 6) withString:[NSString stringWithFormat:@"%C%C", high, low]];
                        }
                    }
                    return value;
                }
            }
        }
    }
    else
    {
        return json[key];
    }
    return nil;
}

#pragma mark - AXRatingViewDelegate

- (void)axRatingViewDidEndChangeValue
{
    [self rateWithValue:self.ratingView.value];
}

#pragma mark - DQAlertViewDelegate

- (void)didAppearAlertView:(DQAlertView *)alertView
{
    if (alertView == self.commentAlertView) {
        centerAlert = self.commentAlertView.center;
        if ([self.delegate respondsToSelector:@selector(ASRateDidShowRateAlertView)]) {
            [self.delegate ASRateDidShowRateAlertView];
        }
    } else if (alertView == self.rateAlertView) {
        if ([self.delegate respondsToSelector:@selector(ASRateDidShowCommentAlertView)]) {
            [self.delegate ASRateDidShowCommentAlertView];
        }
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    CGPoint center = self.commentAlertView.center;
    center.y = center.y - 120.0;
    
    __weak typeof(self) this = self;
    [UIView animateWithDuration:0.2 animations:^{
        this.commentAlertView.center = center;
    } completion:^(BOOL finished) {
        
    }];
}

@end
