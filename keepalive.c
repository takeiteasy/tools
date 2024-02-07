/* keepalive (https://github.com/takeiteasy/tools) (Mac only)
 Description: Prevent sleep on Mac until exit
 Build: clang keepalive.c -framework IOKit -framework Foundation -o keepalive
 
 Version 2, December 2004

 Copyright (C) 2022 George Watson [gigolo@hotmail.co.uk]

 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

 DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE TERMS AND CONDITIONS FOR
 COPYING, DISTRIBUTION AND MODIFICATION

 0. You just DO WHAT THE FUCK YOU WANT TO. */

#include <stdio.h>
#include <termios.h>
#include <IOKit/pwr_mgt/IOPMLib.h>

int main(int argc, const char* argv[]) {
	CFStringRef reasonForActivity = CFSTR("DON'T SLEEP!");
	IOPMAssertionID assertionID;

	if (IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, reasonForActivity, &assertionID) != kIOReturnSuccess) {
		fprintf(stderr, "ERROR! Failed to prevent sleep");
        return 1;
	}

	printf("Sleep prevented! Press any key to stop...\n");

	struct termios info;
	tcgetattr(0, &info);
	info.c_lflag &= ~ICANON;
	info.c_cc[VMIN] = 1;
	info.c_cc[VTIME] = 0;
	tcsetattr(0, TCSANOW, &info);

	getchar();

	IOPMAssertionRelease(assertionID);
	return 0;
}
