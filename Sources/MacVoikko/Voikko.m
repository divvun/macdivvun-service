//
//  Voikko.m
//  VoikkoTest
//
//  Created by Brendan Molloy on 17/11/2015.
//  Copyright © 2015 Brendan Molloy. All rights reserved.
//

#import "Voikko.h"

@implementation VoikkoDict

@synthesize description;

- (id)initWithHandle:(struct voikko_dict*)handle {
    self = [super init];
    
    if (self) {
        _language = [NSString stringWithUTF8String:voikko_dict_language(handle)];
        _script = [NSString stringWithUTF8String:voikko_dict_script(handle)];
        _variant = [NSString stringWithUTF8String:voikko_dict_variant(handle)];
        description = [NSString stringWithUTF8String:voikko_dict_description(handle)];
    }
    
    return self;
}

@end


@implementation Voikko

+ (NSArray<VoikkoDict*>*)dicts:(NSURL* _Nonnull)path {
    struct voikko_dict** dicts = voikko_list_dicts([[path absoluteString] fileSystemRepresentation]);
    
    if (dicts == NULL) {
        return nil;
    }
    
    NSMutableArray* o = [NSMutableArray init];
    
    struct voikko_dict* dict;
    while ((dict = *dicts++) != NULL) {
        [o addObject:[[VoikkoDict alloc] initWithHandle:dict]];
    }
    
    voikko_free_dicts(dicts);
    
    return [o copy];
}

+ (NSArray<NSString*>*)supportedSpellingLanguages:(NSURL* _Nonnull)path {
    char** langs = voikkoListSupportedSpellingLanguages([[path absoluteString] fileSystemRepresentation]);
    
    NSMutableArray* o = [NSMutableArray arrayWithCapacity:1];
    
    char* lang;
    char **cur = langs;
    while ((lang = *cur++) != NULL) {
        [o addObject:[NSString stringWithUTF8String:lang]];
    }
    
    voikkoFreeCstrArray(langs);
    
    return o;
}

+ (NSArray<NSString*>*)supportedHyphenationLanguages:(NSURL* _Nonnull)path {
    char** langs = voikkoListSupportedHyphenationLanguages([[path absoluteString] fileSystemRepresentation]);
    
    NSMutableArray* o = [NSMutableArray arrayWithCapacity:1];
    
    char* lang;
    char **cur = langs;
    while ((lang = *cur++) != NULL) {
        [o addObject:[NSString stringWithUTF8String:lang]];
    }
    
    voikkoFreeCstrArray(langs);
    
    return o;
}

+ (NSArray<NSString*>*)supportedGrammarCheckingLanguages:(NSURL* _Nonnull)path {
    char** langs = voikkoListSupportedGrammarCheckingLanguages([[path absoluteString] fileSystemRepresentation]);
    
    NSMutableArray* o = [NSMutableArray arrayWithCapacity:1];
    
    char* lang;
    char **cur = langs;
    while ((lang = *cur++) != NULL) {
        [o addObject:[NSString stringWithUTF8String:lang]];
    }
    
    voikkoFreeCstrArray(langs);
    
    return o;
}

+ (NSString*)version {
    return [NSString stringWithUTF8String:voikkoGetVersion()];
}

- (id)initWithLangCode:(NSString*)langcode error:(NSError** _Nonnull)error {
    return [self initWithLangCode:langcode path:nil error:error];
}

- (id)initWithLangCode:(NSString*)langcode path:(NSURL* _Nullable)path error:(NSError** _Nonnull)error {
    self = [super init];
    
    if (self) {
        const char* cError;
        const char* cLangCode = [langcode UTF8String];
        const char* cPath = path == nil ? NULL : [path fileSystemRepresentation];
        
        self.handle = voikkoInit(&cError, cLangCode, cPath);
        
        if (cError) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: NSLocalizedString([NSString stringWithUTF8String:cError], nil),
            };
            
            *error = [NSError
                      errorWithDomain:@"Voikko"
                      code:0
                      userInfo:userInfo];
            
            voikkoFreeCstr((char*) cError);
            
            return nil;
        }
    }
    
    return self;
}

- (void)dealloc {
    voikkoTerminate(self.handle);
}

- (BOOL)setBoolean:(int)option value:(BOOL)value {
    return voikkoSetBooleanOption(self.handle, option, value);
}

- (BOOL)setInteger:(int)option value:(int)value {
    return voikkoSetIntegerOption(self.handle, option, value);
}

- (int)spell:(NSString*)word {
    return voikkoSpellCstr(self.handle, [word UTF8String]);
}

- (NSArray<NSString*>*)suggest:(NSString*)word {
    char** suggs = voikkoSuggestCstr(self.handle, [word UTF8String]);
    
    if (suggs == NULL) {
        return nil;
    }
    
    NSMutableArray* o = [NSMutableArray arrayWithCapacity:10];
    
    char* sugg;
    char** cur = suggs;
    while ((sugg = *cur++) != NULL) {
        [o addObject:[NSString stringWithUTF8String:sugg]];
    }
    
    voikkoFreeCstrArray(suggs);
    
    return o;
}

- (NSString*)hyphenate:(NSString *)word {
    char* res = voikkoHyphenateCstr(self.handle, [word UTF8String]);
    
    NSString* o = [NSString stringWithUTF8String:res];
    
    voikkoFreeCstr(res);
    
    return o;
}

- (int)checkSpelling:(NSString *)word {
    return voikkoSpellUcs4(self.handle, (const wchar_t *)[word cStringUsingEncoding:NSUTF32StringEncoding]);
}

- (void)eachTokenInSentence:(NSString *)sentence withBlock:(VoikkoTokenCallback)callback {
    const size_t length = [sentence lengthOfBytesUsingEncoding:NSUTF32StringEncoding] / 4;
    const wchar_t* text = (const wchar_t *)[sentence cStringUsingEncoding:NSUTF32StringEncoding];
    
    enum voikko_token_type token;
    size_t offset = 0;
    
    do {
        size_t tokenLen = 0;
        token = voikkoNextTokenUcs4(self.handle, text + offset, length - offset, &tokenLen);
        NSRange tokenRange = NSMakeRange(offset, tokenLen);
        NSString* word = [sentence substringWithRange:tokenRange];
        
        if (!callback(token, word, tokenRange)) {
            break;
        }
        
        offset += tokenLen;
    } while (token != TOKEN_NONE);
}

@end
