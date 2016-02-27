//
//  KSPSectionedFetchedResultsControllerTests.m
//  KSPFetchedResultsController Tests
//
//  Created by Konstantin Pavlikhin on 26.11.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import "KSPSectionedFetchedResultsController.h"

#import "KSPSectionedFetchedResultsControllerDelegate.h"

#import "KSPTableSection.h"

@interface KSPSectionedFetchedResultsControllerTests : XCTestCase

@end

@implementation KSPSectionedFetchedResultsControllerTests

+ (NSManagedObjectContext *)managedObjectContextForTests
{
  static NSManagedObjectModel *model = nil;
  if (!model) {
    NSURL* URL = [[NSBundle bundleForClass: self] URLForResource: @"TestModel" withExtension: @"mom"];

    model = [[NSManagedObjectModel alloc] initWithContentsOfURL: URL];
  }

  NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
  NSPersistentStore *store = [psc addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:nil];
  NSAssert(store, @"Should have a store by now");

  NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
  moc.persistentStoreCoordinator = psc;

  moc.undoManager = nil;

  return moc;
}

/// Returns a new Employee instance unassociated with any managed object context.
+ (NSManagedObject*) employeeWithName: (NSString*) name salary: (NSNumber*) salary platform: (NSString*) platform
{
  NSManagedObjectContext* MOC = [self managedObjectContextForTests];

  NSEntityDescription* entityDescription = [NSEntityDescription entityForName: @"Employee" inManagedObjectContext: MOC];

  NSManagedObject* employee = [[NSManagedObject alloc] initWithEntity: entityDescription insertIntoManagedObjectContext: nil];

  [employee setValue: name forKey: @"name"];

  [employee setValue: salary forKey: @"salary"];

  [employee setValue: platform forKey: @"platform"];

  return employee;
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testEverything
{
  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName: @"Employee"];

  fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"platform" ascending: YES selector: @selector(caseInsensitiveCompare:)],

                                   [NSSortDescriptor sortDescriptorWithKey: @"salary" ascending: NO],

                                   [NSSortDescriptor sortDescriptorWithKey: @"name" ascending: YES]];

  // * * *.

  NSManagedObjectContext* context = [[self class] managedObjectContextForTests];

  KSPSectionedFetchedResultsController* SFRC = [[KSPSectionedFetchedResultsController alloc] initWithFetchRequest: fetchRequest managedObjectContext: context sectionNameKeyPath: @"platform"];

  // * * *.

  id<KSPSectionedFetchedResultsControllerDelegate> delegate = mockProtocol(@protocol(KSPSectionedFetchedResultsControllerDelegate));

  SFRC.delegate = delegate;

  NSError* error;

  if(![SFRC performFetch: &error]) NSLog(@"%@", error);

  // * * *.

  NSManagedObject* konstantin = [[self class] employeeWithName: @"Konstantin" salary: @100 platform: @"OS X"];

  NSManagedObject* yan = [[self class] employeeWithName: @"Yan" salary: @100 platform: @"iOS"];

  NSManagedObject* alexey = [[self class] employeeWithName: @"Alexey" salary: @110 platform: @"iOS"];

  NSManagedObject* leonid = [[self class] employeeWithName: @"Leonid" salary: @100 platform: @"Android"];

  NSManagedObject* oleg = [[self class] employeeWithName: @"Oleg" salary: @110 platform: @"Java"];

  NSManagedObject* stas = [[self class] employeeWithName: @"Stas" salary: @100 platform: @"Java"];

  NSManagedObject* igor = [[self class] employeeWithName: @"Igor" salary: @100 platform: @"None"];

  // * * *.

  XCTAssert(SFRC.fetchedObjects.count == 0, @"fetchedObjects count should be 0.");

  // * * *.

  // Insert Konstantin into an empty context.

  [context insertObject: konstantin];

  [context processPendingChanges];

  [verify(delegate) controller: SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: 0];

  [verify(delegate) controller: SFRC willChangeObject: konstantin atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  [verify(delegate) controller: SFRC didChangeObject: konstantin atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  // * * *

  // Insert Yan into a context with a Konstantin.

  [context insertObject: yan];

  [context processPendingChanges];

  [verifyCount(delegate, atLeastOnce()) controller: SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: 0];

  [verify(delegate) controller: SFRC willChangeObject: yan atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  [verify(delegate) controller: SFRC didChangeObject: yan atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  // Insert Alexey into a context with Konstantin and Yan.

  [context insertObject: alexey];

  [context processPendingChanges];

  [verify(delegate) controller: SFRC willChangeObject: alexey atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  [verify(delegate) controller: SFRC didChangeObject: alexey atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  // * * *.

  // Insert Leonid into a context.

  [context insertObject: leonid];

  [context processPendingChanges];

  // Android starts with 'A' and goes first.
  [verifyCount(delegate, atLeastOnce()) controller: SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: 0];

  [verify(delegate) controller: SFRC willChangeObject: leonid atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  [verify(delegate) controller: SFRC didChangeObject: leonid atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  // * * *.

  // Add Oleg to an exising employees.

  [context insertObject: oleg];

  [context processPendingChanges];

  // Java starts with 'J' and goes after iOS, but before OS X.
  [verifyCount(delegate, atLeastOnce()) controller: SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: 2];

  [verify(delegate) controller: SFRC willChangeObject: oleg atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  [verify(delegate) controller: SFRC didChangeObject: oleg atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  // * * *.

  // Insert Stas to an existing employees.

  [context insertObject: stas];

  [context processPendingChanges];

  [verify(delegate) controller: SFRC willChangeObject: stas atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 1 inSection: instanceOf([KSPTableSection class])];

  [verify(delegate) controller: SFRC didChangeObject: stas atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 1 inSection: instanceOf([KSPTableSection class])];

  // * * *.

  // Add Igor to an existing employees.

  [context insertObject: igor];

  [context processPendingChanges];

  [verifyCount(delegate, atLeastOnce()) controller: SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: 3];

  [verify(delegate) controller: SFRC willChangeObject: igor atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  [verify(delegate) controller: SFRC didChangeObject: igor atIndex: NSNotFound inSection: nil forChangeType: KSPFetchedResultsChangeInsert newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  // * * *.

  /*
   Current sections state:
   0 [Android]
   1 [iOS]
   2 [Java]
   3 [None]
   4 [OS X]
   */

  // * * *.

  [igor setValue: @"AAA None" forKey: @"platform"];

  [context processPendingChanges];

  [verify(delegate) controller: SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: 3 forChangeType: KSPSectionedFetchedResultsChangeMove newIndex: 0];

  // * * *.

  /*
   Current sections state:
   0 [AAA None]
   1 [Android]
   2 [iOS]
   3 [Java]
   4 [OS X]
   */

  // * * *.

  // Remove Stas, Oleg becomes a sole Java member.

  [context deleteObject: stas];

  [context processPendingChanges];

  [verify(delegate) controller: SFRC willChangeObject: stas atIndex: 1 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];

  [verify(delegate) controller: SFRC didChangeObject: stas atIndex: 1 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound inSection: nil];

  // * * *.

  // Remove the last Java-guy Oleg.

  [context deleteObject: oleg];

  [context processPendingChanges];

  [verify(delegate) controller: SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: 3 forChangeType: KSPSectionedFetchedResultsChangeDelete newIndex: NSNotFound];

  // * * *.

  /*
   Current sections state:
   0 [AAA None]
   1 [Android]
   2 [iOS]
   3 [OS X]
   */
}

@end
