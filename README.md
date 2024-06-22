# dialog-tools

A collection of dialog-related tools designed to be used by shell scripts (Mac only).

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

## LICENSE
```
 The MIT License (MIT)
 
 Copyright (c) 2024 George Watson
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge,
 publish, distribute, sublicense, and/or sell copies of the Software,
 and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
