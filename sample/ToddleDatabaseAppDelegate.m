//
//  ToddleDatabaseAppDelegate.m
//  ToddleDatabase
//
//  Created by mootoh on 4/15/09.
//  Copyright deadbeaf.org 2009. All rights reserved.
//

#import "ToddleDatabaseAppDelegate.h"
#import "SampleAppTavleViewController.h"

@implementation ToddleDatabaseAppDelegate

@synthesize window, tvc;

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
   tvc = [[SampleAppTavleViewController alloc] initWithStyle:UITableViewStylePlain];
   [window addSubview:tvc.view];
   // Override point for customization after application launch
   [window makeKeyAndVisible];
}


- (void)dealloc
{
   [tvc release];
   [window release];
   [super dealloc];
}


@end
