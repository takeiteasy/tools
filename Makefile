default: all

all: alert fdialog cdialog cocr stayawake stayawakeif

fdialog:
	clang fdialog.m -framework AppKit -o fdialog

cdialog:
	clang cdialog.m -framework AppKit -o cdialog

alert:
	clang alert.m -framework AppKit -o alert

cocr:
	clang cocr.m -framework Carbon -framework Cocoa -framework Vision -o cocr

stayawake:
	clang stayawake.c -framework IOKit -framework Foundation -o stayawake

stayawakeif:
	clang stayawakeif.m -framework Cocoa -framework IOKit -framework Foundation -o stayawakeif

.PHONY: default all alert fdialog cdialog
