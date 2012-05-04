Pod::Spec.new do |s|
  s.name     = 'CocoaAsyncSocket'
  s.version  = '0.0.1'
  s.license  = 'public domain'
  s.summary  = 'An asynchronous socket networking library for Cocoa.'
  s.homepage = 'http://code.google.com/p/cocoaasyncsocket/'
  s.authors  = 'Dustin Voss', { 'Robbie Hanson' => 'robbiehanson@deusty.com' }

  s.source   = { :git => 'https://github.com/robbiehanson/CocoaAsyncSocket.git', :commit => 'a87a901f6b3bbc83e2c449ffd33515f8d31da2f8' }

  s.description = 'CocoaAsyncSocket supports TCP and UDP. The AsyncSocket class is for TCP, and the AsyncUdpSocket class is for UDP. ' \
                  'AsyncSocket is a TCP/IP socket networking library that wraps CFSocket and CFStream. It offers asynchronous ' \
                  'operation, and a native Cocoa class complete with delegate support or use the GCD variant GCDAsyncSocket. ' \
                  'AsyncUdpSocket is a UDP/IP socket networking library that wraps CFSocket. It works almost exactly like the TCP ' \
                  'version, but is designed specifically for UDP. This includes queued non-blocking send/receive operations, full ' \
                  'delegate support, run-loop based, self-contained class, and support for IPv4 and IPv6.'

  s.source_files = '{GCD,RunLoop}/*.{h,m}'
  s.clean_paths  = 'Vendor', 'GCD/Xcode', 'RunLoop/Xcode'
  s.requires_arc = true
  if config.ios?
    s.frameworks = ['CFNetwork', 'Security']
  else
    s.frameworks = ['CoreServices', 'Security']
  end
end