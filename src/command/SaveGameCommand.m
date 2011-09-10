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


// Project includes
#import "SaveGameCommand.h"
#import "../gtp/GtpCommand.h"



@implementation SaveGameCommand

// -----------------------------------------------------------------------------
/// @brief Executes this command. See the class documentation for details.
// -----------------------------------------------------------------------------
- (bool) doIt
{
  // TODO get filename from user
  static int iii = 0;
  iii++;
  NSString* sgfFileName = [NSString stringWithFormat:@"foo-%d.sgf", iii];
  GtpCommand* command = [GtpCommand command:[NSString stringWithFormat:@"savesgf %@", sgfFileName]];
  [command submit];

  // TODO send these when we get the response
  [[NSNotificationCenter defaultCenter] postNotificationName:gameSavedToArchive object:sgfFileName];
  [[NSNotificationCenter defaultCenter] postNotificationName:archiveContentChanged object:nil];

  return true;
}

@end