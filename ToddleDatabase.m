//
//  ToddleDatabase.m
//  Milpon
//
//  Created by mootoh on 8/29/08.
//  Copyright 2008 deadbeaf.org. All rights reserved.
//

#import <sqlite3.h>
#import "ToddleDatabase.h"

#ifdef DEBUG
   #define TODDLE_DB_LOG(...) NSLog(__VA_ARGS__)
#else // DEBUG
   #define TODDLE_DB_LOG(...) ;
#endif // DEBUG

@interface ToddleDatabase (Private)
- (NSArray *) splitSQLs:(NSString *)migrations;
- (void) run_migration_sql:(NSString *)sql;
- (NSArray *) migrations;
- (void) migrate;
- (int) current_migrate_version;
@end

@implementation ToddleDatabase

-(id) initWithPath:(NSString *)path
{
   if (self = [super init]) {
      path_ = [path retain];
      if (SQLITE_OK != sqlite3_open([path_ UTF8String], &handle_))
         [[NSException
            exceptionWithName:@"ToddleDatabaseException"
            reason:[NSString stringWithFormat:@"Failed to open sqlite file: path=%@, msg='%s LINE=%d'", path_, sqlite3_errmsg(handle_), __LINE__]
            userInfo:nil] raise];

      [self migrate];
   }
   return self;
}

- (void) dealloc
{
   [path_ release];
   sqlite3_close(handle_);
   [super dealloc];
}

- (NSArray *) select:(NSDictionary *)dict from:(NSString *)table
{
   return [self select:dict from:table option:nil];
}

- (NSArray *) select:(NSDictionary *)dict from:(NSString *)table option:(NSDictionary *)option
{
   sqlite3_stmt *stmt = nil;
   NSMutableArray *results = [NSMutableArray array];
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

   // construct the query.
   NSString *keys = @"";
   for (NSString *key in dict)
      keys = [keys stringByAppendingFormat:@"%@,", key];

   keys = [keys substringToIndex:keys.length-1]; // cut last ', '

   NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@", keys, table];

   NSDictionary *join = [option objectForKey:@"JOIN"];
   if (join)
      sql = [sql stringByAppendingFormat:@" JOIN %@ ON %@ ",
         [join objectForKey:@"table"], [join objectForKey:@"condition"]];

   NSString *where = [option objectForKey:@"WHERE"];
   if (where)
      sql = [sql stringByAppendingFormat:@" WHERE %@", where];

   NSString *group = [option objectForKey:@"GROUP"];
   if (group)
      sql = [sql stringByAppendingFormat:@" GROUP BY %@", group];

   NSString *order = [option objectForKey:@"ORDER"];
   if (order)
      sql = [sql stringByAppendingFormat:@" ORDER BY %@", order];

   TODDLE_DB_LOG(@"SQL SELECT: %@", sql);

   if (sqlite3_prepare_v2(handle_, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK)
      [[NSException
        exceptionWithName:@"ToddleDatabaseException"
        reason:[NSString stringWithFormat:@"Failed to prepare statement: msg='%s, LINE=%d'", sqlite3_errmsg(handle_), __LINE__]
        userInfo:nil] raise];

   while (sqlite3_step(stmt) == SQLITE_ROW) {
      NSMutableDictionary *result = [NSMutableDictionary dictionary];
      int i = 0;

      for (NSString *key in dict) {
         Class klass = [dict objectForKey:key];
         if (klass == [NSNumber class]) {
            NSNumber *num = [NSNumber numberWithInt:sqlite3_column_int(stmt, i)];
            [result setObject:num forKey:key];
         } else if (klass == [NSString class]) {
            char *chs = (char *)sqlite3_column_text(stmt, i);
            NSString *str = chs ? [NSString stringWithUTF8String:chs] : @"";
            [result setObject:str forKey:key];
         } else if (klass == [NSDate class]) {
            char *chs = (char *)sqlite3_column_text(stmt, i);
            NSDate *date = (chs && chs[0] != '\0') ? [theFormatter dateFromString:[NSString stringWithUTF8String:chs]] : [invalidDate retain];
            [result setObject:date forKey:key];
         } else {
            [[NSException
              exceptionWithName:@"ToddleDatabaseException"
              reason:[NSString stringWithFormat:@"should not reach here, LINE=%d", __LINE__]
              userInfo:nil] raise];
         }
         i++;
      }
      [results addObject:result];
   }

   [pool release];
   return results;
}

- (void) insert:(NSDictionary *)dict into:(NSString *)table
{
   sqlite3_stmt *stmt = nil;
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

   NSString *keys = @"";
   NSString *vals = @"";

   for (NSString *key in dict) {
      keys = [keys stringByAppendingFormat:@"%@, ", key];
      id v = [dict objectForKey:key];
      NSString *val = nil;
      if ([v isKindOfClass:[NSString class]]) {
         val = [NSString stringWithFormat:@"'%@'", [(NSString *)v stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
      } else if ([v isKindOfClass:[NSNumber class]]) {
         val = [(NSNumber *)v stringValue];
      } else if ([v isKindOfClass:[NSDate class]]) {
         val = ([invalidDate isEqualToDate:v]) ?
            @"NULL" :
            [NSString stringWithFormat:@"'%@'", [theFormatter stringFromDate:v]];
      } else if ([v isKindOfClass:[NSArray class]]) {
         // fall through
      } else {
         [[NSException
           exceptionWithName:@"ToddleDatabaseException"
           reason:[NSString stringWithFormat:@"unknown typ %s for key %@, LINE=%d", object_getClassName(v), key, __LINE__]
           userInfo:nil] raise];
      }
      vals = [vals stringByAppendingFormat:@"%@, ", val];
   }

   // cut last ', '
   keys = [keys substringToIndex:keys.length-2];
   vals = [vals substringToIndex:vals.length-2];

   NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@);", table, keys, vals];
   TODDLE_DB_LOG(@"SQL INSERT: %@", sql);
   

   if (sqlite3_prepare_v2(handle_, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
      [[NSException
        exceptionWithName:@"ToddleDatabaseException"
        reason:[NSString stringWithFormat:@"Failed to prepare statement: msg='%s, LINE=%d'", sqlite3_errmsg(handle_), __LINE__]
        userInfo:nil] raise];
   }

   int i = 1;
   for (NSString *key in dict) {
      id v = [dict objectForKey:key];
      if ([v isKindOfClass:[NSString class]]) {
         sqlite3_bind_text(stmt, i, [(NSString *)v UTF8String], -1, SQLITE_TRANSIENT);
      } else if ([v isKindOfClass:[NSNumber class]]) {
         sqlite3_bind_int(stmt,  i, [(NSNumber *)v intValue]);
      } else if ([v isKindOfClass:[NSDate class]]) {
         v = [theFormatter stringFromDate:v];
         sqlite3_bind_text(stmt, i, [(NSString *)v UTF8String], -1, SQLITE_TRANSIENT);
      } else if ([v isKindOfClass:[NSArray class]]) {
         // fall through
      } else {
         [[NSException
           exceptionWithName:@"ToddleDatabaseException"
           reason:[NSString stringWithFormat:@"should not reach here, LINE=%d", __LINE__]
           userInfo:nil] raise];
      }
      i++;
   }

   if (SQLITE_ERROR == sqlite3_step(stmt)) {
      [[NSException
         exceptionWithName:@"ToddleDatabaseException"
         reason:[NSString stringWithFormat:@"Failed to INSERT INTO ToddleDatabase: msg='%s', LINE=%d", sqlite3_errmsg(handle_), __LINE__]
         userInfo:nil] raise];
   }
   sqlite3_finalize(stmt);
   [pool release];
}

- (void) update:(NSDictionary *)dict table:(NSString *)table condition:(NSString *)cond
{
   sqlite3_stmt *stmt = nil;
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

   NSString *sets = @"";

   for (NSString *key in dict) {
      id v = [dict objectForKey:key];
      NSString *val = nil;
      if ([v isKindOfClass:[NSString class]]) {
         val = [NSString stringWithFormat:@"'%@'", (NSString *)v];
      } else if ([v isKindOfClass:[NSNumber class]]) {
         val = [(NSNumber *)v stringValue];
      } else if ([v isKindOfClass:[NSDate class]]) {
         val = ([invalidDate isEqualToDate:v]) ?
            @"NULL" :
            [NSString stringWithFormat:@"'%@'", [theFormatter stringFromDate:v]];
      } else if (v == nil) {
         val = @"NULL";
      } else {
         [[NSException
           exceptionWithName:@"ToddleDatabaseException"
           reason:[NSString stringWithFormat:@"should not reach here: key=%@, LINE=%d", key, __LINE__]
           userInfo:nil] raise];
      }
      sets = [sets stringByAppendingFormat:@"%@=%@, ", key, val];
   }

   // cut last ', '
   sets = [sets substringToIndex:sets.length-2];

   NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@", table, sets];
   sql = [sql stringByAppendingFormat:@" %@;", cond ? cond : @""];

   TODDLE_DB_LOG(@"update sql = %@", sql);

   if (sqlite3_prepare_v2(handle_, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
      [[NSException
        exceptionWithName:@"ToddleDatabaseException"
        reason:[NSString stringWithFormat:@"Failed to prepare statement: msg='%s', LINE=%d", sqlite3_errmsg(handle_), __LINE__]
        userInfo:nil] raise];
   }

   int i = 1;
   for (NSString *key in dict) {
      id v = [dict objectForKey:key];
      if ([v isKindOfClass:[NSString class]]) {
         sqlite3_bind_text(stmt, i, [(NSString *)v UTF8String], -1, SQLITE_TRANSIENT);
      } else if ([v isKindOfClass:[NSNumber class]]) {
         sqlite3_bind_int(stmt,  i, [(NSNumber *)v intValue]);
      } else if ([v isKindOfClass:[NSDate class]]) {
         NSString *date_str = [theFormatter stringFromDate:(NSDate *)v];
         sqlite3_bind_text(stmt, i, [date_str UTF8String], -1, SQLITE_TRANSIENT);
      } else {
         [[NSException
           exceptionWithName:@"ToddleDatabaseException"
           reason:[NSString stringWithFormat:@"should not reach here 2, LINE=%d", __LINE__]
           userInfo:nil] raise];
      }
      i++;
   }

   if (SQLITE_ERROR == sqlite3_step(stmt)) {
      [[NSException
         exceptionWithName:@"ToddleDatabaseException"
         reason:[NSString stringWithFormat:@"Failed to UPDATE ToddleDatabase: msg='%s, LINE=%d'", sqlite3_errmsg(handle_), __LINE__]
         userInfo:nil] raise];
   }
   sqlite3_finalize(stmt);
   [pool release];
}

- (void) delete:(NSString *)table condition:(NSString *)cond
{
   sqlite3_stmt *stmt = nil;
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

   NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@;", table, cond ? cond : @""];
   TODDLE_DB_LOG(@"delete sql = %@", sql);

   if (sqlite3_prepare_v2(handle_, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
      [[NSException
        exceptionWithName:@"ToddleDatabaseException"
        reason:[NSString stringWithFormat:@"Failed to prepare statement: msg='%s', LINE=%d", sqlite3_errmsg(handle_), __LINE__]
        userInfo:nil] raise];
   }

   if (SQLITE_ERROR == sqlite3_step(stmt)) {
      [[NSException
         exceptionWithName:@"ToddleDatabaseException"
         reason:[NSString stringWithFormat:@"Failed to DELETE FROM ToddleDatabase: msg='%s', LINE=%d", sqlite3_errmsg(handle_), __LINE__]
         userInfo:nil] raise];
   }
   sqlite3_finalize(stmt);
   [pool release];
}

@end // ToddleDatabase

@implementation ToddleDatabase (Private)

- (void) migrate
{
   for (NSString *mig_path in [self migrations]) {
      NSError *error;
      NSString *mig = [NSString stringWithContentsOfFile:mig_path encoding:NSUTF8StringEncoding error:&error];
      if (! mig) {
         [[NSException
            exceptionWithName:@"ToddleDatabaseException"
            reason:[NSString stringWithFormat:@"failed to read migration file: %@, error=%@", mig_path, [error localizedDescription]]
            userInfo:nil] raise];
      }
      for (NSString *sql in [self splitSQLs:mig]) {
         NSString *version = [[mig_path componentsSeparatedByString:@"_"] objectAtIndex:1];
         int mig_version = [version integerValue];
         if (mig_version <= [self current_migrate_version])
            continue;
         
         [self run_migration_sql:sql];
      }

      if (! [[NSFileManager defaultManager] removeItemAtPath:mig_path error:&error]) {
         [[NSException
            exceptionWithName:@"ToddleDatabaseException"
            reason:[NSString stringWithFormat:@"Failed to remove used migration: %@, error=%@", mig_path, [error localizedDescription]]
            userInfo:nil] raise];
      }
   }
}

- (NSArray *) migrations
{
   NSMutableArray *ret = [NSMutableArray array];

   NSString *target_dir = [[NSBundle mainBundle] resourcePath];
   NSDirectoryEnumerator *dir = [[NSFileManager defaultManager] enumeratorAtPath:target_dir];
   for (NSString *mig_path in dir)
      if ([mig_path hasPrefix:@"migrate_"] && [mig_path hasSuffix:@"sql"])
         [ret addObject:[target_dir stringByAppendingPathComponent:mig_path]];

   return ret;
}

- (void) run_migration_sql:(NSString *)sql_str
{
   TODDLE_DB_LOG(@"run_migration_sql: %@", sql_str);

   sqlite3_stmt *stmt = nil;
   const char *sql = [sql_str UTF8String];
   if (sqlite3_prepare_v2(handle_, sql, -1, &stmt, NULL) != SQLITE_OK) {
      [[NSException
         exceptionWithName:@"ToddleDatabaseException"
         reason:[NSString stringWithFormat:@"Error: failed to prepare statement with message '%s'.", sqlite3_errmsg(handle_)]
         userInfo:nil] raise];
   }
   if (sqlite3_step(stmt) == SQLITE_ERROR) {
      [[NSException
         exceptionWithName:@"ToddleDatabaseException"
         reason:[NSString stringWithFormat:@"Error: failed to exec sql with message '%s'.", sqlite3_errmsg(handle_)]
         userInfo:nil] raise];
   }
   sqlite3_finalize(stmt);
}

- (NSArray *) splitSQLs:(NSString *)migrations
{
   return [migrations componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";"]];
}

- (int) current_migrate_version
{
   sqlite3_stmt *stmt = nil;
   const char *sql = "select version from migrate_version";
   if (sqlite3_prepare_v2(handle_, sql, -1, &stmt, NULL) != SQLITE_OK) {
      [[NSException
         exceptionWithName:@"ToddleDatabaseException"
         reason:[NSString stringWithFormat:@"Error: failed to prepare statement with message '%s'.", sqlite3_errmsg(handle_)]
         userInfo:nil] raise];
   }
   if (sqlite3_step(stmt) == SQLITE_ERROR) {
      [[NSException
         exceptionWithName:@"ToddleDatabaseException"
         reason:[NSString stringWithFormat:@"Error: failed to exec sql with message '%s'.", sqlite3_errmsg(handle_)]
         userInfo:nil] raise];
   }

   int ret = sqlite3_column_int(stmt, 0);
   sqlite3_finalize(stmt);
   return ret;
}

@end // ToddleDatabase