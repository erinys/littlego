// -----------------------------------------------------------------------------
// Copyright 2011 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
/// @defgroup gtp GTP module
///
/// Classes in this module are associated with GTP, the Go Text Protocol.
// -----------------------------------------------------------------------------


// Project includes
#import "GtpClient.h"
#import "GtpCommand.h"
#import "GtpResponse.h"

// System includes
#include <fstream>   // ifstream and ofstream

// It would be much nicer to make these variables members of the GtpClient
// class, but they are C++ and GtpClient.h is also #import'ed by pure
// Objective-C implementations.
static std::ofstream commandStream;
static std::ifstream responseStream;


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for GtpClient.
// -----------------------------------------------------------------------------
@interface GtpClient()
/// @name Initialization and deallocation
//@{
- (id) initWithPipes:(NSArray*)pipes;
- (void) dealloc;
//@}
/// @name Private helper methods
//@{
- (void) processCommand:(GtpCommand*)command;
- (void) receive:(GtpResponse*)response;
//@}
@end


@implementation GtpClient

@synthesize shouldExit;

// -----------------------------------------------------------------------------
/// @brief Convenience constructor. Creates a GtpClient instance which will use
/// the two named pipes to communicate with its counterpart GtpEngine.
// -----------------------------------------------------------------------------
+ (GtpClient*) clientWithInputPipe:(NSString*)inputPipe outputPipe:(NSString*)outputPipe;
{
  // Create copies so that the objects can be safely used by the thread when
  // it starts
  NSArray* pipes = [NSArray arrayWithObjects:[inputPipe copy], [outputPipe copy], nil];
  return [[[GtpClient alloc] initWithPipes:pipes] autorelease];
}

// -----------------------------------------------------------------------------
/// @brief Initializes a GtpClient object.
///
/// @note This is the designated initializer of GtpClient.
// -----------------------------------------------------------------------------
- (id) initWithPipes:(NSArray*)pipes
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;

  self.shouldExit = false;

  // Create and start the thread
  m_thread = [[NSThread alloc] initWithTarget:self selector:@selector(mainLoop:) object:pipes];
  [m_thread start];

  // TODO: Clients that work with self returned here will invoke methods in
  // the context of the main thread. Find a clever/elegant solution so that
  // there is an automatic context switch. We don't want clients to worry about
  // calling NSObject's performSelector:onThread:withObject:waitUntilDone.
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this GtpClient object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  // TODO implement stuff
  [m_thread release];
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief The secondary thread's main loop method. Returns only after the
/// @e shouldExit property has been set to true.
// -----------------------------------------------------------------------------
- (void) mainLoop:(NSArray*)pipes
{
  // Create an autorelease pool as the very first thing in this thread
  NSAutoreleasePool* mainPool = [[NSAutoreleasePool alloc] init];

  // Stream to write commands for the GTP engine
  NSString* inputPipePath = [pipes objectAtIndex:0];
  const char* pchInputPipePath = [inputPipePath cStringUsingEncoding:[NSString defaultCStringEncoding]];
  commandStream.open(pchInputPipePath);

  // Stream to read responses from the GTP engine
  NSString* outputPipePath = [pipes objectAtIndex:1];
  const char* pchOutputPipePath = [outputPipePath cStringUsingEncoding:[NSString defaultCStringEncoding]];
  responseStream.open(pchOutputPipePath);

  // The timer is required because otherwise the run loop has no input source
  NSDate* distantFuture = [NSDate distantFuture]; 
  NSTimer* distantFutureTimer = [[NSTimer alloc] initWithFireDate:distantFuture
                                                         interval:1.0
                                                           target:self
                                                         selector:@selector(dealloc:)   // pseudo selector
                                                         userInfo:nil
                                                          repeats:NO];
  [[NSRunLoop currentRunLoop] addTimer:distantFutureTimer forMode:NSDefaultRunLoopMode];
  [distantFutureTimer autorelease];

  while (true)
  {
    NSAutoreleasePool* loopPool = [[NSAutoreleasePool alloc] init];
    bool hasInputSources = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                                    beforeDate:distantFuture];
    [loopPool drain];
    if (! hasInputSources)  // always true, see timer input source above
      break;
    if (self.shouldExit)
      break;
  }

  // Deallocate the autorelease pool as the very last thing in this thread
  [mainPool drain];
}

// -----------------------------------------------------------------------------
/// @brief Processes the GTP command @a command. This method is executed in the
/// secondary thread's context.
///
/// Performs the following operations:
/// - Pass @a command to the GtpEngine
/// - Wait for the response from the GtpEngine (blocks)
/// - Creates a GtpResponse object using the response received from the
///   GtpEngine
/// - Invokes receive:() with the GtpResponse object in the context of the main
///   thread
// -----------------------------------------------------------------------------
- (void) processCommand:(GtpCommand*)command
{
  // Undo retain message sent to the command object by submit:()
  [command autorelease];

  // Send the command to the engine
  if (nil == command.command || 0 == [command.command length])
    return;
  const char* pchCommand = [command.command cStringUsingEncoding:[NSString defaultCStringEncoding]];
  commandStream << pchCommand << std::endl;  // this wakes up the engine

  // Read the engine's response (blocking if necessary)
  std::string fullResponse;
  std::string singleLineResponse;
  while (true)
  {
    getline(responseStream, singleLineResponse);
    if (singleLineResponse.empty())
      break;
    if (! fullResponse.empty())
      fullResponse += "\n";
    fullResponse += singleLineResponse;
  }

  // Notify the main thread of the response
  NSString* nsResponse = [NSString stringWithCString:fullResponse.c_str() 
                                            encoding:[NSString defaultCStringEncoding]];
  GtpResponse* response = [GtpResponse response:nsResponse toCommand:command];
  // Retain to make sure that object is still alive when the it "arrives" in
  // the main thread
  [response retain];
  [self performSelectorOnMainThread:@selector(receive:) withObject:response waitUntilDone:NO];

  if (NSOrderedSame == [command.command compare:@"quit"])
  {
    // After the current method is executed, the thread's run loop will wake
    // up, the main loop will find that the flag is true and stop running
    self.shouldExit = true;
  }
}

// -----------------------------------------------------------------------------
/// @brief Submits @a command to the GtpEngine. This method is executed in the
/// main thread's context. It returns immediately and does not wait for the
/// GtpEngine's response.
// -----------------------------------------------------------------------------
- (void) submit:(GtpCommand*)command
{
  // Synchronously notify observers
  [[NSNotificationCenter defaultCenter] postNotificationName:gtpCommandSubmittedNotification object:command];
  // Retain to make sure that object is still alive when the it "arrives" in
  // the secondary thread
  [command retain];
  // Trigger secondary thread
  [self performSelector:@selector(processCommand:) onThread:m_thread withObject:command waitUntilDone:NO];
}

// -----------------------------------------------------------------------------
/// @brief Is invoked after @a response has been received from the GtpEngine.
/// This method is executed in the main thread's context. It posts a
/// notification to the default NSNotificationCenter so that clients that
/// previously submitted a command will know when their expected response has
/// come in.
// -----------------------------------------------------------------------------
- (void) receive:(GtpResponse*)response
{
  // Undo retain message sent to the command object by processCommand:()
  [response autorelease];
  // Synchronously notify observers
  [[NSNotificationCenter defaultCenter] postNotificationName:gtpResponseReceivedNotification object:response];
}

@end