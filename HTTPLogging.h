/**
 * In order to provide fast and flexible logging, this project uses Cocoa Lumberjack.
 * 
 * The Google Code page has a wealth of documentation if you have any questions.
 * http://code.google.com/p/cocoalumberjack/
 * 
 * Here's what you need to know concerning how logging is setup for CocoaHTTPServer:
 * 
 * There are 4 log levels:
 * - Error
 * - Warning
 * - Info
 * - Verbose
 * 
 * In addition to this, there is a Trace flag that can be enabled.
 * When tracing is enabled, it spits out the methods that are being called.
 * 
 * Please note that tracing is separate from the log levels.
 * For example, one could set the log level to warning, and enable tracing.
 * 
 * All logging is asynchronous, except errors.
 * To use logging within your own custom files, follow the steps below.
 * 
 * Step 1:
 * Import this header in your implementation file:
 * 
 * #import "HTTPLogging.h"
 * 
 * Step 2:
 * Define your logging level in your implementation file:
 * 
 * // Log levels: off, error, warn, info, verbose
 * static const int httpLogLevel = LOG_LEVEL_VERBOSE;
 * 
 * If you wish to enable tracing, you could do something like this:
 * 
 * // Debug levels: off, error, warn, info, verbose
 * static const int httpLogLevel = LOG_LEVEL_INFO | LOG_FLAG_TRACE;
 * 
 * Step 3:
 * Replace your NSLog statements with HTTPLog statements according to the severity of the message.
 * 
 * NSLog(@"Fatal error, no dohickey found!"); -> HTTPLogError(@"Fatal error, no dohickey found!");
 * 
 * HTTPLog works exactly the same as NSLog.
 * This means you can pass it multiple variables just like NSLog.
**/

#import "DDLog.h"

#define HTTP_LOG_CONTEXT 80

#define HTTP_LOG_ERROR   (httpLogLevel & LOG_FLAG_ERROR)
#define HTTP_LOG_WARN    (httpLogLevel & LOG_FLAG_WARN)
#define HTTP_LOG_INFO    (httpLogLevel & LOG_FLAG_INFO)
#define HTTP_LOG_VERBOSE (httpLogLevel & LOG_FLAG_VERBOSE)

#define HTTPLogError(frmt, ...)    SYNC_LOG_OBJC_MAYBE(httpLogLevel, LOG_FLAG_ERROR,  \
                                                       HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define HTTPLogWarn(frmt, ...)    ASYNC_LOG_OBJC_MAYBE(httpLogLevel, LOG_FLAG_WARN,   \
                                                       HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define HTTPLogInfo(frmt, ...)    ASYNC_LOG_OBJC_MAYBE(httpLogLevel, LOG_FLAG_INFO,    \
                                                       HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define HTTPLogVerbose(frmt, ...) ASYNC_LOG_OBJC_MAYBE(httpLogLevel, LOG_FLAG_VERBOSE, \
                                                       HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)


#define HTTPLogCError(frmt, ...)    SYNC_LOG_C_MAYBE(httpLogLevel, LOG_FLAG_ERROR,   \
                                                     HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define HTTPLogCWarn(frmt, ...)    ASYNC_LOG_C_MAYBE(httpLogLevel, LOG_FLAG_WARN,    \
                                                     HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define HTTPLogCInfo(frmt, ...)    ASYNC_LOG_C_MAYBE(httpLogLevel, LOG_FLAG_INFO,    \
                                                     HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define HTTPLogCVerbose(frmt, ...) ASYNC_LOG_C_MAYBE(httpLogLevel, LOG_FLAG_VERBOSE, \
                                                     HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

// Fine grained logging
// The first 4 bits are being used by the standard log levels (0 - 3)

#define LOG_FLAG_TRACE (1 << 4)

#define HTTPLogTrace()            ASYNC_LOG_OBJC_MAYBE(httpLogLevel, LOG_FLAG_TRACE, \
                                                       HTTP_LOG_CONTEXT, @"%@[%p]: %@", THIS_FILE, self, THIS_METHOD)

#define HTTPLogTrace2(frmt, ...)  ASYNC_LOG_OBJC_MAYBE(httpLogLevel, LOG_FLAG_TRACE, \
                                                       HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define HTTPLogCTrace()           ASYNC_LOG_C_MAYBE(httpLogLevel, LOG_FLAG_TRACE, \
                                                    HTTP_LOG_CONTEXT, @"%@[%p]: %@", THIS_FILE, self, __FUNCTION__)

#define HTTPLogCTrace2(frmt, ...) ASYNC_LOG_C_MAYBE(httpLogLevel, LOG_FLAG_TRACE, \
                                                    HTTP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

