//
//  hoedown_html_patch.h
//  Memex
//
//  Created by Mark Hudnall on 6/13/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

#ifndef __Memex__hoedown_html_patch__
#define __Memex__hoedown_html_patch__

#include "document.h"
#include "html.h"

static unsigned int HOEDOWN_HTML_USE_TASK_LIST = (1 << 15);

void hoedown_patch_render_listitem(
    hoedown_buffer *ob, const hoedown_buffer *text, hoedown_list_flags flags,
    const hoedown_renderer_data *data);

#endif /* defined(__Memex__hoedown_html_patch__) */
