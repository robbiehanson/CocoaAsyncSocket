// Copyright 2011 Pol-Online

#import "HTTPResponse.h"

@interface DELETEResponse : NSObject <HTTPResponse> {
  NSInteger _status;
}
- (id) initWithFilePath:(NSString*)path;
@end
