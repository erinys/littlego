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


// Forward declarations
@class GoPlayer;
@class GoPoint;


// -----------------------------------------------------------------------------
/// @brief The GoMove class represents a move made by one of the players.
///
/// @ingroup go
///
/// A GoMove object always has a type(); the different types of moves are
/// enumerated by #GoMoveType. A GoMove object is always associated with the
/// player who made the move. The player object can be queried for the color of
/// the move.
///
/// If a GoMove object is of type#PlayMove it also has an associated GoPoint
/// object which registers where the stone was placed. The GoPoint object is
/// assigned (soon) after construction.
///
/// @note Assignment of a GoPoint object is a non-trivial operation that
/// triggers the mechanism for placing a stone.
///
/// GoMove objects are interlinked with their predecessor (previous()) and
/// successor (next()) GoMove object. This represents the fact that a game
/// can be seen as a series of moves.
///
/// GoMove objects are immutable, i.e. they cannot be changed once they have
/// been initialized.
// -----------------------------------------------------------------------------
@interface GoMove : NSObject
{
}

+ (GoMove*) move:(enum GoMoveType)type by:(GoPlayer*)player after:(GoMove*)move;
- (void) undo;

/// @brief The type of this GoMove object.
@property(readonly) enum GoMoveType type;
/// @brief The player who made this GoMove.
@property(readonly, retain) GoPlayer* player;
/// @brief The GoPoint object registering where the stone was placed for this
/// GoMove. Is nil if this GoMove is @e not a #PlayMove.
@property(assign) GoPoint* point;
/// @brief The predecessor to this GoMove object. nil if this is the first move
/// of the game.
@property(readonly, assign) GoMove* previous;  // do not retain, otherwise there would be a retain cycle
/// @brief The successor to this GoMove object. nil if this is the last move
/// of the game.
@property(readonly, retain) GoMove* next;      // retain here, making us the parent, and next the child

@end