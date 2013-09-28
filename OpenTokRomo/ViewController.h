//
//  ViewController.h
//  OpenTokRomo
//
//  Created by Song Zheng on 9/28/13.
//  Copyright (c) 2013 Song Zheng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Opentok/Opentok.h>
#import <RMCore/RMCore.h>

@interface ViewController : UIViewController <OTSessionDelegate, OTSubscriberDelegate, OTPublisherDelegate, RMCoreDelegate, UIGestureRecognizerDelegate>
- (void)doConnect;
- (void)doPublish;
- (void)showAlert:(NSString*)string;
@property (strong, nonatomic) IBOutlet UIView *videoContainerView;

@property (nonatomic, strong) RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol> *robot;

@end
