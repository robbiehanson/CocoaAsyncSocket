// Copyright 2011 Pol-Online

#import "HTTPConnection.h"

@interface DAVConnection : HTTPConnection {
	id requestContentBody;
  NSOutputStream* requestContentStream;
}
@end
