//
//  ASAppDelegate.m
//  ASRate
//
//  Created by CocoaPods on 06/24/2015.
//  Copyright (c) 2014 Yor. All rights reserved.
//

#import "ASAppDelegate.h"

#import <ASRate/ASRate.h>

@interface ASAppDelegate () <ASRateDelegate>

@end

#define YOUR_PARSE_APPID       @""
#define YOUR_PARSE_CLIENTID    @""

@implementation ASAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    // Init with your parse app id and client id
    [[ASRate sharedInstance] setParseApplicationId:YOUR_PARSE_APPID ParseClientKey:YOUR_PARSE_CLIENTID];
    // Set first show session. Default is 5
    [ASRate sharedInstance].sessionCountFirstShow = 5;
    // Set show again session. Default is 10
    [ASRate sharedInstance].sessionCountShowAgain = 10;
    // Set delegate if you want
    [ASRate sharedInstance].delegate = self;
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
