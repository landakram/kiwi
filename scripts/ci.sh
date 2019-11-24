KEYS_FILE=Keys.production.xcconfig

# The release build (which is used for unit tests) expects this file to exist.
# Stub it out with some fake values.
if [ ! -f $KEYS_FILE ]; then
    cat > $KEYS_FILE <<- "EOF"
DROPBOX_APP_KEY = ci-dropbox-app-key
DROPBOX_SECRET_KEY = ci-dropbox-secret-key
EOF
fi

xcodebuild test -workspace Kiwi.xcworkspace -scheme Kiwi -sdk iphonesimulator -destination "name=iPhone 11" | bundle exec xcpretty
