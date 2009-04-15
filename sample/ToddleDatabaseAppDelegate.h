//
//  ToddleDatabaseAppDelegate.h
//  ToddleDatabase
//
//  Created by mootoh on 4/15/09.
//  Copyright deadbeaf.org 2009. All rights reserved.
//

@interface ToddleDatabaseAppDelegate : NSObject <UIApplicationDelegate>
{
   IBOutlet UIWindow *window;
   IBOutlet UITableViewController *tvc;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UITableViewController *tvc;

@end

