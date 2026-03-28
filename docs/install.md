# Install

## Download

Download the latest build from the [latest release](https://github.com/martinghunt/seqhiker/releases/latest).

Choose the build that matches your operating system and architecture.

## macOS

macOS Gatekeeper will probably block it from running. If this happens, you have two options:

- Go to "Privacy & Security" in the Settings app. Scroll to the bottom and `seqhiker` should be there for you to allow it
- In a terminal, run this command: `xattr -d com.apple.quarantine -r seqhiker.app`

Then `seqhiker` should just work. We apologise for the inconvenience, but this process is standard for apps that have not been ["notarized" by Apple](https://www.youtube.com/watch?v=X6HZlpPGFf0) (which means paying an annual fee).



## Windows

Double-click on the downloaded file and it should just work.
You may find Windows Defender popping up, in which case you will need to
tell it to allow `seqhiker` to run.

## Linux

You may need to make the downloaded binary file executable
(ie run `chmod +x`). Then opening it in your file browser (or in
a terminal if you want to see logging) should just work.

