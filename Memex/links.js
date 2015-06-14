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

var rawMarkdown;

function injectRawMarkdown(markdown) {
    rawMarkdown = decodeURIComponent(markdown);
    var checklistNodes = document.getElementsByClassName('task-list-item');
    Array.prototype.forEach.call(checklistNodes, function(el, index) {
        var checkbox = el.children[0];
        checkbox.onclick = function(event) {
           var elem = event.currentTarget;
           var newValue = elem.checked ? "[x]": "[ ]";
           var nth = -1;
           var newRaw = rawMarkdown.replace(/\[([\ \_\-\x\*]?)\]/g, function(match) {
                nth += 1;
                console.log("matches?", nth == index);
                console.log("using", nth == index ? newValue : match);
                return nth == index ? newValue : match;
           });
           rawMarkdown = newRaw;
           window.webkit.messageHandlers.updateRaw.postMessage({
               content: rawMarkdown
           });
        };
    });
}

window.webkit.messageHandlers.loaded.postMessage({});
