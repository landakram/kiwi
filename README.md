# Kiwi

Kiwi is a personal wiki app for iOS. A short list of features: 

* You write pages in Markdown
* You link pages together with simple `[[Bracketed Links]]`
* Pages are synced to Dropbox automatically, so you own your wiki, but it works
  offline
* You can add photos, use LaTeX, make checkboxes, and write syntax-highlighted 
  code snippets and prose

## Getting started

Are you interested in **using it**? Consider supporting me by buying the app in
the App Store.

If not, here are the instructions for getting started with development:

1. Clone this repository
2. Run `pod install`
3. Add Dropbox keys. 
  
   To do this, create 2 files in the project's root directory,
   `Keys.development.xcconfig` and `Keys.production.xcconfig`. These files will
   both have the same structure, which looks like this: 

       DROPBOX_APP_KEY = your_dropbox_app_key
       DROPBOX_SECRET_KEY = your_dropbox_secret_key

   You'll need to create a Dropbox "App" integration to get those keys.
