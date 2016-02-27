//
//  KSPFetchedResultsController+Private.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsController.h"

@interface KSPFetchedResultsController ()

@property(readwrite, nonatomic, nonnull) NSFetchRequest* fetchRequest;

@property(readwrite, nonatomic, nonnull) NSManagedObjectContext* managedObjectContext;

- (nullable NSArray<__kindof NSManagedObject*>*) fetchedObjectsNoCopy;

- (void) observeValueForKeyPath: (nullable NSString*) keyPath ofObject: (nullable id) object change: (nullable NSDictionary*) change context: (nullable void*) context NS_REQUIRES_SUPER;

- (void) willChangeContent;

- (void) didInsertObject: (nonnull NSManagedObject*) insertedObject atIndex: (NSUInteger) insertedObjectIndex;

- (void) didDeleteObject: (nonnull NSManagedObject*) deletedObject atIndex: (NSUInteger) deletedObjectIndex;

- (void) didMoveObject: (nonnull NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex;

- (void) didUpdateObject: (nonnull NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex;

- (void) didChangeContent;

@end
