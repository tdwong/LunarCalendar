 //
//  LunarCalendarController.m
//  LunarCalendarController
//
//  Created by Merlin on 12-3-13.
//  Copyright (c) 2012-2014 autopear. All rights reserved.
//

#ifndef __LP64__

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "BBWeeAppController-Protocol.h"
#import "LunarCalendar/LunarCalendar.h"
#import "SpringBoard.h"
#import "TouchFix/TouchFix.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
#define lcAlignLeft NSTextAlignmentLeft
#define lcAlignCenter NSTextAlignmentCenter
#define lcAlignRight NSTextAlignmentRight
#else
#define lcAlignLeft UITextAlignmentLeft
#define lcAlignCenter UITextAlignmentCenter
#define lcAlignRight UITextAlignmentRight
#endif

#define PreferencesChangedNotification "com.autopear.lunarcalendar/prefs"
#define PreferencesFilePath @"/private/var/mobile/Library/Preferences/com.autopear.lunarcalendar.plist"

//Controller for iOS 5 & 6
@interface LunarCalendarController : UIViewController <BBWeeAppController, UIAlertViewDelegate> {
    UIView *_weeView;
    UIImageView *_backgroundImageView;
    UIScrollView *_scrollView;
    UILabel *_pageView1;
    UILabel *_pageView2;
    UILabel *_pageView3;
    UIAlertView *_alert;
    unsigned int _currentDate;
    NSMutableDictionary *_dateInfo;
}
- (id)init;
- (void)dealloc;
- (UIView *)view;
- (CGFloat)bulletinViewWidth;
- (void)longPress:(UILongPressGestureRecognizer *)gesture;
- (void)singleTap:(UITapGestureRecognizer *)gesture;
- (void)doubleTap:(UITapGestureRecognizer *)gesture;
- (NSString *)customDatePrinter:(int)format;
- (void)dismissAlert;
- (void)refreshLabel;
- (NSString *)calculateDate:(NSString *)template;
- (void)viewWillAppear;
- (void)viewWillDisappear;
@end

@implementation LunarCalendarController

static NSBundle *localizedBundle = nil;
static NSString *lanCode = nil;
static NSDictionary *languageStrings = nil;
static CGFloat viewHeight = 28.0f;
static int fontSize = 18;
static int switchGesture = 0;
static int textAlign = 1;
static int pageNo = 0;
static CGFloat sideMargin = 0;
static CGFloat colorRed = 1.0f;
static CGFloat colorGreen = 1.0f;
static CGFloat colorBlue = 1.0f;
static CGFloat colorAlpha = 1.0f;
static CGFloat shadowWidth = 0.0f;
static CGFloat shadowHeight = 0.0f;
static CGFloat shadowRed = 0.0f;
static CGFloat shadowGreen = 0.0f;
static CGFloat shadowBlue = 0.0f;
static CGFloat shadowAlpha = 1.0f;
static BOOL viewHeightChanged = NO;
static BOOL fontChanged = NO;
static BOOL formatChanged1 = NO;
static BOOL formatChanged2 = NO;
static BOOL formatChanged3 = NO;
static BOOL textAlignChanged = NO;
static BOOL sideMarginChanged = NO;
static BOOL textColorChanged = NO;
static BOOL shadowChaned = NO;
static NSString *displayDate1 = @"";
static NSString *displayDate2 = @"";
static NSString *displayDate3 = @"";
static NSString *fontName = @"";

static void LoadPreferences() {
    if (languageStrings) {
        [languageStrings release];
        languageStrings = nil;
    }
    if (lanCode) {
        [lanCode release];
        lanCode = nil;
    }

    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:PreferencesFilePath];
    if (preferences) {
        NSString *readLanguage = [preferences objectForKey:@"Language"] ? [preferences objectForKey:@"Language"] : @"default";
        if (![readLanguage isEqualToString:@"default"]) {
            lanCode = [readLanguage retain];
            NSString *languagePath = [NSString stringWithFormat:@"/Library/PreferenceBundles/LunarCalendar.bundle/%@.lproj/LunarCalendar.strings", readLanguage];
            if ([[NSFileManager defaultManager] fileExistsAtPath:languagePath])
                languageStrings = [[NSDictionary alloc] initWithContentsOfFile:languagePath];
        }

        int readSwitchGesture = [preferences objectForKey:@"SwitchGesture"] ? [[preferences objectForKey:@"SwitchGesture"] intValue] : 0;
        if (readSwitchGesture > 2 || readSwitchGesture < 0)
            readSwitchGesture = 0;
        if (readSwitchGesture != switchGesture)
            switchGesture = readSwitchGesture;

        CGFloat readViewHeight = [preferences objectForKey:@"ViewHeight"] ? [[preferences objectForKey:@"ViewHeight"] floatValue] : 28.0f;
        if (readViewHeight < 20.0f || readViewHeight > 100.0f)
            readViewHeight = 28.0f;
        if (readViewHeight != viewHeight) {
            viewHeightChanged = YES;
            viewHeight = readViewHeight;
        }

        int readFontSize = [preferences objectForKey:@"FontSize"] ? [[preferences objectForKey:@"FontSize"] intValue] : 18;
        if (readFontSize < 15 || readFontSize > 40)
            readFontSize = 18;
        if (readFontSize != fontSize) {
            fontChanged = YES;
            fontSize = readFontSize;
        }

        NSString *readFontName = [preferences objectForKey:@"FontName"] ? [preferences objectForKey:@"FontName"] : @"Helvetica-Bold";
        if (readFontName != fontName) {
            fontChanged = YES;
            fontName = [readFontName retain];
        }

        NSString *readFormat1 = [preferences objectForKey:@"CustomFormat1"] ? [preferences objectForKey:@"CustomFormat1"] : @"";
        if (![readFormat1 isEqualToString:displayDate1]) {
            formatChanged1 = YES;
            displayDate1 = [readFormat1 retain];
        }

        NSString *readFormat2 = [preferences objectForKey:@"CustomFormat2"] ? [preferences objectForKey:@"CustomFormat2"] : @"";
        if ([readFormat2 length] == 0) {
            if (languageStrings && [languageStrings objectForKey:@"DateFormatNormal"])
                readFormat2 = [languageStrings objectForKey:@"DateFormatNormal"];
            if ([readFormat2 length] == 0)
                readFormat2 =  NSLocalizedStringFromTableInBundle(@"DateFormatNormal", @"LunarCalendar", localizedBundle, @"[HY][EY]/[LM]/[LD] [Z]");
        }

        if (![readFormat2 isEqualToString:displayDate2]) {
            formatChanged2 = YES;
            displayDate2 = [readFormat2 retain];
        }

        NSString *readFormat3 = [preferences objectForKey:@"CustomFormat3"] ? [preferences objectForKey:@"CustomFormat3"] : @"";
        if ([readFormat3 length] == 0) {
            if (languageStrings && [languageStrings objectForKey:@"DateFormatTraditional"])
                readFormat3 = [languageStrings objectForKey:@"DateFormatTraditional"];
            if ([readFormat3 length] == 0)
                readFormat3 =  NSLocalizedStringFromTableInBundle(@"DateFormatTraditional", @"LunarCalendar", localizedBundle, @"[HY][EY]/[HM][EM]/[HD][ED]");
        }

        if (![readFormat3 isEqualToString:displayDate3]) {
            formatChanged3 = YES;
            displayDate3 = [readFormat3 retain];
        }

        int readTextAlign = [preferences objectForKey:@"TextAlign"] ? [[preferences objectForKey:@"TextAlign"] intValue] : 1;
        if (readTextAlign < 0 || readTextAlign > 2)
            readTextAlign = 1;
        if (readTextAlign != textAlign) {
            textAlignChanged = YES;
            textAlign = readTextAlign;
        }
        if (textAlign == 1) {
            if (sideMargin != 0.0f) {
                sideMargin = 0.0f;
                sideMarginChanged = YES;
            }
        }

        if (!sideMarginChanged) {
            CGFloat readSideMargin = [preferences objectForKey:@"SideMargin"] ? [[preferences objectForKey:@"SideMargin"] floatValue] : 0;
            if (readSideMargin < 0)
                readSideMargin = 0;
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                if (readSideMargin > 250.0f)
                    readSideMargin = 250.0f;
            } else {
                if (readSideMargin > 150.0f)
                    readSideMargin = 150.0f;
            }
            if (readSideMargin != sideMargin) {
                sideMarginChanged = YES;
                sideMargin = readSideMargin;
            }
        }

        CGFloat readColorRed = [preferences objectForKey:@"ColorRed"] ? [[preferences objectForKey:@"ColorRed"] floatValue] : 1.0f;
        if (readColorRed < 0.0f || readColorRed > 1.0f)
            readColorRed = 1.0f;
        CGFloat readColorGreen = [preferences objectForKey:@"ColorGreen"] ? [[preferences objectForKey:@"ColorGreen"] floatValue] : 1.0f;
        if (readColorGreen < 0.0f || readColorGreen > 1.0f)
            readColorGreen = 1.0f;
        CGFloat readColorBlue = [preferences objectForKey:@"ColorBlue"] ? [[preferences objectForKey:@"ColorBlue"] floatValue] : 1.0f;
        if (readColorBlue < 0.0f || readColorBlue > 1.0f)
            readColorBlue = 1.0f;
        CGFloat readColorAlpha = [preferences objectForKey:@"ColorAlpha"] ? [[preferences objectForKey:@"ColorAlpha"] floatValue] : 1.0f;
        if (readColorAlpha < 0.0f || readColorAlpha > 1.0f)
            readColorAlpha = 1.0f;
        if (readColorRed != colorRed || readColorGreen != colorGreen || readColorBlue != colorBlue || readColorAlpha != colorAlpha) {
            textColorChanged = YES;
            colorRed = readColorRed;
            colorGreen = readColorGreen;
            colorBlue = readColorBlue;
            colorAlpha = readColorAlpha;
        }

        CGFloat readShadowWidth = [preferences objectForKey:@"ShadowWidth"] ? [[preferences objectForKey:@"ShadowWidth"] floatValue] : 1.0f;
        if (readShadowWidth < -5.0f)
            readShadowWidth = -5.0f;
        if (readShadowWidth > 5.0f)
            readShadowWidth = 5.0f;
        CGFloat readShadowHeight = [preferences objectForKey:@"ShadowHeight"] ? [[preferences objectForKey:@"ShadowHeight"] floatValue] : 1.0f;
        if (readShadowHeight < -5.0f)
            readShadowHeight = -5.0f;
        if (readShadowHeight > 5.0f)
            readShadowHeight = 5.0f;

        CGFloat readShadowRed = [preferences objectForKey:@"ShadowRed"] ? [[preferences objectForKey:@"ShadowRed"] floatValue] : 0.0f;
        if (readShadowRed < 0.0f || readShadowRed > 1.0f)
            readShadowRed = 1.0f;
        CGFloat readShadowGreen = [preferences objectForKey:@"ShadowGreen"] ? [[preferences objectForKey:@"ShadowGreen"] floatValue] : 0.0f;
        if (readShadowGreen < 0.0f || readShadowGreen > 1.0f)
            readShadowGreen = 1.0f;
        CGFloat readShadowBlue = [preferences objectForKey:@"ShadowBlue"] ? [[preferences objectForKey:@"ShadowBlue"] floatValue] : 0.0f;
        if (readShadowBlue < 0.0f || readShadowBlue > 1.0f)
            readShadowBlue = 1.0f;
        CGFloat readShadowAlpha = [preferences objectForKey:@"ShadowAlpha"] ? [[preferences objectForKey:@"ShadowAlpha"] floatValue] : 1.0f;
        if (readShadowAlpha < 0.0f || readShadowAlpha > 1.0f)
            readShadowAlpha = 1.0f;
        if (readShadowWidth != shadowWidth || readShadowHeight != shadowHeight || readShadowRed != shadowRed || readShadowGreen != shadowGreen || readShadowBlue != shadowBlue || readShadowAlpha != shadowAlpha) {
            shadowChaned = YES;
            shadowWidth = readShadowWidth;
            shadowHeight = readShadowHeight;
            shadowRed = readShadowRed;
            shadowGreen = readShadowGreen;
            shadowBlue = readShadowBlue;
            shadowAlpha = readShadowAlpha;
        }
    } else {
        displayDate1 = @"";
        displayDate2 = [NSLocalizedStringFromTableInBundle(@"DateFormatNormal", @"LunarCalendar", localizedBundle, @"[HY][EY]/[LM]/[LD] [Z]") retain];
        displayDate3 = [NSLocalizedStringFromTableInBundle(@"DateFormatTraditional", @"LunarCalendar", localizedBundle, @"[HY][EY]/[HM][EM]/[HD][ED]") retain];
        switchGesture = 0;
        fontSize = 18;
        fontName = @"Helvetica-Bold";
        textAlign = 1;
        sideMargin = 0;
        colorRed = 1.0f;
        colorGreen = 1.0f;
        colorBlue = 1.0f;
        colorAlpha = 1.0f;
        shadowWidth = 1.0f;
        shadowHeight = 1.0f;
        shadowRed = 0.0f;
        shadowGreen = 0.0f;
        shadowBlue = 0.0f;
        shadowAlpha = 1.0f;
    }
    [preferences release];
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    LoadPreferences();
}

- (id)init {
    if (kCFCoreFoundationVersionNumber >= 847.20) //iOS 7+
        return nil;

    if ((self = [super init])) {
        localizedBundle = [[NSBundle alloc] initWithPath:@"/Library/PreferenceBundles/LunarCalendar.bundle/"];

        LoadPreferences();

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);

        _dateInfo = [[NSMutableDictionary alloc] initWithCapacity:17];

        CGFloat superWidth = [self bulletinViewWidth];

        _weeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, superWidth, viewHeight)];

        UIImage *bg = [[UIImage imageWithContentsOfFile:@"/System/Library/WeeAppPlugins/LunarCalendar.bundle/WeeAppBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];

        _backgroundImageView = [[UIImageView alloc] initWithImage:bg];
        _backgroundImageView.frame = CGRectMake(2, 0, (superWidth - 4), viewHeight);
        [_weeView addSubview:_backgroundImageView];

        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(2, 0, (superWidth - 4), viewHeight)];
        _scrollView.pagingEnabled = YES;
        _scrollView.bounces = YES;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.userInteractionEnabled = YES;

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];

        UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
        doubleTapGestureRecognizer.numberOfTapsRequired = 2;

        UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
        singleTapGestureRecognizer.numberOfTapsRequired = 1;
        [singleTapGestureRecognizer requireGestureRecognizerToFail:doubleTapGestureRecognizer];

        [_scrollView addGestureRecognizer:longPress];
        [_scrollView addGestureRecognizer:doubleTapGestureRecognizer];
        [_scrollView addGestureRecognizer:singleTapGestureRecognizer];

        [longPress release];
        [doubleTapGestureRecognizer release];
        [singleTapGestureRecognizer release];

        UIColor *labelTextColor = [UIColor colorWithRed:colorRed green:colorGreen blue:colorBlue alpha:colorAlpha];
        UIColor *labelShadowColor = [UIColor colorWithRed:shadowRed green:shadowGreen blue:shadowBlue alpha:shadowAlpha];
        CGSize labelShadowSize = CGSizeMake(shadowWidth, shadowHeight);

        CGRect frame1, frame2, frame3;
        if (textAlign == 0) {
            frame1 = CGRectMake(sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
            frame2 = CGRectMake((superWidth - 4) + sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
            frame3 = CGRectMake((superWidth - 4) * 2 + sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
        } else if (textAlign == 2) {
            frame1 = CGRectMake(0, 0, (superWidth - 4 - sideMargin), viewHeight);
            frame2 = CGRectMake((superWidth - 4), 0, (superWidth - 4 - sideMargin), viewHeight);
            frame3 = CGRectMake((superWidth - 4) * 2, 0, (superWidth - 4 - sideMargin), viewHeight);
        } else {
            frame1 = CGRectMake(0, 0, (superWidth - 4), viewHeight);
            frame2 = CGRectMake((superWidth - 4), 0, (superWidth - 4), viewHeight);
            frame3 = CGRectMake((superWidth - 4) * 2, 0, (superWidth - 4), viewHeight);
        }

        _pageView1 = [[UILabel alloc] initWithFrame:frame1];
        _pageView1.backgroundColor = [UIColor clearColor];
        _pageView1.textColor = labelTextColor;
        _pageView1.shadowColor = labelShadowColor;
        _pageView1.shadowOffset = labelShadowSize;
        _pageView1.text = @"";
        if (textAlign == 0)
            _pageView1.textAlignment = lcAlignLeft;
        else if (textAlign == 2)
            _pageView1.textAlignment = lcAlignRight;
        else
            _pageView1.textAlignment = lcAlignCenter;
        [_pageView1 setFont:[UIFont fontWithName:fontName size:fontSize]];
        [_pageView1 setNumberOfLines:1];
        _pageView1.adjustsFontSizeToFitWidth = YES;
        _pageView1.userInteractionEnabled = NO;
        [_scrollView addSubview:_pageView1];

        _pageView2 = [[UILabel alloc] initWithFrame:frame2];
        _pageView2.backgroundColor = [UIColor clearColor];
        _pageView2.textColor = labelTextColor;
        _pageView2.shadowColor = labelShadowColor;
        _pageView2.shadowOffset = labelShadowSize;
        _pageView2.text = @"";
        if (textAlign == 0)
            _pageView2.textAlignment = lcAlignLeft;
        else if (textAlign == 2)
            _pageView2.textAlignment = lcAlignRight;
        else
            _pageView2.textAlignment = lcAlignCenter;
        [_pageView2 setFont:[UIFont fontWithName:fontName size:fontSize]];
        [_pageView2 setNumberOfLines:1];
        _pageView2.adjustsFontSizeToFitWidth = YES;
        _pageView2.userInteractionEnabled = NO;
        [_scrollView addSubview:_pageView2];

        _pageView3 = [[UILabel alloc] initWithFrame:frame3];
        _pageView3.backgroundColor = [UIColor clearColor];
        _pageView3.textColor = labelTextColor;
        _pageView3.shadowColor = labelShadowColor;
        _pageView3.shadowOffset = labelShadowSize;
        _pageView3.text = @"";
        if (textAlign == 0)
            _pageView3.textAlignment = lcAlignLeft;
        else if (textAlign == 2)
            _pageView3.textAlignment = lcAlignRight;
        else
            _pageView3.textAlignment = lcAlignCenter;
        [_pageView3 setFont:[UIFont fontWithName:fontName size:fontSize]];
        [_pageView3 setNumberOfLines:1];
        _pageView3.adjustsFontSizeToFitWidth = YES;
        _pageView3.userInteractionEnabled = NO;
        [_scrollView addSubview:_pageView3];

        _scrollView.contentSize = CGSizeMake((superWidth - 4) * 3, viewHeight);
        _scrollView.showsHorizontalScrollIndicator = NO;

        [_weeView addSubview:_scrollView];

        NSLog(@"Lunar Calendar for Notification Center for iOS 5 & 6 loaded.");
    }

    return self;
}

- (void)dealloc {
    if (languageStrings)
        [languageStrings release];
    [localizedBundle release];
    if (_alert)
        [_alert release];
    [_dateInfo release];
    [_pageView1 release];
    [_pageView2 release];
    [_pageView3 release];
    [_scrollView release];
    [_backgroundImageView release];
    [_weeView release];
    [super dealloc];
}

- (UIView *)view {
    return _weeView;
}

-(CGFloat)bulletinViewWidth {
    return ((UIView *)[[[objc_getClass("SBBulletinListController") sharedInstance] listView] linenView]).frame.size.width;
}

- (void)dismissAlert {
    if (_alert) {
        [_alert dismissWithClickedButtonIndex:-1 animated:YES];
        [_alert release];
        _alert = nil;
    }
}

- (void)longPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        NSString *message = NSLocalizedStringFromTableInBundle(@"Copied to clipboard.", @"LunarCalendar", localizedBundle, @"Copied to clipboard.");

        _alert = [[UIAlertView alloc] initWithTitle:message message:nil delegate:self cancelButtonTitle:nil otherButtonTitles: nil];

        [_alert show];

        NSArray *subViewArray = _alert.subviews;

        UIView *alertView = [subViewArray objectAtIndex:0];
        alertView.frame = CGRectMake(alertView.frame.origin.x, alertView.frame.origin.y + alertView.frame.size.height / 2 - 40, alertView.frame.size.width, 80);
        UILabel *label = [subViewArray objectAtIndex:1];
        label.frame = alertView.frame;
        [label setTextAlignment:lcAlignCenter];

        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (switchGesture == 0)
            pasteboard.string = [NSString stringWithFormat:@"%@\n%@\n%@", _pageView1.text, _pageView2.text, _pageView3.text];
        else
            pasteboard.string = [NSString stringWithFormat:@"%@\n%@\n%@", [self customDatePrinter:0], [self customDatePrinter:1], [self customDatePrinter:2]];

        [self performSelector:@selector(dismissAlert) withObject:nil afterDelay:1.5];
    }
}

- (void)singleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded && switchGesture == 1)
        [self performSelector:@selector(refreshLabel) withObject:nil afterDelay:0.3];
}

- (void)doubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded && switchGesture == 2)
        [self performSelector:@selector(refreshLabel) withObject:nil afterDelay:0.3];
}

- (void)refreshLabel {
    if (pageNo <= 0)
        pageNo = 1;
    else if (pageNo > 1)
        pageNo = 0;
    else
        pageNo++;

    [_pageView1 setText:[self customDatePrinter:pageNo]];
}

- (NSString *)calculateDate:(NSString *)template {
    template = [template stringByReplacingOccurrencesOfString:@"[GY]" withString:[NSString stringWithFormat:@"%d", [[_dateInfo objectForKey:@"GregorianYear"] intValue]]];
    template = [template stringByReplacingOccurrencesOfString:@"[GM]" withString:[NSString stringWithFormat:@"%d", [[_dateInfo objectForKey:@"GregorianMonth"] intValue]]];
    template = [template stringByReplacingOccurrencesOfString:@"[GD]" withString:[NSString stringWithFormat:@"%d", [[_dateInfo objectForKey:@"GregorianDay"] intValue]]];
    template = [template stringByReplacingOccurrencesOfString:@"[LM]" withString:[_dateInfo objectForKey:@"LunarMonth"]];
    template = [template stringByReplacingOccurrencesOfString:@"[LD]" withString:[_dateInfo objectForKey:@"LunarDay"]];
    template = [template stringByReplacingOccurrencesOfString:@"[HY]" withString:[_dateInfo objectForKey:@"YearHeavenlyStem"]];
    template = [template stringByReplacingOccurrencesOfString:@"[EY]" withString:[_dateInfo objectForKey:@"YearEarthlyBranch"]];
    template = [template stringByReplacingOccurrencesOfString:@"[HM]" withString:[_dateInfo objectForKey:@"MonthHeavenlyStem"]];
    template = [template stringByReplacingOccurrencesOfString:@"[EM]" withString:[_dateInfo objectForKey:@"MonthEarthlyBranch"]];
    template = [template stringByReplacingOccurrencesOfString:@"[HD]" withString:[_dateInfo objectForKey:@"DayHeavenlyStem"]];
    template = [template stringByReplacingOccurrencesOfString:@"[ED]" withString:[_dateInfo objectForKey:@"DayEarthlyBranch"]];
    template = [template stringByReplacingOccurrencesOfString:@"[L]" withString:([[_dateInfo objectForKey:@"IsLeap"] boolValue] ? [_dateInfo objectForKey:@"LeapTitle"] : @"")];
    template = [template stringByReplacingOccurrencesOfString:@"[C]" withString:[_dateInfo objectForKey:@"Constellation"]];
    template = [template stringByReplacingOccurrencesOfString:@"[Z]" withString:[_dateInfo objectForKey:@"Zodiac"]];
    template = [template stringByReplacingOccurrencesOfString:@"[S]" withString:[_dateInfo objectForKey:@"SolarTerm"]];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    if (lanCode)
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:lanCode]];
    else
        [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateStyle:NSDateFormatterLongStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];

    template = [template stringByReplacingOccurrencesOfString:@"[WD]" withString:[[dateFormatter weekdaySymbols] objectAtIndex:([[_dateInfo objectForKey:@"Weekday"] intValue] + 6) % 7]];
    [dateFormatter release];

    return [template stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)customDatePrinter:(int)format {
    NSDate *today = [NSDate date];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

    if (lanCode)
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:lanCode]];
    else
        [dateFormatter setLocale:[NSLocale currentLocale]];

    [dateFormatter setDateStyle:NSDateFormatterFullStyle];

    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];

    NSString *date = [dateFormatter stringFromDate:today];

    [dateFormatter release];

    if (format == 0) //date + weekday + constellation
        return ([displayDate1 length] == 0) ? [NSString stringWithFormat:@"%@  %@", date, [_dateInfo objectForKey:@"Constellation"]] : [self calculateDate:displayDate1];
    else if (format == 1)
        return [self calculateDate:displayDate2];
    else
        return [self calculateDate:displayDate3];
}

- (void)viewWillAppear {
    CGFloat superWidth = [self bulletinViewWidth];

    if (superWidth != _weeView.frame.size.height) {
        _weeView.frame = CGRectMake(0, 0, superWidth, viewHeight);
        _backgroundImageView.frame = CGRectMake(2, 0, (superWidth - 4), viewHeight);
        _scrollView.frame = CGRectMake(2, 0, (superWidth - 4), viewHeight);

        if (textAlign == 0) {
            _pageView1.frame = CGRectMake(sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
            _pageView2.frame = CGRectMake((superWidth - 4) + sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
            _pageView3.frame = CGRectMake((superWidth - 4) * 2 + sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
        } else if (textAlign == 2) {
            _pageView1.frame = CGRectMake(0, 0, (superWidth - 4 - sideMargin), viewHeight);
            _pageView2.frame = CGRectMake((superWidth - 4), 0, (superWidth - 4 - sideMargin), viewHeight);
            _pageView3.frame = CGRectMake((superWidth - 4) * 2, 0, (superWidth - 4 - sideMargin), viewHeight);
        } else {
            _pageView1.frame = CGRectMake(0, 0, (superWidth - 4), viewHeight);
            _pageView2.frame = CGRectMake((superWidth - 4), 0, (superWidth - 4), viewHeight);
            _pageView3.frame = CGRectMake((superWidth - 4) * 2, 0, (superWidth - 4), viewHeight);
        }

        if (sideMarginChanged)
            sideMarginChanged = NO;

        _scrollView.contentSize = CGSizeMake((superWidth - 4) * 3, viewHeight);
    } else {
        if (sideMarginChanged) {
            if (textAlign == 0) {
                _pageView1.frame = CGRectMake(sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
                _pageView2.frame = CGRectMake((superWidth - 4) + sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
                _pageView3.frame = CGRectMake((superWidth - 4) * 2 + sideMargin, 0, (superWidth - 4 - sideMargin), viewHeight);
            } else if (textAlign == 2) {
                _pageView1.frame = CGRectMake(0, 0, (superWidth - 4 - sideMargin), viewHeight);
                _pageView2.frame = CGRectMake((superWidth - 4), 0, (superWidth - 4 - sideMargin), viewHeight);
                _pageView3.frame = CGRectMake((superWidth - 4) * 2, 0, (superWidth - 4 - sideMargin), viewHeight);
            } else {
                _pageView1.frame = CGRectMake(0, 0, (superWidth - 4), viewHeight);
                _pageView2.frame = CGRectMake((superWidth - 4), 0, (superWidth - 4), viewHeight);
                _pageView3.frame = CGRectMake((superWidth - 4) * 2, 0, (superWidth - 4), viewHeight);
            }
            sideMarginChanged = NO;
        }
    }

    if (fontChanged) {
        [_pageView1 setFont:[UIFont fontWithName:fontName size:fontSize]];
        [_pageView2 setFont:[UIFont fontWithName:fontName size:fontSize]];
        [_pageView3 setFont:[UIFont fontWithName:fontName size:fontSize]];
        fontChanged = NO;
    }

    if (textAlignChanged) {
        if (textAlign == 0) {
            _pageView1.textAlignment = lcAlignLeft;
            _pageView2.textAlignment = lcAlignLeft;
            _pageView3.textAlignment = lcAlignLeft;
        } else if (textAlign == 2) {
            _pageView1.textAlignment = lcAlignRight;
            _pageView2.textAlignment = lcAlignRight;
            _pageView3.textAlignment = lcAlignRight;
        } else {
            _pageView1.textAlignment = lcAlignCenter;
            _pageView2.textAlignment = lcAlignCenter;
            _pageView3.textAlignment = lcAlignCenter;
        }
        textAlignChanged = NO;
    }

    if (viewHeightChanged) {
        _pageView1.frame = CGRectMake(_pageView1.frame.origin.x, _pageView1.frame.origin.y, _pageView1.frame.size.width, viewHeight);
        _pageView2.frame = CGRectMake(_pageView2.frame.origin.x, _pageView2.frame.origin.y, _pageView2.frame.size.width, viewHeight);
        _pageView3.frame = CGRectMake(_pageView3.frame.origin.x, _pageView3.frame.origin.y, _pageView3.frame.size.width, viewHeight);
        viewHeightChanged = NO;
    }

    if (textColorChanged) {
        UIColor *color = [UIColor colorWithRed:colorRed green:colorGreen blue:colorBlue alpha:colorAlpha];
        _pageView1.textColor = color;
        _pageView2.textColor = color;
        _pageView3.textColor = color;
        textColorChanged = NO;
    }

    if (shadowChaned) {
        UIColor *color = [UIColor colorWithRed:shadowRed green:shadowGreen blue:shadowBlue alpha:shadowAlpha];
        CGSize size = CGSizeMake(shadowWidth, shadowHeight);
        _pageView1.shadowColor = color;
        _pageView1.shadowOffset = size;
        _pageView2.shadowColor = color;
        _pageView2.shadowOffset = size;
        _pageView3.shadowColor = color;
        _pageView3.shadowOffset = size;
        shadowChaned = NO;
    }

    BOOL willRefresh = NO;

    NSDate *today = [NSDate date];

    NSDateFormatter *currentFormatter = [[NSDateFormatter alloc] init];

    [currentFormatter setDateFormat:@"yyyyMMdd"];

    if ([[currentFormatter stringFromDate:today] intValue] != _currentDate || formatChanged1 || formatChanged2 || formatChanged3) {
        willRefresh = YES;
        _currentDate = [[currentFormatter stringFromDate:today] intValue];
        [currentFormatter release];
        formatChanged1 = NO;
        formatChanged2 = NO;
        formatChanged3 = NO;
    } else
        [currentFormatter release];

    if (willRefresh) {
        //recalculate
        LunarCalendar *lunarCal = [[LunarCalendar alloc] init];

        [lunarCal loadWithDate:today];

        [lunarCal InitializeValue];

        [_dateInfo setObject:[NSNumber numberWithInt:[lunarCal GregorianYear]] forKey:@"GregorianYear"];
        [_dateInfo setObject:[NSNumber numberWithInt:[lunarCal GregorianMonth]] forKey:@"GregorianMonth"];
        [_dateInfo setObject:[NSNumber numberWithInt:[lunarCal GregorianDay]] forKey:@"GregorianDay"];

        [_dateInfo setObject:[NSNumber numberWithInt:[lunarCal Weekday]] forKey:@"Weekday"];

        NSString *localizedTemp = @"";
        if (languageStrings && [languageStrings objectForKey:[lunarCal Constellation]])
            localizedTemp = [languageStrings objectForKey:[lunarCal Constellation]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal Constellation], @"LunarCalendar", localizedBundle, [lunarCal Constellation]) forKey:@"Constellation"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"Constellation"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal YearHeavenlyStem]])
            localizedTemp = [languageStrings objectForKey:[lunarCal YearHeavenlyStem]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal YearHeavenlyStem], @"LunarCalendar", localizedBundle, [lunarCal YearHeavenlyStem]) forKey:@"YearHeavenlyStem"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"YearHeavenlyStem"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal YearEarthlyBranch]])
            localizedTemp = [languageStrings objectForKey:[lunarCal YearEarthlyBranch]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal YearEarthlyBranch], @"LunarCalendar", localizedBundle, [lunarCal YearEarthlyBranch]) forKey:@"YearEarthlyBranch"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"YearEarthlyBranch"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal MonthHeavenlyStem]])
            localizedTemp = [languageStrings objectForKey:[lunarCal MonthHeavenlyStem]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal MonthHeavenlyStem], @"LunarCalendar", localizedBundle, [lunarCal MonthHeavenlyStem]) forKey:@"MonthHeavenlyStem"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"MonthHeavenlyStem"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal MonthEarthlyBranch]])
            localizedTemp = [languageStrings objectForKey:[lunarCal MonthEarthlyBranch]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal MonthEarthlyBranch], @"LunarCalendar", localizedBundle, [lunarCal MonthEarthlyBranch]) forKey:@"MonthEarthlyBranch"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"MonthEarthlyBranch"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal MonthHeavenlyStem]])
            localizedTemp = [languageStrings objectForKey:[lunarCal MonthHeavenlyStem]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal MonthHeavenlyStem], @"LunarCalendar", localizedBundle, [lunarCal MonthHeavenlyStem]) forKey:@"MonthHeavenlyStem"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"MonthHeavenlyStem"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal MonthEarthlyBranch]])
            localizedTemp = [languageStrings objectForKey:[lunarCal MonthEarthlyBranch]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal MonthEarthlyBranch], @"LunarCalendar", localizedBundle, [lunarCal MonthEarthlyBranch]) forKey:@"MonthEarthlyBranch"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"MonthEarthlyBranch"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal DayHeavenlyStem]])
            localizedTemp = [languageStrings objectForKey:[lunarCal DayHeavenlyStem]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal DayHeavenlyStem], @"LunarCalendar", localizedBundle, [lunarCal DayHeavenlyStem]) forKey:@"DayHeavenlyStem"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"DayHeavenlyStem"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal DayEarthlyBranch]])
            localizedTemp = [languageStrings objectForKey:[lunarCal DayEarthlyBranch]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal DayEarthlyBranch], @"LunarCalendar", localizedBundle, [lunarCal DayEarthlyBranch]) forKey:@"DayEarthlyBranch"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"DayEarthlyBranch"];
            localizedTemp = @"";
        }

        [_dateInfo setObject:[NSNumber numberWithBool:[lunarCal IsLeap]] forKey:@"IsLeap"];

        if (languageStrings && [languageStrings objectForKey:[lunarCal ZodiacLunar]])
            localizedTemp = [languageStrings objectForKey:[lunarCal ZodiacLunar]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal ZodiacLunar], @"LunarCalendar", localizedBundle, [lunarCal ZodiacLunar]) forKey:@"Zodiac"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"Zodiac"];
            localizedTemp = @"";
        }

        if ([lunarCal SolarTermTitle] && [[lunarCal SolarTermTitle] length] > 0) {
            if (languageStrings && [languageStrings objectForKey:[lunarCal SolarTermTitle]])
                localizedTemp = [languageStrings objectForKey:[lunarCal SolarTermTitle]];
            if ([localizedTemp length] == 0)
                [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal SolarTermTitle], @"LunarCalendar", localizedBundle, [lunarCal SolarTermTitle]) forKey:@"SolarTerm"];
            else {
                [_dateInfo setObject:localizedTemp forKey:@"SolarTerm"];
                localizedTemp = @"";
            }
        } else
            [_dateInfo setObject:@"" forKey:@"SolarTerm"];

        if (languageStrings && [languageStrings objectForKey:@"LeapTitle"])
            localizedTemp = [languageStrings objectForKey:@"LeapTitle"];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle(@"LeapTitle", @"LunarCalendar", localizedBundle, @"LeapTitle") forKey:@"LeapTitle"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"LeapTitle"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal MonthLunar]])
            localizedTemp = [languageStrings objectForKey:[lunarCal MonthLunar]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal MonthLunar], @"LunarCalendar", localizedBundle, [lunarCal MonthLunar]) forKey:@"LunarMonth"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"LunarMonth"];
            localizedTemp = @"";
        }

        if (languageStrings && [languageStrings objectForKey:[lunarCal DayLunar]])
            localizedTemp = [languageStrings objectForKey:[lunarCal DayLunar]];
        if ([localizedTemp length] == 0)
            [_dateInfo setObject:NSLocalizedStringFromTableInBundle([lunarCal DayLunar], @"LunarCalendar", localizedBundle, [lunarCal DayLunar]) forKey:@"LunarDay"];
        else {
            [_dateInfo setObject:localizedTemp forKey:@"LunarDay"];
            localizedTemp = @"";
        }

        [lunarCal release];
    }

    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:PreferencesFilePath];
    if (switchGesture == 0) {
        CGPoint contentOffset = _scrollView.contentOffset;

        contentOffset.x = ([preferences objectForKey:@"PageNo"] ? [[preferences objectForKey:@"PageNo"] intValue] : 0) * _scrollView.frame.size.width;

        [_scrollView setContentOffset:contentOffset animated:NO];

        [_pageView1 setText:[self customDatePrinter:0]];

        [_pageView2 setText:[self customDatePrinter:1]];

        [_pageView3 setText:[self customDatePrinter:2]];
        _scrollView.scrollEnabled = YES;
    } else {
        CGPoint contentOffset = _scrollView.contentOffset;
        contentOffset.x = 0;
        [_scrollView setContentOffset:contentOffset animated:NO];

        [_pageView1 setText:[self customDatePrinter:pageNo]];
        _scrollView.scrollEnabled = NO;
    }
    [preferences release];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIView *list = [[objc_getClass("SBBulletinListController") sharedInstance] listView];
        for (UIGestureRecognizer *gr in list.gestureRecognizers)
            gr.cancelsTouchesInView = NO;
    }
}

- (void)viewWillDisappear {
    //Dismiss the alert if visible
    [self dismissAlert];

    //Save settings
    if (switchGesture == 0)
        pageNo = (int)(_scrollView.contentOffset.x / (_weeView.superview.bounds.size.width - 12));

    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:PreferencesFilePath];
    [preferences setValue:[NSNumber numberWithInt:pageNo] forKey:@"PageNo"];
    [preferences writeToFile:PreferencesFilePath atomically:YES];
    [preferences release];
}

- (float)viewHeight {
    return viewHeight;
}

- (NSURL *)launchURLForTapLocation:(CGPoint)point {
    UITouch *touch = [[UITouch alloc] initWithPoint:[self.view convertPoint:point toView:self.view.window] andView:self.view];
    UIEvent *eventDown = [[UIEvent alloc] initWithTouch:touch];
    [touch.view touchesBegan:[eventDown allTouches] withEvent:eventDown];
    [touch setPhase:UITouchPhaseEnded];

    UIEvent *eventUp = [[UIEvent alloc] initWithTouch:touch];
    [touch.view touchesEnded:[eventUp allTouches] withEvent:eventUp];

    return nil;
}

@end

#endif
