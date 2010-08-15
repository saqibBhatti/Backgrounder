/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2010-08-12 01:03:22
 */

/**
 * Copyright (C) 2008-2010  Lance Fetters (aka. ashikase)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


// NOTE: This struct comes from UIApplication

// Firmware 3.0 - 3.2.
// NOTE: This declaration is incomplete.
typedef struct {
    unsigned isActive : 1;
    unsigned isSuspended : 1;
    unsigned isSuspendedEventsOnly : 1;
    unsigned isLaunchedSuspended : 1;
    unsigned isHandlingURL : 1;
    unsigned isHandlingRemoteNotification : 1;
    unsigned statusBarMode : 8;
    unsigned statusBarShowsProgress : 1;
    unsigned blockInteractionEvents : 4;
    unsigned forceExit : 1;
    unsigned receivesMemoryWarnings : 1;
    unsigned showingProgress : 1;
    unsigned receivesPowerMessages : 1;
    unsigned launchEventReceived : 1;
    unsigned isAnimatingSuspensionOrResumption : 1;
    unsigned isSuspendedUnderLock : 1;
    unsigned shouldExitAfterSendSuspend : 1;
    // ...
} UIApplicationFlags3x;

// Firmware 4.0
typedef struct {
    unsigned isActive : 1;
    unsigned isSuspended : 1;
    unsigned isSuspendedEventsOnly : 1;
    unsigned isLaunchedSuspended : 1;
    unsigned calledNonSuspendedLaunchDelegate : 1;
    unsigned isHandlingURL : 1;
    unsigned isHandlingRemoteNotification : 1;
    unsigned isHandlingLocalNotification : 1;
    unsigned statusBarShowsProgress : 1;
    unsigned statusBarRequestedStyle : 4;
    unsigned statusBarHidden : 1;
    unsigned blockInteractionEvents : 4;
    unsigned receivesMemoryWarnings : 1;
    unsigned showingProgress : 1;
    unsigned receivesPowerMessages : 1;
    unsigned launchEventReceived : 1;
    unsigned isAnimatingSuspensionOrResumption : 1;
    unsigned isResuming : 1;
    unsigned isSuspendedUnderLock : 1;
    unsigned isRunningInTaskSwitcher : 1;
    unsigned shouldExitAfterSendSuspend : 1;
    unsigned shouldExitAfterTaskCompletion : 1;
    unsigned terminating : 1;
    unsigned isHandlingShortCutURL : 1;
    unsigned idleTimerDisabled : 1;
    unsigned deviceOrientation : 3;
    unsigned delegateShouldBeReleasedUponSet : 1;
    unsigned delegateHandleOpenURL : 1;
    unsigned delegateDidReceiveMemoryWarning : 1;
    unsigned delegateWillTerminate : 1;
    unsigned delegateSignificantTimeChange : 1;
    unsigned delegateWillChangeInterfaceOrientation : 1;
    unsigned delegateDidChangeInterfaceOrientation : 1;
    unsigned delegateWillChangeStatusBarFrame : 1;
    unsigned delegateDidChangeStatusBarFrame : 1;
    unsigned delegateDeviceAccelerated : 1;
    unsigned delegateDeviceChangedOrientation : 1;
    unsigned delegateDidBecomeActive : 1;
    unsigned delegateWillResignActive : 1;
    unsigned delegateDidEnterBackground : 1;
    unsigned delegateWillEnterForeground : 1;
    unsigned delegateWillSuspend : 1;
    unsigned delegateDidResume : 1;
    unsigned idleTimerDisableActive : 1;
    unsigned userDefaultsSyncDisabled : 1;
    unsigned headsetButtonClickCount : 4;
    unsigned isHeadsetButtonDown : 1;
    unsigned isFastForwardActive : 1;
    unsigned isRewindActive : 1;
    unsigned disableViewGroupOpacity : 1;
    unsigned disableViewEdgeAntialiasing : 1;
    unsigned shakeToEdit : 1;
    unsigned isClassic : 1;
    unsigned zoomInClassicMode : 1;
    unsigned ignoreHeadsetClicks : 1;
    unsigned touchRotationDisabled : 1;
    unsigned taskSuspendingUnsupported : 1;
    unsigned isUnitTests : 1;
    unsigned disableViewContentScaling : 1;
} UIApplicationFlags4x;

//==============================================================================

@interface UIApplication (Private)
- (void)addStatusBarImageNamed:(id)named;
- (NSString *)displayIdentifier;
- (void)removeStatusBarImageNamed:(id)named;
- (void)terminateWithSuccess;
@end
@interface UIApplication (Firmware4x)
- (id)_backgroundModes;
@end

@interface UIModalView : UIView
@property(copy, nonatomic) NSString *message;
@property(copy, nonatomic) NSString *title;
- (void)setNumberOfRows:(int)rows;
@end

//==============================================================================

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SpringBoard.h>

@interface SBIcon (Firmware32x)
+ (CGSize)defaultIconImageSize;
@end

// Firmware >= 4.0
@interface SBProcess : NSObject
@property(readonly, assign) int pid;
@end

// Firmware >= 4.0
@interface SBApplication (Firmware4x)
@property(retain) SBProcess *process;
- (void)setSuspendType:(int)type;
- (int)_suspensionType;
@end

// Firmware >= 4.0
@interface SBIconModel (Firmware4x)
- (id)leafIconForIdentifier:(id)identifier; 
@end

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */