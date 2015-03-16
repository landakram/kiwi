var links = document.getElementsByTagName("a");

for (var i = 0; i < links.length; i++) {
    var el = links[i];
    var isInternal = el.className.indexOf("internal") > -1;
    var page = el.href;
    var name = el.textContent;
    el.onclick = (function(page, name, isInternal) {
        return function(e) {
            e.preventDefault();
            window.webkit.messageHandlers.navigation.postMessage({
                page: page,
                name: name,
                isInternal: isInternal
            });
        };
    })(page, name, isInternal);
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
