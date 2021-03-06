//
//  SampleAppTavleViewController.m
//  ToddleDatabase
//
//  Created by mootoh on 4/15/09.
//  Copyright 2009 deadbeaf.org. All rights reserved.
//

#import "SampleAppTavleViewController.h"
#import "ToddleDatabase.h"

@implementation SampleAppTavleViewController

- (NSArray *) lists
{
   NSArray *keys  = [NSArray arrayWithObjects:@"id", @"name", nil];                     // fields of table
   NSArray *types = [NSArray arrayWithObjects:[NSNumber class], [NSString class], nil]; // types of each fields
   NSDictionary *query = [NSDictionary dictionaryWithObjects:types forKeys:keys];       // run SQL SELECT
   return [toddleDB select:query from:@"list"];
}

- (id)initWithStyle:(UITableViewStyle)style {
   // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
   if (self = [super initWithStyle:style]) {
      toddleDB = [[ToddleDatabase alloc] initWithPath:[SampleAppTavleViewController databasePath]];
   }
   return self;
}

/*
 - (void)viewDidLoad {
 [super viewDidLoad];
 
 // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
 // self.navigationItem.rightBarButtonItem = self.editButtonItem;
 }
 */

/*
 - (void)viewWillAppear:(BOOL)animated {
 [super viewWillAppear:animated];
 }
 */
/*
 - (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];
 }
 */
/*
 - (void)viewWillDisappear:(BOOL)animated {
 [super viewWillDisappear:animated];
 }
 */
/*
 - (void)viewDidDisappear:(BOOL)animated {
 [super viewDidDisappear:animated];
 }
 */

/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
   [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
   return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
   return [self lists].count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   
   static NSString *CellIdentifier = @"Cell";
   
   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
   if (cell == nil) {
      cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
   }
   
   NSArray *lists = [self lists];
   
   cell.text = [[lists objectAtIndex:indexPath.row] objectForKey:@"name"];
	
   return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
   // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
}


/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */


/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
 }   
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }   
 }
 */


/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */


- (void)dealloc {
   [super dealloc];
}

+ (NSString *) databasePath
{
   NSFileManager *fm = [NSFileManager defaultManager];
   
   NSString *doc_dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
   NSString *db_path = [doc_dir stringByAppendingPathComponent:@"toddle.sql"];
   
   NSError *error;
   if ([fm fileExistsAtPath:db_path])
      return db_path;
   
   // The writable database does not exist, so copy the default to the appropriate location.
   // from path
   NSString *from_path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"toddle.sql"];
   
   if (! [fm copyItemAtPath:from_path toPath:db_path error:&error])
      [[NSException
        exceptionWithName:@"file exception"
        reason:[NSString stringWithFormat:@"Failed to create writable database file with message '%@', from=%@, to=%@.", [error localizedDescription], from_path, db_path]
        userInfo:nil] raise];
   
   return db_path;
}


@end