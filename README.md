# tools

My miscellaneous CLI tools

### fdialog.m

Display a open or save file dialog from the terminal that returns the path

```
usage: fdialog [options]

    -o/--open    Open file dialog        [required*]
    -d/--dir    Open directory dialog        [required*]
    -s/--save    Save file dialog        [required*]
    -m/--multiple    Allow selecting multiple files    [disabled by default]
    -f/--filter    Allowed file extension pattern    [comma delimeter]
    -p/--path    Initial directory for dialog to show
    -n/--filename    Default filename for dialog to use
    -h/--help    Display this message

    [*] Only one of these is required
```

### cdialog.m

Display the color-picker dialog. Select a color from the wheel or use the eye-dropper to select a color from the screen

```
usage: cdialog [options]

  -f/--format  Specify the color output format [default: RGB]
  -o/--opacity Enable opacity
  -h/--help    Display this message
formats:
  rgb = 0-255, hex = 00-FF, float = 0.0-1.0

```

### alert.m

Display an alert box from the terminal

```
usage: alert [options] -m [message]

    -i/--info    Info style alert    [required*]
    -w/--warning    Warning style alert    [required*]
    -e/--error    Error style dialog    [required*]
    -o/--ok        Add OK button
    -c/--cancel    Add Cancel button
    -y/--yes    Add Yes button
    -n/--no        Add No button
    -x/--custom    Add button with custom text
    -m/--message    Dialog message        [required]
    -h/--help    Display this message

    [*] Only one of these is required
```

### stayawake.c

This is a small tool that takes no arguments, just run it and it will block the computer sleeping until the user presses a key.

### cocr

General purpose OCR for Mac from the terminal. Tell cocr where to read on the screen and it will output what it thinks is written there. Uses the Vision framework.

```
usage: cocr [options]

  Description:
    A general purpose CLI on-screen OCR for Mac

  Arguments:
    * --disable-overlay/-o -- Disable capture overlay
    * --color/-c -- Background color for capture overlay (Hex or RGBA)
    * --disable-border/-b -- Disable border on capture overlay
    * --frame/-f -- Capture frame (x,y,w,h)
    * --keep-alive/-k -- Capture periodically, see -i
    * --interval/-i -- Capture timer interval (default: 1 second)
    * --fullscreen/-F -- Set capture frame to screen size
    * --disable-statusbar/-s -- Disable status bar icon to quit app
    * --disable-md5check/-m -- Disable MD5 duplicate check
    * --clipboard/-p -- Output OCR result to clipboard instead of STDOUT
    * --language/-l -- Set the target language, default "en-US"
    * --verbose/-v -- Enable logging
    * --help/-h -- Display this message
```

### charlotte

Web scraping tool, built with nokogiri + selenium. Selenium is used to manually bypass bot protection for websites and getting HTML post-javascript. Nokogiri is used to parse HTML attributes + CSS selectors.

```
 Usage: `echo [TEXT] | charlotte.rb` or `charlotte.rb -f [FILE]` or `charlotte.rb -u [URL]`

 Description: A little spider to crawl the web!

 Example:
    ruby charlotte.rb --url http://www.example.com --selector 'p a' --attrs 'href'
      => https://www.iana.org/domains/example

    -h, --help                       Print help
    -v, --verbose                    Enable verbose logging
    -f, --file A,B,C                 Read document(s) from path(s)
    -u, --url=URL                    Download HTML/XML from URL
    -d, --driver=DRIVER              Specify a WebDriver to use if you would like to use Selenium
                                     when using the `--url` option. Useful for websites that have
                                     automated `prove you are human` captchas. Or if you need to
                                     wait some something on the page to load.
                                     Valid drivers: chrome, edge, firefox, ie, safari
    -H, --headless                   Enable `--headless` for Selenium WebDriver
    -l, --load-strategy              Specify the page load strategy for Selenium WebDriver.
                                     Valid strats: `normal`, wait until page fully loads before
                                     returning. `eager` will wait until the DOM is loaded then
                                     return, other resources may still be loading. `none` doesn't
                                     block the WebDriver at all, `--timeout` option is required.
    -t, --timeout=SECONDS            Set the page load timeout when using `--url` (in seconds)
    -p, --proxy=ADDRESS              Set a proxy for Selenium WebDriver
    -s, --selector=SELECTOR          Filter document(s) with a CSS selector
    -x, --xpath=PATH                 Filter document(s) with an XML XPath
    -a, --attrs A,B,C                Specify any tag attributes to print
    -b, --body                       When printing a matched result, only print the tag`s body
```
