//
//  UIViewController+RackspaceCloud.m
//
//  Created by Michael Mayo on 2/19/10.
//  Copyright Rackspace Hosting 2010. All rights reserved.
//

#import "UIViewController+RackspaceCloud.h"
#import "UIViewController+SpinnerView.h"
#import "ASICloudFilesRequest.h"


@implementation UIViewController (RackspaceCloud)

-(void)request:(ASICloudFilesRequest *)request behavior:(NSString *)behavior success:(SEL)success showSpinner:(BOOL)showSpinner {
    [self request:request behavior:behavior success:success failure:nil showSpinner:showSpinner];
}

-(void)request:(ASICloudFilesRequest *)request behavior:(NSString *)behavior success:(SEL)success failure:(SEL)failure showSpinner:(BOOL)showSpinner {
    // retain the delegate to prevent bad access if the view controller goes away
    [self retain];
    
    if (showSpinner) {
    	[self showSpinnerView];
    }
	[request setDelegate:self];
    if (failure != nil) {
        request.userInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:behavior, NSStringFromSelector(success), NSStringFromSelector(failure), [NSNumber numberWithBool:showSpinner], nil] forKeys:[NSArray arrayWithObjects:@"behavior", @"success", @"failure", @"showSpinner", nil]];
    } else {
        request.userInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:behavior, NSStringFromSelector(success), [NSNumber numberWithBool:showSpinner], nil] forKeys:[NSArray arrayWithObjects:@"behavior", @"success", @"showSpinner", nil]];
    }
	[request startAsynchronous];    
}

-(void)request:(ASICloudFilesRequest *)request behavior:(NSString *)behavior success:(SEL)success {
    [self request:request behavior:behavior success:success showSpinner:YES];
}

-(void)request:(ASICloudFilesRequest *)request behavior:(NSString *)behavior success:(SEL)success failure:(SEL)failure {
    [self request:request behavior:behavior success:success failure:failure showSpinner:YES];
}

-(void)requestFinished:(ASICloudFilesRequest *)request {
    if ([[request.userInfo objectForKey:@"behavior"] boolValue]) {
    	[self hideSpinnerView];	
    }
	if ([request isSuccess]) {
        SEL selector = NSSelectorFromString([request.userInfo objectForKey:@"success"]);
        if ([self respondsToSelector:selector]) {
            NSMethodSignature *signature = [self methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:self];
            [invocation setSelector:selector];
            [invocation setArgument:&request atIndex:2]; // 0 and 1 are hidden/reserved
            [invocation invoke];
        }		
	} else {
		[self hideSpinnerView];	
		if ([[request.userInfo objectForKey:@"behavior"] boolValue]) {
			[self alertForCloudServersResponseStatusCode:[request responseStatusCode] behavior:[request.userInfo objectForKey:@"behavior"]];
		}
	}  
    [self release];
}

-(void)requestFailed:(ASICloudFilesRequest *)request {
    SEL selector = NSSelectorFromString([request.userInfo objectForKey:@"failure"]);
    if ([self respondsToSelector:selector]) {
        NSMethodSignature *signature = [self methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:selector];
        [invocation setArgument:&request atIndex:2]; // 0 and 1 are hidden/reserved
        [invocation invoke];
    } else {
        [self hideSpinnerView];
        if ([[request.userInfo objectForKey:@"behavior"] boolValue]) {
            [self alertForCloudServersResponseStatusCode:[request responseStatusCode] behavior:[request.userInfo objectForKey:@"behavior"]];
        }
    }
        
    [self release];
}


@end
