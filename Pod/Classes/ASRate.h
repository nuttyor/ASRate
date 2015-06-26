//
//  ASRate.h
//  ASRate
//
//  Created by Yor on 6/24/15.
//  Copyright (c) 2015 Yor. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ASRateDelegate <NSObject>
@optional
- (void)ASRateDidShowRateAlertView;
- (void)ASRateDidTapMaybeLaterInRateAlertView;
- (void)ASRateDidTapDontAskInRateAlertView;
- (void)ASRateDidShowCommentAlertView;
- (void)ASRateDidTapDismissInCommentAlertView;
- (void)ASRateUserDidRateWithValue:(float)value;
- (void)ASRateUserDidSendCommentWithText:(NSString *)comment;

@end

@interface ASRate : NSObject

+ (instancetype)sharedInstance;

/*
 * Set parse applicationId and client key
 * You should assign when launch app
 */
- (void)setParseApplicationId:(NSString *)applicationId ParseClientKey:(NSString *)clientKey;

//app store ID - this is only needed if your
//bundle ID is not unique between iOS and Mac app stores
//Assign this if app you want to go is not the same as your bundleID
@property (nonatomic, assign) NSUInteger appStoreID;
// Default is set same as your bundle id
@property (copy, nonatomic) NSString *applicationBundleID;

//application details - these are set automatically
@property (nonatomic, assign) NSUInteger appStoreGenreID;
@property (nonatomic, copy) NSString *appStoreCountry;
@property (nonatomic, copy) NSString *applicationName;

// Limit session you want to show first alert view. Default is 5
@property (assign, nonatomic) NSInteger sessionCountFirstShow;

// Limit session you want to show after user did choose "Maybe Later". Default is 10
@property (assign, nonatomic) NSInteger sessionCountShowAgain;

/*
 * Use when want to forced rate view alert to show or not after it was appeared first time.
 */
@property (assign, nonatomic) BOOL shouldShowAgain;

@property (strong, nonatomic) id<ASRateDelegate> delegate;

@end
