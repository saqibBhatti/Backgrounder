/**
 * Name: Backgrounder
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Description: allow applications to run in the background
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2009-11-30 02:28:27
 */

/**
 * Copyright (C) 2008-2009  Lance Fetters (aka. ashikase)
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


#import "SpringBoardHooks.h"

#import <CoreFoundation/CoreFoundation.h>

#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SpringBoard.h>

#import "SimplePopup.h"

struct GSEvent;


static BOOL isPersistent = YES;

static NSMutableArray *activeApps = nil;
static NSMutableArray *bgEnabledApps = nil;
static NSArray *blacklistedApps = nil;

#if 0
static NSMutableDictionary *statusBarStates = nil;
static NSString *deactivatingApp = nil;

static BOOL animateStatusBar = YES;
#endif

static BOOL badgeEnabled = NO;
static BOOL badgeEnabledForAll = YES;

typedef enum {
    BGInvocationMethodNone,
    BGInvocationMethodMenuShortHold,
    BGInvocationMethodLockShortHold
} BGInvocationMethod;

static BGInvocationMethod invocationMethod = BGInvocationMethodMenuShortHold;

//______________________________________________________________________________
//______________________________________________________________________________

static void loadPreferences()
{
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("persistent"), CFSTR(APP_ID));
    if (propList) {
        // NOTE: Defaults to YES
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            isPersistent = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("badgeEnabled"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            badgeEnabled = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("badgeEnabledForAll"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID())
            badgeEnabledForAll = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("blacklistedApplications"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFArrayGetTypeID())
            blacklistedApps = [[NSArray alloc] initWithArray:(NSArray *)propList];
        CFRelease(propList);
    }

    propList = CFPreferencesCopyAppValue(CFSTR("invocationMethod"), CFSTR(APP_ID));
    if (propList) {
        // NOTE: Defaults to BGInvocationMethodMenuShortHold
        if ([(NSString *)propList isEqualToString:@"powerShortHold"])
            invocationMethod = BGInvocationMethodLockShortHold;
        else if ([(NSString *)propList isEqualToString:@"none"])
            invocationMethod = BGInvocationMethodNone;
        CFRelease(propList);
    }
}

//______________________________________________________________________________
//______________________________________________________________________________

@interface UIView (Private)
- (void)setOrigin:(CGPoint)origin;
@end

static void showBadgeForDisplayIdentifier(NSString *identifier)
{
    // Update the application's SpringBoard icon to indicate that it is running
    SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
    if (![icon viewWithTag:1000]) {
        // Icon does not have a badge
        UIImageView *badgeView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Backgrounder_Badge.png"]];
        [badgeView setOrigin:CGPointMake(-12.0f, 39.0f)];
        [badgeView setTag:1000];
        [icon addSubview:badgeView];
        [badgeView release];
    }
}

//______________________________________________________________________________
//______________________________________________________________________________

NSMutableArray *displayStacks = nil;

// Display stack names
#define SBWPreActivateDisplayStack        [displayStacks objectAtIndex:0]
#define SBWActiveDisplayStack             [displayStacks objectAtIndex:1]
#define SBWSuspendingDisplayStack         [displayStacks objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack [displayStacks objectAtIndex:3]

HOOK(SBDisplayStack, init, id)
{
    id stack = CALL_ORIG(SBDisplayStack, init);
    [displayStacks addObject:stack];
    return stack;
}

HOOK(SBDisplayStack, dealloc, void)
{
    [displayStacks removeObject:self];
    CALL_ORIG(SBDisplayStack, dealloc);
}

//______________________________________________________________________________
//______________________________________________________________________________

#if 0
HOOK(SBStatusBarController, setStatusBarMode$mode$orientation$duration$fenceID$animation$,
    void, int mode, int orientation, float duration, int fenceID, int animation)
{
    if (!animateStatusBar) {
        duration = 0;
        // Reset the flag to default (animation enabled)
        animateStatusBar = YES;
    }
    CALL_ORIG(SBStatusBarController, setStatusBarMode$mode$orientation$duration$fenceID$animation$,
            mode, orientation, duration, fenceID, animation);
}
#endif

//______________________________________________________________________________
//______________________________________________________________________________

// The alert window displays instructions when the home button is held down
static NSTimer *invocationTimer = nil;
static BOOL invocationTimerDidFire = NO;
static id alert = nil;

static void startInvocationTimer()
{
    SpringBoard *springBoard = (SpringBoard *)[objc_getClass("SpringBoard") sharedApplication];
    invocationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.7f
        target:springBoard selector:@selector(invokeBackgrounder)
        userInfo:nil repeats:NO] retain];
}

static void cancelInvocationTimer()
{
    // Disable and release timer (may be nil)
    [invocationTimer invalidate];
    [invocationTimer release];
    invocationTimer = nil;
}

// NOTE: Only hooked when invocationMethod == BGInvocationMethodMenuShortHold
HOOK(SpringBoard, menuButtonDown$, void, GSEvent *event)
{
    invocationTimerDidFire = NO;

    if ([SBWActiveDisplayStack topApplication] != nil)
        // Not SpringBoard, start hold timer
        startInvocationTimer();

    CALL_ORIG(SpringBoard, menuButtonDown$, event);
}

// NOTE: Only hooked when invocationMethod == BGInvocationMethodMenuShortHold
HOOK(SpringBoard, menuButtonUp$, void, GSEvent *event)
{
    if (invocationTimerDidFire)
        // Backgrounder popup is visible; hide it
        [self dismissBackgrounderFeedback];
    else
        cancelInvocationTimer();

    CALL_ORIG(SpringBoard, menuButtonUp$, event);
}

// NOTE: Only hooked when invocationMethod == BGInvocationMethodLockShortHold
HOOK(SpringBoard, lockButtonDown$, void, GSEvent *event)
{
    invocationTimerDidFire = NO;

    if ([SBWActiveDisplayStack topApplication] != nil)
        // Not SpringBoard, start hold timer
        startInvocationTimer();

    CALL_ORIG(SpringBoard, lockButtonDown$, event);
}

// NOTE: Only hooked when invocationMethod == BGInvocationMethodLockShortHold
HOOK(SpringBoard, lockButtonUp$, void, GSEvent *event)
{
    if (invocationTimerDidFire) {
        // Reset the lock button state
        [self _unsetLockButtonBearTrap];
        [self _setLockButtonTimer:nil];

        // Backgrounder popup is visible; hide it
        [self dismissBackgrounderFeedback];

        // Simulate menu button press to suspend current app
        [self _handleMenuButtonEvent];
    } else {
        cancelInvocationTimer();
        CALL_ORIG(SpringBoard, lockButtonUp$, event);
    }
}

HOOK(SpringBoard, applicationDidFinishLaunching$, void, id application)
{
    // NOTE: SpringBoard creates four stacks at startup
    displayStacks = [[NSMutableArray alloc] initWithCapacity:4];

    // NOTE: The initial capacity value was chosen to hold the default active
    //       apps (MobilePhone and MobileMail) plus two others
    activeApps = [[NSMutableArray alloc] initWithCapacity:4];
    bgEnabledApps = [[NSMutableArray alloc] initWithCapacity:2];

#if 0
    // Create a dictionary to store the statusbar state for active apps
    // FIXME: Determine a way to do this without requiring extra storage
    statusBarStates = [[NSMutableDictionary alloc] initWithCapacity:5];
#endif

    // Initialize simple notification popup
    initSimplePopup();

    CALL_ORIG(SpringBoard, applicationDidFinishLaunching$, application);
}

HOOK(SpringBoard, dealloc, void)
{
    [bgEnabledApps release];
    [activeApps release];
    [displayStacks release];
    CALL_ORIG(SpringBoard, dealloc);
}

static void $SpringBoard$invokeBackgrounder(SpringBoard *self, SEL sel)
{
    invocationTimerDidFire = YES;

    id app = [SBWActiveDisplayStack topApplication];
    NSString *identifier = [app displayIdentifier];
    if (app && ![blacklistedApps containsObject:identifier]) {
        BOOL isEnabled = [bgEnabledApps containsObject:identifier];
        [self setBackgroundingEnabled:(!isEnabled) forDisplayIdentifier:identifier];

        // Display simple popup
        NSString *status = [NSString stringWithFormat:@"Backgrounding %s",
                 (isEnabled ? "Disabled" : "Enabled")];

        alert = [[objc_getClass("BackgrounderAlertItem") alloc] initWithTitle:status message:nil];

        SBAlertItemsController *controller = [objc_getClass("SBAlertItemsController") sharedInstance];
        [controller activateAlertItem:alert];
    }
}

static void $SpringBoard$dismissBackgrounderFeedback(SpringBoard *self, SEL sel)
{
    // Hide and release alert window (may be nil)
    [alert dismiss];
    [alert release];
    alert = nil;
}

static void $SpringBoard$setBackgroundingEnabled$forDisplayIdentifier$(SpringBoard *self, SEL sel, BOOL enable, NSString *identifier)
{
    if (![blacklistedApps containsObject:identifier]) {
        // Not blacklisted
        BOOL isEnabled = [bgEnabledApps containsObject:identifier];
        if (isEnabled != enable) {
            // Tell the application to change its backgrounding status
            SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
                applicationWithDisplayIdentifier:identifier];
            // FIXME: If the target application does not have the Backgrounder
            //        hooks enabled, this will cause it to exit abnormally
            kill([app pid], SIGUSR1);

            // Store the new backgrounding status of the application
            if (enable)
                [bgEnabledApps addObject:identifier];
            else
                [bgEnabledApps removeObject:identifier];
        }
    }
}

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SBApplication, launchSucceeded$, void, BOOL unknownFlag)
{
    NSString *identifier = [self displayIdentifier];

    BOOL isAlwaysEnabled = NO;
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("enabledApplications"), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFArrayGetTypeID())
            isAlwaysEnabled = [(NSArray *)propList containsObject:identifier];
        CFRelease(propList);
    }

    if ([activeApps containsObject:identifier]) {
        // Was restored from backgrounded state
        if (!isPersistent && !isAlwaysEnabled) {
            // Tell the application to disable backgrounding
            kill([self pid], SIGUSR1);

            // Store the backgrounding status of the application
            [bgEnabledApps removeObject:identifier];
        } 
    } else {
        // Initial launch; check if this application is set to always background
        if (isAlwaysEnabled) {
            // Tell the application to enable backgrounding
            kill([self pid], SIGUSR1);

            // Store the backgrounding status of the application
            [bgEnabledApps addObject:identifier];
        }

        // Track active status of application
        [activeApps addObject:identifier];
    }

    if (badgeEnabled && (badgeEnabledForAll || [bgEnabledApps containsObject:identifier]))
        // NOTE: This is mainly to catch applications that start in the background
        showBadgeForDisplayIdentifier(identifier);

    CALL_ORIG(SBApplication, launchSucceeded$, unknownFlag);
}

HOOK(SBApplication, exitedAbnormally, void)
{
    [bgEnabledApps removeObject:[self displayIdentifier]];
    CALL_ORIG(SBApplication, exitedAbnormally);
}

HOOK(SBApplication, exitedCommon, void)
{
    // Application has exited (either normally or abnormally);
    // remove from active applications list
    NSString *identifier = [self displayIdentifier];
    [activeApps removeObject:identifier];

#if 0
    // ... also remove status bar state data from states list
    [statusBarStates removeObjectForKey:identifier];
#endif

    if (badgeEnabled) {
        // Update the SpringBoard icon to indicate that the app is not running
        SBApplicationIcon *icon = [[objc_getClass("SBIconModel") sharedInstance] iconForDisplayIdentifier:identifier];
        [[icon viewWithTag:1000] removeFromSuperview];
    }

    CALL_ORIG(SBApplication, exitedCommon);
}

HOOK(SBApplication, deactivate, void)
{
#if 0
    NSString *identifier = [self displayIdentifier];
    if ([identifier isEqualToString:deactivatingApp]) {
        [[objc_getClass("SpringBoard") sharedApplication] dismissBackgrounderFeedback];
        [deactivatingApp release];
        deactivatingApp = nil;
    }

    // Store the status bar state of the current application
    SBStatusBarController *sbCont = [objc_getClass("SBStatusBarController") sharedStatusBarController];
    NSNumber *mode = [NSNumber numberWithInt:[sbCont statusBarMode]];
    NSNumber *orientation = [NSNumber numberWithInt:[sbCont statusBarOrientation]];
    [statusBarStates setObject:[NSArray arrayWithObjects:mode, orientation, nil] forKey:identifier];
#endif

    NSString *identifier = [self displayIdentifier];
    BOOL isBackgrounded = [bgEnabledApps containsObject:identifier];

    if (badgeEnabled && (badgeEnabledForAll || isBackgrounded))
        // In case badge has not been added yet, add now
        showBadgeForDisplayIdentifier(identifier);

    BOOL flag;
    if (isBackgrounded) {
        // Temporarily enable the eventOnly flag to prevent the applications's views
        // from being deallocated.
        // NOTE: Credit for this goes to phoenix3200 (author of Pandora Controls, http://phoenix-dev.com/)
        // FIXME: Run a trace on deactivate to determine why this works.
        flag = [self deactivationSetting:0x1];
        [self setDeactivationSetting:0x1 flag:YES];
    }

    CALL_ORIG(SBApplication, deactivate);

    if (isBackgrounded)
        // Must disable the eventOnly flag before returning, or else the application
        // will remain in the event-only display stack and prevent SpringBoard from
        // operating properly.
        // NOTE: This is the continuation of phoenix3200's fix
        [self setDeactivationSetting:0x1 flag:flag];
}

// NOTE: Observed types:
//         0: Launch
//         1: Resume
//         2: Deactivation
//         3: Termination
HOOK(SBApplication, _startWatchdogTimerType$, void, int type)
{
    if (type != 3 || ![bgEnabledApps containsObject:[self displayIdentifier]])
        CALL_ORIG(SBApplication, _startWatchdogTimerType$, type);
}

//______________________________________________________________________________
//______________________________________________________________________________

void initSpringBoardHooks()
{
    loadPreferences();

    Class $SBDisplayStack = objc_getClass("SBDisplayStack");
    LOAD_HOOK($SBDisplayStack, @selector(init), SBDisplayStack$init);
    LOAD_HOOK($SBDisplayStack, @selector(dealloc), SBDisplayStack$dealloc);

#if 0
    Class $SBStatusBarController(objc_getClass("SBStatusBarController"));
    LOAD_HOOK($SBStatusBarController, @selector(setStatusBarMode:orientation:duration:fenceID:animation:),
        SBStatusBarController$setStatusBarMode$mode$orientation$duration$fenceID$animation$);
#endif

    Class $SpringBoard = objc_getClass("SpringBoard");
    LOAD_HOOK($SpringBoard, @selector(applicationDidFinishLaunching:), SpringBoard$applicationDidFinishLaunching$);
    LOAD_HOOK($SpringBoard, @selector(dealloc), SpringBoard$dealloc);

    class_addMethod($SpringBoard, @selector(setBackgroundingEnabled:forDisplayIdentifier:),
        (IMP)&$SpringBoard$setBackgroundingEnabled$forDisplayIdentifier$, "v@:c@");
    class_addMethod($SpringBoard, @selector(invokeBackgrounder), (IMP)&$SpringBoard$invokeBackgrounder, "v@:");
    class_addMethod($SpringBoard, @selector(dismissBackgrounderFeedback), (IMP)&$SpringBoard$dismissBackgrounderFeedback, "v@:");

    Class $SBApplication = objc_getClass("SBApplication");
    LOAD_HOOK($SBApplication, @selector(launchSucceeded:), SBApplication$launchSucceeded$);
    LOAD_HOOK($SBApplication, @selector(deactivate), SBApplication$deactivate);
    LOAD_HOOK($SBApplication, @selector(exitedAbnormally), SBApplication$exitedAbnormally);
    LOAD_HOOK($SBApplication, @selector(exitedCommon), SBApplication$exitedCommon);
    LOAD_HOOK($SBApplication, @selector(_startWatchdogTimerType:), SBApplication$_startWatchdogTimerType$);
#if 0
    LOAD_HOOK($SBApplication, @selector(_relaunchAfterAbnormalExit:), SBApplication$_relaunchAfterAbnormalExit$);
    LOAD_HOOK($SBApplication, @selector(pathForDefaultImage:), SBApplication$pathForDefaultImage$);
#endif

    switch (invocationMethod) {
        case BGInvocationMethodMenuShortHold:
            LOAD_HOOK($SpringBoard, @selector(menuButtonDown:), SpringBoard$menuButtonDown$);
            LOAD_HOOK($SpringBoard, @selector(menuButtonUp:), SpringBoard$menuButtonUp$);
            break;
        case BGInvocationMethodLockShortHold:
            LOAD_HOOK($SpringBoard, @selector(lockButtonDown:), SpringBoard$lockButtonDown$);
            LOAD_HOOK($SpringBoard, @selector(lockButtonUp:), SpringBoard$lockButtonUp$);
            break;
        case BGInvocationMethodNone:
        default:
            break;
    }
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */