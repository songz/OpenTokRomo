//
//  ViewController.m
//  OpenTokRomo
//
//  Created by Charley Robinson on 12/13/11.
//  Copyright (c) 2011 Tokbox, Inc. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController {
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    NSDictionary* roomInfo;
}

static bool subscribeToSelf = NO; // Change to NO if you want to subscribe to streams other than your own.
@synthesize videoContainerView;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSLog(@"robot is set delegate");
    [RMCore setDelegate:self];
    
    
}


- (void)viewDidAppear:(BOOL)animated {
    NSString* roomInfoUrl = @"http://opentokromo.herokuapp.com/romogen";
    NSURL *url = [NSURL URLWithString: roomInfoUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setHTTPMethod: @"GET"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if (error){
            //NSLog(@"Error,%@", [error localizedDescription]);
        }
        else{
            roomInfo = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            
            _session = [[OTSession alloc] initWithSessionId: roomInfo[@"sid"]
                                                   delegate:self];
            [self doConnect];
        }
    }];
}


- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // Currently the only kind of robot is Romo3, so this is just future-proofing
    if (robot.isDrivable && robot.isHeadTiltable && robot.isLEDEquipped) {
        self.robot = (RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol> *) robot;
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.robot) {
        self.robot = nil;
    }
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return NO;
    } else {
        return YES;
    }
}

- (void)updateSubscriber {
    for (NSString* streamId in _session.streams) {
        OTStream* stream = [_session.streams valueForKey:streamId];
        if (![stream.connection.connectionId isEqualToString: _session.connection.connectionId]) {
            _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
            break;
        }
    }
}

#pragma mark - OpenTok methods

- (void)doConnect
{
    [_session connectWithApiKey:roomInfo[@"apiKey"] token:roomInfo[@"token"]];
    [_session receiveSignalType:@"control" withHandler:^(NSString *type, id data, OTConnection *fromConnection){
        
        int command = [(NSString* )data intValue];
        
        if (!self.robot) {
            [self showAlert: [[NSString alloc] initWithFormat:@"Please connect romo, command received: %d", command]  ];
            return;
        }
        
        switch ( [(NSString* )data intValue] )
        {
            case 37:
                NSLog (@"left");
                [self.robot turnByAngle:23.0
                             withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                             completion:^(float heading) {
                                 NSLog(@"Finished! Ended up at heading: %f", heading);
                             }];
                break;
            case 38:
                [self.robot driveForwardWithSpeed:1.0];
                break;
            case 39:
                [self.robot turnByAngle:-23.0
                             withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                             completion:^(float heading) {
                                 NSLog(@"Finished! Ended up at heading: %f", heading);
                             }];
                break;
            case 40:
                [self.robot driveBackwardWithSpeed:1.0];
                break;
            case 87:
            case 188:
                [self.robot tiltByAngle:15
                             completion:^(BOOL success) {
                                 if (success) {
                                     NSLog(@"Successfully tilted");
                                 } else {
                                     NSLog(@"Couldn't tilt to the desired angle");
                                 }
                             }];
                break;
            case 83:
            case 79:
                
                [self.robot tiltByAngle:-15
                             completion:^(BOOL success) {
                                 if (success) {
                                     NSLog(@"Successfully tilted");
                                 } else {
                                     NSLog(@"Couldn't tilt to the desired angle");
                                 }
                             }];
                break;
            case 32:
                [self.robot stopAllMotion];
                break;
            default:
                NSLog (@"Integer out of range");
                break;
        }
    }];
}

- (void)doPublish
{
    // get screen bounds
    float width = self.view.frame.size.width;
    float height = self.view.frame.size.height;
    
    // create publisher and style publisher
    _publisher = [[OTPublisher alloc] initWithDelegate:self];
    [_publisher setName:[[UIDevice currentDevice] name]];
    float diameter = 120.0;
    [_publisher.view setFrame:CGRectMake( (width/2.0-60.0), height-140, diameter, diameter)];
    _publisher.view.layer.cornerRadius = diameter/2.0;
    
    UIPanGestureRecognizer *pgr = [[UIPanGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(handlePan:)];
    [_publisher.view addGestureRecognizer:pgr];
    pgr.delegate = self;
    _publisher.view.userInteractionEnabled = YES;
    _publisher.view.layer.zPosition = 3;
    
    
    [self.view addSubview:_publisher.view];
    
    [_session publish: _publisher];
}

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    [self doPublish];
}


- (void)session:(OTSession*)mySession didReceiveStream:(OTStream*)stream
{
    NSLog(@"session didReceiveStream (%@)", stream.streamId);
    
    // See the declaration of subscribeToSelf above.
    if( ![stream.connection.connectionId isEqualToString: _session.connection.connectionId]){
        _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    }
}


- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage = [NSString stringWithFormat:@"Session disconnected: (%@)", session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
    [self showAlert:alertMessage];
}



- (void)session:(OTSession*)session didDropStream:(OTStream*)stream{
    NSLog(@"session didDropStream (%@)", stream.streamId);
    NSLog(@"_subscriber.stream.streamId (%@)", _subscriber.stream.streamId);
    if (!subscribeToSelf
        && _subscriber
        && [_subscriber.stream.streamId isEqualToString: stream.streamId])
    {
        _subscriber = nil;
        [self updateSubscriber];
    }
}

- (void)subscriberDidConnectToStream:(OTSubscriber*)subscriber
{
    CGFloat containerWidth = CGRectGetWidth( videoContainerView.bounds );
    CGFloat containerHeight = CGRectGetHeight( videoContainerView.bounds );
    [_subscriber.view setFrame:CGRectMake( 0, 0, containerWidth, containerHeight)];
    [videoContainerView addSubview:_subscriber.view];
}

- (void)publisher:(OTPublisher*)publisher didFailWithError:(OTError*) error {
    NSLog(@"publisher didFailWithError %@", error);
    [self showAlert:[NSString stringWithFormat:@"There was an error publishing."]];
}

- (void)subscriber:(OTSubscriber*)subscriber didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@", subscriber.stream.streamId, error);
    [self showAlert:[NSString stringWithFormat:@"There was an error subscribing to stream %@", subscriber.stream.streamId]];
}

- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
    NSLog(@"sessionDidFail");
    [self showAlert:[NSString stringWithFormat:@"There was an error connecting to session %@", session.sessionId]];
}


- (void)showAlert:(NSString*)string {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from video session"
                                                    message:string
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (IBAction)handlePan:(UIPanGestureRecognizer *)recognizer{
    // user is panning publisher object
    CGPoint translation = [recognizer translationInView:_publisher.view];
    recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                         recognizer.view.center.y + translation.y);
    [recognizer setTranslation:CGPointMake(0, 0) inView:_publisher.view];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    return YES;
}
- (void)viewTapped:(UITapGestureRecognizer *)tgr
{
}

@end

