//
//  Hoedown.m
//  Memex
//
//  Created by Mark Hudnall on 3/3/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

#import "Hoedown.h"
#include "document.h"
#include "html.h"

@implementation Hoedown

+ (NSString *)convertMarkdownString:(NSString *)markdownString {
    if (markdownString.length == 0) return markdownString;
    
    NSData *data = [markdownString dataUsingEncoding:NSUTF8StringEncoding];
    
    hoedown_buffer *buffer = hoedown_buffer_new(data.length);
    hoedown_renderer *renderer = hoedown_html_renderer_new(0, 16);
    hoedown_document *document = hoedown_document_new(renderer, HOEDOWN_EXT_BLOCK | HOEDOWN_EXT_SPAN, 16);
    
    hoedown_document_render(document, buffer, data.bytes, data.length);
    NSString *html = [[NSString alloc] initWithBytes:buffer->data length:buffer->size encoding:NSUTF8StringEncoding];
    
    hoedown_buffer_free(buffer);
    hoedown_document_free(document);
    hoedown_html_renderer_free(renderer);
    
    return html;
}

@end
