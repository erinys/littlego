// -----------------------------------------------------------------------------
// Copyright 2011-2012 Patrick Näf (herzbube@herzbube.ch)
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
#import "PlayViewController.h"
#import "PlayView.h"
#import "BoardPositionModel.h"
#import "DebugPlayViewController.h"
#import "StatusLineController.h"
#import "ActivityIndicatorController.h"
#import "ScoringModel.h"
#import "../main/ApplicationDelegate.h"
#import "../go/GoGame.h"
#import "../go/GoMove.h"
#import "../go/GoPlayer.h"
#import "../go/GoScore.h"
#import "../go/GoPoint.h"
#import "../player/Player.h"
#import "../command/InterruptComputerCommand.h"
#import "../command/boardposition/DiscardAndPlayCommand.h"
#import "../command/move/ComputerPlayMoveCommand.h"
#import "../command/move/PlayMoveCommand.h"
#import "../command/game/ContinueGameCommand.h"
#import "../command/game/PauseGameCommand.h"
#import "../ui/UiElementMetrics.h"
#import "../ui/UiUtilities.h"

// System includes
#import <QuartzCore/QuartzCore.h>


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for PlayViewController.
// -----------------------------------------------------------------------------
@interface PlayViewController()
/// @name Initialization and deallocation
//@{
- (void) dealloc;
//@}
/// @name UIViewController methods
//@{
- (void) loadView;
- (void) viewDidLoad;
- (void) viewDidUnload;
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration;
//@}
/// @name Action methods for toolbar items
//@{
- (void) pass:(id)sender;
- (void) playForMe:(id)sender;
- (void) oneMoveBack:(id)sender;
- (void) oneMoveForward:(id)sender;
- (void) pause:(id)sender;
- (void) continue:(id)sender;
- (void) interrupt:(id)sender;
- (void) gameInfo:(id)sender;
- (void) gameActions:(id)sender;
- (void) done:(id)sender;
//@}
/// @name Handlers for recognized gestures
//@{
- (void) handlePanFrom:(UIPanGestureRecognizer*)gestureRecognizer;
- (void) handleTapFrom:(UITapGestureRecognizer*)gestureRecognizer;
//@}
/// @name UIGestureRecognizerDelegate protocol
//@{
- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer;
//@}
/// @name GameInfoViewControllerDelegate protocol
//@{
- (void) gameInfoViewControllerDidFinish:(GameInfoViewController*)controller;
//@}
/// @name PlayViewActionSheetDelegate protocol
//@{
- (void) playViewActionSheetControllerDidFinish:(PlayViewActionSheetController*)controller;
//@}
/// @name UIAlertViewDelegate protocol
//@{
- (void) alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;
//@}
/// @name Notification responders
//@{
- (void) applicationIsReadyForAction:(NSNotification*)notification;
- (void) goGameWillCreate:(NSNotification*)notification;
- (void) goGameDidCreate:(NSNotification*)notification;
- (void) goGameStateChanged:(NSNotification*)notification;
- (void) computerPlayerThinkingChanged:(NSNotification*)notification;
- (void) playViewBoardPositionChanged:(NSNotification*)notification;
- (void) goScoreScoringModeEnabled:(NSNotification*)notification;
- (void) goScoreScoringModeDisabled:(NSNotification*)notification;
- (void) goScoreCalculationStarts:(NSNotification*)notification;
- (void) goScoreCalculationEnds:(NSNotification*)notification;
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
//@}
/// @name Updaters
//@{
- (void) populateToolbar;
- (void) updateButtonStates;
- (void) updatePlayForMeButtonState;
- (void) updatePassButtonState;
- (void) updateBackButtonState;
- (void) updateForwardButtonState;
- (void) updatePauseButtonState;
- (void) updateContinueButtonState;
- (void) updateInterruptButtonState;
- (void) updateGameInfoButtonState;
- (void) updateGameActionsButtonState;
- (void) updateDoneButtonState;
- (void) updatePanningEnabled;
- (void) updateTappingEnabled;
//@}
/// @name Private helpers
//@{
- (CGRect) mainViewFrame;
- (CGRect) subViewFrame;
- (CGRect) toolbarViewFrame;
- (CGRect) playViewFrame;
- (CGRect) statusLineViewFrame;
- (CGRect) activityIndicatorViewFrame;
- (int) statusLineNumberOfTextLines;
- (void) makeControllerReadyForAction;
- (void) flipToFrontSideView:(bool)flipToFrontSideView;
- (void) playOrAlertWithCommand:(DiscardAndPlayCommand*)command;
- (void) alertCannotPlayOnComputersTurn;
//@}
/// @name Privately declared properties
//@{
/// @brief True if this controller has been set up is now "ready for action".
@property(nonatomic, assign) bool controllerReadyForAction;
/// @brief The model that manages scoring-related data.
@property(nonatomic, assign) ScoringModel* scoringModel;
/// @brief The gesture recognizer used to detect the long-press gesture.
@property(nonatomic, retain) UILongPressGestureRecognizer* longPressRecognizer;
/// @brief The gesture recognizer used to detect the tap gesture.
@property(nonatomic, retain) UITapGestureRecognizer* tapRecognizer;
/// @brief True if a panning gesture is currently allowed, false if not (e.g.
/// while a computer player is thinking).
@property(nonatomic, assign, getter=isPanningEnabled) bool panningEnabled;
/// @brief True if a tapping gesture is currently allowed, false if not (e.g.
/// if scoring mode is not enabled).
@property(nonatomic, assign, getter=isTappingEnabled) bool tappingEnabled;
/// @brief GoScore object used while the game info view is displayed and scoring
/// mode is NOT enabled. If scoring mode is enabled, the GoScore object is
/// obtained from elsewhere.
@property(nonatomic, retain) GoScore* gameInfoScore;
/// @brief The command to execute a human player's move.
///
/// This property is required to temporarily store a command object from the
/// time an alert is displayed until the user dismisses the alert and the alert
/// handler is invoked.
///
/// The command object is not retained.
@property(nonatomic, assign) DiscardAndPlayCommand* discardAndPlayCommand;
/// @brief The frontside view. A superview of @e playView.
@property(nonatomic, retain) UIView* frontSideView;
/// @brief The backside view with information about the current game.
@property(nonatomic, retain) UIView* backSideView;
/// @brief The view that PlayViewController is responsible for.
@property(nonatomic, retain) PlayView* playView;
/// @brief The toolbar that displays action buttons.
@property(nonatomic, retain) UIToolbar* toolbar;
/// @brief The status line that displays messages to the user.
@property(nonatomic, retain) UILabel* statusLine;
/// @brief The activity indicator that is animated for long running operations.
@property(nonatomic, retain) UIActivityIndicatorView* activityIndicator;
/// @brief The controller that manages the status line.
@property(nonatomic, retain) StatusLineController* statusLineController;
/// @brief The controller that manages the activity indicator.
@property(nonatomic, retain) ActivityIndicatorController* activityIndicatorController;
/// @brief The "Play for me" button. Tapping this button causes the computer
/// player to generate a move for the human player whose turn it currently is.
@property(nonatomic, retain) UIBarButtonItem* playForMeButton;
/// @brief The "Pass" button. Tapping this button generates a "Pass" move for
/// the human player whose turn it currently is.
@property(nonatomic, retain) UIBarButtonItem* passButton;
/// @brief The "Back" button. Tapping this button goes back one move in the
/// game's move history. The board is updated to display the new situation.
@property(nonatomic, retain) UIBarButtonItem* oneMoveBackButton;
/// @brief The "Forward" button. Tapping this button goes forward one move in
/// the game's move history. The board is updated to display the new situation.
@property(nonatomic, retain) UIBarButtonItem* oneMoveForwardButton;
/// @brief The "Pause" button. Tapping this button causes the game to pause if
/// two computer players play against each other.
@property(nonatomic, retain) UIBarButtonItem* pauseButton;
/// @brief The "Continue" button. Tapping this button causes the game to
/// continue if it is paused while two computer players play against each other.
@property(nonatomic, retain) UIBarButtonItem* continueButton;
/// @brief The "Interrupt" button. Tapping this button interrupts the computer
/// player while it is thinking.
@property(nonatomic, retain) UIBarButtonItem* interruptButton;
/// @brief Dummy button that creates an expanding space between the "New"
/// button and its predecessors.
@property(nonatomic, retain) UIBarButtonItem* flexibleSpaceButton;
/// @brief The "Game Info" button. Tapping this button flips the game view to
/// display an alternate view with information about the game in progress.
@property(nonatomic, retain) UIBarButtonItem* gameInfoButton;
/// @brief The "Game Actions" button. Tapping this button displays an action
/// sheet with actions that relate to Go games as a whole.
@property(nonatomic, retain) UIBarButtonItem* gameActionsButton;
/// @brief The "Done" button. Tapping this button ends the currently active
/// mode and returns to normal play mode.
@property(nonatomic, retain) UIBarButtonItem* doneButton;
//@}
@end


@implementation PlayViewController

@synthesize controllerReadyForAction;
@synthesize frontSideView;
@synthesize backSideView;
@synthesize playView;
@synthesize toolbar;
@synthesize statusLine;
@synthesize activityIndicator;
@synthesize statusLineController;
@synthesize activityIndicatorController;
@synthesize playForMeButton;
@synthesize passButton;
@synthesize oneMoveBackButton;
@synthesize oneMoveForwardButton;
@synthesize pauseButton;
@synthesize continueButton;
@synthesize interruptButton;
@synthesize flexibleSpaceButton;
@synthesize gameInfoButton;
@synthesize gameActionsButton;
@synthesize doneButton;
@synthesize scoringModel;
@synthesize longPressRecognizer;
@synthesize tapRecognizer;
@synthesize panningEnabled;
@synthesize tappingEnabled;
@synthesize gameInfoScore;
@synthesize discardAndPlayCommand;


// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this PlayViewController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.frontSideView = nil;
  self.backSideView = nil;
  self.playView = nil;
  self.toolbar = nil;
  self.statusLine = nil;
  self.activityIndicator = nil;
  self.statusLineController = nil;
  self.activityIndicatorController = nil;
  self.playForMeButton = nil;
  self.passButton = nil;
  self.oneMoveBackButton = nil;
  self.oneMoveForwardButton = nil;
  self.pauseButton = nil;
  self.continueButton = nil;
  self.interruptButton = nil;
  self.flexibleSpaceButton = nil;
  self.gameInfoButton = nil;
  self.gameActionsButton = nil;
  self.doneButton = nil;
  self.scoringModel = nil;
  self.longPressRecognizer = nil;
  self.tapRecognizer = nil;
  self.gameInfoScore = nil;
  self.discardAndPlayCommand = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Creates the view that this controller manages.
// -----------------------------------------------------------------------------
- (void) loadView
{
  // Create view hierarchy
  CGRect mainViewFrame = [self mainViewFrame];
  self.view = [[[UIView alloc] initWithFrame:mainViewFrame] autorelease];
  CGRect subViewFrame = [self subViewFrame];
  self.frontSideView = [[[UIView alloc] initWithFrame:subViewFrame] autorelease];
  self.backSideView = [[[UIView alloc] initWithFrame:subViewFrame] autorelease];
  // Add frontside view to the main view already here, do not wait until
  // makeControllerReadyForAction is invoked. Reason: If the user is holding the
  // device in landscape orientation while the application is starting up, iOS
  // will first start up in portrait orientation and then initiate an
  // auto-rotation to landscape orientation. If the frontside view has not yet
  // been added as a subview at this time, it will not be auto-resized, and all
  // size calculations for the play view during auto-rotation will miserably
  // fail. Because startup auto-rotation happens before
  // makeControllerReadyForAction is called, we must add the frontside view
  // to the main view here.
  [self.view addSubview:self.frontSideView];
  CGRect toolbarFrame = [self toolbarViewFrame];
  self.toolbar = [[[UIToolbar alloc] initWithFrame:toolbarFrame] autorelease];
  [self.frontSideView addSubview:self.toolbar];
  CGRect playViewFrame = [self playViewFrame];
  self.playView = [[[PlayView alloc] initWithFrame:playViewFrame] autorelease];
  [self.frontSideView addSubview:self.playView];
  CGRect statusLineViewFrame = [self statusLineViewFrame];
  self.statusLine = [[[UILabel alloc] initWithFrame:statusLineViewFrame] autorelease];
  [self.frontSideView addSubview:self.statusLine];
  CGRect activityIndicatorFrame = [self activityIndicatorViewFrame];
  self.activityIndicator = [[[UIActivityIndicatorView alloc] initWithFrame:activityIndicatorFrame] autorelease];
  [self.frontSideView addSubview:self.activityIndicator];

  // Activate the following code to display controls that you can use to change
  // Play view drawing parameters that are normally immutable at runtime. This
  // is nice for debugging changes to the drawing system.
//  DebugPlayViewController* debugPlayViewController = [[DebugPlayViewController alloc] init];
//  [self.frontSideView addSubview:debugPlayViewController.view];
//  CGRect debugPlayViewFrame = debugPlayViewController.view.frame;
//  debugPlayViewFrame.origin.y += toolbarFrame.size.height;
//  debugPlayViewController.view.frame = debugPlayViewFrame;
  
  // Configure autoresizingMask properties for proper autorotation
  self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.frontSideView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.backSideView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.playView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin);
  self.statusLine.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
  self.activityIndicator.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin);

  // Set common background color for all elements on the frontside view
  [UiUtilities addGroupTableViewBackgroundToView:self.frontSideView];
  self.playView.backgroundColor = [UIColor clearColor];
  self.statusLine.backgroundColor = [UIColor clearColor];

  // If the view is resized, the Go board needs to be redrawn (occurs during
  // rotation animation)
  self.playView.contentMode = UIViewContentModeRedraw;

  // Other configuration
  self.statusLine.lineBreakMode = UILineBreakModeWordWrap;
  self.statusLine.numberOfLines = [self statusLineNumberOfTextLines];
  self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
}

// -----------------------------------------------------------------------------
/// @brief Calculates the frame of this controller's main view, taking into
/// account the current interface orientation. Assumes that super views have
/// the correct bounds.
// -----------------------------------------------------------------------------
- (CGRect) mainViewFrame
{
  int mainViewX = 0;
  int mainViewY = 0;
  int mainViewWidth = [UiElementMetrics screenWidth];
  int mainViewHeight = ([UiElementMetrics screenHeight]
                        - [UiElementMetrics tabBarHeight]
                        - [UiElementMetrics statusBarHeight]);
  return CGRectMake(mainViewX, mainViewY, mainViewWidth, mainViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief Calculates the frame of the frontside and backside subviews, taking
/// into account the current interface orientation. Assumes that super views
/// have the correct bounds.
// -----------------------------------------------------------------------------
- (CGRect) subViewFrame
{
  CGSize superViewSize = self.view.bounds.size;
  int subViewX = 0;
  int subViewY = 0;
  int subViewWidth = superViewSize.width;
  int subViewHeight = superViewSize.height;
  return CGRectMake(subViewX, subViewY, subViewWidth, subViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief Calculates the frame of the toolbar view, taking into account the
/// current interface orientation. Assumes that super views have the correct
/// bounds.
// -----------------------------------------------------------------------------
- (CGRect) toolbarViewFrame
{
  CGSize superViewSize = self.frontSideView.bounds.size;
  int toolbarViewX = 0;
  int toolbarViewY = 0;
  int toolbarViewWidth = superViewSize.width;
  int toolbarViewHeight = [UiElementMetrics toolbarHeight];
  return CGRectMake(toolbarViewX, toolbarViewY, toolbarViewWidth, toolbarViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief Calculates the frame of the play view, taking into account the
/// current interface orientation. Assumes that super views have the correct
/// bounds.
// -----------------------------------------------------------------------------
- (CGRect) playViewFrame
{
  // Dimensions if all the available space were used. The result would be a
  // rectangle.
  CGSize superViewSize = self.frontSideView.bounds.size;
  int playViewFullWidth = superViewSize.width;
  int playViewFullHeight = (superViewSize.height
                            - [UiElementMetrics toolbarHeight]
                            - [UiElementMetrics spacingVertical]
                            - ([UiElementMetrics labelHeight] * [self statusLineNumberOfTextLines]));

  // Now make the view square so that auto-rotation on orientation change does
  // not cause the view to be squashed or stretched. This is possibly not
  // necessary anymore, because now there is a custom animation going on during
  // auto-rotation that resizes the view to its proper dimensions.
  // Note: There's already a small bit of code in PlayView that lets it handle
  // rectangular frames.
  int playViewSideLength;
  if (playViewFullHeight >= playViewFullWidth)
    playViewSideLength = playViewFullWidth;
  else
    playViewSideLength = playViewFullHeight;

  // Calculate the final values
  int playViewX = (superViewSize.width - playViewSideLength) / 2;  // center horizontally
  int playViewY = [UiElementMetrics toolbarHeight];                // place just below the toolbar
  int playViewWidth = playViewSideLength;
  int playViewHeight = playViewSideLength;
  return CGRectMake(playViewX, playViewY, playViewWidth, playViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief Calculates the frame of the status line view, taking into account
/// the current interface orientation. Assumes that super views have the
/// correct bounds.
// -----------------------------------------------------------------------------
- (CGRect) statusLineViewFrame
{
  CGSize superViewSize = self.frontSideView.bounds.size;
  int statusLineViewX = 0;
  int statusLineViewY = superViewSize.height - ([UiElementMetrics labelHeight] * [self statusLineNumberOfTextLines]);
  int statusLineViewWidth = (superViewSize.width
                             - [UiElementMetrics spacingHorizontal]
                             - [UiElementMetrics activityIndicatorWidthAndHeight]);
  int statusLineViewHeight = [UiElementMetrics labelHeight] * [self statusLineNumberOfTextLines];
  return CGRectMake(statusLineViewX, statusLineViewY, statusLineViewWidth, statusLineViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief Calculates the frame of the activity indicator view, taking into
/// account the current interface orientation. Assumes that super views have
/// the correct bounds.
// -----------------------------------------------------------------------------
- (CGRect) activityIndicatorViewFrame
{
  CGSize superViewSize = self.frontSideView.bounds.size;
  int activityIndicatorViewX = superViewSize.width - [UiElementMetrics activityIndicatorWidthAndHeight];
  int activityIndicatorViewY = superViewSize.height - [UiElementMetrics activityIndicatorWidthAndHeight];
  int activityIndicatorViewWidth = [UiElementMetrics activityIndicatorWidthAndHeight];
  int activityIndicatorViewHeight = [UiElementMetrics activityIndicatorWidthAndHeight];
  return CGRectMake(activityIndicatorViewX, activityIndicatorViewY, activityIndicatorViewWidth, activityIndicatorViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief Returns how many number of text lines the status line should display.
// -----------------------------------------------------------------------------
- (int) statusLineNumberOfTextLines
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    return 2;
  else
    return 1;
}

// -----------------------------------------------------------------------------
/// @brief Called after the controller’s view is loaded into memory, usually
/// to perform additional initialization steps.
// -----------------------------------------------------------------------------
- (void) viewDidLoad
{
  [super viewDidLoad];

  ApplicationDelegate* delegate = [ApplicationDelegate sharedDelegate];
  if (! delegate.applicationReadyForAction)
  {
    self.controllerReadyForAction = false;
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(applicationIsReadyForAction:) name:applicationIsReadyForAction object:nil];
  }
  else
  {
    [self makeControllerReadyForAction];
    self.controllerReadyForAction = true;
  }
}

// -----------------------------------------------------------------------------
/// @brief Sets up this controller and makes it "ready for action".
// -----------------------------------------------------------------------------
- (void) makeControllerReadyForAction
{
  ApplicationDelegate* delegate = [ApplicationDelegate sharedDelegate];
  self.scoringModel = delegate.scoringModel;
  if (! self.scoringModel)
  {
    DDLogError(@"PlayViewController::makeControllerReadyForAction(): Unable to find the ScoringModel object");
    assert(0);
  }

  self.panningEnabled = false;
  self.tappingEnabled = false;

  self.longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)];
	[self.longPressRecognizer release];
	[self.playView addGestureRecognizer:self.longPressRecognizer];
  self.longPressRecognizer.delegate = self;
  self.longPressRecognizer.minimumPressDuration = 0;  // place stone immediately
  CGFloat infiniteMovement = CGFLOAT_MAX;
  self.longPressRecognizer.allowableMovement = infiniteMovement;  // let the user pan as long as he wants

  self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
	[self.tapRecognizer release];
	[self.playView addGestureRecognizer:self.tapRecognizer];
  self.tapRecognizer.delegate = self;

  self.statusLineController = [StatusLineController controllerWithStatusLine:self.statusLine];
  self.activityIndicatorController = [ActivityIndicatorController controllerWithActivityIndicator:self.activityIndicator];

  self.playForMeButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:playForMeButtonIconResource]
                                                           style:UIBarButtonItemStyleBordered
                                                          target:self
                                                          action:@selector(playForMe:)] autorelease];
  self.passButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:passButtonIconResource]
                                                      style:UIBarButtonItemStyleBordered
                                                     target:self
                                                     action:@selector(pass:)] autorelease];
  self.oneMoveBackButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:backButtonIconResource]
                                                             style:UIBarButtonItemStyleBordered
                                                            target:self
                                                            action:@selector(oneMoveBack:)] autorelease];
  self.oneMoveForwardButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:playButtonIconResource]
                                                                style:UIBarButtonItemStyleBordered
                                                               target:self
                                                               action:@selector(oneMoveForward:)] autorelease];
  self.pauseButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:pauseButtonIconResource]
                                                       style:UIBarButtonItemStyleBordered
                                                      target:self
                                                      action:@selector(pause:)] autorelease];
  self.continueButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:continueButtonIconResource]
                                                          style:UIBarButtonItemStyleBordered
                                                         target:self
                                                         action:@selector(continue:)] autorelease];
  self.interruptButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:interruptButtonIconResource]
                                                           style:UIBarButtonItemStyleBordered
                                                          target:self
                                                          action:@selector(interrupt:)] autorelease];
  self.gameInfoButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:gameInfoButtonIconResource]
                                                          style:UIBarButtonItemStyleBordered
                                                         target:self
                                                         action:@selector(gameInfo:)] autorelease];
  self.gameActionsButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                          target:self
                                                                          action:@selector(gameActions:)] autorelease];
  self.gameActionsButton.style = UIBarButtonItemStyleBordered;
  self.doneButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                   target:self
                                                                   action:@selector(done:)] autorelease];
  self.doneButton.style = UIBarButtonItemStyleBordered;
  self.flexibleSpaceButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil] autorelease];

  self.gameInfoScore = nil;
  self.discardAndPlayCommand = nil;

  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(goGameWillCreate:) name:goGameWillCreate object:nil];
  [center addObserver:self selector:@selector(goGameDidCreate:) name:goGameDidCreate object:nil];
  [center addObserver:self selector:@selector(goGameStateChanged:) name:goGameStateChanged object:nil];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStarts object:nil];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStops object:nil];
  [center addObserver:self selector:@selector(playViewBoardPositionChanged:) name:playViewBoardPositionChanged object:nil];
  [center addObserver:self selector:@selector(goScoreScoringModeEnabled:) name:goScoreScoringModeEnabled object:nil];
  [center addObserver:self selector:@selector(goScoreScoringModeDisabled:) name:goScoreScoringModeDisabled object:nil];
  [center addObserver:self selector:@selector(goScoreCalculationStarts:) name:goScoreCalculationStarts object:nil];
  [center addObserver:self selector:@selector(goScoreCalculationEnds:) name:goScoreCalculationEnds object:nil];
  // KVO observing
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  [boardPositionModel addObserver:self forKeyPath:@"playOnComputersTurnAlert" options:0 context:NULL];

  // We invoke this to set up initial state because we did not get
  // get goGameDidCreate for the initial game (viewDidLoad gets called too
  // late)
  [self goGameDidCreate:nil];
}

// -----------------------------------------------------------------------------
/// @brief Called when the controller’s view is released from memory, e.g.
/// during low-memory conditions.
///
/// Releases additional objects (e.g. by resetting references to retained
/// objects) that can be easily recreated when viewDidLoad() is invoked again
/// later.
// -----------------------------------------------------------------------------
- (void) viewDidUnload
{
  [super viewDidUnload];

  self.frontSideView = nil;
  self.backSideView = nil;
  self.playView = nil;
  self.toolbar = nil;
  self.statusLine = nil;
  self.activityIndicator = nil;
  self.statusLineController = nil;
  self.activityIndicatorController = nil;
  self.playForMeButton = nil;
  self.passButton = nil;
  self.oneMoveBackButton = nil;
  self.oneMoveForwardButton = nil;
  self.pauseButton = nil;
  self.continueButton = nil;
  self.interruptButton = nil;
  self.flexibleSpaceButton = nil;
  self.gameInfoButton = nil;
  self.gameActionsButton = nil;
  self.doneButton = nil;
  self.scoringModel = nil;
  self.longPressRecognizer = nil;
  self.tapRecognizer = nil;
  self.gameInfoScore = nil;
  self.discardAndPlayCommand = nil;
}

// -----------------------------------------------------------------------------
/// @brief Called by UIKit when the view is about to made visible.
// -----------------------------------------------------------------------------
- (void) viewWillAppear:(BOOL)animated
{
  // Default does nothing, we don't have to invoke [super viewWillAppear]

  // If an interface orientation change occurred while the "Play" tab was not
  // visible, this controller's roation handling in
  // willAnimateRotationToInterfaceOrientation:duration:() was never executed.
  // We therefore provide some additional handling here.

  // Either the frontside or the backside view is currently not part of the
  // view hierarchy, so we must update it manually. The other one who *IS* part
  // of the view hierarchy has already been automatically updated by UIKit.
  if (! self.frontSideView.superview)
    self.frontSideView.frame = self.view.bounds;
  else
    self.backSideView.frame = self.view.bounds;
  // Calculate the PlayView frame only after we can be sure that the superview's
  // bounds are correct (either by the manual update above, or by an automatic
  // update by UIKit).
  CGRect currentPlayViewFrame = self.playView.frame;
  CGRect newPlayViewFrame = [self playViewFrame];
  if (! CGRectEqualToRect(currentPlayViewFrame, newPlayViewFrame))
  {
    // Apparently UIKit invokes viewWillAppear:() while an animation is running.
    // This usage of CATransaction prevents the size change from being animated.
    // If we don't do this, a shrinking animation will take place when an
    // interface rotation to landscape occurred.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.playView.frame = newPlayViewFrame;
    [self.playView frameChanged];
    [CATransaction commit];
  }
}

// -----------------------------------------------------------------------------
/// @brief Called by UIKit at various times to determine whether this controller
/// supports the given orientation @a interfaceOrientation.
// -----------------------------------------------------------------------------
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return [UiUtilities shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

// -----------------------------------------------------------------------------
/// @brief Called by UIKit before performing a one-step user interface
/// rotation.
// -----------------------------------------------------------------------------
- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
  if (self.frontSideView.superview)
  {
    // Manually update backside view because it is currently not part of the
    // view hierarchy
    self.backSideView.frame = self.view.bounds;
    // The frontside view is part of the view hierarchy, so its bounds have
    // been automatically changed and we can safely calculate the new PlayView
    // frame
    CGRect playViewFrame = [self playViewFrame];
    // Because we don't allow the Play view to autoresize we need to perform its
    // animation ourselves.
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationCurveEaseOut
                     animations:^{
                       self.playView.frame = playViewFrame;
                       [self.playView frameChanged];
                     }
                     completion:NULL];
  }
  else
  {
    // Manually update frontside view because it is currently not part of the
    // view hierarchy
    self.frontSideView.frame = self.view.bounds;
    // Calculate the PlayView frame only after the manual change of its
    // superview's bounds
    CGRect playViewFrame = [self playViewFrame];
    // The PlayView is not visible, so no need to animate the frame size change
    self.playView.frame = playViewFrame;
    [self.playView frameChanged];
  }
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Pass" button. Generates a "Pass"
/// move for the human player whose turn it currently is.
// -----------------------------------------------------------------------------
- (void) pass:(id)sender
{
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  if (boardPositionModel.isLastPosition || ! boardPositionModel.isComputerPlayersTurn)
  {
    DiscardAndPlayCommand* command = [[DiscardAndPlayCommand alloc] initPass];
    [self playOrAlertWithCommand:command];
  }
  else
  {
    [self alertCannotPlayOnComputersTurn];
  }
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Play for me" button. Causes the
/// computer player to generate a move for the human player whose turn it
/// currently is.
// -----------------------------------------------------------------------------
- (void) playForMe:(id)sender
{
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  if (boardPositionModel.isLastPosition || ! boardPositionModel.isComputerPlayersTurn)
  {
    DiscardAndPlayCommand* command = [[DiscardAndPlayCommand alloc] initPlayForMe];
    [self playOrAlertWithCommand:command];
  }
  else
  {
    [self alertCannotPlayOnComputersTurn];
  }
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Back" button. Goes back one move in
/// the game's move history. The board is updated to display the new situation.
// -----------------------------------------------------------------------------
- (void) oneMoveBack:(id)sender
{
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  int currentBoardPosition = boardPositionModel.currentBoardPosition;
  boardPositionModel.currentBoardPosition = currentBoardPosition - 1;
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Forward" button. Goes forward one
/// move in the game's move history. The board is updated to display the new
/// situation.
// -----------------------------------------------------------------------------
- (void) oneMoveForward:(id)sender
{
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  int currentBoardPosition = boardPositionModel.currentBoardPosition;
  boardPositionModel.currentBoardPosition = currentBoardPosition + 1;
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Pause" button. Pauses the game if
/// two computer players play against each other.
// -----------------------------------------------------------------------------
- (void) pause:(id)sender
{
  PauseGameCommand* command = [[PauseGameCommand alloc] init];
  [command submit];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Continue" button. Continues the game
/// if it is paused while two computer players play against each other.
// -----------------------------------------------------------------------------
- (void) continue:(id)sender
{
  ContinueGameCommand* command = [[ContinueGameCommand alloc] init];
  [command submit];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Interrupt" button. Interrupts the
/// computer while it is thinking.
// -----------------------------------------------------------------------------
- (void) interrupt:(id)sender
{
  InterruptComputerCommand* command = [[InterruptComputerCommand alloc] init];
  [command submit];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Info" button. Flips the game view to
/// display an alternate view with information about the game in progress.
// -----------------------------------------------------------------------------
- (void) gameInfo:(id)sender
{
  GoScore* score;
  if (self.scoringModel.scoringMode)
    score = self.scoringModel.score;
  else
  {
    assert(! self.gameInfoScore);
    if (! self.gameInfoScore)
    {
      self.gameInfoScore = [GoScore scoreForGame:[GoGame sharedGame] withTerritoryScores:false];
      [self.gameInfoScore calculateWaitUntilDone:true];
    }
    score = self.gameInfoScore;
  }
  GameInfoViewController* gameInfoController = [GameInfoViewController controllerWithDelegate:self score:score];
  [gameInfoController retain];
  [self.backSideView addSubview:gameInfoController.view];

  bool flipToFrontSideView = false;
  [self flipToFrontSideView:flipToFrontSideView];
}

// -----------------------------------------------------------------------------
/// @brief GameInfoViewControllerDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) gameInfoViewControllerDidFinish:(GameInfoViewController*)controller
{
  bool flipToFrontSideView = true;
  [self flipToFrontSideView:flipToFrontSideView];
  [controller.view removeFromSuperview];
  [controller release];
  // Get rid of temporary scoring object
  if (! self.scoringModel.scoringMode)
  {
    assert(self.gameInfoScore);
    self.gameInfoScore = nil;
  }
}

// -----------------------------------------------------------------------------
/// @brief PlayViewActionSheetDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) playViewActionSheetControllerDidFinish:(PlayViewActionSheetController*)controller
{
  [controller release];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to the user dismissing an alert view for which this controller
/// is the delegate.
// -----------------------------------------------------------------------------
- (void) alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (AlertViewTypePlayingNowWillDiscardAllFutureMoves != alertView.tag)
    return;
  switch (buttonIndex)
  {
    case AlertViewButtonTypeNo:
    {
      [self.discardAndPlayCommand release];
      self.discardAndPlayCommand = nil;
    }
    case AlertViewButtonTypeYes:
    {
      [self.discardAndPlayCommand submit];  // deallocates the command
      self.discardAndPlayCommand = nil;
      break;
    }
    default:
    {
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Flips the main play view (on the frontside) over to the game info
/// view (on the backside), and vice versa.
// -----------------------------------------------------------------------------
- (void) flipToFrontSideView:(bool)flipToFrontSideView
{
  [UIView beginAnimations:nil context:nil];
  [UIView setAnimationDuration:0.75];

  if (flipToFrontSideView)
  {
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.view cache:YES];
    [backSideView removeFromSuperview];
    [self.view addSubview:frontSideView];
  }
  else
  {
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.view cache:YES];
    [frontSideView removeFromSuperview];
    [self.view addSubview:backSideView];
  }
  [UIView commitAnimations];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Game Actions" button. Displays an
/// action sheet with actions that related to Go games as a whole.
// -----------------------------------------------------------------------------
- (void) gameActions:(id)sender
{
  PlayViewActionSheetController* controller = [[PlayViewActionSheetController alloc] initWithModalMaster:self delegate:self];
  [controller showActionSheetFromView:self.playView];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Done" button. Ends the currently
/// active mode and returns to normal play mode.
// -----------------------------------------------------------------------------
- (void) done:(id)sender
{
  self.scoringModel.scoringMode = false;  // triggers notification to which this controller reacts
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a dragging, or panning, gesture in the view's Go board
/// area.
// -----------------------------------------------------------------------------
- (void) handlePanFrom:(UIPanGestureRecognizer*)gestureRecognizer
{
  // TODO move the following summary somewhere else where it is not buried in
  // code and forgotten...
  // 1. Touching the screen starts stone placement
  // 2. Stone is placed when finger leaves the screen and the stone is placed
  //    in a valid location
  // 3. Stone placement can be cancelled by placing in an invalid location
  // 4. Invalid locations are: Another stone is already placed on the point;
  //    placing the stone would be suicide; the point is guarded by a Ko; the
  //    point is outside the board
  // 5. While panning/dragging, provide continuous feedback on the current
  //    stone location
  //    - Display a stone of the correct color at the current location
  //    - Mark up the stone differently from already placed stones
  //    - Mark up the stone differently if it is in a valid location, and if
  //      it is in an invalid location
  //    - Display in the status line the vertex of the current location
  //    - If the location is invalid, display the reason in the status line
  //    - If placing a stone would capture other stones, mark up those stones
  //      and display in the status line how many stones would be captured
  //    - If placing a stone would set a group (your own or an enemy group) to
  //      atari, mark up that group
  // 6. Place the stone with an offset to the fingertip position so that the
  //    user can see the stone location

  CGPoint panningLocation = [gestureRecognizer locationInView:self.playView];
  GoPoint* crossHairPoint = [self.playView crossHairPointNear:panningLocation];

  // TODO If the move is not legal, determine the reason (another stone is
  // already placed on the point; suicide move; guarded by Ko rule)
  bool isLegalMove = false;
  if (crossHairPoint)
    isLegalMove = [[GoGame sharedGame] isLegalMove:crossHairPoint];

  UIGestureRecognizerState recognizerState = gestureRecognizer.state;
  switch (recognizerState)
  {
    case UIGestureRecognizerStateBegan:
    {
      BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
      if (! boardPositionModel.isLastPosition && boardPositionModel.isComputerPlayersTurn)
        [self alertCannotPlayOnComputersTurn];
      else
        [self.playView moveCrossHairTo:crossHairPoint isLegalMove:isLegalMove];
      break;
    }
    case UIGestureRecognizerStateChanged:
    {
      [self.playView moveCrossHairTo:crossHairPoint isLegalMove:isLegalMove];
      break;
    }
    case UIGestureRecognizerStateEnded:
    {
      [self.playView moveCrossHairTo:nil isLegalMove:true];
      if (isLegalMove)
      {
        DiscardAndPlayCommand* command = [[DiscardAndPlayCommand alloc] initWithPoint:crossHairPoint];
        [self playOrAlertWithCommand:command];
      }
      break;
    }
    case UIGestureRecognizerStateCancelled:
    {
      // Occurs, for instance, if an alert is displayed while a gesture is
      // being handled.
      [self.playView moveCrossHairTo:nil isLegalMove:true];
      break;
    }
    default:
    {
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tapping gesture in the view's Go board area.
// -----------------------------------------------------------------------------
- (void) handleTapFrom:(UITapGestureRecognizer*)gestureRecognizer
{
  UIGestureRecognizerState recognizerState = gestureRecognizer.state;
  if (UIGestureRecognizerStateEnded != recognizerState)
    return;
  CGPoint tappingLocation = [gestureRecognizer locationInView:self.playView];
  GoPoint* deadStonePoint = [self.playView pointNear:tappingLocation];
  if (! deadStonePoint || ! [deadStonePoint hasStone])
    return;
  [self.scoringModel.score toggleDeadStoneStateOfGroup:deadStonePoint.region];
  [self.scoringModel.score calculateWaitUntilDone:false];
}

// -----------------------------------------------------------------------------
/// @brief UIGestureRecognizerDelegate protocol method. Disables gesture
/// recognition while interactionEnabled() is false.
// -----------------------------------------------------------------------------
- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer
{
  if (gestureRecognizer == self.longPressRecognizer)
    return self.isPanningEnabled;
  else if (gestureRecognizer == self.tapRecognizer)
    return self.isTappingEnabled;
  else
    return false;
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #applicationIsReadyForAction notification.
// -----------------------------------------------------------------------------
- (void) applicationIsReadyForAction:(NSNotification*)notification
{
  // We only need this notification once
  [[NSNotificationCenter defaultCenter] removeObserver:self name:applicationIsReadyForAction object:nil];
  
  [self makeControllerReadyForAction];
  self.controllerReadyForAction = true;
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameWillCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameWillCreate:(NSNotification*)notification
{
  // Disable scoring mode while the old GoGame is still around
  self.scoringModel.scoringMode = false;
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameDidCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameDidCreate:(NSNotification*)notification
{
  [self populateToolbar];
  [self updateButtonStates];
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameStateChanged notification.
// -----------------------------------------------------------------------------
- (void) goGameStateChanged:(NSNotification*)notification
{
  [self updateButtonStates];
  [self updatePanningEnabled];
  if (GoGameStateGameHasEnded == [GoGame sharedGame].state)
  {
    self.scoringModel.scoringMode = true;
    [self.scoringModel.score calculateWaitUntilDone:false];
  }
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #computerPlayerThinkingStarts and
/// #computerPlayerThinkingStops notifications.
// -----------------------------------------------------------------------------
- (void) computerPlayerThinkingChanged:(NSNotification*)notification
{
  [self populateToolbar];
  [self updateButtonStates];
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #playViewBoardPositionChanged notification.
// -----------------------------------------------------------------------------
- (void) playViewBoardPositionChanged:(NSNotification*)notification
{
  [self updateButtonStates];
  [self updatePanningEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreScoringModeEnabled notification.
// -----------------------------------------------------------------------------
- (void) goScoreScoringModeEnabled:(NSNotification*)notification
{
  [self populateToolbar];
  [self updateButtonStates];
  [self updatePanningEnabled];  // disable panning
  [self updateTappingEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreScoringModeDisabled notification.
// -----------------------------------------------------------------------------
- (void) goScoreScoringModeDisabled:(NSNotification*)notification
{
  [self populateToolbar];
  [self updateButtonStates];
  [self updatePanningEnabled];  // enable panning
  [self updateTappingEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreCalculationStarts notification.
// -----------------------------------------------------------------------------
- (void) goScoreCalculationStarts:(NSNotification*)notification
{
  [self updateButtonStates];
  [self updateTappingEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreCalculationEnds notification.
// -----------------------------------------------------------------------------
- (void) goScoreCalculationEnds:(NSNotification*)notification
{
  [self updateButtonStates];
  [self updateTappingEnabled];
}

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  if (object == boardPositionModel)
  {
    if ([keyPath isEqualToString:@"playOnComputersTurnAlert"])
    {
      [self updateButtonStates];
      [self updatePanningEnabled];
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Populates the toolbar with toolbar items that are appropriate for
/// the #GoGameType currently in progress.
// -----------------------------------------------------------------------------
- (void) populateToolbar
{
  NSMutableArray* toolbarItems = [NSMutableArray arrayWithCapacity:0];
  if (self.scoringModel.scoringMode)
  {
    if (GoGameStateGameHasEnded != [GoGame sharedGame].state)
      [toolbarItems addObject:self.doneButton];  // cannot get out of scoring mode if game has ended
    [toolbarItems addObject:self.flexibleSpaceButton];
    [toolbarItems addObject:self.gameInfoButton];
    [toolbarItems addObject:self.gameActionsButton];
  }
  else
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
        [toolbarItems addObject:self.pauseButton];
        [toolbarItems addObject:self.continueButton];
        [toolbarItems addObject:self.interruptButton];
        [toolbarItems addObject:self.flexibleSpaceButton];
        [toolbarItems addObject:self.gameInfoButton];
        [toolbarItems addObject:self.gameActionsButton];
        break;
      default:
        if ([GoGame sharedGame].isComputerThinking)
          [toolbarItems addObject:self.interruptButton];
        else
        {
          [toolbarItems addObject:self.playForMeButton];
          [toolbarItems addObject:self.passButton];
          [toolbarItems addObject:self.oneMoveBackButton];
          [toolbarItems addObject:self.oneMoveForwardButton];
        }
        [toolbarItems addObject:self.flexibleSpaceButton];
        [toolbarItems addObject:self.gameInfoButton];
        [toolbarItems addObject:self.gameActionsButton];
        break;
    }
  }
  self.toolbar.items = toolbarItems;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of all toolbar items.
// -----------------------------------------------------------------------------
- (void) updateButtonStates
{
  [self updatePlayForMeButtonState];
  [self updatePassButtonState];
  [self updateBackButtonState];
  [self updateForwardButtonState];
  [self updatePauseButtonState];
  [self updateContinueButtonState];
  [self updateInterruptButtonState];
  [self updateGameInfoButtonState];
  [self updateGameActionsButtonState];
  [self updateDoneButtonState];
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Play for me" button.
// -----------------------------------------------------------------------------
- (void) updatePlayForMeButtonState
{
  BOOL enabled = NO;
  if (! self.scoringModel.scoringMode)
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
        break;
      default:
      {
        if ([GoGame sharedGame].isComputerThinking)
          break;
        switch ([GoGame sharedGame].state)
        {
          case GoGameStateGameHasNotYetStarted:
          case GoGameStateGameHasStarted:
          {
            BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
            if (boardPositionModel.isLastPosition)
              enabled = YES;
            else if (! boardPositionModel.isComputerPlayersTurn)
              enabled = YES;
            else if (boardPositionModel.playOnComputersTurnAlert)
              enabled = YES;
            else
              enabled = NO;
            break;
          }
          default:
            break;
        }
        break;
      }
    }
  }
  self.playForMeButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Pass" button.
// -----------------------------------------------------------------------------
- (void) updatePassButtonState
{
  BOOL enabled = NO;
  if (! self.scoringModel.scoringMode)
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
        break;
      default:
      {
        if ([GoGame sharedGame].isComputerThinking)
          break;
        switch ([GoGame sharedGame].state)
        {
          case GoGameStateGameHasNotYetStarted:
          case GoGameStateGameHasStarted:
          {
            BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
            if (boardPositionModel.isLastPosition)
              enabled = YES;
            else if (! boardPositionModel.isComputerPlayersTurn)
              enabled = YES;
            else if (boardPositionModel.playOnComputersTurnAlert)
              enabled = YES;
            else
              enabled = NO;
            break;
          }
          default:
            break;
        }
        break;
      }
    }
  }
  self.passButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Back" button.
// -----------------------------------------------------------------------------
- (void) updateBackButtonState
{
  BOOL enabled = NO;
  if (! self.scoringModel.scoringMode)
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
        break;
      default:
      {
        if ([GoGame sharedGame].isComputerThinking)
          break;
        BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
        if (boardPositionModel.isFirstPosition)
          enabled = NO;
        else
          enabled = YES;
        break;
      }
    }
  }
  self.oneMoveBackButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Forward" button.
// -----------------------------------------------------------------------------
- (void) updateForwardButtonState
{
  BOOL enabled = NO;
  if (! self.scoringModel.scoringMode)
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
        break;
      default:
      {
        if ([GoGame sharedGame].isComputerThinking)
          break;
        BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
        if (boardPositionModel.isLastPosition)
          enabled = NO;
        else
          enabled = YES;
        break;
      }
    }
  }
  self.oneMoveForwardButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Pause" button.
// -----------------------------------------------------------------------------
- (void) updatePauseButtonState
{
  BOOL enabled = NO;
  if (! self.scoringModel.scoringMode)
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
      {
        switch ([GoGame sharedGame].state)
        {
          case GoGameStateGameHasNotYetStarted:
          case GoGameStateGameHasStarted:
            enabled = YES;
            break;
          default:
            break;
        }
        break;
      }
      default:
        break;
    }
  }
  self.pauseButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Continue" button.
// -----------------------------------------------------------------------------
- (void) updateContinueButtonState
{
  BOOL enabled = NO;
  if (! self.scoringModel.scoringMode)
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
      {
        switch ([GoGame sharedGame].state)
        {
          case GoGameStateGameIsPaused:
            enabled = YES;
            break;
          default:
            break;
        }
        break;
      }
      default:
        break;
    }
  }
  self.continueButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Interrupt" button.
// -----------------------------------------------------------------------------
- (void) updateInterruptButtonState
{
  BOOL enabled = NO;
  if (self.scoringModel.scoringMode)
  {
    if (self.scoringModel.score.scoringInProgress)
      enabled = YES;
  }
  else
  {
    if ([GoGame sharedGame].isComputerThinking)
      enabled = YES;
  }
  self.interruptButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Info" button.
// -----------------------------------------------------------------------------
- (void) updateGameInfoButtonState
{
  BOOL enabled = NO;
  if (self.scoringModel.scoringMode)
  {
    if (! self.scoringModel.score.scoringInProgress)
      enabled = YES;
  }
  else
  {
    enabled = YES;
  }
  self.gameInfoButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Game Actions" button.
// -----------------------------------------------------------------------------
- (void) updateGameActionsButtonState
{
  BOOL enabled = NO;
  if (self.scoringModel.scoringMode)
  {
    if (! self.scoringModel.score.scoringInProgress)
      enabled = YES;
  }
  else
  {
    switch ([GoGame sharedGame].type)
    {
      case GoGameTypeComputerVsComputer:
      {
        switch ([GoGame sharedGame].state)
        {
          case GoGameStateGameHasNotYetStarted:
          case GoGameStateGameHasEnded:
            enabled = YES;
          case GoGameStateGameIsPaused:
            // Computer may still be thinking
            enabled = ! [GoGame sharedGame].isComputerThinking;
            break;
          default:
            break;
        }
        break;
      }
      default:
      {
        if ([GoGame sharedGame].isComputerThinking)
          break;
        switch ([GoGame sharedGame].state)
        {
          default:
            enabled = YES;
            break;
        }
        break;
      }
    }
  }
  self.gameActionsButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates the enabled state of the "Done" button.
// -----------------------------------------------------------------------------
- (void) updateDoneButtonState
{
  BOOL enabled = NO;
  if (self.scoringModel.scoringMode)
  {
    if (! self.scoringModel.score.scoringInProgress)
      enabled = YES;
  }
  self.doneButton.enabled = enabled;
}

// -----------------------------------------------------------------------------
/// @brief Updates whether panning is enabled.
// -----------------------------------------------------------------------------
- (void) updatePanningEnabled
{
  if (self.scoringModel.scoringMode)
  {
    self.panningEnabled = false;
    return;
  }

  GoGame* game = [GoGame sharedGame];
  if (! game)
  {
    self.panningEnabled = false;
    return;
  }

  if (GoGameTypeComputerVsComputer == game.type)
  {
    self.panningEnabled = false;
    return;
  }

  switch (game.state)
  {
    case GoGameStateGameHasNotYetStarted:
    case GoGameStateGameHasStarted:
      if (game.isComputerThinking)
        self.panningEnabled = false;
      else
      {
        BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
        if (boardPositionModel.isLastPosition)
          self.panningEnabled = true;
        else if (! boardPositionModel.isComputerPlayersTurn)
          self.panningEnabled = true;
        else if (boardPositionModel.playOnComputersTurnAlert)
          self.panningEnabled = true;
        else
          self.panningEnabled = false;
      }
      break;
    default:  // specifically GoGameStateGameHasEnded
      self.panningEnabled = false;
      break;
  }
}

// -----------------------------------------------------------------------------
/// @brief Updates whether tapping is enabled.
// -----------------------------------------------------------------------------
- (void) updateTappingEnabled
{
  if (self.scoringModel.scoringMode)
    self.tappingEnabled = ! self.scoringModel.score.scoringInProgress;
  else
    self.tappingEnabled = false;
}

// -----------------------------------------------------------------------------
/// @brief Executes @a command, or displays an alert and delays execution until
/// the alert is dismissed by the user.
///
/// @a command represents one of several possible ways how a human player can
/// make a move: Either a regular pass or play move, or a "play for me" move.
/// @a command must have a retain count of 1 so that its submit() method can be
/// invoked.
///
/// If the Play view currently displays the board position after the most recent
/// move, @a command is executed immediately.
///
/// If a board position in the middle of the game is displayed, an alert is
/// displayed that warns the user that playing now will discard all future
/// moves. If the user confirms that this is OK, @a command is executed. If the
/// user cancels the operation, @a command is not executed. Handling of the
/// user's response happens in alertView:didDismissWithButtonIndex:().
///
/// The user can suppress the alert in the user preferences. In this case
/// @a command is immediately executed.
// -----------------------------------------------------------------------------
- (void) playOrAlertWithCommand:(DiscardAndPlayCommand*)command
{
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  if (boardPositionModel.isLastPosition || ! boardPositionModel.discardFutureMovesAlert)
  {
    [command submit];  // deallocates the command
  }
  else
  {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Future moves will be discarded"
                                                    message:@"You are looking at a board position in the middle of the game. If you play now, all moves that have been made after this position will be discarded.\n\nDo you want to continue?"
                                                   delegate:self
                                          cancelButtonTitle:@"No"
                                          otherButtonTitles:@"Yes", nil];
    alert.tag = AlertViewTypePlayingNowWillDiscardAllFutureMoves;
    [alert show];
    // Store command object for later use by the alert handler
    self.discardAndPlayCommand = command;
  }
}

// -----------------------------------------------------------------------------
/// @brief Displays the alert #AlertViewTypeCannotPlayOnComputersTurn.
///
/// The user can suppress the alert in the user preferences.
// -----------------------------------------------------------------------------
- (void) alertCannotPlayOnComputersTurn
{
  BoardPositionModel* boardPositionModel = [ApplicationDelegate sharedDelegate].boardPositionModel;
  if (boardPositionModel.playOnComputersTurnAlert)
  {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Cannot play during computer's turn"
                                                    message:@"You are looking at a board position where it is the computer's turn to play. To make a move you must first view a position where it is your turn to play.\n\nNote: You can disable this alert in the board position settings."
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"Ok", nil];
    alert.tag = AlertViewTypeCannotPlayOnComputersTurn;
    // Displaying an alert cancels this round of gesture recognizing (i.e.
    // the gesture recognizer sends UIGestureRecognizerStateCancelled)
    [alert show];
  }
}

@end
