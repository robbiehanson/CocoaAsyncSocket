//  
//  GCDAsyncUdpSocket
//  
//  This class is in the public domain.
//  Originally created by Robbie Hanson of Deusty LLC.
//  Updated and maintained by Deusty LLC and the Apple development community.
//  
//  http://code.google.com/p/cocoaasyncsocket/
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>


extern NSString *const GCDAsyncUdpSocketException;
extern NSString *const GCDAsyncUdpSocketErrorDomain;

enum GCDAsyncUdpSocketError
{
	GCDAsyncUdpSocketNoError = 0,          // Never used
	GCDAsyncUdpSocketBadConfigError,       // Invalid configuration
	GCDAsyncUdpSocketBadParamError,        // Invalid parameter was passed
	GCDAsyncUdpSocketSendTimeoutError,     // A send operation timed out
	GCDAsyncUdpSocketClosedError,          // The socket was closed
	GCDAsyncUdpSocketOtherError,           // Description provided in userInfo
};
typedef enum GCDAsyncUdpSocketError GCDAsyncUdpSocketError;

/**
 * You may optionally set a receive filter for the socket.
 * This receive filter may be set to run in its own queue (independent of delegate queue).
 * 
 * A filter can provide several useful features.
 * 
 * 1. Many times udp packets are discarded because they are duplicate/unneeded/unsolicited.
 *    The filter can prevent such packets from arriving at the delegate.
 *    And because the filter can run in its own independent queue, this doesn't slow down the delegate.
 * 
 *    - Since the udp protocol does not guarnatee delivery, udp packets may be lost.
 *      Many protocols built atop udp thus provide various resend/re-request algorithms.
 *      This sometimes results in duplicate packets arriving.
 *    
 *    - Since the udp socket may be connectionless, its possible for unsolicited packets to arrive.
 *      Such packets need to be ignored.
 *    
 * 2. Many times udp packets need to be parsed.
 *    Since the filter can run in its own independent queue, you can parallelize this parsing quite easily.
 * 
 * 
 * @param data    - The packet that was received.
 * @param address - The address the data was received from.
 *                  See utilities section for methods to extract info from address.
 * @param context - Out parameter you may optionally set, which will then be passed to the delegate method.
 *                  For example, filter block can parse the data and then,
 *                  pass the parsed data to the delegate.
 * 
 * @returns - YES if the received packet should be passed onto the delegate.
 *            NO if the received packet should be discarded, and not reported to the delegete.
 * 
 * Example:
 * 
 * GCDAsyncUdpSocketReceiveFilterBlock filter = ^BOOL (NSData *data, NSData *address, id *context) {
 * 
 *     MyProtocolMessage *msg = [MyProtocol parseMessage:msg];
 *     
 *     *context = response;
 *     return (response != nil);
 * };
 * [udpSocket setReceiveFilter:filter withQueue:myParsingQueue];
 * 
**/
typedef BOOL (^GCDAsyncUdpSocketReceiveFilterBlock)(NSData *data, NSData *address, id *context);


@interface GCDAsyncUdpSocket : NSObject

/**
 * GCDAsyncUdpSocket uses the standard delegate paradigm,
 * but executes all delegate callbacks on a given delegate dispatch queue.
 * This allows for maximum concurrency, while at the same time providing easy thread safety.
 * 
 * You MUST set a delegate AND delegate dispatch queue before attempting to
 * use the socket, or you will get an error.
 * 
 * The socket queue is optional.
 * If you pass NULL, GCDAsyncSocket will automatically create its own socket queue.
 * If you choose to provide a socket queue, the socket queue must not be a concurrent queue.
 * 
 * The delegate queue and socket queue can optionally be the same.
**/
- (id)init;
- (id)initWithSocketQueue:(dispatch_queue_t)sq;
- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq;
- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq socketQueue:(dispatch_queue_t)sq;

#pragma mark Configuration

- (id)delegate;
- (void)setDelegate:(id)delegate;
- (void)synchronouslySetDelegate:(id)delegate;

- (dispatch_queue_t)delegateQueue;
- (void)setDelegateQueue:(dispatch_queue_t)delegateQueue;
- (void)synchronouslySetDelegateQueue:(dispatch_queue_t)delegateQueue;

- (void)getDelegate:(id *)delegatePtr delegateQueue:(dispatch_queue_t *)delegateQueuePtr;
- (void)setDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)synchronouslySetDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;

/**
 * By default, both IPv4 and IPv6 are enabled.
 * 
 * This means GCDAsyncUdpSocket automatically supports both protocols,
 * and can send to IPv4 or IPv6 addresses,
 * as well as receive over IPv4 and IPv6.
 * 
 * For operations that require DNS resolution, GCDAsyncUdpSocket supports both IPv4 and IPv6.
 * If a DNS lookup returns only IPv4 results, GCDAsyncUdpSocket will automatically use IPv4.
 * If a DNS lookup returns only IPv6 results, GCDAsyncUdpSocket will automatically use IPv6.
 * If a DNS lookup returns both IPv4 and IPv6 results, then the protocol used depends on the configured preference.
 * If IPv4 is preferred, then IPv4 is used.
 * If IPv6 is preferred, then IPv6 is used.
 * If neutral, then the first IP version in the resolved array will be used.
 * 
 * Starting with Mac OS X 10.7 Lion and iOS 5, the default IP preference is neutral.
 * On prior systems the default IP preference is IPv4.
 **/
- (BOOL)isIPv4Enabled;
- (void)setIPv4Enabled:(BOOL)flag;

- (BOOL)isIPv6Enabled;
- (void)setIPv6Enabled:(BOOL)flag;

- (BOOL)isIPv4Preferred;
- (BOOL)isIPv6Preferred;
- (BOOL)isIPVersionNeutral;

- (void)setPreferIPv4;
- (void)setPreferIPv6;
- (void)setIPVersionNeutral;

/**
 * Gets/Sets the maximum size of the buffer that will be allocated for receive operations.
 * The default maximum size is 9216 bytes.
 * 
 * The theoretical maximum size of any IPv4 UDP packet is UINT16_MAX = 65535.
 * The theoretical maximum size of any IPv6 UDP packet is UINT32_MAX = 4294967295.
 * 
 * Since the OS/GCD notifies us of the size of each received UDP packet,
 * the actual allocated buffer size for each packet is exact.
 * And in practice the size of UDP packets is generally much smaller than the max.
 * Indeed most protocols will send and receive packets of only a few bytes,
 * or will set a limit on the size of packets to prevent fragmentation in the IP layer.
 * 
 * If you set the buffer size too small, the sockets API in the OS will silently discard
 * any extra data, and you will not be notified of the error.
**/
- (uint16_t)maxReceiveIPv4BufferSize;
- (void)setMaxReceiveIPv4BufferSize:(uint16_t)max;

- (uint32_t)maxReceiveIPv6BufferSize;
- (void)setMaxReceiveIPv6BufferSize:(uint32_t)max;

/**
 * User data allows you to associate arbitrary information with the socket.
 * This data is not used internally in any way.
**/
- (id)userData;
- (void)setUserData:(id)arbitraryUserData;

#pragma mark Diagnostics

/**
 * Returns the local address info for the socket.
 * 
 * The localAddress method returns a sockaddr structure wrapped in a NSData object.
 * The localHost method returns the human readable IP address as a string.
 * 
 * Note: Address info may not be available until after the socket has been binded, connected
 * or until after data has been sent.
**/
- (NSData *)localAddress;
- (NSString *)localHost;
- (uint16_t)localPort;

- (NSData *)localAddress_IPv4;
- (NSString *)localHost_IPv4;
- (uint16_t)localPort_IPv4;

- (NSData *)localAddress_IPv6;
- (NSString *)localHost_IPv6;
- (uint16_t)localPort_IPv6;

/**
 * Returns the remote address info for the socket.
 * 
 * The connectedAddress method returns a sockaddr structure wrapped in a NSData object.
 * The connectedHost method returns the human readable IP address as a string.
 * 
 * Note: Since UDP is connectionless by design, connected address info
 * will not be available unless the socket is explicitly connected to a remote host/port.
 * If the socket is not connected, these methods will return nil / 0.
**/
- (NSData *)connectedAddress;
- (NSString *)connectedHost;
- (uint16_t)connectedPort;

/**
 * Returns whether or not this socket has been connected to a single host.
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * If connected, the socket will only be able to send/receive data to/from the connected host.
**/
- (BOOL)isConnected;

/**
 * Returns whether or not this socket has been closed.
 * The only way a socket can be closed is if you explicitly call one of the close methods.
**/
- (BOOL)isClosed;

/**
 * Returns whether or not this socket is IPv4.
 * 
 * By default this will be true, unless:
 * - IPv4 is disabled (via setIPv4Enabled:)
 * - The socket is explicitly bound to an IPv6 address
 * - The socket is connected to an IPv6 address
**/
- (BOOL)isIPv4;

/**
 * Returns whether or not this socket is IPv6.
 * 
 * By default this will be true, unless:
 * - IPv6 is disabled (via setIPv6Enabled:)
 * - The socket is explicitly bound to an IPv4 address
 * _ The socket is connected to an IPv4 address
 * 
 * This method will also return false on platforms that do not support IPv6.
 * Note: The iPhone does not currently support IPv6.
**/
- (BOOL)isIPv6;

#pragma mark Binding

/**
 * Binds the UDP socket to the given port.
 * Binding should be done for server sockets that receive data prior to sending it.
 * Client sockets can skip binding,
 * as the OS will automatically assign the socket an available port when it starts sending data.
 * 
 * You may optionally pass a port number of zero to immediately bind the socket,
 * yet still allow the OS to automatically assign an available port.
 * 
 * You cannot bind a socket after its been connected.
 * You can only bind a socket once.
 * You can still connect a socket (if desired) after binding.
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass NULL for errPtr.
**/
- (BOOL)bindToPort:(uint16_t)port error:(NSError **)errPtr;

/**
 * Binds the UDP socket to the given port and optional interface.
 * Binding should be done for server sockets that receive data prior to sending it.
 * Client sockets can skip binding,
 * as the OS will automatically assign the socket an available port when it starts sending data.
 * 
 * You may optionally pass a port number of zero to immediately bind the socket,
 * yet still allow the OS to automatically assign an available port.
 * 
 * The interface may be a name (e.g. "en1" or "lo0") or the corresponding IP address (e.g. "192.168.4.35").
 * You may also use the special strings "localhost" or "loopback" to specify that
 * the socket only accept packets from the local machine.
 * 
 * You cannot bind a socket after its been connected.
 * You can only bind a socket once.
 * You can still connect a socket (if desired) after binding.
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass NULL for errPtr.
**/
- (BOOL)bindToPort:(uint16_t)port interface:(NSString *)interface error:(NSError **)errPtr;

/**
 * Binds the UDP socket to the given address, specified as a sockaddr structure wrapped in a NSData object.
 * 
 * If you have an existing struct sockaddr you can convert it to a NSData object like so:
 * struct sockaddr sa  -> NSData *dsa = [NSData dataWithBytes:&remoteAddr length:remoteAddr.sa_len];
 * struct sockaddr *sa -> NSData *dsa = [NSData dataWithBytes:remoteAddr length:remoteAddr->sa_len];
 * 
 * Binding should be done for server sockets that receive data prior to sending it.
 * Client sockets can skip binding,
 * as the OS will automatically assign the socket an available port when it starts sending data.
 * 
 * You cannot bind a socket after its been connected.
 * You can only bind a socket once.
 * You can still connect a socket (if desired) after binding.
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass NULL for errPtr.
**/
- (BOOL)bindToAddress:(NSData *)localAddr error:(NSError **)errPtr;

#pragma mark Connecting

/**
 * Connects the UDP socket to the given host and port.
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * 
 * Choosing to connect to a specific host/port has the following effect:
 * - You will only be able to send data to the connected host/port.
 * - You will only be able to receive data from the connected host/port.
 * - You will receive ICMP messages that come from the connected host/port, such as "connection refused".
 * 
 * The actual process of connecting a UDP socket does not result in any communication on the socket.
 * It simply changes the internal state of the socket.
 * 
 * You cannot bind a socket after it has been connected.
 * You can only connect a socket once.
 * 
 * The host may be a domain name (e.g. "deusty.com") or an IP address string (e.g. "192.168.0.2").
 * 
 * This method is asynchronous as it requires a DNS lookup to resolve the given host name.
 * If an obvious error is detected, this method immediately returns NO and sets errPtr.
 * If you don't care about the error, you can pass nil for errPtr.
 * Otherwise, this method returns YES and begins the asynchronous connection process.
 * The result of the asynchronous connection process will be reported via the delegate methods.
 **/
- (BOOL)connectToHost:(NSString *)host onPort:(uint16_t)port error:(NSError **)errPtr;

/**
 * Connects the UDP socket to the given address, specified as a sockaddr structure wrapped in a NSData object.
 * 
 * If you have an existing struct sockaddr you can convert it to a NSData object like so:
 * struct sockaddr sa  -> NSData *dsa = [NSData dataWithBytes:&remoteAddr length:remoteAddr.sa_len];
 * struct sockaddr *sa -> NSData *dsa = [NSData dataWithBytes:remoteAddr length:remoteAddr->sa_len];
 * 
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * 
 * Choosing to connect to a specific address has the following effect:
 * - You will only be able to send data to the connected address.
 * - You will only be able to receive data from the connected address.
 * - You will receive ICMP messages that come from the connected address, such as "connection refused".
 * 
 * Connecting a UDP socket does not result in any communication on the socket.
 * It simply changes the internal state of the socket.
 * 
 * You cannot bind a socket after its been connected.
 * You can only connect a socket once.
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass nil for errPtr.
 * 
 * Note: Unlike the connectToHost:onPort:error: method, this method does not require a DNS lookup.
 * Thus when this method returns, the connection has either failed or fully completed.
 * In other words, this method is synchronous, unlike the asynchronous connectToHost::: method.
 * However, for compatibility and simplification of delegate code, if this method returns YES
 * then the corresponding delegate method (udpSocket:didConnectToHost:port:) is still invoked.
**/
- (BOOL)connectToAddress:(NSData *)remoteAddr error:(NSError **)errPtr;

#pragma mark Multicast

/**
 * Join multicast group.
 * Group should be an IP address (eg @"225.228.0.1").
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass nil for errPtr.
**/
- (BOOL)joinMulticastGroup:(NSString *)group error:(NSError **)errPtr;

/**
 * Join multicast group.
 * Group should be an IP address (eg @"225.228.0.1").
 * The interface may be a name (e.g. "en1" or "lo0") or the corresponding IP address (e.g. "192.168.4.35").
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass nil for errPtr.
**/
- (BOOL)joinMulticastGroup:(NSString *)group onInterface:(NSString *)interface error:(NSError **)errPtr;

- (BOOL)leaveMulticastGroup:(NSString *)group error:(NSError **)errPtr;
- (BOOL)leaveMulticastGroup:(NSString *)group onInterface:(NSString *)interface error:(NSError **)errPtr;

#pragma mark Broadcast

/**
 * By default, the underlying socket in the OS will not allow you to send broadcast messages.
 * In order to send broadcast messages, you need to enable this functionality in the socket.
 * 
 * A broadcast is a UDP message to addresses like "192.168.255.255" or "255.255.255.255" that is
 * delivered to every host on the network.
 * The reason this is generally disabled by default (by the OS) is to prevent
 * accidental broadcast messages from flooding the network.
**/
- (BOOL)enableBroadcast:(BOOL)flag error:(NSError **)errPtr;

#pragma mark Sending

/**
 * Asynchronously sends the given data, with the given timeout and tag.
 * 
 * If the timeout value is negative, the receive operation will not use a timeout.
 * 
 * 
 * 
 * This method may only be used with a connected socket.
 * Recall that connecting is optional for a UDP socket.
 * For connected sockets, data can only be sent to the connected address.
 * For non-connected sockets, the remote destination is specified for each packet.
 * 
 * If data is nil or zero-length this method does nothing.
 * Otherwise the result is reported via the delegate methods.
**/
- (void)sendData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;

/**
 * Asynchronously sends the given data, with the given timeout and tag, to the given host and port.
 * 
 * If the timeout value is negative, the receive operation will not use a timeout.
 * 
 * This method cannot be used with a connected socket.
 * Recall that connecting is optional for a UDP socket.
 * For connected sockets, data can only be sent to the connected address.
 * For non-connected sockets, the remote destination is specified for each packet.
 * 
 * If data is nil or zero-length this method does nothing.
 * Otherwise the result is reported via the delegate methods.
**/
- (void)sendData:(NSData *)data
          toHost:(NSString *)host
            port:(uint16_t)port
     withTimeout:(NSTimeInterval)timeout
             tag:(long)tag;

/**
 * Asynchronously sends the given data, with the given timeout and tag, to the given address.
 * 
 * This method cannot be used with a connected socket.
 * Recall that connecting is optional for a UDP socket.
 * For connected sockets, data can only be sent to the connected address.
 * For non-connected sockets, the remote destination is specified for each packet.
 * 
 * @param data
 *     The data to send.
 *     If data is nil or zero-length, this method does nothing.
 * 
 * @param address
 *     The address to send the data to (specified as a sockaddr structure wrapped in a NSData object).
 * 
 * @param timeout
 *    The timeout for the send opeartion.
 *    If the timeout value is negative, the send operation will not use a timeout.
 * 
 * @param tag
 *    The tag is for your convenience.
 *    It is not sent or received over the socket in any manner what-so-ever.
 *    It is reported back as a parameter in the delegate methods.
 *    You can use it as an array index, state id, type constant, etc.
 * 
 * If data is nil or zero-length, this method does nothing.
 * Otherwise the result is reported via the delegate methods.
**/
- (void)sendData:(NSData *)data toAddress:(NSData *)remoteAddr withTimeout:(NSTimeInterval)timeout tag:(long)tag;

#pragma mark Receiving

/**
 * Begins receiving udp packets on the socket.
 * It will continue to receive packets until the socket is closed, or until pauseReceiving is called.
 * 
 * For every received packet (not filtered by the optional receive filter),
 * the delegate method (udpSocket:didReceiveData:fromAddress:withFilterContext:) is invoked.
 * 
 * If the socket is able to begin receiving packets, this method returns YES.
 * Otherwise it returns NO, and sets the errPtr with appropriate error information.
**/
- (BOOL)beginReceiving:(NSError **)errPtr;

/**
 * If the socket is currently receiving (beginReceiving has been called), this method pauses the receiving.
 * That is, it won't read any more packets from the underlying OS socket until beginReceiving is called again.
 * 
 * Important Note:
 * GCDAsyncUdpSocket may be running in parallel with your code.
 * That is, your delegate is likely running on a separate thread/dispatch_queue.
 * When you invoke this method, GCDAsyncUdpSocket may have already dispatched delegate methods to be invoked.
 * Thus, if those delegate methods have already been dispatch_async'd,
 * your didReceive delegate method may still be invoked after this method has been called.
 * You should be aware of this, and program defensively.
**/
- (void)pauseReceiving;

/**
 * You may optionally set a receive filter for the socket.
 * This receive filter may be set to run in its own queue (independent of delegate queue).
 * 
 * A filter can provide several useful features.
 * 
 * 1. Many times udp packets are discarded because they are duplicate/unneeded/unsolicited.
 *    The filter can prevent such packets from arriving at the delegate.
 *    And because the filter can run in its own independent queue, this doesn't slow down the delegate.
 * 
 *    - Since the udp protocol does not guarnatee delivery, udp packets may be lost.
 *      Many protocols built atop udp thus provide various resend/re-request algorithms.
 *      This sometimes results in duplicate packets arriving.
 *    
 *    - Since the udp socket may be connectionless, its possible for unsolicited packets to arrive.
 *      Such packets need to be ignored.
 *    
 * 2. Many times udp packets need to be parsed.
 *    Since the filter can run in its own independent queue, you can parallelize this parsing quite easily.
 * 
 * 
 * For more information about GCDAsyncUdpSocketReceiveFilterBlock, see the documentation for its typedef.
 * To remove a previously set filter, invoke this method and pass a nil filterBlock and NULL filterQueue.
 * 
 * Example:
 * 
 * GCDAsyncUdpSocketReceiveFilterBlock filter = ^BOOL (NSData *data, NSData *address, id *context) {
 * 
 *     MyProtocolMessage *msg = [MyProtocol parseMessage:msg];
 *     
 *     *context = response;
 *     return (response != nil);
 * };
 * [udpSocket setReceiveFilter:filter withQueue:myParsingQueue];
 * 
**/
- (void)setReceiveFilter:(GCDAsyncUdpSocketReceiveFilterBlock)filterBlock withQueue:(dispatch_queue_t)filterQueue;

#pragma mark Closing

- (void)close;
- (void)closeAfterSending;

#pragma mark Advanced

/**
 * It's not thread-safe to access certain variables from outside the socket's internal queue.
 * 
 * For example, the socket file descriptor.
 * File descriptors are simply integers which reference an index in the per-process file table.
 * However, when one requests a new file descriptor (by opening a file or socket),
 * the file descriptor returned is guaranteed to be the lowest numbered unused descriptor.
 * So if we're not careful, the following could be possible:
 * 
 * - Thread A invokes a method which returns the socket's file descriptor.
 * - The socket is closed via the socket's internal queue on thread B.
 * - Thread C opens a file, and subsequently receives the file descriptor that was previously the socket's FD.
 * - Thread A is now accessing/altering the file instead of the socket.
 * 
 * In addition to this, other variables are not actually objects,
 * and thus cannot be retained/released or even autoreleased.
 * An example is the sslContext, of type SSLContextRef, which is actually a malloc'd struct.
 * 
 * Although there are internal variables that make it difficult to maintain thread-safety,
 * it is important to provide access to these variables
 * to ensure this class can be used in a wide array of environments.
 * This method helps to accomplish this by invoking the current block on the socket's internal queue.
 * The methods below can be invoked from within the block to access
 * those generally thread-unsafe internal variables in a thread-safe manner.
 * The given block will be invoked synchronously on the socket's internal queue.
 * 
 * If you save references to any protected variables and use them outside the block, you do so at your own peril.
**/
- (void)performBlock:(dispatch_block_t)block;

/**
 * These methods are only available from within the context of a performBlock: invocation.
 * See the documentation for the performBlock: method above.
 * 
 * Provides access to the socket's file descriptor(s).
 * If the socket isn't connected, or explicity bound to a particular interface,
 * it might actually have multiple internal socket file descriptors - one for IPv4 and one for IPv6.
**/
- (int)socketFD;
- (int)socket4FD;
- (int)socket6FD;

#if TARGET_OS_IPHONE

/**
 * These methods are only available from within the context of a performBlock: invocation.
 * See the documentation for the performBlock: method above.
 * 
 * Returns (creating if necessary) a CFReadStream/CFWriteStream for the internal socket.
 * 
 * Generally GCDAsyncUdpSocket doesn't use CFStream. (It uses the faster GCD API's.)
 * However, if you need one for any reason,
 * these methods are a convenient way to get access to a safe instance of one.
**/
- (CFReadStreamRef)readStream;
- (CFWriteStreamRef)writeStream;

/**
 * This method is only available from within the context of a performBlock: invocation.
 * See the documentation for the performBlock: method above.
 * 
 * Configures the socket to allow it to operate when the iOS application has been backgrounded.
 * In other words, this method creates a read & write stream, and invokes:
 * 
 * CFReadStreamSetProperty(readStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP);
 * CFWriteStreamSetProperty(writeStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP);
 * 
 * Returns YES if successful, NO otherwise.
 * 
 * Example usage:
 * 
 * [asyncUdpSocket performBlock:^{
 *     [asyncUdpSocket enableBackgroundingOnSocket];
 * }];
 * 
 * 
 * NOTE : Apple doesn't currently support backgrounding UDP sockets. (Only TCP for now).
**/
//- (BOOL)enableBackgroundingOnSockets;

#endif

#pragma mark Utilities

/**
 * Extracting host/port/family information from raw address data.
**/

+ (NSString *)hostFromAddress:(NSData *)address;
+ (uint16_t)portFromAddress:(NSData *)address;
+ (int)familyFromAddress:(NSData *)address;

+ (BOOL)isIPv4Address:(NSData *)address;
+ (BOOL)isIPv6Address:(NSData *)address;

+ (BOOL)getHost:(NSString **)hostPtr port:(uint16_t *)portPtr fromAddress:(NSData *)address;
+ (BOOL)getHost:(NSString **)hostPtr port:(uint16_t *)portPtr family:(int *)afPtr fromAddress:(NSData *)address;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol GCDAsyncUdpSocketDelegate
@optional

/**
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * However, you may optionally choose to connect to a particular host for reasons
 * outlined in the documentation for the various connect methods listed above.
 * 
 * This method is called if one of the connect methods are invoked, and the connection is successful.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address;

/**
 * By design, UDP is a connectionless protocol, and connecting is not needed.
 * However, you may optionally choose to connect to a particular host for reasons
 * outlined in the documentation for the various connect methods listed above.
 * 
 * This method is called if one of the connect methods are invoked, and the connection fails.
 * This may happen, for example, if a domain name is given for the host and the domain name is unable to be resolved.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error;

/**
 * Called when the datagram with the given tag has been sent.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag;

/**
 * Called if an error occurs while trying to send a datagram.
 * This could be due to a timeout, or something more serious such as the data being too large to fit in a sigle packet.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error;

/**
 * Called when the socket has received the requested datagram.
**/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
                                             fromAddress:(NSData *)address
                                       withFilterContext:(id)filterContext;

/**
 * Called when the socket is closed.
**/
- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error;

@end

