# Update notes

## v2.0.0

**tldr: you'll have to re-link your Dropbox account**. Don't worry — your wiki is still there.

----

In this release, I re-architected the app to support Dropbox's new version of their API.

Previously, Kiwi used [Dropbox's v1 API](https://www.dropbox.com/developers-v1/sync), but since they're [dropping support](https://blogs.dropbox.com/developers/2016/06/api-v1-deprecated/) for it at the end of June, I was forced to upgrade.

Unfortunately, as a result of this, **you'll have to re-link your Dropbox account**. Don't worry — your wiki is still there.

In addition to using the new Dropbox API, this release also:

* Fixes a bug with non-English wiki links. They were popping up the new page editor instead of navigating to the page that was already created.
* Adds better highlighting to the page editor
* Fixes an issue where the navigation bar would sometimes completely disappear
* Fixes an issue where swiping back and forth between pages would cause the page to scroll slightly

But most of the changes in this update are invisible. When I first made Kiwi, I did most of the development over a very short period of time, hacking things together to *make it work*. Though this helped me actually build the thing, it also meant that the code was messy and hard to extend.

Future changes will now be easier to make. I hope to provide more features and bug fixes faster.

On the other hand, it's possible I introduced some bugs. Because I can no longer use Dropbox's Sync SDK, I had to reimplement a lot of the functionality myself.

If you run into any issues, please reach out to me at me@markhudnall.com or [file an issue on the GitHub repository](https://github.com/landakram/kiwi).
