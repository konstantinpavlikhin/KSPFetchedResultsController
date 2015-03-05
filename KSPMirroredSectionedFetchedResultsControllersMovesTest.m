//
//  KSPMirroredSectionedFetchedResultsControllersMovesTest.m
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

#import "KSPMirroredSectionedFetchedResultsController.h"

#import "KSPSectionedFetchedResultsControllerDelegate.h"

#import "KSPTableSection.h"

static const NSUInteger DummyUnsignedInteger = 888;

@interface KSPMirroredSectionedFetchedResultsControllersMovesTest : XCTestCase

@end

@implementation KSPMirroredSectionedFetchedResultsControllersMovesTest
{
  NSManagedObjectContext* _context;

  KSPMirroredSectionedFetchedResultsController* _MSFRC;

  id<KSPSectionedFetchedResultsControllerDelegate> _delegate;

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

  NSDate* date = [NSDate date];

  _msg0 = [[self class] messageWithSequenceNumber: 10 text: @"Here's to the crazy ones." date: date];

  [_context insertObject: _msg0];

  _msg1 = [[self class] messageWithSequenceNumber: 20 text: @"The misfits." date: date];

  [_context insertObject: _msg1];

  _msg2 = [[self class] messageWithSequenceNumber: 30 text: @"The rebels." date: date];

  [_context insertObject: _msg2];

  _msg3 = [[self class] messageWithSequenceNumber: 40 text: @"The troublemakers." date: date];

  [_context insertObject: _msg3];

  _msg4 = [[self class] messageWithSequenceNumber: 50 text: @"The round pegs in the square holes." date: date];

  [_context insertObject: _msg4];

  _msg5 = [[self class] messageWithSequenceNumber: 60 text: @"The ones who see things differently." date: date];

  [_context insertObject: _msg5];

  _msg6 = [[self class] messageWithSequenceNumber: 70 text: @"They're not fond of rules." date: date];

  [_context insertObject: _msg6];

  _msg7 = [[self class] messageWithSequenceNumber: 80 text: @"And they have no respect for the status quo." date: date];

  [_context insertObject: _msg7];

  // * * *.

  [_context processPendingChanges];

  // * * *.

  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] initWithEntityName: @"Message"];

  fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"sequenceNumber" ascending: YES]];

  // * * *.

  _MSFRC = [[KSPMirroredSectionedFetchedResultsController alloc] initWithFetchRequest: fetchRequest managedObjectContext: _context sectionNameKeyPath: @"date"];

  // * * *.

  _delegate = mockProtocol(@protocol(KSPSectionedFetchedResultsControllerDelegate));

  _MSFRC.delegate = _delegate;

  NSError* error;

  if(![_MSFRC performFetch: &error])
  {
    NSLog(@"%@", error);
  }

  // * * *.

  XCTAssert(_MSFRC.mirroredFetchedObjects.count == 8, @"fetchedObjects count should be 8.");
}

- (void) tearDown
{
  [[[self class] managedObjectContextForTests] reset];

  // * * *.

  [super tearDown];
}

#pragma mark - Adjacent

//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 0           Here's to the crazy ones.              │          │ 0           Here's to the crazy ones.              │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 1                  The misfits.                    │          │ 1                  The misfits.                    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 2                  The rebels.                     │          │ 2                  The rebels.                     │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓          ┌────────────────────────────────────────────────────┐
//┃ 3               The troublemakers.                 ┃────┐     │ 4      The round pegs in the square holes.         │
//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//│ 4      The round pegs in the square holes.         │    └────▶┃ 3               The troublemakers.                 ┃
//└────────────────────────────────────────────────────┘          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 5      The ones who see things differently.        │          │ 5      The ones who see things differently.        │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 6           They're not fond of rules.             │          │ 6           They're not fond of rules.             │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 7  And they have no respect for the status quo.    │          │ 7  And they have no respect for the status quo.    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘

- (void) testAdjacentMessagesMoveDown
{
  [_msg3 setValue: @55 forKey: @"sequenceNumber"];

  [_context processPendingChanges];

  // * * *.

  [verify(_delegate) controller: _MSFRC willChangeObject: _msg3 atIndex: 4 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 3 inSection: instanceOf([KSPTableSection class])];

  [verify(_delegate) controller: _MSFRC didChangeObject: _msg3 atIndex: 4 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 3 inSection: instanceOf([KSPTableSection class])];
}

//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 0           Here's to the crazy ones.              │          │ 0           Here's to the crazy ones.              │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 1                  The misfits.                    │          │ 1                  The misfits.                    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 2                  The rebels.                     │          │ 2                  The rebels.                     │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//│ 3               The troublemakers.                 │    ┌────▶┃ 4      The round pegs in the square holes.         ┃
//└────────────────────────────────────────────────────┘    │     ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │     ┌────────────────────────────────────────────────────┐
//┃ 4      The round pegs in the square holes.         ┃────┘     │ 3               The troublemakers.                 │
//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 5      The ones who see things differently.        │          │ 5      The ones who see things differently.        │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 6           They're not fond of rules.             │          │ 6           They're not fond of rules.             │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 7  And they have no respect for the status quo.    │          │ 7  And they have no respect for the status quo.    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘

- (void) testAdjacentMessagesMoveUp
{
  [_msg4 setValue: @35 forKey: @"sequenceNumber"];

  [_context processPendingChanges];

  // * * *.

  [verify(_delegate) controller: _MSFRC willChangeObject: _msg4 atIndex: 3 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 4 inSection: instanceOf([KSPTableSection class])];

  [verify(_delegate) controller: _MSFRC didChangeObject: _msg4 atIndex: 3 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 4 inSection: instanceOf([KSPTableSection class])];
}

#pragma mark - Close Enough

//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 0           Here's to the crazy ones.              │          │ 0           Here's to the crazy ones.              │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 1                  The misfits.                    │          │ 1                  The misfits.                    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓          ┌────────────────────────────────────────────────────┐
//┃ 2                  The rebels.                     ┃────┐     │ 3               The troublemakers.                 │
//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 3               The troublemakers.                 │    │     │ 4      The round pegs in the square holes.         │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//│ 4      The round pegs in the square holes.         │    └────▶┃ 2                  The rebels.                     ┃
//└────────────────────────────────────────────────────┘          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 5      The ones who see things differently.        │          │ 5      The ones who see things differently.        │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 6           They're not fond of rules.             │          │ 6           They're not fond of rules.             │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 7  And they have no respect for the status quo.    │          │ 7  And they have no respect for the status quo.    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘

- (void) testCloseEnoughMoveDown
{
  [_msg2 setValue: @55 forKey: @"sequenceNumber"];

  [_context processPendingChanges];

  // * * *.

  [verify(_delegate) controller: _MSFRC willChangeObject: _msg2 atIndex: 5 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 3 inSection: instanceOf([KSPTableSection class])];

  [verify(_delegate) controller: _MSFRC didChangeObject: _msg2 atIndex: 5 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 3 inSection: instanceOf([KSPTableSection class])];
}

//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 0           Here's to the crazy ones.              │          │ 0           Here's to the crazy ones.              │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 1                  The misfits.                    │          │ 1                  The misfits.                    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//│ 2                  The rebels.                     │    ┌────▶┃ 6           They're not fond of rules.             ┃
//└────────────────────────────────────────────────────┘    │     ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 3               The troublemakers.                 │    │     │ 2                  The rebels.                     │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 4      The round pegs in the square holes.         │    │     │ 3               The troublemakers.                 │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 5      The ones who see things differently.        │    │     │ 4      The round pegs in the square holes.         │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │     ┌────────────────────────────────────────────────────┐
//┃ 6           They're not fond of rules.             ┃────┘     │ 5      The ones who see things differently.        │
//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛          └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐          ┌────────────────────────────────────────────────────┐
//│ 7  And they have no respect for the status quo.    │          │ 7  And they have no respect for the status quo.    │
//└────────────────────────────────────────────────────┘          └────────────────────────────────────────────────────┘

- (void) testCloseEnoughMoveUp
{
  [_msg6 setValue: @25 forKey: @"sequenceNumber"];

  [_context processPendingChanges];

  // * * *.

  [verify(_delegate) controller: _MSFRC willChangeObject: _msg6 atIndex: 1 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 5 inSection: instanceOf([KSPTableSection class])];

  [verify(_delegate) controller: _MSFRC didChangeObject: _msg6 atIndex: 1 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 5 inSection: instanceOf([KSPTableSection class])];
}

#pragma mark - Outermost

//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓          ┌────────────────────────────────────────────────────┐
//┃ 0           Here's to the crazy ones.              ┃────┐     │ 1                  The misfits.                    │
//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 1                  The misfits.                    │    │     │ 2                  The rebels.                     │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 2                  The rebels.                     │    │     │ 3               The troublemakers.                 │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 3               The troublemakers.                 │    │     │ 4      The round pegs in the square holes.         │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 4      The round pegs in the square holes.         │    │     │ 5      The ones who see things differently.        │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 5      The ones who see things differently.        │    │     │ 6           They're not fond of rules.             │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 6           They're not fond of rules.             │    │     │ 7  And they have no respect for the status quo.    │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//│ 7  And they have no respect for the status quo.    │    └────▶┃ 0           Here's to the crazy ones.              ┃
//└────────────────────────────────────────────────────┘          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

- (void) testOutermostMessageMoveDown
{
  [_msg0 setValue: @90 forKey: @"sequenceNumber"];

  [_context processPendingChanges];

  // * * *.

  [verify(_delegate) controller: _MSFRC willChangeObject: _msg0 atIndex: 7 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 0 inSection: instanceOf([KSPTableSection class])];

  [verify(_delegate) controller: _MSFRC didChangeObject: _msg0 atIndex: 7 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 0 inSection: instanceOf([KSPTableSection class])];
}

//┌────────────────────────────────────────────────────┐          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
//│ 0           Here's to the crazy ones.              │    ┌────▶┃ 7  And they have no respect for the status quo.    ┃
//└────────────────────────────────────────────────────┘    │     ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 1                  The misfits.                    │    │     │ 0           Here's to the crazy ones.              │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 2                  The rebels.                     │    │     │ 1                  The misfits.                    │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 3               The troublemakers.                 │    │     │ 2                  The rebels.                     │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 4      The round pegs in the square holes.         │    │     │ 3               The troublemakers.                 │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 5      The ones who see things differently.        │    │     │ 4      The round pegs in the square holes.         │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┌────────────────────────────────────────────────────┐    │     ┌────────────────────────────────────────────────────┐
//│ 6           They're not fond of rules.             │    │     │ 5      The ones who see things differently.        │
//└────────────────────────────────────────────────────┘    │     └────────────────────────────────────────────────────┘
//┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │     ┌────────────────────────────────────────────────────┐
//┃ 7  And they have no respect for the status quo.    ┃────┘     │ 6           They're not fond of rules.             │
//┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛          └────────────────────────────────────────────────────┘

- (void) testOutermostMessageMoveUp
{
  [_msg7 setValue: @0 forKey: @"sequenceNumber"];

  [_context processPendingChanges];

  // * * *.

  [verify(_delegate) controller: _MSFRC willChangeObject: _msg7 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 7 inSection: instanceOf([KSPTableSection class])];

  [verify(_delegate) controller: _MSFRC didChangeObject: _msg7 atIndex: 0 inSection: instanceOf([KSPTableSection class]) forChangeType: KSPFetchedResultsChangeMove newIndex: 7 inSection: instanceOf([KSPTableSection class])];
}

@end
