//
//  RSSParser.h
//  RackspaceCloud
//
//  Created by Michael Mayo on 1/28/10.
//  Copyright Rackspace Hosting 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FeedItem;

@interface RSSParser : NSObject {
	NSMutableString *currentElementValue;
	NSString *currentDataType;
	FeedItem *feedItem;
	NSMutableArray *feedItems;
	BOOL parsingItem;
    BOOL parsingContent;
}

@property (nonatomic, retain) FeedItem *feedItem;
@property (nonatomic, retain) NSString *currentDataType;
@property (nonatomic, retain) NSMutableArray *feedItems;

@end
