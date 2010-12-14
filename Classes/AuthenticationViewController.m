    //
//  AuthenticationViewController.m
//  RackspaceCloud
//
//  Created by Michael Mayo on 1/27/10.
//  Copyright Rackspace Hosting 2010. All rights reserved.
//

#import "AuthenticationViewController.h"
#import "ASICloudFilesRequest.h"
#import "RackspaceCloudAppDelegate.h"
#import "ASICloudServersImageRequest.h"
#import "ASICloudServersFlavorRequest.h"
#import "UIViewController+SpinnerView.h"
#import "FeedItem.h"
#import "AtomParser.h"
#import "RSSParser.h"
#import "RSSTableViewDelegateAndDataSource.h"

@implementation AuthenticationViewController

@synthesize smallSpinner, largeSpinner;
@synthesize smallAuthenticatingLabel, largeAuthenticatingLabel;
@synthesize usernameTextField, apiKeyTextField;
@synthesize statusButton, statusScrollView;
@synthesize statusView;
@synthesize statusToolbar;
@synthesize tableView;
@synthesize tableViewDelegate;

#pragma mark -
#pragma mark HTTP Requests

-(void)loadFlavors {
	ASICloudServersFlavorRequest *flavorRequest = [ASICloudServersFlavorRequest listRequest];
	[flavorRequest setDelegate:self];
	[flavorRequest setDidFinishSelector:@selector(flavorListRequestFinished:)];
	[flavorRequest setDidFailSelector:@selector(flavorListRequestFailed:)];
	[flavorRequest startAsynchronous];
}

-(void)loadImages {
	ASICloudServersImageRequest *imageRequest = [ASICloudServersImageRequest listRequest];
	[imageRequest setDelegate:self];
	[imageRequest setDidFinishSelector:@selector(imageListRequestFinished:)];
	[imageRequest setDidFailSelector:@selector(imageListRequestFailed:)];
	[imageRequest startAsynchronous];
}

#pragma mark -
#pragma mark View Lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	// we'll try up to three times to load flavors and images
	imageLoadAttempts = 0;
	flavorLoadAttempts = 0;
	
    // turn the toolbar 90 degrees
	CGAffineTransform transform = self.statusToolbar.transform;
	self.statusToolbar.transform = CGAffineTransformRotate(transform, 4.71238898);
	
	statusView.backgroundColor = [UIColor clearColor];
	self.tableView.backgroundView = nil; // clear background
	self.tableViewDelegate = [[RSSTableViewDelegateAndDataSource alloc] initWithTableView:self.tableView];
	self.tableView.delegate = self.tableViewDelegate;
	self.tableView.dataSource = self.tableViewDelegate;
    
    // kill me now
    [self.view.superview retain];
    
}

- (void)viewWillAppear:(BOOL)animated {	
	[self loadSettings];
	[super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Override to allow orientations other than the default portrait orientation.
    // only show cool status view in landscape.  looks weird in portrait
    self.statusView.hidden = (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
    return YES;
}


#pragma mark -
#pragma mark Utilities

-(void)loadSettings {
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
	username = [defaults stringForKey:@"username_preference"];
	apiKey = [defaults stringForKey:@"api_key_preference"];
    
    // we don't actually need the lock password here, but it's introduced in version 1.1,
    // so we're going to see if it exists so we can register the new 1.1 preferences
    NSString *lockPassword = [defaults stringForKey:@"lock_password"];
    
    RackspaceCloudAppDelegate *app = [[UIApplication sharedApplication] delegate];
    if (lockPassword == nil || [lockPassword isEqualToString:@""]) {
        app.isPasswordLocked = NO;
    } else {
        app.isPasswordLocked = YES;
    }
	
	if (username == nil) {
		username = @"";
		apiKey = @"";
		
		// settings haven't been created, so let's create them here
		NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
									 @"", @"username_preference",
									 @"", @"api_key_preference",
                                     [NSNumber numberWithBool:NO], @"password_lock_enabled",
                                     @"", @"lock_password",
                                     [NSDictionary dictionary], @"secondary_accounts",
									 nil];
		[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
		[[NSUserDefaults standardUserDefaults] synchronize];
	} else if (lockPassword == nil) {
		// settings haven't been created, so let's create them here
		NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
									 username, @"username_preference",
									 apiKey, @"api_key_preference",
                                     [NSNumber numberWithBool:NO], @"password_lock_enabled",
                                     @"", @"lock_password",
                                     [NSDictionary dictionary], @"secondary_accounts",
									 nil];
		[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
		[[NSUserDefaults standardUserDefaults] synchronize];
    }
	
	self.usernameTextField.text = username;
	self.apiKeyTextField.text = apiKey;
}

-(void)hideSpinners {
	self.smallAuthenticatingLabel.text = @"";
	self.smallAuthenticatingLabel.hidden = YES;
	[self.smallSpinner stopAnimating];
}

#pragma mark -
#pragma mark Animations

-(void)transitionComplete {
	[self.view removeFromSuperview];
}

-(void)transitionToAppView {
	RackspaceCloudAppDelegate *app = [[UIApplication sharedApplication] delegate];
	[app.window addSubview:app.splitViewController.view];	
    [self.view removeFromSuperview];
}

#pragma mark -
#pragma mark HTTP Response Handlers

-(void)flavorListRequestFinished:(ASICloudServersFlavorRequest *)request {
	[self hideSpinners];	
	[ASICloudServersFlavorRequest setFlavors:[request flavors]];
	
	// we're done.  now let's get to the app
	[self transitionToAppView];
}

-(void)flavorListRequestFailed:(ASIHTTPRequest *)request {
	flavorLoadAttempts++;
	if (flavorLoadAttempts < 3) {
		// try again
		[self loadFlavors];
	} else {
		[self alertForCloudServersResponseStatusCode:[request responseStatusCode] behavior:@"loading server flavors"];
		[self hideSpinners];
	}
}

-(void)imageListRequestFinished:(ASICloudServersImageRequest *)request {
	[ASICloudServersImageRequest setImages:[request images]];
	self.smallAuthenticatingLabel.text = @"Loading server flavors...";
	[self loadFlavors];
}

-(void)imageListRequestFailed:(ASIHTTPRequest *)request {
	imageLoadAttempts++;
	if (imageLoadAttempts < 3) {
		// try again
		[self loadImages];
	} else {
		[self alertForCloudServersResponseStatusCode:[request responseStatusCode] behavior:@"loading server images"];
		[self hideSpinners];
	}
	
}

-(void)authenticationRequestFinished:(ASICloudFilesRequest *)request {
	if ([request isSuccess]) {
		NSDictionary *responseHeaders = [request responseHeaders];
		[ASICloudFilesRequest setAuthToken:[responseHeaders objectForKey:@"X-Auth-Token"]];
		[ASICloudFilesRequest setStorageURL:[responseHeaders objectForKey:@"X-Storage-Url"]];
		[ASICloudFilesRequest setCdnManagementURL:[responseHeaders objectForKey:@"X-Cdn-Management-Url"]];
		[ASICloudFilesRequest setServerManagementURL:[responseHeaders objectForKey:@"X-Server-Management-Url"]];	
		self.smallAuthenticatingLabel.text = @"Loading server images...";
                
		[self loadImages];
	} else {
		[self alertForCloudServersResponseStatusCode:[request responseStatusCode] behavior:@"authenticating"];
		[self hideSpinners];
	}	
}

-(void)authenticationRequestFailed:(ASIHTTPRequest *)request {

	[self hideSpinners];
	
	NSString *title = @"";
	NSString *message = @"";
	
	if ([request responseStatusCode] == 401) {
		title = @"Authentication Failure";
		message = @"Please check your User Name and API Key.";
	} else {
		title = @"Connection Failure";
		message = @"Please check your connection and try again.";
	}
	
	[self alert:title message:message];
	self.smallAuthenticatingLabel.text = @"";
	
}

#pragma mark -
#pragma mark Button Handlers

-(void)loginButtonPressed:(id)sender {
	
	// validate input
	username = self.usernameTextField.text;
	apiKey = self.apiKeyTextField.text;
	
	if ([username isEqualToString:@""] || [apiKey isEqualToString:@""]) {
		[self alert:@"Required Fields Missing" message:@"Please enter your Rackspace Cloud User Name and API Key."];
	} else {
		
		// save to defaults
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
		[defaults setObject:username forKey:@"username_preference"];
		[defaults setObject:apiKey forKey:@"api_key_preference"];
		
		self.smallAuthenticatingLabel.text = @"Authenticating...";
		
		// attempt to login
		self.smallAuthenticatingLabel.hidden = NO;
		[self.smallSpinner startAnimating];
		
		[ASICloudFilesRequest setUsername:username];
		[ASICloudFilesRequest setApiKey:apiKey];
		ASICloudFilesRequest *request = [ASICloudFilesRequest authenticationRequest];
		[request setDelegate:self];
		[request setDidFinishSelector:@selector(authenticationRequestFinished:)];
		[request setDidFailSelector:@selector(authenticationRequestFailed:)];
		[request startAsynchronous];
	}
	
}


#pragma mark -
#pragma mark System Status Support

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {	
	for (UITouch *touch in touches) {
		CGPoint newPosition = [touch locationInView:self.statusView];		
		if (newPosition.x >= 0) {
			dragging = YES;
			if (CGRectContainsPoint(self.statusView.frame, newPosition)) {
				startPosition = newPosition;
				break; // only care about the first touch
			}
		}
	}	
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (dragging) {
		for (UITouch *touch in touches) {
			CGPoint windowPosition = [touch locationInView:self.view];
			CGRect rect = self.statusView.frame;
			float newX = rect.origin.x - (rect.origin.x - windowPosition.x);
			
			if (newX >= 270.0 && newX <= 980.0) {
				rect.origin.x = newX;
				startPosition = windowPosition;
				self.statusView.frame = rect;
			}
			break; // only care about the first touch
		}		
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	CGRect rect = self.statusView.frame;
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.25];
	[UIView setAnimationDelegate:self];
	if (statusViewExpanded) {
		if (rect.origin.x > 300.0) {
			rect.origin.x = 980.0;
			statusViewExpanded = NO;
		} else {
			rect.origin.x = 270.0;
			statusViewExpanded = YES;
		}
	} else {
		if (rect.origin.x < 889.0) {
			rect.origin.x = 270.0;
			statusViewExpanded = YES;
		} else {
			rect.origin.x = 980.0;
			statusViewExpanded = NO;
		}
	}
	self.statusView.frame = rect;
	dragging = NO;
	[UIView commitAnimations];
}

#pragma mark -
#pragma mark Memory Management

- (void)dealloc {
	[smallSpinner release];
	[largeSpinner release];
	[smallAuthenticatingLabel release];
	[largeAuthenticatingLabel release];
	[usernameTextField release];
	[apiKeyTextField release];
	
	[statusButton release];
	[statusScrollView release];
	[statusView release];
	[statusToolbar release];
	[tableView release];	
	[tableViewDelegate release];
	
    [super dealloc];
}

@end
