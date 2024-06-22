default: all

all: alert fdialog cdialog

fdialog:
	clang fdialog.m -framework AppKit -o fdialog

cdialog:
	clang cdialog.m -framework AppKit -o cdialog

alert:
	clang alert.m -framework AppKit -o alert

.PHONY: default all alert fdialog cdialog
