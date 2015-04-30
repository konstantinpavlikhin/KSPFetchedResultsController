//
//  KSPSectionedFetchedResultsControllerExteriorMovesTest.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05/03/15.
//
//

#import <Cocoa/Cocoa.h>

#import <XCTest/XCTest.h>

// * * *.

#define HC_SHORTHAND

#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND

#import <OCMockito/OCMockito.h>

// * * *.

#import "KSPSectionedFetchedResultsController.h"

#import "KSPSectionedFetchedResultsControllerDelegate.h"

#import "KSPTableSection.h"

@interface KSPSectionedFetchedResultsControllerExteriorMovesTest : XCTestCase

@end

@implementation KSPSectionedFetchedResultsControllerExteriorMovesTest
{
  NSManagedObjectContext* _context;

  KSPSectionedFetchedResultsController* _SFRC;

  id<KSPSectionedFetchedResultsControllerDelegate> _delegate;

  NSDate *_date0, *_date1;

  NSManagedObject *_msg0, *_msg1, *_msg2, *_msg3, *_msg4, *_msg5, *_msg6, *_msg7;
}

#pragma mark - Core Data Helpers

+ (NSManagedObjectContext*) managedObjectContextForTests
{
  static NSManagedObjectModel* model = nil;

  if(!model)
  {
    NSURL* URL = [[NSBundle bundleForClass: self] URLForResource: @"TestModel" withExtension: @"mom"];

    model = [[NSManagedObjectModel alloc] initWithContentsOfURL: URL];
  }

  static NSManagedObjectContext* MOC = nil;

  if(!MOC)
  {
    NSPersistentStoreCoordinator* PSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: model];

    NSPersistentStore* store = [PSC addPersistentStoreWithType: NSInMemoryStoreType configuration: nil URL: nil options: nil error: nil];

    NSAssert(store, @"Should have a store by now.");

    MOC = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];

    MOC.persistentStoreCoordinator = PSC;

    MOC.undoManager = nil;
  }

  return MOC;
}

+ (NSManagedObject*) messageWithSequenceNumber: (NSUInteger) sequenceNumber text: (NSString*) text date: (NSDate*) date
{
  NSManagedObjectContext* MOC = [self managedObjectContextForTests];

  NSEntityDescription* entityDescription = [NSEntityDescription entityForName: @"Message" inManagedObjectContext: MOC];

  NSManagedObject* message = [[NSManagedObject alloc] initWithEntity: entityDescription insertIntoManagedObjectContext: nil];

  [message setValue: @(sequenceNumber) forKey: @"sequenceNumber"];

  [message setValue: text forKey: @"text"];

  [message setValue: date forKey: @"date"];

  return message;
}

#pragma mark - Setup & Teardown

- (void) setUp
{
  [super setUp];

  // * * *.

  _context = [[self class] managedObjectContextForTests];

  _date0 = [NSDate date];

  _msg0 = [[self class] messageWithSequenceNumber: 10 text: @"Here's to the crazy ones." date: _date0];

  [_context insertObject: _msg0];

  _msg1 = [[self class] messageWithSequenceNumber: 20 text: @"The misfits." date: _date0];

  [_context insertObject: _msg1];

  _msg2 = [[self class] messageWithSequenceNumber: 30 text: @"The rebels." date: _date0];

  [_context insertObject: _msg2];

  _msg3 = [[self class] messageWithSequenceNumber: 40 text: @"The troublemakers." date: _date0];

  [_context insertObject: _msg3];

  // * * *.

  _date1 = [NSDate dateWithTimeInterval: 1000 sinceDate: _date0];

  _msg4 = [[self class] messageWithSequenceNumber: 50 text: @"The round pegs in the square holes." date: _date1];

  [_context insertObject: _msg4];

  _msg5 = [[self class] messageWithSequenceNumber: 60 text: @"The ones who see things differently." date: _date1];

  [_context insertObject: _msg5];

  _msg6 = [[self class] messageWithSequenceNumber: 70 text: @"They're not fond of rules." date: _date1];

  [_context insertObject: _msg6];

  _msg7 = [[self class] messageWithSequenceNumber: 80 text: @"And they have no respect for the status quo." date: _date1];

  [_context insertObject: _msg7];

  // * * *.

  [_context processPendingChanges];

  // * * *.

  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName: @"Message"];

  fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"date" ascending: YES],

                                   [NSSortDescriptor sortDescriptorWithKey: @"sequenceNumber" ascending: YES]];

  // * * *.

  _SFRC = [[KSPSectionedFetchedResultsController alloc] initWithFetchRequest: fetchRequest managedObjectContext: _context sectionNameKeyPath: @"date"];

  // * * *.

  _delegate = mockProtocol(@protocol(KSPSectionedFetchedResultsControllerDelegate));

  _SFRC.delegate = _delegate;

  NSError* error;

  if(![_SFRC performFetch: &error])
  {
    NSLog(@"%@", error);
  }

  // * * *.

  XCTAssert(_SFRC.fetchedObjects.count == 8, @"fetchedObjects count should be 8.");
}

- (void) tearDown
{
  [[[self class] managedObjectContextForTests] reset];

  // * * *.

  [super tearDown];
}

#pragma mark - Tests

// ╔════════════════════════════════════════════════════╗
// ║                       _date0                       ║
// ╚════════════════════════════════════════════════════╝
// ┌────────────────────────────────────────────────────┐
// │ 0           Here's to the crazy ones.              │ @10
// └────────────────────────────────────────────────────┘
// ┌────────────────────────────────────────────────────┐
// │ 1                  The misfits.                    │ @20
// └────────────────────────────────────────────────────┘
// ┌────────────────────────────────────────────────────┐
// │ 2                  The rebels.                     │ @30
// └────────────────────────────────────────────────────┘
// ┌────────────────────────────────────────────────────┐
// │ 3               The troublemakers.                 │ @40
// └────────────────────────────────────────────────────┘
//
// ╔════════════════════════════════════════════════════╗
// ║                       _date1                       ║
// ╚════════════════════════════════════════════════════╝
// ┌────────────────────────────────────────────────────┐
// │ 4      The round pegs in the square holes.         │ @50
// └────────────────────────────────────────────────────┘
// ┌────────────────────────────────────────────────────┐
// │ 5      The ones who see things differently.        │ @60
// └────────────────────────────────────────────────────┘
// ┌────────────────────────────────────────────────────┐
// │ 6           They're not fond of rules.             │ @70
// └────────────────────────────────────────────────────┘
// ┌────────────────────────────────────────────────────┐
// │ 7  And they have no respect for the status quo.    │ @80
// └────────────────────────────────────────────────────┘

- (void) testSequentialMessageMoves
{
  {{
    // ╔════════════════════════════════════════════════════╗         ╔════════════════════════════════════════════════════╗
    // ║                       _date0                       ║         ║                       _date0                       ║
    // ╚════════════════════════════════════════════════════╝         ╚════════════════════════════════════════════════════╝
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓         ┌────────────────────────────────────────────────────┐
    // ┃ 0           Here's to the crazy ones.              ┃────┐    │ 1                  The misfits.                    │
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │    └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐    │    ┌────────────────────────────────────────────────────┐
    // │ 1                  The misfits.                    │    │    │ 2                  The rebels.                     │
    // └────────────────────────────────────────────────────┘    │    └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐    │    ┌────────────────────────────────────────────────────┐
    // │ 2                  The rebels.                     │    │    │ 3               The troublemakers.                 │
    // └────────────────────────────────────────────────────┘    │    └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐    │
    // │ 3               The troublemakers.                 │    │    ╔════════════════════════════════════════════════════╗
    // └────────────────────────────────────────────────────┘    │    ║                       _date1                       ║
    //                                                           │    ╚════════════════════════════════════════════════════╝
    // ╔════════════════════════════════════════════════════╗    │    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ║                       _date1                       ║    └───▶┃ 0           Here's to the crazy ones.              ┃ @10
    // ╚════════════════════════════════════════════════════╝         ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 4      The round pegs in the square holes.         │         │ 4      The round pegs in the square holes.         │ @50
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 5      The ones who see things differently.        │         │ 5      The ones who see things differently.        │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 6           They're not fond of rules.             │         │ 6           They're not fond of rules.             │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 7  And they have no respect for the status quo.    │         │ 7  And they have no respect for the status quo.    │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘

    [_msg0 setValue: _date1 forKey: @"date"];

    [_context processPendingChanges];

    // * * *.

    [verify(_delegate) controller: _SFRC willChangeObject: _msg0 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 0 inSection: instanceOf([KSPTableSection class])];

    [verify(_delegate) controller: _SFRC didChangeObject: _msg0 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 0 inSection: instanceOf([KSPTableSection class])];
  }}

  // * * *.

  {{
    // ╔════════════════════════════════════════════════════╗         ╔════════════════════════════════════════════════════╗
    // ║                       _date0                       ║         ║                       _date0                       ║
    // ╚════════════════════════════════════════════════════╝         ╚════════════════════════════════════════════════════╝
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 1                  The misfits.                    │         │ 1                  The misfits.                    │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 2                  The rebels.                     │         │ 2                  The rebels.                     │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃ 3               The troublemakers.                 ┃────┐    ╔════════════════════════════════════════════════════╗
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │    ║                       _date1                       ║
    //                                                           │    ╚════════════════════════════════════════════════════╝
    // ╔════════════════════════════════════════════════════╗    │    ┌────────────────────────────────────────────────────┐
    // ║                       _date1                       ║    │    │ 0           Here's to the crazy ones.              │ @10
    // ╚════════════════════════════════════════════════════╝    │    └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐    │    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // │ 0           Here's to the crazy ones.              │    └───▶┃ 3               The troublemakers.                 ┃ @40
    // └────────────────────────────────────────────────────┘         ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 4      The round pegs in the square holes.         │         │ 4      The round pegs in the square holes.         │ @50
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 5      The ones who see things differently.        │         │ 5      The ones who see things differently.        │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 6           They're not fond of rules.             │         │ 6           They're not fond of rules.             │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 7  And they have no respect for the status quo.    │         │ 7  And they have no respect for the status quo.    │
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘

    [_msg3 setValue: _date1 forKey: @"date"];

    [_context processPendingChanges];

    // * * *.

    [verify(_delegate) controller: _SFRC willChangeObject: _msg3 atIndex: 2 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 1 inSection: instanceOf([KSPTableSection class])];

    [verify(_delegate) controller: _SFRC didChangeObject: _msg3 atIndex: 2 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 1 inSection: instanceOf([KSPTableSection class])];
  }}

  // * * *.

  {{
    // ╔════════════════════════════════════════════════════╗         ╔════════════════════════════════════════════════════╗
    // ║                       _date0                       ║         ║                       _date0                       ║
    // ╚════════════════════════════════════════════════════╝         ╚════════════════════════════════════════════════════╝
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓         ┌────────────────────────────────────────────────────┐
    // ┃ 1                  The misfits.                    ┃────┐    │ 2                  The rebels.                     │
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │    └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐    │
    // │ 2                  The rebels.                     │    │    ╔════════════════════════════════════════════════════╗
    // └────────────────────────────────────────────────────┘    │    ║                       _date1                       ║
    //                                                           │    ╚════════════════════════════════════════════════════╝
    // ╔════════════════════════════════════════════════════╗    │    ┌────────────────────────────────────────────────────┐
    // ║                       _date1                       ║    │    │ 0           Here's to the crazy ones.              │ @10
    // ╚════════════════════════════════════════════════════╝    │    └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐    │    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // │ 0           Here's to the crazy ones.              │    └───▶┃ 1                  The misfits.                    ┃ @20
    // └────────────────────────────────────────────────────┘         ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 3               The troublemakers.                 │         │ 3               The troublemakers.                 │ @40
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 4      The round pegs in the square holes.         │         │ 4      The round pegs in the square holes.         │ @50
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 5      The ones who see things differently.        │         │ 5      The ones who see things differently.        │ @60
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 6           They're not fond of rules.             │         │ 6           They're not fond of rules.             │ @70
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐         ┌────────────────────────────────────────────────────┐
    // │ 7  And they have no respect for the status quo.    │         │ 7  And they have no respect for the status quo.    │ @80
    // └────────────────────────────────────────────────────┘         └────────────────────────────────────────────────────┘

    [_msg1 setValue: _date1 forKey: @"date"];

    [_context processPendingChanges];

    // * * *.

    [verify(_delegate) controller: _SFRC willChangeObject: _msg1 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 1 inSection: instanceOf([KSPTableSection class])];

    [verify(_delegate) controller: _SFRC didChangeObject: _msg1 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 1 inSection: instanceOf([KSPTableSection class])];
  }}

  // * * *.

  {{
    // ╔════════════════════════════════════════════════════╗         ╔════════════════════════════════════════════════════╗
    // ║                       _date0                       ║         ║                       _date1                       ║
    // ╚════════════════════════════════════════════════════╝         ╚════════════════════════════════════════════════════╝
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓         ┌────────────────────────────────────────────────────┐
    // ┃ 2                  The rebels.                     ┃────┐    │ 0           Here's to the crazy ones.              │ @10
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │    └────────────────────────────────────────────────────┘
    //                                                           │    ┌────────────────────────────────────────────────────┐
    // ╔════════════════════════════════════════════════════╗    │    │ 1                  The misfits.                    │ @20
    // ║                       _date1                       ║    │    └────────────────────────────────────────────────────┘
    // ╚════════════════════════════════════════════════════╝    │    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┌────────────────────────────────────────────────────┐    └───▶┃ 2                  The rebels.                     ┃ @30
    // │ 0           Here's to the crazy ones.              │         ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    // └────────────────────────────────────────────────────┘         ┌────────────────────────────────────────────────────┐
    // ┌────────────────────────────────────────────────────┐         │ 3               The troublemakers.                 │ @40
    // │ 1                  The misfits.                    │         └────────────────────────────────────────────────────┘
    // └────────────────────────────────────────────────────┘         ┌────────────────────────────────────────────────────┐
    // ┌────────────────────────────────────────────────────┐         │ 4      The round pegs in the square holes.         │ @50
    // │ 3               The troublemakers.                 │         └────────────────────────────────────────────────────┘
    // └────────────────────────────────────────────────────┘         ┌────────────────────────────────────────────────────┐
    // ┌────────────────────────────────────────────────────┐         │ 5      The ones who see things differently.        │ @60
    // │ 4      The round pegs in the square holes.         │         └────────────────────────────────────────────────────┘
    // └────────────────────────────────────────────────────┘         ┌────────────────────────────────────────────────────┐
    // ┌────────────────────────────────────────────────────┐         │ 6           They're not fond of rules.             │ @70
    // │ 5      The ones who see things differently.        │         └────────────────────────────────────────────────────┘
    // └────────────────────────────────────────────────────┘         ┌────────────────────────────────────────────────────┐
    // ┌────────────────────────────────────────────────────┐         │ 7  And they have no respect for the status quo.    │ @80
    // │ 6           They're not fond of rules.             │         └────────────────────────────────────────────────────┘
    // └────────────────────────────────────────────────────┘
    // ┌────────────────────────────────────────────────────┐
    // │ 7  And they have no respect for the status quo.    │
    // └────────────────────────────────────────────────────┘

    [_msg2 setValue: _date1 forKey: @"date"];

    [_context processPendingChanges];

    // * * *.

    [verify(_delegate) controller: _SFRC willChangeObject: _msg2 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 2 inSection: instanceOf([KSPTableSection class])];

    [verify(_delegate) controller: _SFRC didChangeObject: _msg2 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 2 inSection: instanceOf([KSPTableSection class])];

    [verify(_delegate) controller: _SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: 0 forChangeType: KSPSectionedFetchedResultsChangeDelete newIndex: NSNotFound];
  }}

  // * * *.

  {{
    // ╔════════════════════════════════════════════════════╗         ╔════════════════════════════════════════════════════╗
    // ║                       _date1                       ║         ║                       _date0                       ║
    // ╚════════════════════════════════════════════════════╝         ╚════════════════════════════════════════════════════╝
    // ┌────────────────────────────────────────────────────┐         ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // │ 0           Here's to the crazy ones.              │    ┌───▶┃ 7  And they have no respect for the status quo.    ┃
    // └────────────────────────────────────────────────────┘    │    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    // ┌────────────────────────────────────────────────────┐    │
    // │ 1                  The misfits.                    │    │    ╔════════════════════════════════════════════════════╗
    // └────────────────────────────────────────────────────┘    │    ║                       _date1                       ║
    // ┌────────────────────────────────────────────────────┐    │    ╚════════════════════════════════════════════════════╝
    // │ 2                  The rebels.                     │    │    ┌────────────────────────────────────────────────────┐
    // └────────────────────────────────────────────────────┘    │    │ 0           Here's to the crazy ones.              │
    // ┌────────────────────────────────────────────────────┐    │    └────────────────────────────────────────────────────┘
    // │ 3               The troublemakers.                 │    │    ┌────────────────────────────────────────────────────┐
    // └────────────────────────────────────────────────────┘    │    │ 1                  The misfits.                    │
    // ┌────────────────────────────────────────────────────┐    │    └────────────────────────────────────────────────────┘
    // │ 4      The round pegs in the square holes.         │    │    ┌────────────────────────────────────────────────────┐
    // └────────────────────────────────────────────────────┘    │    │ 2                  The rebels.                     │
    // ┌────────────────────────────────────────────────────┐    │    └────────────────────────────────────────────────────┘
    // │ 5      The ones who see things differently.        │    │    ┌────────────────────────────────────────────────────┐
    // └────────────────────────────────────────────────────┘    │    │ 3               The troublemakers.                 │
    // ┌────────────────────────────────────────────────────┐    │    └────────────────────────────────────────────────────┘
    // │ 6           They're not fond of rules.             │    │    ┌────────────────────────────────────────────────────┐
    // └────────────────────────────────────────────────────┘    │    │ 4      The round pegs in the square holes.         │
    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │    └────────────────────────────────────────────────────┘
    // ┃ 7  And they have no respect for the status quo.    ┃────┘    ┌────────────────────────────────────────────────────┐
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛         │ 5      The ones who see things differently.        │
    //                                                                └────────────────────────────────────────────────────┘
    //                                                                ┌────────────────────────────────────────────────────┐
    //                                                                │ 6           They're not fond of rules.             │
    //                                                                └────────────────────────────────────────────────────┘

    [_msg7 setValue: _date0 forKey: @"date"];

    [_context processPendingChanges];

    // * * *.

    [verify(_delegate) controller: _SFRC didChangeSection: instanceOf([KSPTableSection class]) atIndex: NSNotFound forChangeType: KSPSectionedFetchedResultsChangeInsert newIndex: 0];

    [verify(_delegate) controller: _SFRC willChangeObject: _msg7 atIndex: 7 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 0 inSection: instanceOf([KSPTableSection class])];

    [verify(_delegate) controller: _SFRC didChangeObject: _msg7 atIndex: 7 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 0 inSection: instanceOf([KSPTableSection class])];
  }}
}

@end
