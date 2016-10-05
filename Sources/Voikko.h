//
//  voikko.h
//  voikko
//
//  Created by Brendan Molloy on 18/11/2015.
//  Copyright © 2015 Brendan Molloy. All rights reserved.
//

#ifndef Voikko_h
#define Voikko_h

@import Foundation;
#import <libvoikko/libvoikko/voikko.h>

//! Project version number for voikko.
FOUNDATION_EXPORT double voikkoVersionNumber;

//! Project version string for voikko.
FOUNDATION_EXPORT const unsigned char voikkoVersionString[];

typedef BOOL (^VoikkoTokenCallback)(enum voikko_token_type token, NSString* _Nonnull word, NSRange tokenLoc);

@interface VoikkoDict : NSObject

@property (copy, readonly) NSString* _Nonnull description;
@property (copy, readonly) NSString* _Nonnull language;
@property (copy, readonly) NSString* _Nonnull script;
@property (copy, readonly) NSString* _Nonnull variant;

- (id _Nonnull)initWithHandle:(struct voikko_dict* _Nonnull)handle;

@end


@interface Voikko : NSObject

@property struct VoikkoHandle* _Nullable handle;

+ (NSString* _Nonnull)version;
+ (NSArray<VoikkoDict*>* _Nonnull)dicts:(NSURL* _Nonnull)path;
+ (NSArray<NSString*>* _Nonnull)supportedSpellingLanguages:(NSURL* _Nonnull)path;
+ (NSArray<NSString*>* _Nonnull)supportedHyphenationLanguages:(NSURL* _Nonnull)path;
+ (NSArray<NSString*>* _Nonnull)supportedGrammarCheckingLanguages:(NSURL* _Nonnull)path;
- (id _Nullable)initWithLangCode:(NSString* _Nonnull)langcode error:(NSError*_Nullable *_Nonnull)error;

- (id _Nullable)initWithLangCode:(NSString* _Nonnull)langcode path:(NSURL* _Nullable)path error:(NSError*_Nullable *_Nonnull)error;
- (BOOL) setBoolean:(int)option value:(BOOL)value;
- (BOOL) setInteger:(int)option value:(int)value;
- (int)spell:(NSString* _Nonnull)word;
- (NSArray<NSString*>* _Nonnull)suggest:(NSString* _Nonnull)word;
- (NSString* _Nonnull)hyphenate:(NSString* _Nonnull)word;
- (int)checkSpelling:(NSString * _Nonnull)word;
- (void)eachTokenInSentence:(NSString * _Nonnull)sentence withBlock:(VoikkoTokenCallback _Nonnull)callback;

@end


#endif /* Voikko_h */
