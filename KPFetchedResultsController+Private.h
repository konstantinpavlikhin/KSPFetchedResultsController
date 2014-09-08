//
//  KPFetchedResultsController+Private.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPFetchedResultsController.h"

@interface KPFetchedResultsController ()

@property(readwrite, nonatomic) NSFetchRequest* fetchRequest;

@property(readwrite, nonatomic) NSManagedObjectContext* managedObjectContext;

- (void) willChangeContent;

- (void) didInsertObject: (NSManagedObject*) insertedObject atIndex: (NSUInteger) insertedObjectIndex;

- (void) didDeleteObject: (NSManagedObject*) deletedObject atIndex: (NSUInteger) deletedObjectIndex;

- (void) didMoveObject: (NSManagedObject*) movedObject atIndex: (NSUInteger) oldIndex toIndex: (NSUInteger) newIndex;

- (void) didUpdateObject: (NSManagedObject*) updatedObject atIndex: (NSUInteger) updatedObjectIndex;

- (void) didChangeContent;

@end
