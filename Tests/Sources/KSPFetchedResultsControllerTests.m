//
//  KSPFetchedResultsControllerTests.m
//  KSPFetchedResultsController Tests
//
//  Created by Konstantin Pavlikhin on 26.11.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import "KSPFetchedResultsController.h"

#import "KSPFetchedResultsControllerDelegate.h"

@interface KSPFetchedResultsControllerTests : XCTestCase

@end

@implementation KSPFetchedResultsControllerTests

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

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testFRCWillChangeDidChange
{
  NSFetchRequest* fetchRequest = [NSFetchRequest fetchRequestWithEntityName: @"Employee"];

  NSManagedObjectContext* context = [[self class] managedObjectContextForTests];

  KSPFetchedResultsController* FRC = [[KSPFetchedResultsController alloc] initWithFetchRequest: fetchRequest managedObjectContext: context];

  id<KSPFetchedResultsControllerDelegate> delegate = mockProtocol(@protocol(KSPFetchedResultsControllerDelegate));

  FRC.delegate = delegate;

  NSError* error;

  if(![FRC performFetch: &error])
  {
    NSLog(@"%@", error);
  }

  XCTAssert(FRC.fetchedObjects.count == 0, @"FUCK");

  [NSEntityDescription insertNewObjectForEntityForName: @"Employee" inManagedObjectContext: context];

  [context processPendingChanges];

  XCTAssert(FRC.fetchedObjects.count == 1, @"FUCK");

  [verify(delegate) controllerWillChangeContent: FRC];

  [verify(delegate) controllerDidChangeContent: FRC];
}

/// Returns a new Employee instance unassociated with any managed object context.
+ (NSManagedObject*) employeeWithName: (NSString*) name salary: (NSNumber*) salary
{
  NSManagedObjectContext* MOC = [self managedObjectContextForTests];

  NSEntityDescription* entityDescription = [NSEntityDescription entityForName: @"Employee" inManagedObjectContext: MOC];

  NSManagedObject* employee = [[NSManagedObject alloc] initWithEntity: entityDescription insertIntoManagedObjectContext: nil];

  [employee setValue: name forKey: @"name"];

  [employee setValue: salary forKey: @"salary"];

  return employee;
}

+ (NSFetchRequest*) fetchRequestForEmployeesSortedByAscendingSalary
{
  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName: @"Employee"];

  fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"salary" ascending: YES]];

  return fetchRequest;
}

- (void) testObjectInsert
{
  NSFetchRequest* fetchRequest = [[self class] fetchRequestForEmployeesSortedByAscendingSalary];

  NSManagedObjectContext* context = [[self class] managedObjectContextForTests];

  KSPFetchedResultsController* FRC = [[KSPFetchedResultsController alloc] initWithFetchRequest: fetchRequest managedObjectContext: context];

  // * * *.

  id<KSPFetchedResultsControllerDelegate> delegate = mockProtocol(@protocol(KSPFetchedResultsControllerDelegate));

  FRC.delegate = delegate;

  NSError* error;

  if(![FRC performFetch: &error]) NSLog(@"%@", error);

  // * * *.

  XCTAssert(FRC.fetchedObjects.count == 0, @"fetchedObjects count should be 0.");

  // New object inserted.

  NSManagedObject* employee = [[self class] employeeWithName: @"Konstantin" salary: @(100)];

  [context insertObject: employee];

  [context processPendingChanges];

  [verify(delegate) controllerWillChangeContent: FRC];

  [[verify(delegate) withMatcher: equalToUnsignedInteger(0) forArgument: 4] controller: FRC willChangeObject: employee atIndex: NSNotFound forChangeType: KSPFetchedResultsChangeInsert newIndex: 0];

  [[verify(delegate) withMatcher: equalToUnsignedInteger(0) forArgument: 4] controller: FRC didChangeObject: employee atIndex: NSNotFound forChangeType: KSPFetchedResultsChangeInsert newIndex: 0];

  [verify(delegate) controllerDidChangeContent: FRC];

  XCTAssert(FRC.fetchedObjects.count == 1, @"fetchedObjects count should be 1.");

  // * * *.

  // Existing object updated.

  [employee setValue: @(200) forKey: @"salary"];

  [context processPendingChanges];

  [verify(delegate) controller: FRC willChangeObject: employee atIndex: 0 forChangeType: KSPFetchedResultsChangeUpdate newIndex: NSNotFound];

  [verify(delegate) controller: FRC didChangeObject: employee atIndex: 0 forChangeType: KSPFetchedResultsChangeUpdate newIndex: NSNotFound];

  // * * *.

  // Existing object moved.

  NSManagedObject* steve = [[self class] employeeWithName: @"Steve" salary: @500];

  [context insertObject: steve];

  [context processPendingChanges];

  [verify(delegate) controller: FRC willChangeObject: steve atIndex: NSNotFound forChangeType: KSPFetchedResultsChangeInsert newIndex: 1];

  [verify(delegate) controller: FRC didChangeObject: steve atIndex: NSNotFound forChangeType: KSPFetchedResultsChangeInsert newIndex: 1];

  [employee setValue: @800 forKey: @"salary"];

  [context processPendingChanges];

  [verify(delegate) controller: FRC willChangeObject: employee atIndex: 0 forChangeType: KSPFetchedResultsChangeMove newIndex: 1];

  [verify(delegate) controller: FRC didChangeObject: employee atIndex: 0 forChangeType: KSPFetchedResultsChangeMove newIndex: 1];

  // * * *.

  // Existing object deleted.

  [context deleteObject: employee];

  [context processPendingChanges];

  [verify(delegate) controller: FRC willChangeObject: employee atIndex: 1 forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound];

  [verify(delegate) controller: FRC didChangeObject: employee atIndex: 1 forChangeType: KSPFetchedResultsChangeDelete newIndex: NSNotFound];
}

- (void) testMultipleSimultaneousUpdates
{
  NSFetchRequest* const fetchRequest = [[self class] fetchRequestForEmployeesSortedByAscendingSalary];

  NSManagedObjectContext* const context = [[self class] managedObjectContextForTests];

  KSPFetchedResultsController* const FRC = [[KSPFetchedResultsController alloc] initWithFetchRequest: fetchRequest managedObjectContext: context];

  // * * *.

  id<KSPFetchedResultsControllerDelegate> const delegate = mockProtocol(@protocol(KSPFetchedResultsControllerDelegate));

  FRC.delegate = delegate;

  NSError* error;

  if(![FRC performFetch: &error]) NSLog(@"%@", error);

  // * * *.

  NSMutableArray* const employees = [NSMutableArray array];

  for(NSUInteger i = 0; i < 1000; i++)
  {
    NSManagedObject* const employee = [[self class] employeeWithName: [@(i) description] salary: @(i)];

    [employees addObject: employee];

    [context insertObject: employee];
  }

  [context processPendingChanges];

  // * * *.

  [employees enumerateObjectsUsingBlock: ^(NSManagedObject* _Nonnull const employee, const NSUInteger idx, BOOL* _Nonnull stop)
  {
    [employee setValue: @(employees.count - idx) forKey: @"salary"];
  }];

  [context processPendingChanges];
}

- (void) testMoveCausedBySingleObjectUpdate
{
  NSFetchRequest* const fetchRequest = [[self class] fetchRequestForEmployeesSortedByAscendingSalary];

  NSManagedObjectContext* const context = [[self class] managedObjectContextForTests];

  KSPFetchedResultsController* const FRC = [[KSPFetchedResultsController alloc] initWithFetchRequest: fetchRequest managedObjectContext: context];

  // * * *.

  id<KSPFetchedResultsControllerDelegate> const delegate = mockProtocol(@protocol(KSPFetchedResultsControllerDelegate));

  FRC.delegate = delegate;

  NSError* error;

  if(![FRC performFetch: &error]) NSLog(@"%@", error);

  // * * *.

  NSManagedObject* const employeeA = [[self class] employeeWithName: @"A" salary: @(100)];

  [context insertObject: employeeA];

  // * * *.

  NSManagedObject* const employeeB = [[self class] employeeWithName: @"B" salary: @(200)];

  [context insertObject: employeeB];

  // * * *.

  NSManagedObject* const employeeC = [[self class] employeeWithName: @"C" salary: @(300)];

  [context insertObject: employeeC];

  // * * *.

  [context processPendingChanges];

  // * * *.

  [employeeB setValue: @(50) forKey: @"salary"];

  // * * *.

  [context processPendingChanges];

  // * * *.

  [verify(delegate) controller: FRC willChangeObject: employeeB atIndex: 1 forChangeType: KSPFetchedResultsChangeUpdate newIndex: NSNotFound];

  [verify(delegate) controller: FRC didChangeObject: employeeB atIndex: 1 forChangeType: KSPFetchedResultsChangeUpdate newIndex: NSNotFound];

  [verify(delegate) controller: FRC willChangeObject: employeeB atIndex: 1 forChangeType: KSPFetchedResultsChangeMove newIndex: 0];

  [verify(delegate) controller: FRC didChangeObject: employeeB atIndex: 1 forChangeType: KSPFetchedResultsChangeMove newIndex: 0];
}

@end
