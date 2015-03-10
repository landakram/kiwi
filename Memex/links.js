var links = document.getElementsByTagName("a");

for (var i = 0; i < links.length; i++) {
    var el = links[i];
    var internal = el.className.contains("internal");
    var page = el.href;
    var name = el.textContent
    el.onclick = (function(page, name, internal) {
        return function(e) {
            e.preventDefault();
            window.webkit.messageHandlers.navigation.postMessage({
                page: page,
                name: name,
                internal: internal
            });
        };
    })(page, name, internal);
}

var images = document.getElementsByTagName("img");

for (var i = 0; i < images.length; i++) {
    var el = images[i];
    var src = el.src;
    el.onclick = (function(src) {
        return function(e) {
            e.preventDefault();
            window.webkit.messageHandlers.showImageBrowser.postMessage({
                src: src
            });
        };
    })(src);
}
