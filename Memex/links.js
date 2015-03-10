var elements = document.getElementsByClassName("internal");

for (var i = 0; i < elements.length; i++) {
    var el = elements[i];
    var page = el.href;
    var name = el.textContent
    el.onclick = (function(page, name) {
        return function(e) {
            e.preventDefault();
            window.webkit.messageHandlers.navigation.postMessage({
                page: page,
                name: name
            });
        };
    })(page, name);
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
